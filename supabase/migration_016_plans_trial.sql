-- Sistem paket & trial. Plan baru selalu mulai dari trial 14 hari (full akses
-- Pro), abis itu turun ke starter kalau gak di-upgrade manual. Admin Tapply
-- (kamu) nge-upgrade customer manual dari Supabase Table Editor pas mereka
-- transfer/bayar di luar sistem (billing manual dulu, belum ada payment gateway).

alter table businesses
  add column if not exists plan text default 'trial', -- 'trial' | 'starter' | 'pro' | 'multi_outlet'
  add column if not exists plan_expires_at timestamptz default (now() + interval '14 days'),
  add column if not exists trial_started_at timestamptz default now();
