-- =====================================================
-- Dashboard Pemeliharaan Kendaraan Dinas - setup Supabase
-- Jalankan seluruh file ini sekali di: Supabase > SQL Editor > New query > Run
-- =====================================================

-- 1. TABEL
create table if not exists public.kendaraan (
  nopol             text primary key,
  jenis             text,
  merek_tipe        text,
  tahun             int,
  unit_kerja        text not null,
  kondisi           text not null default 'Baik'
                    check (kondisi in ('Baik','Rusak Ringan','Rusak Berat')),
  status            text not null default 'Siap Pakai'
                    check (status in ('Siap Pakai','Dalam Perbaikan')),
  pajak_tahunan     date,
  stnk_5tahunan     date,
  servis_berikutnya date,
  diubah_pada       timestamptz not null default now(),
  diubah_oleh       uuid default auth.uid()
);

create table if not exists public.servis (
  id           bigint generated always as identity primary key,
  tanggal      date not null default current_date,
  nopol        text not null references public.kendaraan(nopol) on update cascade,
  unit_kerja   text,
  jenis        text not null check (jenis in ('Rutin','Perbaikan')),
  uraian       text not null,
  bengkel      text,
  km           int  check (km >= 0),
  biaya        bigint not null check (biaya >= 0),
  dicatat_pada timestamptz not null default now(),
  dicatat_oleh uuid default auth.uid()
);
create index if not exists servis_tanggal_idx on public.servis (tanggal);
create index if not exists servis_nopol_idx   on public.servis (nopol);

create table if not exists public.anggaran (
  tahun      int    not null,
  unit_kerja text   not null,
  pagu       bigint not null check (pagu >= 0),
  primary key (tahun, unit_kerja)
);

-- 2. OTOMATISASI
-- Unit kerja pada catatan servis diisi otomatis dari data kendaraan
create or replace function public.isi_unit_kerja_servis()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.unit_kerja is null then
    select unit_kerja into new.unit_kerja from public.kendaraan where nopol = new.nopol;
  end if;
  return new;
end $$;

drop trigger if exists trg_isi_unit_kerja on public.servis;
create trigger trg_isi_unit_kerja before insert on public.servis
  for each row execute function public.isi_unit_kerja_servis();

-- Catat siapa dan kapan data kendaraan terakhir diubah
create or replace function public.tandai_perubahan_kendaraan()
returns trigger language plpgsql set search_path = public as $$
begin
  new.diubah_pada := now();
  new.diubah_oleh := auth.uid();
  return new;
end $$;

drop trigger if exists trg_tandai_kendaraan on public.kendaraan;
create trigger trg_tandai_kendaraan before update on public.kendaraan
  for each row execute function public.tandai_perubahan_kendaraan();

-- 3. KEAMANAN (Row Level Security)
-- Tanpa login: tidak bisa membaca atau mengubah apa pun.
-- Sudah login: boleh membaca semua tabel, mencatat servis baru,
--              dan mengubah status/kondisi/jadwal kendaraan.
-- Menghapus data dan mengubah anggaran hanya lewat dashboard Supabase (admin).
alter table public.kendaraan enable row level security;
alter table public.servis    enable row level security;
alter table public.anggaran  enable row level security;

drop policy if exists "baca_login"   on public.kendaraan;
drop policy if exists "ubah_login"   on public.kendaraan;
drop policy if exists "baca_login"   on public.servis;
drop policy if exists "tambah_login" on public.servis;
drop policy if exists "baca_login"   on public.anggaran;

create policy "baca_login"   on public.kendaraan for select to authenticated using (true);
create policy "ubah_login"   on public.kendaraan for update to authenticated using (true) with check (true);
create policy "baca_login"   on public.servis    for select to authenticated using (true);
create policy "tambah_login" on public.servis    for insert to authenticated with check (true);
create policy "baca_login"   on public.anggaran  for select to authenticated using (true);

