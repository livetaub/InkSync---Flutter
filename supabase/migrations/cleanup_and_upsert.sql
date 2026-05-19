-- 1. Delete older duplicate invites, keeping only the most recent one for each (note_id, to_email) pair
DELETE FROM collaboration_invites
WHERE id IN (
  SELECT id
  FROM (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY note_id, to_email ORDER BY created_at DESC) as rnum
    FROM collaboration_invites
  ) t
  WHERE t.rnum > 1
);

-- 2. Add unique constraint to prevent future duplicates
ALTER TABLE collaboration_invites
DROP CONSTRAINT IF EXISTS collaboration_invites_note_id_to_email_key;

ALTER TABLE collaboration_invites
ADD CONSTRAINT collaboration_invites_note_id_to_email_key UNIQUE (note_id, to_email);

-- 3. Replace the email trigger to fire on INSERT OR UPDATE (when changing to pending)
DROP TRIGGER IF EXISTS on_invite_created_send_email ON collaboration_invites;

CREATE OR REPLACE FUNCTION send_collaboration_invite_email()
RETURNS trigger AS $$
DECLARE
  _note_title text;
  _subject text;
  _html text;
  _plain_text text;
  _permission_label text;
  _permission_desc text;
BEGIN
  -- Only proceed if the status is exactly 'pending'
  IF NEW.status != 'pending' THEN
    RETURN NEW;
  END IF;

  -- If this is an UPDATE, only send if the status JUST changed to 'pending' from something else (like 'revoked' or 'rejected')
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'pending' THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Use the title from the invite or default
  _note_title := COALESCE(NEW.note_title, 'a note');

  -- Define permission strings based on can_edit
  IF NEW.can_edit THEN
    _permission_label := 'Editor';
    _permission_desc := 'You have full editing permissions. You can modify the note, check off items, and collaborate in real-time.';
  ELSE
    _permission_label := 'Viewer';
    _permission_desc := 'You have view-only access. You can see the note and read all updates in real-time.';
  END IF;

  -- Define subject
  _subject := NEW.from_email || ' invited you to collaborate on "' || _note_title || '"';

  -- Step 2: Build HTML content
  _html := '<!DOCTYPE html>'
    || '<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>'
    || '<body style="margin:0;padding:0;background-color:#f3f4f6;font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,Helvetica,Arial,sans-serif;">'
    || '<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6;padding:40px 20px;"><tr><td align="center">'
    
    -- Main card container
    || '<table width="100%" max-width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 6px -1px rgba(0,0,0,0.1),0 2px 4px -1px rgba(0,0,0,0.06);">'
    
    -- ========== HEADER ==========
    || '<tr><td style="background-color:#111827;padding:32px 40px;text-align:center;">'
    || '<h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:700;letter-spacing:-0.5px;">InkSync</h1>'
    || '<p style="color:#9ca3af;margin:8px 0 0;font-size:14px;font-weight:500;">Real-Time Collaboration</p>'
    || '</td></tr>'

    -- ========== BODY ==========
    || '<tr><td style="padding:40px 40px 32px;">'
    
    -- Avatar / Icon
    || '<div style="text-align:center;margin-bottom:24px;">'
    || '<div style="display:inline-block;background-color:#eff6ff;color:#3b82f6;width:56px;height:56px;line-height:56px;border-radius:28px;font-size:24px;">&#9997;</div>'
    || '</div>'

    -- Main message
    || '<h2 style="margin:0 0 16px;color:#111827;font-size:20px;font-weight:600;text-align:center;line-height:1.4;">'
    || 'You''ve been invited to collaborate!'
    || '</h2>'
    || '<p style="margin:0 0 24px;color:#4b5563;font-size:15px;line-height:1.6;text-align:center;">'
    || '<strong style="color:#111827;">' || NEW.from_email || '</strong> has invited you to collaborate on the note <strong style="color:#111827;">"' || _note_title || '"</strong> in InkSync.'
    || '</p>'

    -- Role / Permission Card
    || '<table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border-radius:12px;margin-bottom:32px;">'
    || '<tr><td style="padding:20px;">'
    || '<p style="margin:0 0 4px;font-size:12px;text-transform:uppercase;letter-spacing:0.05em;color:#64748b;font-weight:600;">Your Access Level</p>'
    || '<p style="margin:0 0 8px;font-size:16px;font-weight:600;color:#0f172a;">' || _permission_label || '</p>'
    || '<p style="margin:0;font-size:14px;color:#475569;line-height:1.5;">' || _permission_desc || '</p>'
    || '</td></tr></table>'

    -- Call to action button
    || '<div style="text-align:center;margin-bottom:32px;">'
    || '<a href="https://inksyncnote.com" style="display:inline-block;background-color:#3b82f6;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;padding:14px 28px;border-radius:8px;box-shadow:0 2px 4px rgba(59,130,246,0.3);">Open InkSync to Accept</a>'
    || '</div>'

    -- Sub-text
    || '<p style="margin:0;color:#6b7280;font-size:13px;line-height:1.6;text-align:center;">'
    || 'If you don''t have an InkSync account yet, you can create one for free to access this note.'
    || '</p>'
    || '</td></tr>'

    -- Divider
    || '<tr><td style="padding:0 40px;"><div style="border-top:1px solid #e5e7eb;"></div></td></tr>'

    -- ========== FEATURES GRID ==========
    || '<tr><td style="padding:32px 40px;">'
    || '<p style="margin:0 0 20px;font-size:14px;font-weight:600;color:#374151;text-align:center;">Why you''ll love InkSync</p>'
    
    || '<table width="100%" cellpadding="0" cellspacing="0">'
    -- Row 1
    || '<tr>'
    || '<td width="50%" style="padding:0 8px 16px 0;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#10024;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">Rich Editor</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">Format text with a beautiful, intuitive interface.</div>'
    || '</div></td>'
    || '<td width="50%" style="padding:0 0 16px 8px;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#9889;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">Real-Time Sync</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">See changes instantly as your team types.</div>'
    || '</div></td>'
    || '</tr>'

    -- Row 2
    || '<tr>'
    || '<td width="50%" style="padding:0 8px 16px 0;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#9745;&#65039;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">Smart Checklists</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">Organize tasks with interactive checklists.</div>'
    || '</div></td>'
    || '<td width="50%" style="padding:0 0 16px 8px;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#129302;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">AI-Powered Writing</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">Proofread, rephrase, and enhance with Gemini AI.</div>'
    || '</div></td>'
    || '</tr>'

    -- Row 3
    || '<tr>'
    || '<td width="50%" style="padding:0 8px 16px 0;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#128274;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">Note Locking</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">Protect sensitive notes with password locks.</div>'
    || '</div></td>'
    || '<td width="50%" style="padding:0 0 16px 8px;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#127912;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">Color Themes</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">Personalize notes with beautiful accent colors.</div>'
    || '</div></td>'
    || '</tr>'

    || '</table>'
    || '</td></tr>'

    -- Divider
    || '<tr><td style="padding:8px 40px 0;"><div style="border-top:1px solid #e5e7eb;"></div></td></tr>'

    -- ========== PLATFORM LINKS ==========
    || '<tr><td style="padding:24px 40px 8px;text-align:center;">'
    || '<p style="margin:0 0 12px;font-size:13px;font-weight:600;color:#374151;">Available on all your devices</p>'
    || '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;"><tr>'
    || '<td style="padding:0 8px;">'
    || '<a href="https://inksyncnote.com" style="display:inline-block;background:#111827;color:#fff;font-size:12px;font-weight:600;text-decoration:none;padding:10px 20px;border-radius:8px;">&#127760; Web App</a>'
    || '</td>'
    || '<td style="padding:0 8px;">'
    || '<a href="#" style="display:inline-block;background:#111827;color:#fff;font-size:12px;font-weight:600;text-decoration:none;padding:10px 20px;border-radius:8px;">&#63743; iOS (Coming Soon)</a>'
    || '</td>'
    || '<td style="padding:0 8px;">'
    || '<a href="#" style="display:inline-block;background:#111827;color:#fff;font-size:12px;font-weight:600;text-decoration:none;padding:10px 20px;border-radius:8px;">&#129302; Android (Coming Soon)</a>'
    || '</td>'
    || '</tr></table>'
    || '</td></tr>'

    -- ========== FOOTER ==========
    || '<tr><td style="padding:24px 40px 32px;text-align:center;">'
    || '<p style="margin:0 0 8px;font-size:11px;color:#9ca3af;line-height:1.5;">'
    || 'You''re receiving this because <strong>' || NEW.to_email || '</strong> was invited to collaborate by ' || NEW.from_email || '.'
    || '</p>'
    || '<p style="margin:0;font-size:11px;color:#d1d5db;">'
    || '&copy; InkSync &middot; <a href="https://inksyncnote.com" style="color:#9ca3af;text-decoration:none;">inksyncnote.com</a>'
    || '</p>'
    || '</td></tr>'

    || '</table>'  -- end main card
    || '</td></tr></table>'  -- end outer wrapper
    || '</body></html>';

  -- Plain text version
  _plain_text := 'You''ve been invited to collaborate!' || E'\n\n'
    || NEW.from_email || ' has invited you to collaborate on "' || _note_title || '" in InkSync.' || E'\n\n'
    || 'Your access level: ' || _permission_label || E'\n'
    || _permission_desc || E'\n\n'
    || 'Open InkSync: https://inksyncnote.com' || E'\n'
    || 'Already have an account? Sign in at https://inksyncnote.com' || E'\n'
    || 'New to InkSync? Create a free account at https://inksyncnote.com' || E'\n\n'
    || '---' || E'\n'
    || 'InkSync is a beautiful, cross-platform note-taking app for seamless writing and real-time collaboration.' || E'\n'
    || 'Features: Rich Editor, Real-Time Collaboration, Smart Checklists, AI-Powered Writing, Note Locking, Color Themes' || E'\n'
    || 'Web: https://inksyncnote.com' || E'\n\n'
    || 'You''re receiving this because ' || NEW.to_email || ' was invited by ' || NEW.from_email || '.';

  -- Step 3: Fire the HTTP request to Resend
  PERFORM net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer re_9ViRG4Ys_6u6EK1mdu27KSBDTTmDGRMEJ'
    ),
    body := jsonb_build_object(
      'from', 'InkSync <noreply@invite.inksyncnote.com>',
      'reply_to', NEW.from_email,
      'to', jsonb_build_array(NEW.to_email),
      'subject', _subject,
      'html', _html,
      'text', _plain_text
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_invite_created_send_email
  AFTER INSERT OR UPDATE ON collaboration_invites
  FOR EACH ROW
  EXECUTE FUNCTION send_collaboration_invite_email();
