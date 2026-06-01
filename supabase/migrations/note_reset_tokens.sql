-- ============================================================
-- InkSync: Note Lock Password Reset Tokens & RPC Functions
-- ============================================================

-- Create table for note reset tokens
CREATE TABLE IF NOT EXISTS note_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Enable Row Level Security (RLS)
ALTER TABLE note_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Note reset tokens is a system table, so no direct client access is needed.
-- Security definer functions will manage inserts and deletes.

-- Function to request note unlock
CREATE OR REPLACE FUNCTION request_note_unlock(
  p_note_id UUID,
  p_email TEXT,
  p_origin TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  _note_title TEXT;
  _token TEXT;
  _subject TEXT;
  _html TEXT;
  _plain_text TEXT;
  _link TEXT;
  _origin TEXT;
BEGIN
  -- 1. Verify note exists and belongs to the user
  SELECT title INTO _note_title
  FROM notes
  WHERE id = p_note_id AND user_id = auth.uid();
  
  IF _note_title IS NULL THEN
    RAISE EXCEPTION 'Note not found or unauthorized';
  END IF;

  _note_title := COALESCE(NULLIF(_note_title, ''), 'Untitled Note');

  -- 2. Generate a secure random token (64-character hex)
  _token := encode(gen_random_bytes(32), 'hex');

  -- 3. Delete any existing tokens for this note
  DELETE FROM note_reset_tokens WHERE note_id = p_note_id;

  -- 4. Insert new token (expires in 1 hour)
  INSERT INTO note_reset_tokens (note_id, token, expires_at, user_id)
  VALUES (p_note_id, _token, now() + interval '1 hour', auth.uid());

  -- 5. Build verification link (defaulting to production if empty)
  _origin := COALESCE(NULLIF(p_origin, ''), 'https://app.inksyncnote.com');
  _link := _origin || '/note-unlock?token=' || _token || '&note_id=' || p_note_id;

  -- 6. Construct email
  _subject := 'Reset password for your locked note: "' || _note_title || '"';

  _html := '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>'
    || '<body style="margin:0;padding:0;background-color:#f3f4f6;font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,sans-serif;">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6;padding:40px 16px;">'
    || '<tr><td align="center">'
    || '<table role="presentation" width="520" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 12px rgba(0,0,0,0.05);max-width:520px;width:100%;">'
    || '<tr><td style="background-color:#111827;padding:32px;text-align:center;">'
    || '<div style="font-size:24px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">InkSync</div>'
    || '<div style="font-size:12px;color:#9ca3af;margin-top:4px;">Secure Note Unlock</div>'
    || '</td></tr>'
    || '<tr><td style="padding:32px 32px 0;">'
    || '<h2 style="margin:0 0 16px;font-size:20px;font-weight:600;color:#111827;">Reset Note Password</h2>'
    || '<p style="margin:0 0 24px;font-size:15px;color:#4b5563;line-height:1.6;">'
    || 'You requested to unlock or reset the password for your locked note <strong style="color:#111827;">"' || _note_title || '"</strong> on InkSync.'
    || '</p>'
    || '</td></tr>'
    || '<tr><td style="padding:0 32px 24px;" align="center">'
    || '<a href="' || _link || '" style="display:inline-block;background-color:#10B981;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;padding:14px 28px;border-radius:8px;box-shadow:0 2px 4px rgba(16,185,129,0.3);">Unlock Note</a>'
    || '</td></tr>'
    || '<tr><td style="padding:0 32px 32px;">'
    || '<p style="margin:0;font-size:13px;color:#6b7280;line-height:1.5;">'
    || 'This link will expire in 1 hour. If you did not request this, you can safely ignore this email — your note remains securely locked.'
    || '</p>'
    || '</td></tr>'
    || '<tr><td style="padding:0 32px;"><div style="border-top:1px solid #e5e7eb;"></div></td></tr>'
    || '<tr><td style="padding:24px 32px 32px;text-align:center;">'
    || '<p style="margin:0;font-size:11px;color:#9ca3af;">&copy; InkSync &middot; <a href="https://inksyncnote.com" style="color:#9ca3af;text-decoration:none;">inksyncnote.com</a></p>'
    || '</td></tr>'
    || '</table>'
    || '</td></tr></table>'
    || '</body></html>';

  _plain_text := 'Reset password for your locked note: "' || _note_title || '"' || E'\n\n'
    || 'You requested to unlock or reset the password for your locked note "' || _note_title || '" on InkSync.' || E'\n\n'
    || 'Follow this link to unlock your note and set a new password:' || E'\n'
    || _link || E'\n\n'
    || 'This link will expire in 1 hour. If you did not request this, you can safely ignore this email.';

  -- 7. Fire the HTTP request to Resend
  PERFORM net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'resend_api_key' LIMIT 1)
    ),
    body := jsonb_build_object(
      'from', 'InkSync <noreply@invite.inksyncnote.com>',
      'to', jsonb_build_array(p_email),
      'subject', _subject,
      'html', _html,
      'text', _plain_text
    )
  );

END;
$$;

-- Function to check if a token is valid without consuming it
CREATE OR REPLACE FUNCTION check_note_unlock_token(
  p_note_id UUID,
  p_token TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1
    FROM note_reset_tokens
    WHERE note_id = p_note_id AND token = p_token AND expires_at > now()
  );
END;
$$;

-- Function to verify note unlock and optionally set a new password
CREATE OR REPLACE FUNCTION verify_note_unlock(
  p_note_id UUID,
  p_token TEXT,
  p_new_password TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  _token_record RECORD;
BEGIN
  -- 1. Find valid token
  SELECT * INTO _token_record
  FROM note_reset_tokens
  WHERE note_id = p_note_id AND token = p_token AND expires_at > now();

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- 2. Update the note
  IF p_new_password IS NOT NULL AND p_new_password != '' THEN
    UPDATE notes
    SET is_locked = TRUE, lock_password = p_new_password
    WHERE id = p_note_id;
  ELSE
    UPDATE notes
    SET is_locked = FALSE, lock_password = NULL
    WHERE id = p_note_id;
  END IF;

  -- 3. Delete the used token
  DELETE FROM note_reset_tokens WHERE id = _token_record.id;

  RETURN TRUE;
END;
$$;
