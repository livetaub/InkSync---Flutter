-- =====================================================
-- Admin CRUD policies for paywall_variants
-- =====================================================
-- The admin portal needs full CRUD access to manage
-- paywall variants. These policies check the admin_users
-- table (column: id) to verify the requesting user is an admin.

-- Admins can read ALL variants (including inactive)
CREATE POLICY "Admins can read all variants"
  ON paywall_variants FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid())
  );

-- Admins can insert new variants
CREATE POLICY "Admins can insert variants"
  ON paywall_variants FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid())
  );

-- Admins can update variants
CREATE POLICY "Admins can update variants"
  ON paywall_variants FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid())
  );

-- Admins can delete variants
CREATE POLICY "Admins can delete variants"
  ON paywall_variants FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM admin_users WHERE id = auth.uid())
  );
