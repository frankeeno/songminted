-- Run once in Supabase → SQL Editor (service role). Enables full-length Cover uploads.
-- App uploads WAV to covers/{user_id}/{uuid}.wav then mints with audioUrl.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'covers',
  'covers',
  false,
  104857600,
  array['audio/wav','audio/mpeg','audio/mp4','audio/x-m4a','video/mp4']
)
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit;

drop policy if exists "covers insert own" on storage.objects;
drop policy if exists "covers select own" on storage.objects;

create policy "covers insert own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'covers'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "covers select own"
on storage.objects for select to authenticated
using (
  bucket_id = 'covers'
  and (storage.foldername(name))[1] = auth.uid()::text
);
