-- Enable the pg_cron extension if it isn't already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- Safely unschedule the job if it already exists (prevents duplicates when running migrations multiple times)
DO $$
BEGIN
  PERFORM cron.unschedule('empty_trash_older_than_30_days');
EXCEPTION WHEN OTHERS THEN
  -- Ignore error if the job doesn't exist yet
END;
$$;

-- Schedule a daily job at midnight to permanently delete notes that have been in the trash for > 30 days
SELECT cron.schedule(
    'empty_trash_older_than_30_days', -- Job Name
    '0 0 * * *',                      -- Cron expression: Every day at 00:00
    $$
    DELETE FROM public.notes 
    WHERE trashed_at IS NOT NULL 
      AND trashed_at < (NOW() - INTERVAL '30 days');
    $$
);
