# Tapply Dashboard

Dashboard web buat pemilik bisnis yang pakai Tapply POS — laporan penjualan, kelola produk,
dan (segera) promo/member/shift, semua dari browser. Multi-tenant: tiap bisnis yang daftar
punya datanya sendiri, gak kecampur sama bisnis lain.

**Stack:** Next.js 14 (App Router) + Tailwind CSS + Supabase (auth + database + API).

## Kenapa Supabase?

Daripada bikin backend server dari nol (auth, database, API, semuanya manual), Supabase udah
nyediain itu semua sekaligus — gratis buat mulai, dan kamu tetap punya database Postgres
beneran yang bisa di-scale nanti. Ini pilihan paling cepat buat produk yang mau dijual ke
banyak orang tapi timnya kecil.

## Setup dari nol

### 1. Bikin project Supabase
1. Buka [supabase.com](https://supabase.com), daftar gratis
2. **New Project** — kasih nama (mis. "tapply-prod"), pilih region Singapore (paling deket ke Indonesia)
3. Tunggu beberapa menit sampai project-nya siap

### 2. Jalankan skema database
1. Di dashboard Supabase, buka **SQL Editor** → **New Query**
2. Copy semua isi file `supabase/schema.sql` di project ini, paste, klik **Run**
3. Ini bakal bikin semua tabel (businesses, products, transactions, dst) + aturan keamanan
   (Row Level Security) yang mastiin tiap bisnis cuma bisa lihat datanya sendiri

### 3. Ambil API keys
1. Di Supabase dashboard → **Settings** → **API**
2. Copy **Project URL** dan **anon public** key

### 4. Setup project ini
```bash
cp .env.local.example .env.local
```
Isi `.env.local` dengan URL dan key dari langkah 3.

```bash
npm install
npm run dev
```
Buka `http://localhost:3000`.

### 5. Coba alurnya
1. Klik **Daftar Bisnis Baru** → isi email/password
2. Kamu bakal diarahin ke halaman **onboarding** → isi nama bisnis, alamat, telepon
3. Masuk ke dashboard → coba tambah produk di menu **Produk**

## Struktur project

```
src/
  app/
    page.tsx              # Landing page
    login/                # Halaman masuk
    signup/                # Halaman daftar
    onboarding/             # Setup profil bisnis pertama kali
    dashboard/
      layout.tsx           # Sidebar + topbar, guard auth
      page.tsx             # Ringkasan (stat cards)
      products/             # Kelola produk (CRUD lengkap)
      settings/             # Edit profil bisnis, tax/service
  components/               # Sidebar, Topbar, ReceiptStatCard
  lib/
    supabase/               # Client Supabase (browser, server, middleware)
    business.ts             # Helper ambil data bisnis user yang login
supabase/
  schema.sql                # Skema database + RLS policies
```

## Yang belum selesai (next steps)

Halaman ini baru mencakup **Ringkasan** dan **Produk** secara penuh — cukup buat mulai jualan
dan pantau data beneran. Menu **Promo**, **Member**, dan **Shift** di sidebar masih placeholder
("Segera") — strukturnya (tabel database, RLS) sudah siap di `schema.sql`, tinggal dibikinin
halamannya nanti, mengikuti pola yang sama kayak halaman Produk.

## Deploy ke internet

Cara paling gampang: [Vercel](https://vercel.com) (gratis buat mulai, dan dibikin sama tim
yang bikin Next.js jadi kompatibilitasnya udah pasti).

1. Push project ini ke GitHub (repo baru, terpisah dari repo Flutter app kamu)
2. Buka [vercel.com](https://vercel.com), **Import Project**, pilih repo itu
3. Di step **Environment Variables**, masukin `NEXT_PUBLIC_SUPABASE_URL` dan
   `NEXT_PUBLIC_SUPABASE_ANON_KEY` yang sama kayak di `.env.local`
4. Deploy — dalam beberapa menit dashboard kamu udah live dengan URL publik

## Sinkronisasi dengan app Flutter (Tapply POS)

Ini bagian yang paling besar buat langkah berikutnya: app Flutter yang sekarang nyimpen semua
data lokal di device (Hive). Biar dashboard ini beneran nunjukin data real dari kasir, app
Flutter perlu di-update supaya nulis transaksi/produk/dst juga ke Supabase (bukan cuma lokal),
idealnya tetap nyimpen lokal dulu (biar tetap jalan offline) terus sync ke Supabase begitu ada
internet. Itu kerjaan terpisah dari dashboard ini — kabarin kalau udah siap masuk ke situ.
