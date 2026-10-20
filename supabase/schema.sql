-- Full Service Badminton: Supabase database setup
-- Run this entire file in Supabase Dashboard > SQL Editor.
-- Then register the admin account and run the ADMIN BOOTSTRAP query at the bottom.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 60),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

create table if not exists public.app_state (
  id integer primary key default 1 check (id = 1),
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.attendance (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'belum' check (status in ('hadir','tidak','belum')),
  note text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.app_state enable row level security;
alter table public.attendance enable row level security;

-- Shared group chat: only approved members can read/send.
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  message text not null check (char_length(trim(message)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists chat_messages_created_at_idx on public.chat_messages (created_at desc);
alter table public.chat_messages enable row level security;

-- Helper checks run with invoker rights; policies remain the security boundary.
create or replace function public.is_approved_member()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.user_id = (select auth.uid())
      and p.status = 'approved'
  );
$$;

create or replace function public.is_app_admin()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.user_id = (select auth.uid())
      and p.status = 'approved'
      and p.role = 'admin'
  );
$$;

revoke all on function public.is_approved_member() from public;
revoke all on function public.is_app_admin() from public;
grant execute on function public.is_approved_member() to authenticated;
grant execute on function public.is_app_admin() to authenticated;

-- Create a profile automatically after a user signs up. The display name is
-- supplied as auth user metadata by the registration form.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chosen_name text;
begin
  chosen_name := trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  if char_length(chosen_name) < 2 then
    chosen_name := split_part(coalesce(new.email, 'pemain'), '@', 1);
  end if;
  insert into public.profiles (user_id, display_name, status, role)
  values (new.id, left(chosen_name, 60), 'pending', 'member')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_full_service on auth.users;
create trigger on_auth_user_created_full_service
after insert on auth.users
for each row execute procedure public.handle_new_user();

grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
-- Members may edit display_name; admins can manage approval/role fields under RLS.
grant update (display_name, status, role, approved_at) on public.profiles to authenticated;
grant select, insert, update, delete on public.app_state to authenticated;
grant select, insert, update on public.attendance to authenticated;
grant select, insert, delete on public.chat_messages to authenticated;


-- Profiles: approved members can see approved members and their own profile.
-- Users cannot approve themselves or change their role/status.
drop policy if exists "profile select own or approved" on public.profiles;
create policy "profile select own or approved"
on public.profiles for select to authenticated
using (
  user_id = (select auth.uid())
  or (public.is_approved_member() and status = 'approved')
  or public.is_app_admin()
);

drop policy if exists "profile update own display name" on public.profiles;
create policy "profile update own display name"
on public.profiles for update to authenticated
using (user_id = (select auth.uid()) and status = 'approved')
with check (user_id = (select auth.uid()) and status = 'approved' and role = 'member');

drop policy if exists "admin manage profiles" on public.profiles;
create policy "admin manage profiles"
on public.profiles for update to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

-- Only approved accounts can read shared game state; only admins can write it.
drop policy if exists "approved members read shared state" on public.app_state;
create policy "approved members read shared state"
on public.app_state for select to authenticated
using (public.is_approved_member());

drop policy if exists "admins insert shared state" on public.app_state;
create policy "admins insert shared state"
on public.app_state for insert to authenticated
with check (public.is_app_admin());

drop policy if exists "admins update shared state" on public.app_state;
create policy "admins update shared state"
on public.app_state for update to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

drop policy if exists "admins delete shared state" on public.app_state;
create policy "admins delete shared state"
on public.app_state for delete to authenticated
using (public.is_app_admin());

-- Attendance: approved members can see the group roll-call. Each member may
-- insert/update only their own attendance row. Admins may manage all rows.
drop policy if exists "approved members read attendance" on public.attendance;
create policy "approved members read attendance"
on public.attendance for select to authenticated
using (public.is_approved_member());

drop policy if exists "members insert own attendance" on public.attendance;
create policy "members insert own attendance"
on public.attendance for insert to authenticated
with check (user_id = (select auth.uid()) and public.is_approved_member());

drop policy if exists "members update own attendance" on public.attendance;
create policy "members update own attendance"
on public.attendance for update to authenticated
using ((user_id = (select auth.uid()) and public.is_approved_member()) or public.is_app_admin())
with check ((user_id = (select auth.uid()) and public.is_approved_member()) or public.is_app_admin());

drop policy if exists "admins delete attendance" on public.attendance;
create policy "admins delete attendance"
on public.attendance for delete to authenticated
using (public.is_app_admin());

-- Chat RLS: members can send and delete their own messages; admins can moderate.
drop policy if exists "approved members read chat" on public.chat_messages;
create policy "approved members read chat" on public.chat_messages
for select to authenticated using (public.is_approved_member());

drop policy if exists "approved members send own chat" on public.chat_messages;
create policy "approved members send own chat" on public.chat_messages
for insert to authenticated with check (
 user_id = (select auth.uid()) and public.is_approved_member()
 and char_length(trim(message)) between 1 and 2000
);

drop policy if exists "members delete own chat" on public.chat_messages;
create policy "members delete own chat" on public.chat_messages
for delete to authenticated using (
 (user_id = (select auth.uid()) and public.is_approved_member())
 or public.is_app_admin()
);

-- Allow realtime subscriptions for shared state and attendance.
do $$$
begin
  alter publication supabase_realtime add table public.app_state;
exception when duplicate_object then null;
when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.attendance;
exception when duplicate_object then null;
when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.chat_messages;
exception when duplicate_object then null;
when undefined_object then null;
end $$;

-- INITIAL SETUP (do this only after creating your own account through the app):
-- 1) Find your user UUID in Authentication > Users.
-- 2) Replace YOUR-USER-UUID below and run:
-- update public.profiles set status='approved', role='admin', approved_at=now()
-- where user_id='YOUR-USER-UUID';
--
-- Admin approval of a pending member:
-- update public.profiles set status='approved', approved_at=now()
-- where user_id='MEMBER-USER-UUID' and status='pending';
--
-- Admin rejection:
-- update public.profiles set status='rejected'
-- where user_id='MEMBER-USER-UUID' and status='pending';
