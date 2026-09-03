-- ============================================================
-- InkSync: Allow note owners to manage collaboration invites
-- Adds UPDATE and DELETE policies on collaboration_invites
-- for the user who owns the note (note_owner_id = auth.uid())
-- ============================================================

-- Allow note owners to UPDATE invites they sent (e.g. change permissions)
DROP POLICY IF EXISTS "Note owners can update their invites" ON collaboration_invites;
CREATE POLICY "Note owners can update their invites"
ON collaboration_invites FOR UPDATE
USING (note_owner_id = auth.uid());

-- Allow note owners to DELETE/revoke invites they sent
DROP POLICY IF EXISTS "Note owners can delete their invites" ON collaboration_invites;
CREATE POLICY "Note owners can delete their invites"
ON collaboration_invites FOR DELETE
USING (note_owner_id = auth.uid());
