# Dashboard Pemeliharaan Kendaraan Dinas: versi Supabase

Aplikasi web untuk memantau dan mencatat pemeliharaan kendaraan dinas.

- **Supabase** menyimpan data (kendaraan, servis, anggaran) dan mengatur login.
- **GitHub Pages** (atau Netlify/Vercel) menyajikan halaman web.

## Isi folder

| File | Fungsi |
|---|---|
| `index.html` | Halaman aplikasi: login, dashboard, form catat servis, form update kendaraan |
| `config.js` | **Satu-satunya file yang perlu Anda edit**: alamat & kunci Supabase |
| `setup.sql` | Membuat tabel, aturan keamanan, dan mengisi data contoh di Supabase |

## Fitur

- Login dengan email & password. Tanpa login, data tidak bisa dibaca sama sekali.
- Dashboard: kendaraan siap pakai, biaya bulan ini vs bulan lalu, serapan anggaran, kewajiban jatuh tempo ≤ 30 hari, grafik biaya per bulan / per kendaraan / per unit kerja, daftar armada, riwayat servis.
- Filter per unit kerja.
- **＋ Catat servis**: mencatat servis/perbaikan baru, sekaligus (opsional) mengisi jadwal servis berikutnya dan mengubah status kendaraan jadi *Siap Pakai*.
- **Update kendaraan**: mengubah status, kondisi, tanggal pajak, STNK, dan servis berikutnya. Bisa juga dengan mengklik baris kendaraan di tabel.

Hak akses pengguna yang login: membaca semua data, menambah catatan servis, dan mengubah status/kondisi/tanggal kendaraan.
Menghapus data, menambah kendaraan baru, dan mengubah pagu anggaran hanya bisa dilakukan admin lewat dashboard Supabase.

---

## Langkah pemasangan

### 1. Buat project Supabase
1. Daftar/masuk di <https://supabase.com>, klik **New project**.
2. Isi nama project, buat **Database Password** (simpan baik-baik), pilih region **Southeast Asia (Singapore)**.
3. Tunggu sampai project selesai dibuat (±2 menit).

### 2. Jalankan `setup.sql`
1. Di menu kiri buka **SQL Editor** → **New query**.
2. Buka file `setup.sql`, salin **seluruh** isinya, tempel, lalu klik **Run**.
3. Cek di **Table Editor**: harus ada tabel `kendaraan` (12 baris), `servis` (52 baris), `anggaran` (6 baris).

> Data yang terisi adalah **data contoh**. Untuk mulai dengan data asli, hapus bagian "5. DATA CONTOH" di akhir `setup.sql` sebelum dijalankan, atau kosongkan tabel setelahnya lalu impor data Anda (lihat bagian *Memasukkan data asli*).
> File ini aman dijalankan ulang; data contoh servis tidak akan terduplikasi.

### 3. Buat akun petugas
1. Buka **Authentication → Users → Add user → Create new user**.
2. Isi email & password, centang **Auto Confirm User**, lalu **Create user**. Ulangi untuk setiap petugas.
3. Supaya orang lain tidak bisa mendaftar sendiri: buka **Authentication → Sign In / Providers** dan **matikan** *Allow new users to sign up*.

### 4. Isi `config.js`
1. Buka **Project Settings → API** (di beberapa versi bernama **Data API** / **API Keys**).
2. Salin **Project URL** dan **anon public** key (atau **publishable** key).
3. Tempel ke `config.js`:
   ```js
   window.SUPABASE_URL = 'https://abcdefghijkl.supabase.co';
   window.SUPABASE_ANON_KEY = 'eyJhbGciOi...';
   ```

> ⚠️ **Jangan** pernah memakai **service_role** / **secret** key di file ini. Kunci itu melewati semua aturan keamanan.
> Kunci *anon/publishable* memang dirancang untuk berada di halaman web; datanya tetap terlindungi karena tabel hanya bisa dibaca setelah login.

### 5. Publikasikan di GitHub Pages
1. Buat repository baru di GitHub, upload `index.html` dan `config.js`. `setup.sql` dan `README.md` boleh ikut diupload, tidak berbahaya.
2. **Settings → Pages** → *Deploy from a branch* → branch `main`, folder `/ (root)` → **Save**.
3. Setelah 1–2 menit, aplikasi bisa dibuka di `https://<username>.github.io/<nama-repo>/`.

### 6. Daftarkan alamat situs di Supabase
**Authentication → URL Configuration → Site URL**: isi dengan alamat GitHub Pages Anda.

Selesai. Buka alamat situs, login dengan akun dari langkah 3.

---

## Mencoba di komputer sendiri

Dari folder ini jalankan:
```
python -m http.server 8000
```
lalu buka <http://localhost:8000>.

## Memasukkan data asli

- **Kendaraan / anggaran**: di **Table Editor**, pilih tabel → **Insert → Import data from CSV**. Simpan Excel Anda sebagai CSV dengan nama kolom persis seperti di tabel. Tanggal ditulis `YYYY-MM-DD`.
  - `kondisi`: `Baik` / `Rusak Ringan` / `Rusak Berat`
  - `status`: `Siap Pakai` / `Dalam Perbaikan`
- **Riwayat servis lama**: impor CSV ke tabel `servis` dengan kolom `tanggal, nopol, jenis, uraian, bengkel, km, biaya`. Kolom `id` dan `unit_kerja` terisi otomatis. `jenis` diisi `Rutin` atau `Perbaikan`.
- **Anggaran tahun baru**: tambahkan baris di tabel `anggaran` (`tahun`, `unit_kerja`, `pagu`) setiap awal tahun.
- Nama `unit_kerja` harus ditulis sama persis di tabel `kendaraan` dan `anggaran`.

Untuk mengosongkan data contoh, jalankan di SQL Editor:
```sql
truncate public.servis, public.kendaraan, public.anggaran restart identity cascade;
```

## Catatan

- **Free plan Supabase** menghentikan sementara (*pause*) project yang tidak dipakai selama 7 hari. Buka dashboard Supabase dan klik *Restore* bila itu terjadi, atau pakai paket berbayar untuk penggunaan resmi.
- Setiap catatan servis dan perubahan kendaraan menyimpan **siapa** dan **kapan** (`dicatat_oleh`/`dicatat_pada`, `diubah_oleh`/`diubah_pada`), bisa dilihat di Table Editor.
- Bila muncul pesan "Konfigurasi Supabase belum diisi", periksa `config.js`.
- Bila muncul "Akun Anda tidak memiliki izin", pastikan `setup.sql` sudah dijalankan lengkap.
