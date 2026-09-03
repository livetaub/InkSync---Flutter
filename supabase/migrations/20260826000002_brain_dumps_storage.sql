-- Create a new storage bucket for Brain Dump / Quick Note media
INSERT INTO storage.buckets (id, name, public) 
VALUES ('brain-dumps', 'brain-dumps', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS for the storage bucket
-- Allow public access to read files
CREATE POLICY "Brain Dumps Public Access" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'brain-dumps' );

-- Allow authenticated users to upload files to their own folder
CREATE POLICY "Users can upload brain dumps media" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'brain-dumps' 
  AND auth.role() = 'authenticated'
);

-- Allow authenticated users to update their own files
CREATE POLICY "Users can update brain dumps media" 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'brain-dumps' 
  AND auth.role() = 'authenticated'
);

-- Allow authenticated users to delete their own files
CREATE POLICY "Users can delete brain dumps media" 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'brain-dumps' 
  AND auth.role() = 'authenticated'
);