-- 4. HAK AKSES TABEL
revoke all on public.kendaraan, public.servis, public.anggaran from anon;
grant select on public.kendaraan, public.servis, public.anggaran to authenticated;
grant insert (tanggal, nopol, unit_kerja, jenis, uraian, bengkel, km, biaya) on public.servis to authenticated;
grant update (kondisi, status, pajak_tahunan, stnk_5tahunan, servis_berikutnya) on public.kendaraan to authenticated;


-- =====================================================
-- 5. DATA CONTOH (hapus bagian ini jika ingin mulai dari data kosong)
-- =====================================================

insert into public.anggaran (tahun, unit_kerja, pagu) values
  (2026, 'Sekretariat', 30000000),
  (2026, 'Pimpinan', 25000000),
  (2026, 'Bidang Perencanaan', 20000000),
  (2026, 'Bidang Keuangan', 35000000),
  (2026, 'Bidang Umum', 40000000),
  (2026, 'Bidang Teknis', 60000000)
on conflict do nothing;

insert into public.kendaraan (nopol, jenis, merek_tipe, tahun, unit_kerja, kondisi, status, pajak_tahunan, stnk_5tahunan, servis_berikutnya) values
  ('B 1021 PQA', 'Sedan', 'Toyota Corolla Altis', 2019, 'Sekretariat', 'Baik', 'Siap Pakai', '2026-12-03', '2029-12-03', '2026-12-05'),
  ('B 1034 PQA', 'MPV', 'Toyota Innova Reborn', 2020, 'Sekretariat', 'Baik', 'Siap Pakai', '2027-03-14', '2030-03-14', '2026-11-25'),
  ('B 1045 PQA', 'MPV', 'Toyota Innova Reborn', 2021, 'Bidang Perencanaan', 'Baik', 'Siap Pakai', '2027-05-22', '2026-12-15', '2027-01-10'),
  ('B 1052 PQA', 'MPV', 'Toyota Avanza', 2018, 'Bidang Keuangan', 'Baik', 'Dalam Perbaikan', '2026-11-29', '2028-11-29', '2026-11-21'),
  ('B 1067 PQA', 'MPV', 'Daihatsu Xenia', 2017, 'Bidang Umum', 'Rusak Ringan', 'Siap Pakai', '2026-12-10', '2027-12-10', '2026-12-12'),
  ('B 1078 PQA', 'Double Cabin', 'Mitsubishi Triton', 2020, 'Bidang Teknis', 'Baik', 'Siap Pakai', '2027-07-01', '2030-07-01', '2026-11-30'),
  ('B 1083 PQA', 'Double Cabin', 'Toyota Hilux', 2016, 'Bidang Teknis', 'Rusak Ringan', 'Dalam Perbaikan', '2026-11-12', '2026-11-12', '2026-11-15'),
  ('B 1090 PQA', 'Minibus', 'Toyota Hiace', 2019, 'Bidang Umum', 'Baik', 'Siap Pakai', '2027-02-08', '2029-02-08', '2027-01-20'),
  ('B 1102 PQA', 'SUV', 'Toyota Fortuner', 2022, 'Pimpinan', 'Baik', 'Siap Pakai', '2027-09-17', '2027-09-17', '2026-12-01'),
  ('B 1115 PQA', 'MPV', 'Suzuki Ertiga', 2015, 'Bidang Keuangan', 'Rusak Berat', 'Dalam Perbaikan', '2027-01-25', '2030-01-25', '2027-02-03'),
  ('B 3301 PQB', 'Motor', 'Honda Vario 125', 2021, 'Bidang Umum', 'Baik', 'Siap Pakai', '2027-04-30', '2026-12-28', '2026-12-18'),
  ('B 3302 PQB', 'Motor', 'Honda Vario 125', 2021, 'Bidang Teknis', 'Baik', 'Siap Pakai', '2026-12-20', '2026-12-20', '2026-12-18')
on conflict do nothing;

