-- Migration: tabel staff (kasir & supervisor) dengan role dan PIN masing-masing.
-- Dikelola dari dashboard, di-pull ke app buat dropdown pilih kasir pas mulai
-- shift, dan buat verifikasi role (mis. cuma supervisor yang bisa void receipt).

create table staff (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  role text not null default 'cashier', -- 'cashier' | 'supervisor'
  pin text not null,
  active boolean default true,
  created_at timestamptz default now()
);

alter table staff enable row level security;

create policy "tenant select" on staff for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on staff for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on staff for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on staff for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create index idx_staff_business on staff(business_id);
