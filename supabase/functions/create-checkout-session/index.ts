// Supabase Edge Function: create-checkout-session
// Creates a Stripe Checkout Session for mobile (Android) payments.
// Reads pricing from the paywall_variants table, creates a hosted checkout URL.
//
// Request body:
//   { plan: string, period: string, success_url: string, cancel_url: string, email?: string, variant_id?: string }
//
// Response:
//   { url: string } — The Stripe Checkout Session URL
//
// ENVIRONMENT VARIABLES REQUIRED:
//   STRIPE_SECRET_KEY          = sk_test_... or sk_live_...
//   STRIPE_PRODUCT_PREMIUM     = prod_... (Stripe Product ID for Premium)

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

    const { plan, period, success_url, cancel_url, email, variant_id } = await req.json()

    // Use service role for admin operations (pricing lookup, profile updates)
    const adminSupabase = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // ── Look up pricing from paywall_variants ─────────────────
    let variantRow: any

    if (variant_id) {
      const { data, error } = await adminSupabase
        .from('paywall_variants')
        .select('*')
        .eq('id', variant_id)
        .single()
      if (!error && data) variantRow = data
    }

    if (!variantRow) {
      // Fallback: use the first active variant
      const { data, error } = await adminSupabase
        .from('paywall_variants')
        .select('*')
        .eq('is_active', true)
        .order('traffic_weight', { ascending: false })
        .limit(1)
        .single()
      if (error || !data) {
        return new Response(
          JSON.stringify({ error: 'No active pricing variant found' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      variantRow = data
    }

    // Build the price column name: e.g., "premium_price_monthly" or "pro_price_yearly"
    const planPrefix = 'premium'
    const priceColumn = `${planPrefix}_price_${period === 'yearly' ? 'yearly' : 'monthly'}`
    const priceValue = variantRow[priceColumn]

    if (!priceValue && priceValue !== 0) {
      return new Response(
        JSON.stringify({ error: `Price not found for ${plan} ${period}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const priceCents = Math.round(Number(priceValue) * 100)
    const interval = period === 'yearly' ? 'year' : 'month'

    // Map plan to Stripe Product ID from environment variables
    const productId = Deno.env.get('STRIPE_PRODUCT_PREMIUM')!

    console.log(
      `Creating checkout session: ${plan} ${period} at $${priceCents / 100}/${interval} (variant: ${variantRow.variant_name})`
    )

    // Look up existing Stripe Price before creating a new one
    const prices = await stripe.prices.list({
      product: productId,
      active: true,
    })

    const existingPrice = prices.data.find(
      (p) => p.unit_amount === priceCents && p.recurring?.interval === interval
    )

    let priceId: string
    if (existingPrice) {
      priceId = existingPrice.id
    } else {
      // Create new price on the fly only if no matching price exists
      const newPrice = await stripe.prices.create({
        product: productId,
        unit_amount: priceCents,
        currency: 'usd',
        recurring: { interval },
        metadata: {
          plan: plan,
          period: period,
          variant_id: variant_id || 'default',
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
        variant_id: variant_id || '',
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
