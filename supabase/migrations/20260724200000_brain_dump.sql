-- Brain Dump table
CREATE TABLE IF NOT EXISTS brain_dumps (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'voice', 'image', 'pdf')),
  content TEXT,
  media_url TEXT,
  file_name TEXT,
  duration_seconds INTEGER,
  is_pinned BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE brain_dumps ENABLE ROW LEVEL SECURITY;

-- Users can only see their own messages
CREATE POLICY "Users can view own brain dumps" ON brain_dumps FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can insert own brain dumps" ON brain_dumps FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own brain dumps" ON brain_dumps FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own brain dumps" ON brain_dumps FOR DELETE USING (user_id = auth.uid());

-- Index for fast queries
CREATE INDEX idx_brain_dumps_user_created ON brain_dumps(user_id, created_at);
