-- Migration 020: tabel feedback struk (thumbs up/down dari halaman struk publik).
-- Gak butuh RLS policy publik karena akses cuma lewat admin client di server
-- (Route Handler Next.js), jadi RLS tetap enabled tanpa policy = default-deny
-- buat akses langsung dari client (anon/authenticated).
create table if not exists receipt_feedback (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  transaction_id text not null,
  sentiment text not null check (sentiment in ('positive', 'negative')),
  created_at timestamptz not null default now()
);

create index if not exists receipt_feedback_business_id_idx on receipt_feedback(business_id);
create index if not exists receipt_feedback_transaction_id_idx on receipt_feedback(transaction_id);

alter table receipt_feedback enable row level security;

create policy "tenant select" on receipt_feedback for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
