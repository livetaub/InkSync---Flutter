-- Update Stripe Product IDs and pricing in the pricing_config table
INSERT INTO pricing_config (plan_id, stripe_product_id, price_cents)
VALUES 
  ('premium_monthly', 'prod_UZza7hdtDxkLSm', 499),
  ('premium_yearly', 'prod_UZza7hdtDxkLSm', 4999),
  ('premium_pro_monthly', 'prod_UZzbTaygJpGMIU', 999),
  ('premium_pro_yearly', 'prod_UZzbTaygJpGMIU', 9999)
ON CONFLICT (plan_id) 
DO UPDATE SET 
  stripe_product_id = EXCLUDED.stripe_product_id,
  price_cents = EXCLUDED.price_cents,
  updated_at = NOW();

-- Ensure global_pricing matches initial default values
UPDATE global_pricing 
SET price_monthly = 4.99, price_yearly = 49.99 
WHERE plan_id = 'premium';

UPDATE global_pricing 
SET price_monthly = 9.99, price_yearly = 99.99 
WHERE plan_id = 'premium_pro';
