# Full Service — Badminton Manager

Aplikasi pengelolaan pertandingan badminton yang dipublikasikan melalui GitHub Pages.

## Status

- Situs yang sedang online masih menggunakan penyimpanan lokal untuk data pertandingan.
- Skema backend Supabase berada di `supabase/schema.sql`.
- Skema mencakup profil akun, persetujuan admin, data permainan bersama, konfirmasi kehadiran, dan chat grup realtime.
- Fitur belum aktif di situs sampai proyek Supabase dibuat dan frontend dikonfigurasi dengan URL proyek serta publishable/anon key.

## Rancangan multi-user

- Pendaftaran dengan nama dan email; login melalui magic link tanpa password.
- Akun baru berstatus `pending` sampai admin menyetujuinya.
- Anggota yang disetujui dapat melihat pertandingan bersama, rekap kehadiran, dan chat grup.
- Anggota hanya dapat mengubah kehadirannya sendiri.
- Anggota dapat mengirim pesan dan menghapus pesannya sendiri; admin dapat memoderasi pesan.
- Hanya admin yang dapat mengubah pemain, pertandingan, skor, dan data permainan.
- Row Level Security (RLS) menegakkan izin di database, bukan hanya menyembunyikan tombol di UI.

## Setup Supabase

1. Buat proyek Supabase.
2. Di **SQL Editor**, jalankan seluruh file `supabase/schema.sql`.
3. Di **Authentication → URL Configuration**, set Site URL ke:
   `https://jeffryfe0609-evo.github.io/Full-Sevice/`
4. Tambahkan URL yang sama ke daftar Redirect URLs.
5. Ambil Project URL dan publishable/anon key dari pengaturan API Supabase. Kunci publik hanya boleh digunakan dengan RLS aktif; jangan pernah menaruh service-role key dalam HTML/JavaScript publik.
6. Buat akun admin melalui pendaftaran, lalu promosikan UUID akun pertama menggunakan query bootstrap yang dikomentari di bagian bawah file SQL.
7. Frontend masih perlu diintegrasikan untuk login, approval admin, kehadiran, chat realtime, dan sinkronisasi data pertandingan.

Jangan membagikan service-role key, password, atau tautan login pribadi di chat atau repository.