-- Data contoh servis hanya dimasukkan jika tabel servis masih kosong
insert into public.servis (tanggal, nopol, unit_kerja, jenis, uraian, bengkel, km, biaya)
select v.tanggal::date, v.nopol, v.unit_kerja, v.jenis, v.uraian, v.bengkel, v.km, v.biaya from (values
  ('2026-01-23', 'B 1045 PQA', 'Bidang Perencanaan', 'Perbaikan', 'Perbaikan kaki-kaki', 'Bengkel Resmi Auto2000', 88089, 3593000),
  ('2026-01-23', 'B 1067 PQA', 'Bidang Umum', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Daihatsu', 56552, 919000),
  ('2026-01-27', 'B 1102 PQA', 'Pimpinan', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Auto2000', 50088, 1094000),
  ('2026-02-06', 'B 1067 PQA', 'Bidang Umum', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Daihatsu', 60768, 464000),
  ('2026-02-08', 'B 1078 PQA', 'Bidang Teknis', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Mitsubishi', 81700, 577000),
  ('2026-02-20', 'B 1034 PQA', 'Sekretariat', 'Perbaikan', 'Perbaikan kaki-kaki', 'Bengkel Resmi Auto2000', 108273, 2599000),
  ('2026-03-08', 'B 1102 PQA', 'Pimpinan', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 52702, 656000),
  ('2026-03-19', 'B 1021 PQA', 'Sekretariat', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Auto2000', 75330, 1169000),
  ('2026-03-21', 'B 1115 PQA', 'Bidang Keuangan', 'Perbaikan', 'Ganti 4 ban', 'Bengkel Resmi Suzuki', 38222, 6037000),
  ('2026-04-03', 'B 1034 PQA', 'Sekretariat', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 111616, 797000),
  ('2026-04-04', 'B 1021 PQA', 'Sekretariat', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Auto2000', 79606, 742000),
  ('2026-04-09', 'B 1083 PQA', 'Bidang Teknis', 'Perbaikan', 'Ganti 4 ban', 'Bengkel Resmi Auto2000', 63375, 4018000),
  ('2026-04-18', 'B 1115 PQA', 'Bidang Keuangan', 'Perbaikan', 'Ganti 4 ban', 'Bengkel Resmi Suzuki', 42906, 6063000),
  ('2026-04-20', 'B 1102 PQA', 'Pimpinan', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 56537, 467000),
  ('2026-05-16', 'B 3301 PQB', 'Bidang Umum', 'Perbaikan', 'Ganti ban', 'AHASS Resmi Honda', 11554, 476000),
  ('2026-05-17', 'B 1078 PQA', 'Bidang Teknis', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Mitsubishi', 86108, 443000),
  ('2026-05-20', 'B 1034 PQA', 'Sekretariat', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Auto2000', 115972, 834000),
  ('2026-05-25', 'B 1102 PQA', 'Pimpinan', 'Perbaikan', 'Turun mesin', 'Bengkel Resmi Auto2000', 60486, 13609000),
  ('2026-05-27', 'B 3302 PQB', 'Bidang Teknis', 'Perbaikan', 'Ganti kampas rem', 'AHASS Resmi Honda', 9330, 187000),
  ('2026-06-02', 'B 1083 PQA', 'Bidang Teknis', 'Perbaikan', 'Ganti kopling', 'Bengkel Resmi Auto2000', 65989, 4561000),
  ('2026-06-06', 'B 1102 PQA', 'Pimpinan', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 65130, 797000),
  ('2026-06-11', 'B 1052 PQA', 'Bidang Keuangan', 'Perbaikan', 'Turun mesin', 'Bengkel Resmi Auto2000', 120670, 12702000),
  ('2026-06-20', 'B 1021 PQA', 'Sekretariat', 'Perbaikan', 'Ganti kampas rem depan', 'Bengkel Resmi Auto2000', 82613, 1490000),
  ('2026-06-25', 'B 1078 PQA', 'Bidang Teknis', 'Perbaikan', 'Ganti kopling', 'Bengkel Resmi Mitsubishi', 90011, 4161000),
  ('2026-07-02', 'B 1102 PQA', 'Pimpinan', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 68243, 716000),
  ('2026-07-20', 'B 1034 PQA', 'Sekretariat', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 119701, 773000),
  ('2026-07-21', 'B 1083 PQA', 'Bidang Teknis', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 69899, 586000),
  ('2026-07-26', 'B 1067 PQA', 'Bidang Umum', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Daihatsu', 65558, 601000),
  ('2026-08-05', 'B 1083 PQA', 'Bidang Teknis', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 73328, 504000),
  ('2026-08-09', 'B 1021 PQA', 'Sekretariat', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Auto2000', 85303, 946000),
  ('2026-08-18', 'B 1078 PQA', 'Bidang Teknis', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Mitsubishi', 93992, 1190000),
  ('2026-08-22', 'B 1067 PQA', 'Bidang Umum', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Daihatsu', 69698, 863000),
  ('2026-08-26', 'B 3302 PQB', 'Bidang Teknis', 'Perbaikan', 'Ganti ban', 'AHASS Resmi Honda', 10262, 288000),
  ('2026-09-05', 'B 1067 PQA', 'Bidang Umum', 'Perbaikan', 'Ganti aki', 'Bengkel Resmi Daihatsu', 73590, 1100000),
  ('2026-09-06', 'B 1090 PQA', 'Bidang Umum', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 89487, 735000),
  ('2026-09-14', 'B 1052 PQA', 'Bidang Keuangan', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Auto2000', 125420, 1090000),
  ('2026-09-15', 'B 3301 PQB', 'Bidang Umum', 'Rutin', 'Ganti oli & filter', 'AHASS Resmi Honda', 12881, 200000),
  ('2026-09-21', 'B 1083 PQA', 'Bidang Teknis', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 75835, 729000),
  ('2026-09-22', 'B 1078 PQA', 'Bidang Teknis', 'Perbaikan', 'Spooring & balancing', 'Bengkel Resmi Mitsubishi', 96864, 432000),
  ('2026-10-16', 'B 1115 PQA', 'Bidang Keuangan', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Suzuki', 45967, 626000),
  ('2026-10-18', 'B 1034 PQA', 'Sekretariat', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Auto2000', 123913, 477000),
  ('2026-10-18', 'B 1102 PQA', 'Pimpinan', 'Rutin', 'Servis berkala + ganti oli', 'Bengkel Resmi Auto2000', 72916, 1223000),
  ('2026-10-21', 'B 1090 PQA', 'Bidang Umum', 'Perbaikan', 'Perbaikan kaki-kaki', 'Bengkel Resmi Auto2000', 93929, 2838000),
  ('2026-10-23', 'B 1083 PQA', 'Bidang Teknis', 'Perbaikan', 'Ganti 4 ban', 'Bengkel Resmi Auto2000', 78826, 5158000),
  ('2026-10-24', 'B 1045 PQA', 'Bidang Perencanaan', 'Perbaikan', 'Ganti kopling', 'Bengkel Resmi Auto2000', 91857, 4665000),
  ('2026-11-02', 'B 3301 PQB', 'Bidang Umum', 'Rutin', 'Ganti oli & filter', 'AHASS Resmi Honda', 14027, 330000),
  ('2026-11-09', 'B 1078 PQA', 'Bidang Teknis', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Mitsubishi', 101545, 725000),
  ('2026-11-09', 'B 1115 PQA', 'Bidang Keuangan', 'Rutin', 'Ganti oli & filter', 'Bengkel Resmi Suzuki', 50221, 462000),
  ('2026-11-10', 'B 1102 PQA', 'Pimpinan', 'Perbaikan', 'Ganti kopling', 'Bengkel Resmi Auto2000', 75588, 5800000),
  ('2026-11-10', 'B 1115 PQA', 'Bidang Keuangan', 'Perbaikan', 'Turun mesin', 'Bengkel Resmi Suzuki', 142380, 14250000),
  ('2026-11-13', 'B 1052 PQA', 'Bidang Keuangan', 'Perbaikan', 'Perbaikan AC', 'Bengkel Resmi Auto2000', 129478, 1839000),
  ('2026-11-14', 'B 1083 PQA', 'Bidang Teknis', 'Perbaikan', 'Ganti kopling', 'Bengkel Resmi Auto2000', 187420, 5450000)
) as v(tanggal, nopol, unit_kerja, jenis, uraian, bengkel, km, biaya)
where not exists (select 1 from public.servis);
