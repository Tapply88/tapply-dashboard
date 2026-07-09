-- Persentase komisi platform online order (opsional, default 20%), dipakai
-- buat hitung pendapatan bersih di Laporan Online. Owner bisa sesuaikan
-- sendiri sesuai kontrak masing-masing platform.
alter table businesses
  add column if not exists gofood_commission_percent numeric not null default 20,
  add column if not exists grabfood_commission_percent numeric not null default 20,
  add column if not exists shopeefood_commission_percent numeric not null default 20;
