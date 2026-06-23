-- Migrate existing premium_pro users to premium
-- Premium Pro tier is being consolidated into Premium

UPDATE profiles 
SET account_type = 'premium' 
WHERE account_type = 'premium_pro';

-- Remove premium_pro pricing config rows
DELETE FROM pricing_config WHERE plan_id IN ('premium_pro_monthly', 'premium_pro_yearly');

-- Remove premium_pro from global_pricing if it exists
DELETE FROM global_pricing WHERE plan_id = 'premium_pro';

-- Note: pro_* columns on paywall_variants are left in place (unused) 
-- to avoid breaking existing row data. They will simply be ignored.
