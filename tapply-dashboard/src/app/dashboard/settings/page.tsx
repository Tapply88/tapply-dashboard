'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export default function SettingsPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
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
    </div>
  );
}
