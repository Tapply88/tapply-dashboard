-- Poin cuma bisa ditukar dalam kelipatan tertentu (default 300), biar gak ada
-- angka aneh kayak 37 poin. Default rate juga disesuaikan: 1 poin = Rp100
-- (jadi 300 poin = Rp30.000), bisa diubah lagi di Setelan kalau perlu.
alter table businesses
  add column if not exists points_redemption_multiple integer default 300;

alter table businesses
  alter column points_redemption_value set default 100;
