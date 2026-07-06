-- Rate dapet poin (belanja berapa Rupiah = 1 poin) sekarang bisa diatur,
-- bukan hardcode. Default 1000 = tiap Rp1.000 belanja dapet 1 poin
-- (jadi belanja Rp30.000 = 30 poin).
alter table businesses
  add column if not exists points_earn_rate integer default 1000;
