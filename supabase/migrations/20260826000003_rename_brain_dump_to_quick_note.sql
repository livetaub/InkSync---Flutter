ALTER TABLE brain_dumps RENAME TO quick_notes;
ALTER INDEX idx_brain_dumps_user_created RENAME TO idx_quick_notes_user_created;

ALTER POLICY "Users can view own brain dumps" ON quick_notes RENAME TO "Users can view own quick notes";
ALTER POLICY "Users can insert own brain dumps" ON quick_notes RENAME TO "Users can insert own quick notes";
ALTER POLICY "Users can update own brain dumps" ON quick_notes RENAME TO "Users can update own quick notes";
ALTER POLICY "Users can delete own brain dumps" ON quick_notes RENAME TO "Users can delete own quick notes";

-- Storage Bucket for Quick Notes
INSERT INTO storage.buckets (id, name, public) 
VALUES ('quick-notes', 'quick-notes', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Quick Notes Public Access" ON storage.objects FOR SELECT USING ( bucket_id = 'quick-notes' );
CREATE POLICY "Users can upload quick notes media" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'quick-notes' AND auth.role() = 'authenticated' );
CREATE POLICY "Users can update quick notes media" ON storage.objects FOR UPDATE USING ( bucket_id = 'quick-notes' AND auth.role() = 'authenticated' );
CREATE POLICY "Users can delete quick notes media" ON storage.objects FOR DELETE USING ( bucket_id = 'quick-notes' AND auth.role() = 'authenticated' );
