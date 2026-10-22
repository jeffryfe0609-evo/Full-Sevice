-- Full Service Badminton: profile photo storage setup
-- Run once in Supabase Dashboard > SQL Editor on an existing project.
alter table public.profiles add column if not exists avatar_url text;
grant update (display_name, avatar_url, status, role, approved_at) on public.profiles to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', true, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Profile photos are publicly viewable" on storage.objects;
create policy "Profile photos are publicly viewable" on storage.objects
for select using (bucket_id = 'profile-photos');

drop policy if exists "Users upload own profile photo" on storage.objects;
create policy "Users upload own profile photo" on storage.objects
for insert to authenticated with check (
 bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users update own profile photo" on storage.objects;
create policy "Users update own profile photo" on storage.objects
for update to authenticated using (
 bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text
) with check (
 bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users delete own profile photo" on storage.objects;
create policy "Users delete own profile photo" on storage.objects
for delete to authenticated using (
 bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text
);
