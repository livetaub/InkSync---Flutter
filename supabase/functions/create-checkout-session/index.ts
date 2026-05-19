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

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
})

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // Authenticate the user
    const authHeader = req.headers.get('Authorization')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { plan, period, success_url, cancel_url, email } = await req.json()

    // Construct the pricing_config key (e.g., 'premium_monthly')
    const planKey = `${plan}_${period}`

    // Look up the Stripe product from pricing_config
    const { data: pricingRow, error: pricingError } = await supabase
      .from('pricing_config')
      .select('stripe_product_id, price_cents')
      .eq('plan_id', planKey)
      .single()

    if (pricingError || !pricingRow) {
      return new Response(
        JSON.stringify({ error: `Plan '${planKey}' not found in pricing_config.` }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Look up or create a Stripe Price for this product + amount
    // This allows dynamic pricing — create a new price object on the fly
    const price = await stripe.prices.create({
      product: pricingRow.stripe_product_id,
      unit_amount: pricingRow.price_cents,
      currency: 'usd',
      recurring: {
        interval: period === 'yearly' ? 'year' : 'month',
      },
      metadata: {
        plan_id: planKey,
        source: 'android_checkout',
      },
    })

    // Create the Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: price.id,
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
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (err) {
    console.error('Error creating checkout session:', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Internal server error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})
