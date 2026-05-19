-- Create note_snapshots table for read-only shareable copies of notes
-- Snapshots are immutable frozen copies; no connection back to the original note.
CREATE TABLE IF NOT EXISTS note_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL,
  content_hash TEXT NOT NULL,        -- MD5 of title+content+items for dedup
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  note_type TEXT NOT NULL DEFAULT 'text',       -- 'text' or 'checklist'
  checklist_items JSONB DEFAULT '[]'::jsonb,
  color INT NOT NULL DEFAULT 0,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast dedup lookup: same note + same content hash
CREATE INDEX IF NOT EXISTS idx_snapshots_dedup
  ON note_snapshots (note_id, content_hash);

-- Index for public token lookup
CREATE INDEX IF NOT EXISTS idx_snapshots_token
  ON note_snapshots (token);

-- Enable RLS
ALTER TABLE note_snapshots ENABLE ROW LEVEL SECURITY;

-- Anyone can read snapshots (public - token is the security)
CREATE POLICY "Anyone can read snapshots"
  ON note_snapshots FOR SELECT
  USING (true);

-- Only authenticated users can create snapshots
CREATE POLICY "Authenticated users can create snapshots"
  ON note_snapshots FOR INSERT
  WITH CHECK (auth.uid() = created_by);
