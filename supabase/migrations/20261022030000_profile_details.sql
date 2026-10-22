-- Profile details (all optional except name, which is enforced in-app). Minimal data.
alter table public.profiles
  add column if not exists email text check (email is null or (length(email) <= 120 and email ~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$')),
  add column if not exists profession text check (profession is null or length(profession) <= 40),
  add column if not exists gender text check (gender is null or gender in ('Female','Male','Non-binary','Prefer not to say')),
  add column if not exists city text check (city is null or length(city) <= 60),
  add column if not exists avatar_path text;
alter table public.profiles drop column if exists avatar_url;

-- Private avatars bucket: objects live at avatars/<uid>/avatar.jpg, only the owner can touch them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 1048576, allowed_mime_types = array['image/jpeg'];

create policy "avatar read own" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar update own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatar delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
-- Note: delete_my_data() cannot delete storage objects from SQL; the app removes
-- avatars/<uid>/ via the Storage API before calling it.
