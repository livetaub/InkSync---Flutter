// supabase/functions/stripe-webhook/index.ts
//
// Supabase Edge Function: Stripe Webhook Handler
//
// This function listens for Stripe events and automatically:
// - Activates subscriptions when payment succeeds
// - Downgrades users when subscriptions are cancelled
// - Handles failed payments
//
// ENVIRONMENT VARIABLES REQUIRED:
//   STRIPE_SECRET_KEY       = sk_test_... or sk_live_...
//   STRIPE_WEBHOOK_SECRET   = whsec_...

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const cryptoProvider = Stripe.createSubtleCryptoProvider();

serve(async (req: Request) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body = await req.text();
    const signature = req.headers.get("Stripe-Signature")!;
    const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

    // Verify the webhook signature (security: prevents spoofed requests)
    const event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret,
      undefined,
      cryptoProvider
    );

    // Initialize Supabase with service role (bypasses RLS)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    console.log(`Stripe event received: ${event.type}`);

    switch (event.type) {
      // ─── CHECKOUT COMPLETED ─────────────────────────────────────
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId = session.metadata?.supabase_user_id;
        const plan = session.metadata?.plan || "premium";

        if (!userId) {
          console.error("No supabase_user_id in session metadata");
          break;
        }

        // Retrieve the full subscription to get period end
        const subscription = await stripe.subscriptions.retrieve(
          session.subscription as string
        );

        const periodEnd = new Date(
          subscription.current_period_end * 1000
        ).toISOString();

        // Activate the user's subscription in the database
        await supabase
          .from("profiles")
          .update({
            account_type: plan,
            stripe_customer_id: session.customer as string,
            stripe_subscription_id: session.subscription as string,
            subscription_status: "active",
            subscription_period_end: periodEnd,
            subscription_origin: "stripe",
          })
          .eq("id", userId);

        console.log(
          `✅ Activated ${plan} for user ${userId} until ${periodEnd}`
        );
        break;
      }

      // ─── SUBSCRIPTION UPDATED (renewal, plan change) ────────────
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        const userId = subscription.metadata?.supabase_user_id;

        if (!userId) {
          // Try to find user by stripe_customer_id
          const { data: profile } = await supabase
            .from("profiles")
            .select("id")
            .eq("stripe_customer_id", subscription.customer as string)
            .single();

          if (!profile) {
            console.error("Could not find user for subscription update");
            break;
          }

          const periodEnd = new Date(
            subscription.current_period_end * 1000
          ).toISOString();

          const status = subscription.status;
          const isActive =
            status === "active" || status === "trialing";

          await supabase
            .from("profiles")
            .update({
              subscription_status: status,
              subscription_period_end: periodEnd,
              // If subscription is no longer active, downgrade to free
              ...(isActive ? {} : { account_type: "free" }),
            })
            .eq("id", profile.id);

          console.log(
            `📝 Subscription updated for user ${profile.id}: ${status}`
          );
          break;
        }

        const periodEnd = new Date(
          subscription.current_period_end * 1000
        ).toISOString();

        const status = subscription.status;
        const isActive = status === "active" || status === "trialing";

        await supabase
          .from("profiles")
          .update({
            subscription_status: status,
            subscription_period_end: periodEnd,
            ...(isActive ? {} : { account_type: "free" }),
          })
          .eq("id", userId);

        console.log(
          `📝 Subscription updated for user ${userId}: ${status}`
        );
        break;
      }

      // ─── SUBSCRIPTION DELETED (cancelled) ───────────────────────
      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;

        // Find user by stripe_customer_id
        const { data: profile } = await supabase
          .from("profiles")
          .select("id")
          .eq("stripe_customer_id", subscription.customer as string)
          .single();

        if (profile) {
          await supabase
            .from("profiles")
            .update({
              account_type: "free",
              subscription_status: "cancelled",
              stripe_subscription_id: null,
            })
            .eq("id", profile.id);

          console.log(
            `🚫 Subscription cancelled — user ${profile.id} downgraded to free`
          );
        }
        break;
      }

      // ─── INVOICE PAYMENT FAILED ─────────────────────────────────
      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;

        const { data: profile } = await supabase
          .from("profiles")
          .select("id")
          .eq("stripe_customer_id", invoice.customer as string)
          .single();

        if (profile) {
          await supabase
            .from("profiles")
            .update({
              subscription_status: "past_due",
            })
            .eq("id", profile.id);

          console.log(
            `⚠️ Payment failed for user ${profile.id} — marked as past_due`
          );
        }
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Webhook error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
