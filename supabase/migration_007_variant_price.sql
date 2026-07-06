-- Migration: varian (mis. "Large") sekarang boleh punya harga tambahan opsional,
-- sama kayak add-ons. Default 0 = gratis, gak ngubah perilaku lama.
alter table variations
  add column if not exists price integer default 0;
