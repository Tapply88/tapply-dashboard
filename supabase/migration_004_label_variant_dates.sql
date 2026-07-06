-- Migration: kolom tambahan buat konfigurasi label produk dari dashboard
-- (varian default, tambahan default, tanggal produksi/expiry default).

alter table products
  add column if not exists label_variant text,
  add column if not exists label_addons text[] default '{}',
  add column if not exists expiry_date date,
  add column if not exists production_date date;
