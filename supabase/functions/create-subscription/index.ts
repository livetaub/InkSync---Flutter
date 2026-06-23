// supabase/functions/create-subscription/index.ts
//
// Supabase Edge Function: Create Stripe Subscription
//
// This is the "brain" of the billing system. It:
// 1. Receives a PaymentMethod token + plan selection from the Flutter app
// 2. Reads the EXACT price from the paywall_variants table (dynamic pricing)
// 3. Creates a Stripe Customer + attaches the card
// 4. Creates a Stripe Subscription at the database-driven price
// 5. Returns the subscription status to the app
//
// The user's card details NEVER touch this function — only a secure token.
//
// ENVIRONMENT VARIABLES REQUIRED:
//   STRIPE_SECRET_KEY          = sk_test_... or sk_live_...
//   STRIPE_PRODUCT_PREMIUM     = prod_... (Stripe Product ID for Premium)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://app.inksyncnote.com",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Initialize Stripe ──────────────────────────────────
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
      apiVersion: "2024-06-20",
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
    const { paymentMethodId, plan, period, variant_id } = await req.json();
    // paymentMethodId: "pm_..." from Stripe.js
    // plan: "premium"
    // period: "monthly" | "yearly"
    // variant_id: UUID from paywall_variants (optional)

    if (!paymentMethodId || !plan || !period) {
      return new Response(
        JSON.stringify({ error: "Missing paymentMethodId, plan, or period" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── 4. Read price from paywall_variants table ────────────
    // Pricing is 100% controlled from your database via paywall variants.
    // If variant_id is provided, use that specific variant.
    // Otherwise, fall back to the first active variant.
    const adminSupabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    let variantRow: any;

    if (variant_id) {
      // Look up the specific variant
      const { data, error } = await adminSupabase
        .from("paywall_variants")
        .select("*")
        .eq("id", variant_id)
        .single();
      if (!error && data) variantRow = data;
    }

    if (!variantRow) {
      // Fallback: use the first active variant (sorted by traffic_weight desc)
      const { data, error } = await adminSupabase
        .from("paywall_variants")
        .select("*")
        .eq("is_active", true)
        .order("traffic_weight", { ascending: false })
        .limit(1)
        .single();
      if (error || !data) {
        return new Response(
          JSON.stringify({ error: `No active pricing variant found` }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
      variantRow = data;
    }

    // Build the price column name: e.g., "premium_price_monthly" or "pro_price_yearly"
    const planPrefix = "premium";
    const priceColumn = `${planPrefix}_price_${period === "yearly" ? "yearly" : "monthly"}`;
    const priceValue = variantRow[priceColumn];

    if (!priceValue && priceValue !== 0) {
      return new Response(
        JSON.stringify({ error: `Price not found for ${plan} ${period}` }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Convert to cents (Stripe uses cents)
    const priceAmount = Math.round(Number(priceValue) * 100);
    const interval = period === "yearly" ? "year" : "month";

    // Map plan to Stripe Product ID
    const productId = Deno.env.get("STRIPE_PRODUCT_PREMIUM")!;

    console.log(
      `Creating subscription: ${plan} ${period} at $${priceAmount / 100}/${interval} (variant: ${variantRow.variant_name})`
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

    // ── 7. Look up or create a dynamic Price using database values ───
    // Check for existing price before creating to avoid duplicates
    const existingPrices = await stripe.prices.list({
      product: productId,
      active: true,
    });

    const existingPrice = existingPrices.data.find(
      (p) => p.unit_amount === priceAmount && p.recurring?.interval === interval
    );

    let priceId: string;
    if (existingPrice) {
      priceId = existingPrice.id;
    } else {
      const newPrice = await stripe.prices.create({
        product: productId,
        unit_amount: priceAmount,
        currency: "usd",
        recurring: { interval: interval },
      });
      priceId = newPrice.id;
    }

    // ── 8. Create the Subscription ────────────────────────────
    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: priceId }],
      default_payment_method: paymentMethodId,
      payment_behavior: "default_incomplete",
      payment_settings: {
        save_default_payment_method: "on_subscription",
      },
      expand: ["latest_invoice.payment_intent"],
      metadata: {
        supabase_user_id: user.id,
        plan: plan,
        period: period,
        variant_id: variantRow.id,
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
      let endTimestamp = subscription.current_period_end;
      if (!endTimestamp && subscription.items?.data?.[0]?.current_period_end) {
        endTimestamp = subscription.items.data[0].current_period_end;
      }
      const periodEnd = endTimestamp
        ? new Date(endTimestamp * 1000).toISOString()
        : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

      await adminSupabase
        .from("profiles")
        .update({
          account_type: plan,
          stripe_subscription_id: subscription.id,
          subscription_status: "active",
          subscription_period_end: periodEnd,
        })
        .eq("id", user.id);

      // Track conversion in paywall_events
      if (variantRow.id) {
        try {
          await adminSupabase.from("paywall_events").insert({
            user_id: user.id,
            variant_id: variantRow.id,
            event_type: "checkout_completed",
            platform: "web",
            plan: plan,
            period: period,
            metadata: { subscription_id: subscription.id },
          });
          console.log(`📊 Tracked checkout_completed event immediately for web subscription ${subscription.id}`);
        } catch (eventErr) {
          console.error("Failed to track checkout_completed event:", eventErr);
        }
      }

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
