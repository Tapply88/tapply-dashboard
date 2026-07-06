-- Migration SEKALI JALAN DOANG: nge-hash PIN yang sebelumnya kesimpen sebagai
-- teks polos, biar konsisten sama sistem hashing yang baru (SHA-256 + pepper,
-- sama persis kayak src/lib/hash.ts dan lib/services/db_service.dart).
--
-- PENTING: jangan jalanin migrasi ini dua kali — kalau udah pernah jalan,
-- PIN yang udah di-hash bakal ke-hash lagi (jadi ganda) dan gak bakal
-- cocok lagi sama yang diketik user. Kalau gak yakin udah pernah jalan
-- apa belum, cek dulu: kalau isi kolom `pin`/`manager_pin` panjangnya 64
-- karakter (hex SHA-256), berarti udah di-hash, JANGAN dijalanin lagi.

create extension if not exists pgcrypto;

update businesses
set manager_pin = encode(digest(manager_pin || 'tapply-pin-pepper-v1', 'sha256'), 'hex')
where manager_pin is not null and length(manager_pin) < 64;

update staff
set pin = encode(digest(pin || 'tapply-pin-pepper-v1', 'sha256'), 'hex')
where pin is not null and length(pin) < 64;
