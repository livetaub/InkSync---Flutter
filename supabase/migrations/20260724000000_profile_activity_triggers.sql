-- ============================================================
-- Profile Activity Tracking Triggers
-- 
-- Automatically keeps profiles.last_active_at, 
-- cached_notes_count, and cached_storage_bytes in sync
-- whenever a note is created, updated, or deleted.
-- Also backfills existing data for all current users.
-- ============================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. TRIGGER FUNCTION — Fires on every note INSERT/UPDATE/DELETE
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_profile_on_note_change()
RETURNS TRIGGER AS $$
DECLARE
  _user_id UUID;
  _notes_count INT;
  _storage_bytes BIGINT;
BEGIN
  -- Determine the relevant user_id
  IF TG_OP = 'DELETE' THEN
    _user_id := OLD.user_id;
  ELSE
    _user_id := NEW.user_id;
  END IF;

  -- Skip if no user_id (shouldn't happen, but safety first)
  IF _user_id IS NULL THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

  -- Count active (non-trashed) notes for this user
  SELECT COUNT(*) INTO _notes_count
  FROM notes
  WHERE user_id = _user_id AND trashed_at IS NULL;

  -- Calculate total storage bytes (title + content) for active notes
  SELECT COALESCE(SUM(
    octet_length(COALESCE(title, '')) +
    octet_length(COALESCE(content, ''))
  ), 0) INTO _storage_bytes
  FROM notes
  WHERE user_id = _user_id AND trashed_at IS NULL;

  -- Update the user's profile with fresh stats + activity timestamp
  UPDATE profiles SET
    last_active_at = now(),
    cached_notes_count = _notes_count,
    cached_storage_bytes = _storage_bytes
  WHERE id = _user_id;

  IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════
-- 2. ATTACH TRIGGER TO NOTES TABLE
-- ═══════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS on_note_change_update_profile ON notes;

CREATE TRIGGER on_note_change_update_profile
  AFTER INSERT OR UPDATE OR DELETE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_on_note_change();

-- ═══════════════════════════════════════════════════════════════
-- 3. BACKFILL — Fix existing data for all current users
-- ═══════════════════════════════════════════════════════════════

-- 3a. Set last_active_at to the user's most recent note activity
--     (falls back to created_at if they have no notes)
UPDATE profiles p SET
  last_active_at = COALESCE(
    (SELECT MAX(GREATEST(n.created_at, n.updated_at))
     FROM notes n WHERE n.user_id = p.id),
    p.created_at
  );

-- 3b. Backfill cached_notes_count (active, non-trashed notes)
UPDATE profiles p SET
  cached_notes_count = (
    SELECT COUNT(*)
    FROM notes n
    WHERE n.user_id = p.id AND n.trashed_at IS NULL
  );

-- 3c. Backfill cached_storage_bytes (title + content size of active notes)
UPDATE profiles p SET
  cached_storage_bytes = COALESCE(
    (SELECT SUM(
      octet_length(COALESCE(n.title, '')) +
      octet_length(COALESCE(n.content, ''))
    )
    FROM notes n
    WHERE n.user_id = p.id AND n.trashed_at IS NULL),
    0
  );
