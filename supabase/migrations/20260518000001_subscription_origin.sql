-- Add subscription_origin to profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS subscription_origin TEXT DEFAULT NULL;

-- Possible values for subscription_origin: 'stripe', 'appStore', 'playStore'
