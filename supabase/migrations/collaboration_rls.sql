-- ============================================================
-- InkSync: RLS policies for collaboration
-- Allows accepted collaborators to read/edit shared notes
-- Run this in the Supabase SQL Editor
-- ============================================================

-- Allow collaborators to SELECT notes shared with them
DROP POLICY IF EXISTS "Collaborators can view shared notes" ON notes;
CREATE POLICY "Collaborators can view shared notes"
ON notes FOR SELECT
USING (
  id IN (
    SELECT note_id FROM collaboration_invites
    WHERE to_email = lower(auth.jwt()->>'email')
    AND status = 'accepted'
  )
);

-- Allow collaborators with edit access to UPDATE shared notes
DROP POLICY IF EXISTS "Collaborators can update shared notes" ON notes;
CREATE POLICY "Collaborators can update shared notes"
ON notes FOR UPDATE
USING (
  id IN (
    SELECT note_id FROM collaboration_invites
    WHERE to_email = lower(auth.jwt()->>'email')
    AND status = 'accepted'
    AND can_edit = true
  )
);
