-- Migration: varian & add-on juga bisa punya harga khusus buat Online Order,
-- sama konsepnya kayak produk. Kosong = pakai harga biasa.
alter table variations
  add column if not exists online_price integer;
alter table addons
  add column if not exists online_price integer;
