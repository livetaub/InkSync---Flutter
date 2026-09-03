CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  note_body TEXT,
  event_date DATE NOT NULL,
  event_time TIME,
  is_done BOOLEAN DEFAULT false,
  reminder TEXT CHECK (reminder IN ('at_time', '30_min', '1_hour', '2_hours', 'morning')),
  recurrence_type TEXT CHECK (recurrence_type IN ('weekly', 'monthly')),
  recurrence_days JSONB DEFAULT '[]',
  completed_dates JSONB DEFAULT '[]',
  overrides JSONB DEFAULT '{}',
  linked_note_id UUID REFERENCES notes(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own calendar events" ON calendar_events FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can insert own calendar events" ON calendar_events FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own calendar events" ON calendar_events FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own calendar events" ON calendar_events FOR DELETE USING (user_id = auth.uid());

-- Index
CREATE INDEX idx_calendar_events_user_date ON calendar_events(user_id, event_date);
CREATE INDEX idx_calendar_events_linked_note ON calendar_events(linked_note_id);
