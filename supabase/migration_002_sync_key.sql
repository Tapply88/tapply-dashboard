-- Migration: tambah kolom sync_api_key ke businesses (buat pairing app Flutter ke cloud)
-- Jalankan ini di SQL Editor Supabase kalau schema.sql versi awal udah pernah dijalanin.

alter table businesses
  add column if not exists sync_api_key text unique default replace(uuid_generate_v4()::text, '-', '');

-- Isi sync_api_key buat bisnis yang udah ada duluan (sebelum kolom ini ditambahin)
update businesses set sync_api_key = replace(uuid_generate_v4()::text, '-', '') where sync_api_key is null;
