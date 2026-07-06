-- Tanggal lahir member, buat promo ulang tahun otomatis.
alter table members
  add column if not exists birth_date date;

-- Promo bisa "nyala" cuma pas ulang tahun member atau tanggal tertentu tiap tahun
-- (mis. ulang tahun toko). trigger_month_day formatnya 'MM-DD', tahun diabaikan.
alter table promos
  add column if not exists trigger_type text default 'always', -- 'always' | 'birthday' | 'specific_date'
  add column if not exists trigger_month_day text;

-- Redeem poin: nilai tukar (Rp per 1 poin) + riwayat redeem-nya.
alter table businesses
  add column if not exists points_redemption_value integer default 1000;

create table if not exists point_redemptions (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  member_id uuid references members(id) on delete cascade not null,
  points_redeemed integer not null,
  value_rupiah integer not null,
  redeemed_at timestamptz default now()
);

alter table point_redemptions enable row level security;
create policy "tenant select" on point_redemptions for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on point_redemptions for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));

create index idx_point_redemptions_business on point_redemptions(business_id);
