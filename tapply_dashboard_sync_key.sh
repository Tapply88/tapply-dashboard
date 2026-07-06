cat > supabase/migration_002_sync_key.sql << 'MIGEOF'
-- Migration: tambah kolom sync_api_key ke businesses (buat pairing app Flutter ke cloud)
-- Jalankan ini di SQL Editor Supabase kalau schema.sql versi awal udah pernah dijalanin.

alter table businesses
  add column if not exists sync_api_key text unique default replace(uuid_generate_v4()::text, '-', '');

-- Isi sync_api_key buat bisnis yang udah ada duluan (sebelum kolom ini ditambahin)
update businesses set sync_api_key = replace(uuid_generate_v4()::text, '-', '') where sync_api_key is null;
MIGEOF

cat > src/app/dashboard/settings/page.tsx << 'SETEOF'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export default function SettingsPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [syncApiKey, setSyncApiKey] = useState<string>('');
  const [form, setForm] = useState({
    name: '',
    address: '',
    phone: '',
    tax_percent: '0',
    service_percent: '0',
  });
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;

      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;

      const { data: business } = await supabase.from('businesses').select('*').eq('id', link.business_id).single();
      if (business) {
        setBusinessId(business.id);
        setSyncApiKey(business.sync_api_key ?? '');
        setForm({
          name: business.name ?? '',
          address: business.address ?? '',
          phone: business.phone ?? '',
          tax_percent: String(business.tax_percent ?? 0),
          service_percent: String(business.service_percent ?? 0),
        });
      }
      setLoading(false);
    }
    load();
  }, [supabase]);

  async function handleRegenerateKey() {
    if (!businessId) return;
    if (!confirm('Bikin API key baru? Key lama bakal berhenti kepake — app Flutter yang masih pakai key lama perlu di-update.')) return;
    const newKey = crypto.randomUUID().replace(/-/g, '');
    await supabase.from('businesses').update({ sync_api_key: newKey }).eq('id', businessId);
    setSyncApiKey(newKey);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!businessId) return;
    await supabase
      .from('businesses')
      .update({
        name: form.name,
        address: form.address,
        phone: form.phone,
        tax_percent: Number(form.tax_percent) || 0,
        service_percent: Number(form.service_percent) || 0,
      })
      .eq('id', businessId);
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  }

  if (loading) return <p className="text-sm text-ink/50">Memuat...</p>;

  return (
    <div className="max-w-lg">
      <p className="label-eyebrow mb-2">Profil Bisnis</p>
      <h1 className="text-2xl font-semibold mb-8">Setelan</h1>

      <form onSubmit={handleSave} className="receipt-card flex flex-col gap-4">
        <div>
          <label className="label-eyebrow block mb-1.5">Nama Bisnis</label>
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">Alamat</label>
          <textarea
            value={form.address}
            onChange={(e) => setForm({ ...form, address: e.target.value })}
            rows={2}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none resize-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">No. Telepon</label>
          <input
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>

        <div className="grid grid-cols-2 gap-3 pt-2 border-t border-grey-light">
          <div>
            <label className="label-eyebrow block mb-1.5 mt-4">Tax (%)</label>
            <input
              type="number"
              value={form.tax_percent}
              onChange={(e) => setForm({ ...form, tax_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5 mt-4">Service (%)</label>
            <input
              type="number"
              value={form.service_percent}
              onChange={(e) => setForm({ ...form, service_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        </div>

        <button type="submit" className="rounded-full bg-navy text-white py-3 font-medium mt-2">
          Simpan Perubahan
        </button>
        {saved && <p className="text-sage text-sm text-center">Tersimpan.</p>}
      </form>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">Sinkronisasi</p>
        <h2 className="text-lg font-semibold mb-2">Hubungkan App Kasir</h2>
        <p className="text-sm text-ink/60 mb-4">
          Tempel kode ini ke Setelan → Sinkronisasi di app Tapply POS (Flutter) yang dipakai kasir kamu,
          biar transaksi otomatis ke-kirim ke dashboard ini.
        </p>
        <div className="flex items-center gap-2 mb-3">
          <code className="flex-1 figure text-sm bg-cream border border-grey rounded-lg px-4 py-2.5 break-all">
            {syncApiKey || 'Memuat...'}
          </code>
          <button
            type="button"
            onClick={() => {
              navigator.clipboard.writeText(syncApiKey);
              alert('Kode disalin!');
            }}
            className="rounded-lg border border-navy text-navy px-4 py-2.5 text-sm font-medium shrink-0"
          >
            Copy
          </button>
        </div>
        <button
          type="button"
          onClick={handleRegenerateKey}
          className="text-rust text-sm font-medium"
        >
          Bikin kode baru
        </button>
      </div>
    </div>
  );
}
SETEOF

echo 'Selesai. Jalankan migration_002_sync_key.sql di Supabase SQL Editor, lalu npm run dev'
