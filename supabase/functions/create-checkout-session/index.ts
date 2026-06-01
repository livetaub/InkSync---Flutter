// Supabase Edge Function: create-checkout-session
// Creates a Stripe Checkout Session for mobile (Android) payments.
// Reads pricing from the pricing_config table, creates a hosted checkout URL.
//
// Request body:
//   { plan: string, period: string, success_url: string, cancel_url: string, email?: string }
//
// Response:
//   { url: string } — The Stripe Checkout Session URL

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.inksyncnote.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
})

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Authenticate the user using anon key + user's auth token
    const authHeader = req.headers.get('Authorization')!
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { plan, period, success_url, cancel_url, email } = await req.json()

    // Construct the pricing_config key (e.g., 'premium_monthly')
    const planKey = `${plan}_${period}`

    // Use service role for admin operations (pricing lookup, profile updates)
    const adminSupabase = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // Look up the Stripe product from pricing_config
    const { data: pricingRow, error: pricingError } = await adminSupabase
      .from('pricing_config')
      .select('stripe_product_id, price_cents')
      .eq('plan_id', planKey)
      .single()

    if (pricingError || !pricingRow) {
      return new Response(
        JSON.stringify({ error: `Plan '${planKey}' not found in pricing_config.` }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Look up existing Stripe Price before creating a new one
    const prices = await stripe.prices.list({
      product: pricingRow.stripe_product_id,
      active: true,
    })

    const interval = period === 'yearly' ? 'year' : 'month'
    const existingPrice = prices.data.find(
      (p) => p.unit_amount === pricingRow.price_cents && p.recurring?.interval === interval
    )

    let priceId: string
    if (existingPrice) {
      priceId = existingPrice.id
    } else {
      // Create new price on the fly only if no matching price exists
      const newPrice = await stripe.prices.create({
        product: pricingRow.stripe_product_id,
        unit_amount: pricingRow.price_cents,
        currency: 'usd',
        recurring: { interval },
        metadata: {
          plan_id: planKey,
          source: 'android_checkout',
        },
      })
      priceId = newPrice.id
    }

    // Create the Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: success_url || 'https://inksyncnote.com/#/checkout-success',
      cancel_url: cancel_url || 'https://inksyncnote.com/#/pricing',
      customer_email: email || user.email,
      client_reference_id: user.id,
      metadata: {
        supabase_user_id: user.id,
        plan: plan,
        period: period,
      },
      subscription_data: {
        metadata: {
          supabase_user_id: user.id,
          plan: plan,
        },
      },
    })

    return new Response(
      JSON.stringify({ url: session.url }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (err) {
    console.error('Error creating checkout session:', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
