-- Migration: bahan baku (ingredients) & resep (recipe_items). Produk yang
-- punya resep otomatis kurangin stok bahan pas terjual, bukan pakai field
-- stock produk manual lagi. Produk tanpa resep tetap pakai stock manual
-- seperti biasa.
create table ingredients (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  unit text not null default 'gram', -- 'gram' | 'ml' | 'pcs'
  stock numeric not null default 0,
  low_stock_threshold numeric not null default 0,
  created_at timestamptz default now()
);
alter table ingredients enable row level security;
create policy "tenant select" on ingredients for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on ingredients for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on ingredients for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on ingredients for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create index idx_ingredients_business on ingredients(business_id);

create table recipe_items (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  product_id uuid references products(id) on delete cascade not null,
  ingredient_id uuid references ingredients(id) on delete cascade not null,
  quantity numeric not null default 0,
  created_at timestamptz default now()
);
alter table recipe_items enable row level security;
create policy "tenant select" on recipe_items for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on recipe_items for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on recipe_items for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on recipe_items for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create index idx_recipe_items_business on recipe_items(business_id);
create index idx_recipe_items_product on recipe_items(product_id);
