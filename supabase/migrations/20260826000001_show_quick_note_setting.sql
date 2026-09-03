-- Add show_quick_note setting to user_settings table
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_quick_note BOOLEAN DEFAULT true;
