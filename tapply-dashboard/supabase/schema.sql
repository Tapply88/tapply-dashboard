-- Tapply Dashboard — Supabase schema
-- Jalankan ini di Supabase Dashboard → SQL Editor → New Query → Run.
-- Multi-tenant: setiap baris data terikat ke satu business_id, dan RLS
-- policy memastikan user cuma bisa lihat/ubah data bisnis mereka sendiri.

create extension if not exists "uuid-ossp";

-- ---------- Businesses ----------
create table businesses (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  address text,
  phone text,
  logo_url text,
  footer_text text default 'Terima kasih!',
  tax_percent numeric default 0,
  service_percent numeric default 0,
  discount_percent numeric default 0,
  rounding_enabled boolean default false,
  rounding_nearest integer default 100,
  created_at timestamptz default now()
);

-- Links a Supabase auth user to a business (owner or staff)
create table business_users (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  role text default 'owner',
  created_at timestamptz default now(),
  unique (business_id, user_id)
);

-- ---------- Products ----------
create table products (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  price integer not null default 0,
  category text default 'Umum',
  stock integer default 0,
  image_url text,
  sort_order integer default 0,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- ---------- Variations & Add-ons ----------
create table variations (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  sort_order integer default 0
);

create table addons (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  price integer default 0,
  sort_order integer default 0
);

-- ---------- Members ----------
create table members (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  phone text not null,
  points integer default 0,
  created_at timestamptz default now()
);

-- ---------- Promos ----------
create table promos (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  discount_type text not null default 'percentage', -- 'percentage' | 'fixed'
  value numeric not null default 0,
  scope text not null default 'cart', -- 'cart' | 'product' | 'item'
  product_ids uuid[] default '{}',
  start_date date,
  end_date date,
  min_purchase integer default 0,
  active boolean default true,
  created_at timestamptz default now()
);

-- ---------- Transactions ----------
create table transactions (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  items jsonb not null default '[]',
  total integer not null default 0,
  tax_amount integer default 0,
  service_amount integer default 0,
  discount_amount integer default 0,
  discount_label text,
  rounding_adjustment integer default 0,
  payment_method text not null,
  sales_type text default 'Dine In',
  member_id uuid references members(id),
  guest_name text,
  cashier_name text,
  cashier_email text,
  receipt_number text,
  queue_code text,
  status text default 'paid',
  created_at timestamptz default now()
);

-- ---------- Shifts ----------
create table shifts (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  cashier_name text,
  cashier_email text,
  start_time timestamptz not null default now(),
  starting_cash integer not null default 0,
  end_time timestamptz,
  ending_cash_counted integer,
  status text default 'open', -- 'open' | 'closed'
  note text,
  created_at timestamptz default now()
);

-- ==========================================================
-- Row Level Security — tiap tabel cuma bisa diakses oleh user
-- yang terhubung ke business_id yang sama lewat business_users.
-- ==========================================================

alter table businesses enable row level security;
alter table business_users enable row level security;
alter table products enable row level security;
alter table variations enable row level security;
alter table addons enable row level security;
alter table members enable row level security;
alter table promos enable row level security;
alter table transactions enable row level security;
alter table shifts enable row level security;

-- businesses: user bisa lihat/ubah bisnis yang dia punya link-nya.
-- Insert dibuka buat siapa aja yang login (dipakai pas onboarding),
-- baris berikutnya di-link lewat business_users.
create policy "select own business" on businesses for select
  using (id in (select business_id from business_users where user_id = auth.uid()));
create policy "insert business (onboarding)" on businesses for insert
  with check (auth.uid() is not null);
create policy "update own business" on businesses for update
  using (id in (select business_id from business_users where user_id = auth.uid()));

-- business_users
create policy "select own links" on business_users for select
  using (user_id = auth.uid());
create policy "insert own link (onboarding)" on business_users for insert
  with check (user_id = auth.uid());

-- Generic helper pattern repeated for each tenant table below:
-- select/insert/update/delete all scoped to business_id membership.

create policy "tenant select" on products for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on products for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on products for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on products for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create policy "tenant select" on variations for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on variations for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on variations for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on variations for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create policy "tenant select" on addons for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on addons for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on addons for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on addons for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create policy "tenant select" on members for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on members for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on members for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on members for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create policy "tenant select" on promos for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on promos for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on promos for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on promos for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create policy "tenant select" on transactions for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on transactions for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on transactions for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create policy "tenant select" on shifts for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on shifts for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on shifts for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

-- ---------- Helpful indexes ----------
create index idx_products_business on products(business_id);
create index idx_transactions_business_date on transactions(business_id, created_at);
create index idx_shifts_business_status on shifts(business_id, status);
create index idx_members_business_phone on members(business_id, phone);
