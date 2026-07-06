-- Migration: preferensi bahasa dashboard (per bisnis, bukan per user, biar
-- konsisten dilihat siapapun yang login ke akun bisnis yang sama).
alter table businesses
  add column if not exists dashboard_language text default 'en';
