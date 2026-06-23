-- Add AI token tracking columns to profiles table
-- These track actual Gemini API token usage for precise cost calculation

ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS ai_input_tokens BIGINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ai_output_tokens BIGINT DEFAULT 0;

COMMENT ON COLUMN profiles.ai_input_tokens IS 'Cumulative input tokens sent to Gemini API';
COMMENT ON COLUMN profiles.ai_output_tokens IS 'Cumulative output tokens received from Gemini API';
