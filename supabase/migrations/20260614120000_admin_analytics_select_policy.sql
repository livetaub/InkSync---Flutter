-- Migration: Allow authenticated admin users to SELECT from paywall_events
-- This allows the Admin Portal to fetch and display the statistics.

DROP POLICY IF EXISTS "Admins can read all events" ON paywall_events;

CREATE POLICY "Admins can read all events"
  ON paywall_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid())
  );
