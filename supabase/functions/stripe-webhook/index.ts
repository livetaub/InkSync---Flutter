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

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
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
    let event: Stripe.Event;
    try {
      event = await stripe.webhooks.constructEventAsync(
        body,
        signature,
        webhookSecret,
        undefined,
        cryptoProvider
      );
    } catch (sigErr) {
      console.error("Webhook signature verification failed:", sigErr);
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

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
        let periodEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
        if (session.subscription) {
          try {
            const subscription = await stripe.subscriptions.retrieve(
              session.subscription as string
            );
            let endTimestamp = subscription?.current_period_end;
            if (!endTimestamp && subscription?.items?.data?.[0]?.current_period_end) {
              endTimestamp = subscription.items.data[0].current_period_end;
            }
            if (endTimestamp) {
              periodEnd = new Date(endTimestamp * 1000).toISOString();
            }
          } catch (subErr) {
            console.error("Error retrieving subscription in webhook:", subErr);
          }
        }

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

        // Track checkout_completed in paywall_events for analytics
        const variantId = session.metadata?.variant_id;
        const period = session.metadata?.period;
        if (variantId) {
          await supabase.from("paywall_events").insert({
            user_id: userId,
            variant_id: variantId,
            event_type: "checkout_completed",
            platform: "stripe_webhook",
            plan: plan,
            period: period || null,
            metadata: { subscription_id: session.subscription },
          });
        }

        console.log(
          `✅ Activated ${plan} for user ${userId} until ${periodEnd}`
        );
        break;
      }

      // ─── SUBSCRIPTION UPDATED (renewal, plan change) ────────────
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        const userId = subscription.metadata?.supabase_user_id;
        const plan = subscription.metadata?.plan || "premium";
        const variantId = subscription.metadata?.variant_id;
        const period = subscription.metadata?.period;

        let targetUserId = userId;

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

          targetUserId = profile.id;

          let endTimestamp = subscription.current_period_end;
          if (!endTimestamp && subscription.items?.data?.[0]?.current_period_end) {
            endTimestamp = subscription.items.data[0].current_period_end;
          }
          const periodEnd = endTimestamp
            ? new Date(endTimestamp * 1000).toISOString()
            : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

          const status = subscription.status;
          const isActive = status === "active" || status === "trialing";

          await supabase
            .from("profiles")
            .update({
              subscription_status: status,
              subscription_period_end: periodEnd,
              stripe_subscription_id: subscription.id,
              account_type: isActive ? plan : "free",
            })
            .eq("id", targetUserId);

          console.log(
            `📝 Subscription updated for user ${targetUserId}: ${status} (plan: ${plan})`
          );
        } else {
          let endTimestamp = subscription.current_period_end;
          if (!endTimestamp && subscription.items?.data?.[0]?.current_period_end) {
            endTimestamp = subscription.items.data[0].current_period_end;
          }
          const periodEnd = endTimestamp
            ? new Date(endTimestamp * 1000).toISOString()
            : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

          const status = subscription.status;
          const isActive = status === "active" || status === "trialing";

          await supabase
            .from("profiles")
            .update({
              subscription_status: status,
              subscription_period_end: periodEnd,
              stripe_subscription_id: subscription.id,
              stripe_customer_id: subscription.customer as string,
              account_type: isActive ? plan : "free",
              subscription_origin: "stripe",
            })
            .eq("id", targetUserId);

          console.log(
            `📝 Subscription updated for user ${targetUserId}: ${status} (plan: ${plan})`
          );
        }

        // Track conversion in paywall_events for web checkout Elements flow
        const isActive = subscription.status === "active" || subscription.status === "trialing";
        if (targetUserId && variantId && isActive) {
          try {
            // Check if checkout_completed has already been recorded for this subscription_id
            const { data: existingEvents } = await supabase
              .from("paywall_events")
              .select("id")
              .eq("event_type", "checkout_completed")
              .eq("metadata->>subscription_id", subscription.id)
              .limit(1);

            if (!existingEvents || existingEvents.length === 0) {
              await supabase.from("paywall_events").insert({
                user_id: targetUserId,
                variant_id: variantId,
                event_type: "checkout_completed",
                platform: "web",
                plan: plan,
                period: period || null,
                metadata: { subscription_id: subscription.id },
              });
              console.log(`📊 Tracked checkout_completed event for web subscription ${subscription.id}`);
            }
          } catch (eventErr) {
            console.error("Failed to track checkout_completed event in webhook:", eventErr);
          }
        }

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
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
