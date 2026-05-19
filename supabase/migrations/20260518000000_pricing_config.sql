-- Create table to hold dynamic pricing configuration for Stripe
CREATE TABLE IF NOT EXISTS pricing_config (
  plan_id TEXT PRIMARY KEY, -- e.g., 'premium_monthly', 'premium_yearly'
  stripe_product_id TEXT NOT NULL, -- The Stripe Product ID (e.g. prod_...)
  price_cents INTEGER NOT NULL, -- The price amount in cents (e.g., 700 for $7.00)
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: Only accessible by authenticated users (to read) and service role (to write/update via Edge Function/Admin)
ALTER TABLE pricing_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view pricing config" ON pricing_config
  FOR SELECT USING (true);

-- Admin can manage via service role or admin dashboard.

-- Insert default values (Replace 'prod_xyz' with your actual Stripe product ID)
INSERT INTO pricing_config (plan_id, stripe_product_id, price_cents)
VALUES 
  ('premium_monthly', 'prod_xyz_monthly', 700),
  ('premium_yearly', 'prod_xyz_yearly', 7000)
ON CONFLICT (plan_id) DO NOTHING;
