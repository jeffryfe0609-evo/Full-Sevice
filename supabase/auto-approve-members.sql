-- Full Service: otomatis aktifkan anggota baru setelah Supabase Auth berhasil.
-- Jalankan sekali di Supabase SQL Editor pada project dsaaqmsctxqqhfknwxac.
-- Akun baru selalu role member; akun admin yang sudah ada tidak diturunkan.

create or replace function public.handle_new_full_service_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Anggota'
  );

  insert into public.profiles (user_id, display_name, status, role)
  values (new.id, left(v_name, 60), 'approved', 'member')
  on conflict (user_id) do update
    set display_name = coalesce(nullif(trim(public.profiles.display_name), ''), excluded.display_name),
        status = case when public.profiles.role = 'admin' then public.profiles.status else 'approved' end;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_full_service on auth.users;
create trigger on_auth_user_created_full_service
after insert on auth.users
for each row execute procedure public.handle_new_full_service_user();

-- Aktifkan anggota yang sudah terdaftar dan menunggu; admin tetap admin.
update public.profiles
set status = 'approved'
where status = 'pending' and role <> 'admin';
