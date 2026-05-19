-- ============================================================
-- InkSync: Auto-send collaboration invite emails via Resend
-- Uses pg_net extension (built into Supabase) to call Resend API
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- Step 1: Enable pg_net extension (may already be enabled)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Step 2: Create the trigger function
CREATE OR REPLACE FUNCTION send_collaboration_invite_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  _subject TEXT;
  _html TEXT;
  _plain_text TEXT;
  _note_title TEXT;
  _permission_label TEXT;
  _permission_desc TEXT;
  _permission_color TEXT;
  _permission_bg TEXT;
BEGIN
  -- Build display values
  _note_title := COALESCE(NULLIF(NEW.note_title, ''), 'Untitled Note');
  
  IF NEW.can_edit THEN
    _permission_label := 'Editor';
    _permission_desc := 'You have full editing access — make changes, add content, and collaborate in real time.';
    _permission_color := '#1d4ed8';
    _permission_bg := '#dbeafe';
  ELSE
    _permission_label := 'Viewer';
    _permission_desc := 'You have view-only access to read and reference this note.';
    _permission_color := '#6b7280';
    _permission_bg := '#f3f4f6';
  END IF;

  _subject := NEW.from_email || ' invited you to collaborate on "' || _note_title || '"';

  _html := '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>'
    || '<body style="margin:0;padding:0;background-color:#f0f4f8;font-family:-apple-system,BlinkMacSystemFont,''Segoe UI'',Roboto,''Helvetica Neue'',sans-serif;">'

    -- Outer wrapper
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0f4f8;padding:40px 16px;">'
    || '<tr><td align="center">'

    -- ========== MAIN CARD ==========
    || '<table role="presentation" width="520" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 8px 40px rgba(0,0,0,0.08);max-width:520px;width:100%;">'

    -- Header with gradient
    || '<tr><td style="background:linear-gradient(135deg,#1E88E5 0%,#10D98C 100%);padding:40px 40px 32px;text-align:center;">'
    || '<div style="font-size:32px;font-weight:800;color:#ffffff;letter-spacing:-0.5px;">&#10022; InkSync</div>'
    || '<div style="font-size:14px;color:rgba(255,255,255,0.9);margin-top:6px;font-weight:400;">Collaboration Invitation</div>'
    || '</td></tr>'

    -- Greeting & Invite Message
    || '<tr><td style="padding:36px 40px 0;">'
    || '<h1 style="margin:0 0 16px;font-size:22px;font-weight:700;color:#111827;line-height:1.3;">You''ve been invited to collaborate!</h1>'
    || '<p style="margin:0 0 24px;font-size:15px;color:#4b5563;line-height:1.7;">'
    || '<strong style="color:#111827;">' || NEW.from_email || '</strong> has invited you to collaborate on a note in InkSync. Jump in and start working together!'
    || '</p>'
    || '</td></tr>'

    -- Note Card
    || '<tr><td style="padding:0 40px;">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:28px;">'
    || '<tr><td style="background:linear-gradient(135deg,#f0fdf4,#ecfdf5);border:1px solid #bbf7d0;border-radius:14px;padding:24px;">'
    || '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#9ca3af;margin-bottom:10px;font-weight:600;">&#128196; Shared Note</div>'
    || '<div style="font-size:20px;font-weight:700;color:#111827;margin-bottom:6px;">' || _note_title || '</div>'
    || '<div style="font-size:13px;color:#6b7280;margin-bottom:14px;">Shared by ' || NEW.from_email || '</div>'
    || '<div style="display:inline-block;background-color:' || _permission_bg || ';color:' || _permission_color || ';font-size:12px;font-weight:600;padding:5px 14px;border-radius:20px;">' || _permission_label || ' Access</div>'
    || '</td></tr></table>'
    || '</td></tr>'

    -- Permission Description
    || '<tr><td style="padding:0 40px 28px;">'
    || '<p style="margin:0;font-size:14px;color:#6b7280;line-height:1.6;background-color:#f9fafb;padding:14px 18px;border-radius:10px;border-left:3px solid #10B981;">'
    || _permission_desc
    || '</p>'
    || '</td></tr>'

    -- CTA Buttons
    || '<tr><td style="padding:0 40px 16px;" align="center">'
    || '<a href="https://inksyncnote.com" style="display:inline-block;background:linear-gradient(135deg,#10B981,#059669);color:#ffffff;font-size:16px;font-weight:700;text-decoration:none;padding:16px 48px;border-radius:12px;box-shadow:0 4px 14px rgba(16,185,129,0.4);">Open InkSync</a>'
    || '</td></tr>'

    || '<tr><td style="padding:0 40px 32px;" align="center">'
    || '<p style="margin:0;font-size:13px;color:#9ca3af;">'
    || 'Already have an account? <a href="https://inksyncnote.com" style="color:#10B981;text-decoration:none;font-weight:600;">Sign in here</a>'
    || ' &middot; New to InkSync? <a href="https://inksyncnote.com" style="color:#10B981;text-decoration:none;font-weight:600;">Create a free account</a>'
    || '</p>'
    || '</td></tr>'

    -- Divider
    || '<tr><td style="padding:0 40px;"><div style="border-top:1px solid #e5e7eb;"></div></td></tr>'

    -- ========== ABOUT INKSYNC SECTION ==========
    || '<tr><td style="padding:32px 40px 0;">'
    || '<h2 style="margin:0 0 8px;font-size:16px;font-weight:700;color:#111827;">What is InkSync?</h2>'
    || '<p style="margin:0 0 20px;font-size:14px;color:#6b7280;line-height:1.6;">InkSync is a beautiful, cross-platform note-taking app designed for seamless writing and real-time collaboration.</p>'
    || '</td></tr>'

    -- Feature Grid (2 columns)
    || '<tr><td style="padding:0 40px;">'
    || '<table role="presentation" width="100%" cellpadding="0" cellspacing="0">'

    -- Row 1
    || '<tr>'
    || '<td width="50%" style="padding:0 8px 16px 0;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#9997;&#65039;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">Rich Note Editor</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">Write freely with a distraction-free, premium editor.</div>'
    || '</div></td>'
    || '<td width="50%" style="padding:0 0 16px 8px;vertical-align:top;">'
    || '<div style="background:#f8fafc;border-radius:12px;padding:16px;">'
    || '<div style="font-size:20px;margin-bottom:6px;">&#128101;</div>'
    || '<div style="font-size:13px;font-weight:600;color:#111827;margin-bottom:4px;">Real-Time Collaboration</div>'
    || '<div style="font-size:12px;color:#6b7280;line-height:1.4;">Invite others and work on notes together.</div>'
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

  -- Plain text version (required for deliverability)
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
$$;

-- Step 4: Create the trigger on collaboration_invites
DROP TRIGGER IF EXISTS on_invite_created_send_email ON collaboration_invites;

CREATE TRIGGER on_invite_created_send_email
  AFTER INSERT ON collaboration_invites
  FOR EACH ROW
  EXECUTE FUNCTION send_collaboration_invite_email();
