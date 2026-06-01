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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
      apiVersion: "2024-06-20",
      httpClient: Stripe.createFetchHttpClient(),
    });

    const authHeader = req.headers.get("Authorization")!;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { plan, period } = await req.json();
    if (!plan || !period) {
      return new Response(JSON.stringify({ error: "Missing plan or period" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Dynamic Pricing Logic
    // We expect a table named 'pricing_config' with columns: plan_id (text), stripe_product_id (text), price_cents (integer)
    const planId = `${plan}_${period}`;
    const { data: config } = await supabase
      .from("pricing_config")
      .select("*")
      .eq("plan_id", planId)
      .single();

    let priceId = "";
    
    if (config) {
      const productId = config.stripe_product_id;
      const priceCents = config.price_cents;
      
      // Look for existing price in Stripe
      const prices = await stripe.prices.list({
        product: productId,
        active: true,
      });
      
      const existingPrice = prices.data.find(p => p.unit_amount === priceCents && p.recurring?.interval === (period === 'monthly' ? 'month' : 'year'));
      
      if (existingPrice) {
        priceId = existingPrice.id;
      } else {
        // Create new price on the fly
        const newPrice = await stripe.prices.create({
          product: productId,
          unit_amount: priceCents,
          currency: 'usd',
          recurring: { interval: period === 'monthly' ? 'month' : 'year' },
          metadata: { plan_id: planId },
        });
        priceId = newPrice.id;
      }
    } else {
      // Fallback to environment variables if table doesn't exist or row missing
      const priceMap: Record<string, string | undefined> = {
        "premium_monthly": Deno.env.get("STRIPE_PRICE_PREMIUM_MONTHLY"),
        "premium_yearly": Deno.env.get("STRIPE_PRICE_PREMIUM_YEARLY"),
      };
      priceId = priceMap[planId] || "";
    }

    if (!priceId) {
      return new Response(JSON.stringify({ error: `Invalid plan/period or missing price config for: ${planId}` }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Get or Create Customer
    const adminSupabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    
    const { data: profile } = await adminSupabase
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .single();

    let customerId = profile?.stripe_customer_id;

    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;
      await adminSupabase.from("profiles").update({ stripe_customer_id: customerId }).eq("id", user.id);
    }

    // Create Checkout Session
    const origin = req.headers.get("origin") || "https://app.inksyncnote.com";

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${origin}/#/checkout-success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/#/app`,
      subscription_data: { metadata: { supabase_user_id: user.id, plan: plan } },
      metadata: { supabase_user_id: user.id, plan: plan },
    });

    return new Response(JSON.stringify({ url: session.url, sessionId: session.id }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err) {
    console.error("create-checkout error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
