-- Migration: harga khusus buat online order (GoFood/GrabFood/ShopeeFood/dll),
-- opsional. Kalau kosong (null), online order pakai harga biasa.
alter table products
  add column if not exists online_price integer;
