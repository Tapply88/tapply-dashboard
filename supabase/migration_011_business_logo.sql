-- Migration: logo bisnis disimpen sebagai base64 (konsisten sama foto produk),
-- biar gampang dipull ke app Flutter dan ditampilin di struk.
alter table businesses
  add column if not exists logo_base64 text;
