-- ============================================================
-- Paywall Content & Billing Configuration System
-- Migration: Creates paywall_variants, paywall_assignments, 
--            paywall_events tables + seed control variant
-- ============================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. PAYWALL VARIANTS — Single source of truth for pricing, 
--    copy, and plan limits
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS paywall_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  variant_name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  traffic_weight INTEGER DEFAULT 50,

  -- Page-level copy
  page_headline TEXT,
  page_subheadline TEXT,

  -- ─── Free Tier ─────────────────────────────────────────────
  free_title TEXT DEFAULT 'Free',
  free_subtitle TEXT DEFAULT 'For personal use',
  free_features JSONB DEFAULT '[]',
  free_cta_text TEXT DEFAULT 'Continue for Free',
  free_notes_limit INTEGER DEFAULT 75,
  free_ai_credits INTEGER DEFAULT 0,

  -- ─── Premium Tier ──────────────────────────────────────────
  premium_title TEXT DEFAULT 'Premium',
  premium_subtitle TEXT DEFAULT 'For power users',
  premium_features JSONB DEFAULT '[]',
  premium_badge_text TEXT,
  premium_cta_monthly TEXT DEFAULT 'Subscribe',
  premium_cta_yearly TEXT DEFAULT 'Subscribe',
  premium_price_monthly NUMERIC NOT NULL,
  premium_price_yearly NUMERIC NOT NULL,
  premium_notes_limit INTEGER DEFAULT 250,
  premium_ai_credits INTEGER DEFAULT 100,

  -- ─── Premium Pro Tier ──────────────────────────────────────
  pro_title TEXT DEFAULT 'Premium Pro',
  pro_subtitle TEXT DEFAULT 'For teams & pros',
  pro_features JSONB DEFAULT '[]',
  pro_badge_text TEXT,
  pro_cta_monthly TEXT DEFAULT 'Subscribe',
  pro_cta_yearly TEXT DEFAULT 'Subscribe',
  pro_price_monthly NUMERIC NOT NULL,
  pro_price_yearly NUMERIC NOT NULL,
  pro_notes_limit INTEGER DEFAULT 500,
  pro_ai_credits INTEGER DEFAULT 200,

  -- ─── Shared Copy ───────────────────────────────────────────
  trial_text TEXT,
  money_back_text TEXT,

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: Anyone can read active variants, service role has full access
ALTER TABLE paywall_variants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active variants" 
  ON paywall_variants FOR SELECT 
  USING (is_active = true);

-- ═══════════════════════════════════════════════════════════════
-- 2. PAYWALL ASSIGNMENTS — Sticky A/B test user assignments
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS paywall_assignments (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES paywall_variants(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id)
);

ALTER TABLE paywall_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own assignment"
  ON paywall_assignments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own assignment"
  ON paywall_assignments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════
-- 3. PAYWALL EVENTS — Lightweight analytics tracking
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS paywall_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  variant_id UUID,
  event_type TEXT NOT NULL,
  platform TEXT,
  plan TEXT,
  period TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_pe_event_type ON paywall_events(event_type);
CREATE INDEX idx_pe_variant_id ON paywall_events(variant_id);
CREATE INDEX idx_pe_created_at ON paywall_events(created_at);
CREATE INDEX idx_pe_user_variant ON paywall_events(user_id, variant_id);

ALTER TABLE paywall_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own events"
  ON paywall_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════
-- 4. SAFETY TRIGGER — Prevent deactivating/deleting last variant
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION check_last_active_variant()
RETURNS TRIGGER AS $$
BEGIN
  -- On UPDATE: prevent deactivating last active variant
  IF TG_OP = 'UPDATE' AND OLD.is_active = true AND NEW.is_active = false THEN
    IF (SELECT COUNT(*) FROM paywall_variants WHERE is_active = true AND id != OLD.id) = 0 THEN
      RAISE EXCEPTION 'Cannot deactivate the last active variant. At least one variant must remain active.';
    END IF;
  END IF;
  
  -- On DELETE: prevent deleting last active variant
  IF TG_OP = 'DELETE' AND OLD.is_active = true THEN
    IF (SELECT COUNT(*) FROM paywall_variants WHERE is_active = true AND id != OLD.id) = 0 THEN
      RAISE EXCEPTION 'Cannot delete the last active variant. At least one variant must remain active.';
    END IF;
    RETURN OLD;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_last_variant_deactivation
  BEFORE UPDATE ON paywall_variants
  FOR EACH ROW
  EXECUTE FUNCTION check_last_active_variant();

CREATE TRIGGER prevent_last_variant_deletion
  BEFORE DELETE ON paywall_variants
  FOR EACH ROW
  EXECUTE FUNCTION check_last_active_variant();

-- ═══════════════════════════════════════════════════════════════
-- 5. AUTO-UPDATE updated_at TIMESTAMP
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_paywall_variant_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_variant_updated_at
  BEFORE UPDATE ON paywall_variants
  FOR EACH ROW
  EXECUTE FUNCTION update_paywall_variant_timestamp();

-- ═══════════════════════════════════════════════════════════════
-- 6. SEED "Control" VARIANT — Current production values
-- ═══════════════════════════════════════════════════════════════

INSERT INTO paywall_variants (
  variant_name,
  is_active,
  traffic_weight,
  
  page_headline,
  page_subheadline,

  -- Free
  free_title,
  free_subtitle,
  free_features,
  free_cta_text,
  free_notes_limit,
  free_ai_credits,

  -- Premium
  premium_title,
  premium_subtitle,
  premium_features,
  premium_badge_text,
  premium_cta_monthly,
  premium_cta_yearly,
  premium_price_monthly,
  premium_price_yearly,
  premium_notes_limit,
  premium_ai_credits,

  -- Premium Pro
  pro_title,
  pro_subtitle,
  pro_features,
  pro_badge_text,
  pro_cta_monthly,
  pro_cta_yearly,
  pro_price_monthly,
  pro_price_yearly,
  pro_notes_limit,
  pro_ai_credits,

  -- Shared
  trial_text,
  money_back_text
) VALUES (
  'Control',
  true,
  100,

  'Unlock your full potential',
  'More notes. AI assist. Real-time collaboration.',

  -- Free
  'Free',
  'For personal use',
  '["75 cross-platform notes", "Notes & checklists", "Link notes to calendar", "Filter by tags & colors", "Lock notes for privacy", "Web, iOS & Android"]',
  'Continue for Free',
  75,
  0,

  -- Premium
  'Premium',
  'For power users',
  '["250 cross-platform notes", "100 AI writing credits / month", "Real-time collaboration", "Priority support"]',
  'Most Popular',
  'Subscribe',
  'Subscribe',
  4.99,
  49.99,
  250,
  100,

  -- Premium Pro
  'Premium Pro',
  'For teams & pros',
  '["500 cross-platform notes", "200 AI writing credits / month", "Advanced collaboration", "Priority support"]',
  NULL,
  'Subscribe',
  'Subscribe',
  9.99,
  99.99,
  500,
  200,

  -- Shared
  NULL,
  NULL
);
