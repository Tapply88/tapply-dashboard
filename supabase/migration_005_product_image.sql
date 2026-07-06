-- Migration: simpan foto produk sebagai base64 (konsisten sama app Flutter),
-- daripada setup Supabase Storage bucket buat MVP ini.
alter table products
  add column if not exists image_base64 text;
