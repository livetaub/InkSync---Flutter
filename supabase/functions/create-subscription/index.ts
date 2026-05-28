// supabase/functions/create-subscription/index.ts
//
// Supabase Edge Function: Create Stripe Subscription
//
// This is the "brain" of the billing system. It:
// 1. Receives a PaymentMethod token + plan selection from the Flutter app
// 2. Reads the EXACT price from the global_pricing table (dynamic pricing)
// 3. Creates a Stripe Customer + attaches the card
// 4. Creates a Stripe Subscription at the database-driven price
// 5. Returns the subscription status to the app
//
// The user's card details NEVER touch this function — only a secure token.
//
// ENVIRONMENT VARIABLES REQUIRED:
//   STRIPE_SECRET_KEY          = sk_test_... or sk_live_...
//   STRIPE_PRODUCT_PREMIUM     = prod_... (Stripe Product ID for Premium)
//   STRIPE_PRODUCT_PRO         = prod_... (Stripe Product ID for Premium Pro)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Initialize Stripe ──────────────────────────────────
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
      apiVersion: "2023-10-16",
      httpClient: Stripe.createFetchHttpClient(),
    });

    // ── 2. Authenticate the Supabase user ─────────────────────
    const authHeader = req.headers.get("Authorization")!;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── 3. Parse request body ─────────────────────────────────
    const { paymentMethodId, plan, period } = await req.json();
    // paymentMethodId: "pm_..." from Stripe.js
    // plan: "premium" | "premium_pro"
    // period: "monthly" | "yearly"

    if (!paymentMethodId || !plan || !period) {
      return new Response(
        JSON.stringify({ error: "Missing paymentMethodId, plan, or period" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── 4. Read price from global_pricing table ───────────────
    // This is the magic: pricing is 100% controlled from your database
    const adminSupabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: pricingRow, error: pricingError } = await adminSupabase
      .from("global_pricing")
      .select("price_monthly, price_yearly")
      .eq("plan_id", plan)
      .single();

    if (pricingError || !pricingRow) {
      return new Response(
        JSON.stringify({ error: `Plan not found: ${plan}` }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Get the correct price and convert to cents (Stripe uses cents)
    const priceAmount =
      period === "yearly"
        ? Math.round(pricingRow.price_yearly * 100)
        : Math.round(pricingRow.price_monthly * 100);

    const interval = period === "yearly" ? "year" : "month";

    // Map plan to Stripe Product ID
    const productId =
      plan === "premium_pro"
        ? Deno.env.get("STRIPE_PRODUCT_PRO")!
        : Deno.env.get("STRIPE_PRODUCT_PREMIUM")!;

    console.log(
      `Creating subscription: ${plan} ${period} at $${priceAmount / 100}/${interval}`
    );

    // ── 5. Get or create Stripe Customer ──────────────────────
    const { data: profile } = await adminSupabase
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .single();

    let customerId = profile?.stripe_customer_id;

    if (!customerId) {
      // Create a new Stripe Customer
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;

      // Save to profiles
      await adminSupabase
        .from("profiles")
        .update({ stripe_customer_id: customerId })
        .eq("id", user.id);
    }

    // ── 6. Attach PaymentMethod to Customer ───────────────────
    await stripe.paymentMethods.attach(paymentMethodId, {
      customer: customerId,
    });

    // Set as default payment method
    await stripe.customers.update(customerId, {
      invoice_settings: {
        default_payment_method: paymentMethodId,
      },
    });

    // ── 7. Create a dynamic Price using database values ───────
    const price = await stripe.prices.create({
      product: productId,
      unit_amount: priceAmount,
      currency: "usd",
      recurring: { interval: interval },
    });

    // ── 8. Create the Subscription ────────────────────────────
    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: price.id }],
      default_payment_method: paymentMethodId,
      payment_behavior: "default_incomplete",
      payment_settings: {
        save_default_payment_method: "on_subscription",
      },
      expand: ["latest_invoice.payment_intent"],
      metadata: {
        supabase_user_id: user.id,
        plan: plan,
      },
    });

    // ── 9. Handle the result ──────────────────────────────────
    const invoice = subscription.latest_invoice as Stripe.Invoice;
    const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;

    if (
      subscription.status === "active" ||
      paymentIntent?.status === "succeeded"
    ) {
      // Payment succeeded immediately — activate the subscription
      const periodEnd = new Date(
        subscription.current_period_end * 1000
      ).toISOString();

      await adminSupabase
        .from("profiles")
        .update({
          account_type: plan,
          stripe_subscription_id: subscription.id,
          subscription_status: "active",
          subscription_period_end: periodEnd,
        })
        .eq("id", user.id);

      return new Response(
        JSON.stringify({
          status: "active",
          subscriptionId: subscription.id,
          plan: plan,
          periodEnd: periodEnd,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } else {
      // Check if there was an actual decline error from Stripe
      if (paymentIntent?.last_payment_error) {
        const stripeError = paymentIntent.last_payment_error.message || "Payment could not be processed. Please try a different card.";
        console.log(`Payment failed (decline): ${stripeError} (Stripe Status: ${paymentIntent?.status})`);
        return new Response(
          JSON.stringify({
            status: "failed",
            error: stripeError,
          }),
          {
            status: 402,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // If it requires action, confirmation, or payment method, send the clientSecret to the frontend to confirm the payment
      if (
        paymentIntent?.status === "requires_action" ||
        paymentIntent?.status === "requires_payment_method" ||
        paymentIntent?.status === "requires_confirmation"
      ) {
        console.log(`Subscription requires client-side confirmation. Status: ${paymentIntent.status}`);
        return new Response(
          JSON.stringify({
            status: "requires_action",
            clientSecret: paymentIntent.client_secret,
            subscriptionId: subscription.id,
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // Fallback failed response
      console.log(`Unhandled payment intent status: ${paymentIntent?.status}, Subscription status: ${subscription.status}`);
      return new Response(
        JSON.stringify({
          status: "failed",
          error: "Payment could not be completed. Please try a different card.",
        }),
        {
          status: 402,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  } catch (err) {
    console.error("create-subscription error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
