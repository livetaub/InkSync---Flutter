-- Migration: Allow public (authenticated and anonymous) inserts to paywall_events
-- This allows tracking conversion and view events for guest users before signup/login.

DROP POLICY IF EXISTS "Users can insert own events" ON paywall_events;
DROP POLICY IF EXISTS "Anyone can insert events" ON paywall_events;

CREATE POLICY "Anyone can insert events"
  ON paywall_events FOR INSERT
  WITH CHECK (true);
