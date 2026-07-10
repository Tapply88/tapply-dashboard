-- Migration 019: perbaiki RLS dining_tables jadi tenant-scoped (bukan
-- kebuka buat semua user kayak sebelumnya). Backend Railway tetap bisa akses
-- penuh karena pakai Service Role Key yang bypass RLS.
drop policy if exists "Service role full access to dining_tables" on dining_tables;

create policy "tenant select" on dining_tables for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on dining_tables for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on dining_tables for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on dining_tables for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
