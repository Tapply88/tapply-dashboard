cat > supabase/migration_012_hash_existing_pins.sql << 'MIGEOF'
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
MIGEOF

cat > src/lib/hash.ts << 'HASHEOF'
// PIN hashing — SHA-256 + pepper tetap, HARUS identik sama lib/services/db_service.dart
// (Flutter) biar hasil hash-nya bisa dibandingin lintas platform. Ini bukan penyimpanan
// password kelas berat (PIN 4-6 digit tetep gampang di-brute-force offline kalau
// database-nya bocor), tapi jauh lebih aman daripada nyimpen PIN mentahan/plain text.

const PIN_PEPPER = 'tapply-pin-pepper-v1';

export async function hashPin(pin: string): Promise<string> {
  const data = new TextEncoder().encode(pin + PIN_PEPPER);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
HASHEOF

cat > src/app/dashboard/staff/page.tsx << 'STAFFEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { hashPin } from '@/lib/hash';

type Staff = {
  id: string;
  name: string;
  role: 'cashier' | 'supervisor';
  pin: string;
  active: boolean;
};

const emptyForm = { name: '', role: 'cashier' as 'cashier' | 'supervisor', pin: '', active: true };

export default function StaffPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [staff, setStaff] = useState<Staff[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Staff | null>(null);
  const [form, setForm] = useState(emptyForm);

  const loadData = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) setBusinessId(link.business_id);
    }
    const { data } = await supabase.from('staff').select('*').order('name');
    setStaff(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  function openAddForm() {
    setEditing(null);
    setForm(emptyForm);
    setShowForm(true);
  }

  function openEditForm(s: Staff) {
    setEditing(s);
    // PIN field intentionally left blank — we only ever store a hash, so there's
    // nothing readable to prefill. Leaving it blank keeps the existing PIN unchanged.
    setForm({ name: s.name, role: s.role, pin: '', active: s.active });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;
    if (!editing && !form.pin.trim()) return; // new staff must set a PIN

    const payload: Record<string, unknown> = { name: form.name.trim(), role: form.role, active: form.active };
    if (form.pin.trim()) {
      payload.pin = await hashPin(form.pin.trim());
    }

    if (editing) {
      await supabase.from('staff').update(payload).eq('id', editing.id);
    } else {
      if (!businessId) return;
      await supabase.from('staff').insert({ ...payload, business_id: businessId });
    }
    setShowForm(false);
    loadData();
  }

  async function handleDelete(id: string) {
    if (!confirm('Remove this staff member?')) return;
    await supabase.from('staff').delete().eq('id', id);
    loadData();
  }

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Team</p>
          <h1 className="text-2xl font-semibold">Staff</h1>
        </div>
        <button
          onClick={openAddForm}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          + Add Staff
        </button>
      </div>

      <div className="receipt-card mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          This list syncs to the cashier app automatically. At shift start, cashiers pick their name
          from this list instead of typing it in. Only <strong>Supervisor</strong> PINs can void a
          completed receipt — <strong>Cashier</strong> PINs cannot. PINs are stored as a one-way hash,
          not as plain text — even we can&apos;t read them back, which is why editing a PIN always
          means setting a brand new one.
        </p>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Staff' : 'New Staff'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Full name"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="grid grid-cols-2 gap-3">
            <select
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value as 'cashier' | 'supervisor' })}
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            >
              <option value="cashier">Cashier</option>
              <option value="supervisor">Supervisor</option>
            </select>
            <input
              required={!editing}
              value={form.pin}
              onChange={(e) => setForm({ ...form, pin: e.target.value })}
              placeholder={editing ? 'New PIN (leave blank to keep current)' : 'PIN'}
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={form.active} onChange={(e) => setForm({ ...form, active: e.target.checked })} />
            Active (shows up in the cashier app)
          </label>
          <div className="flex gap-3">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Save
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium">
              Cancel
            </button>
          </div>
        </form>
      )}

      {staff.length === 0 ? (
        <div className="receipt-card text-center py-10">
          <p className="text-ink/60">No staff yet. Add your first cashier or supervisor.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Name</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Role</th>
                <th className="label-eyebrow px-5 py-3 font-medium">PIN</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Status</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {staff.map((s) => (
                <tr key={s.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{s.name}</td>
                  <td className="px-5 py-3">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${s.role === 'supervisor' ? 'bg-navy-50 text-navy' : 'bg-grey-light text-ink/60'}`}>
                      {s.role === 'supervisor' ? 'Supervisor' : 'Cashier'}
                    </span>
                  </td>
                  <td className="px-5 py-3 figure text-xs text-ink/40">••••</td>
                  <td className="px-5 py-3 text-xs text-ink/50">{s.active ? 'Active' : 'Inactive'}</td>
                  <td className="px-5 py-3 text-right">
                    <button onClick={() => openEditForm(s)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(s.id)} className="text-rust text-xs font-medium">
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
STAFFEOF

cat > src/app/dashboard/settings/page.tsx << 'SETEOF'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useI18n } from '@/lib/i18n';
import { hashPin } from '@/lib/hash';

export default function SettingsPage() {
  const supabase = createClient();
  const { t, lang, setLang } = useI18n();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [syncApiKey, setSyncApiKey] = useState<string>('');
  const [form, setForm] = useState({
    name: '',
    address: '',
    phone: '',
    footer_text: '',
    tax_percent: '0',
    service_percent: '0',
    discount_percent: '0',
    rounding_enabled: false,
    rounding_nearest: '100',
    manager_pin: '',
    pin_required_for_cancel: true,
    print_check_enabled: true,
    queue_number_enabled: false,
    queue_start_number: '1',
    logo_base64: '' as string | null,
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
          footer_text: business.footer_text ?? '',
          tax_percent: String(business.tax_percent ?? 0),
          service_percent: String(business.service_percent ?? 0),
          discount_percent: String(business.discount_percent ?? 0),
          rounding_enabled: business.rounding_enabled ?? false,
          rounding_nearest: String(business.rounding_nearest ?? 100),
          manager_pin: '',
          pin_required_for_cancel: business.pin_required_for_cancel ?? true,
          print_check_enabled: business.print_check_enabled ?? true,
          queue_number_enabled: business.queue_number_enabled ?? false,
          queue_start_number: String(business.queue_start_number ?? 1),
          logo_base64: business.logo_base64,
        });
      }
      setLoading(false);
    }
    load();
  }, [supabase]);

  async function handleRegenerateKey() {
    if (!businessId) return;
    if (!confirm('Generate a new API key? The old key will stop working — any Flutter app still using it will need to be updated.')) return;
    const newKey = crypto.randomUUID().replace(/-/g, '');
    await supabase.from('businesses').update({ sync_api_key: newKey }).eq('id', businessId);
    setSyncApiKey(newKey);
  }

  function handleLogoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      const base64 = result.split(',')[1];
      setForm((f) => ({ ...f, logo_base64: base64 }));
    };
    reader.readAsDataURL(file);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!businessId) return;
    const payload: Record<string, unknown> = {
      name: form.name,
      address: form.address,
      phone: form.phone,
      footer_text: form.footer_text,
      tax_percent: Number(form.tax_percent) || 0,
      service_percent: Number(form.service_percent) || 0,
      discount_percent: Number(form.discount_percent) || 0,
      rounding_enabled: form.rounding_enabled,
      rounding_nearest: Number(form.rounding_nearest) || 100,
      pin_required_for_cancel: form.pin_required_for_cancel,
      print_check_enabled: form.print_check_enabled,
      queue_number_enabled: form.queue_number_enabled,
      queue_start_number: Number(form.queue_start_number) || 1,
      logo_base64: form.logo_base64 || null,
    };
    if (form.manager_pin.trim()) {
      payload.manager_pin = await hashPin(form.manager_pin.trim());
    }
    await supabase.from('businesses').update(payload).eq('id', businessId);
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  }

  if (loading) return <p className="text-sm text-ink/50">{t('loading')}</p>;

  return (
    <div className="max-w-lg">
      <p className="label-eyebrow mb-2">{t('business_settings')}</p>
      <h1 className="text-2xl font-semibold mb-2">{t('settings')}</h1>
      <p className="text-sm text-ink/60 mb-8">
        {t('settings_intro')}
      </p>

      <form onSubmit={handleSave} className="receipt-card flex flex-col gap-4">
        <p className="label-eyebrow">{t('business_profile')}</p>

        <div className="flex items-center gap-4">
          <div className="w-20 h-20 rounded-lg bg-cream border border-grey flex items-center justify-center overflow-hidden shrink-0">
            {form.logo_base64 ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={`data:image/png;base64,${form.logo_base64}`} alt="Logo" className="w-full h-full object-contain" />
            ) : (
              <span className="text-xs text-ink/40 text-center px-1">No logo</span>
            )}
          </div>
          <div>
            <input type="file" accept="image/*" onChange={handleLogoChange} className="text-xs" />
            <p className="text-xs text-ink/50 mt-1">Shown at the top of every printed receipt.</p>
          </div>
        </div>

        <div>
          <label className="label-eyebrow block mb-1.5">{t('business_name')}</label>
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('address')}</label>
          <textarea
            value={form.address}
            onChange={(e) => setForm({ ...form, address: e.target.value })}
            rows={2}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none resize-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('phone_number')}</label>
          <input
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('receipt_footer')}</label>
          <input
            value={form.footer_text}
            onChange={(e) => setForm({ ...form, footer_text: e.target.value })}
            placeholder="Thank you!"
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('tax_service_discount')}</p>
        <div className="grid grid-cols-3 gap-3">
          <div>
            <label className="label-eyebrow block mb-1.5">Tax (%)</label>
            <input
              type="number"
              value={form.tax_percent}
              onChange={(e) => setForm({ ...form, tax_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Service (%)</label>
            <input
              type="number"
              value={form.service_percent}
              onChange={(e) => setForm({ ...form, service_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Discount (%)</label>
            <input
              type="number"
              value={form.discount_percent}
              onChange={(e) => setForm({ ...form, discount_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        </div>

        <label className="flex items-center gap-2 text-sm pt-2">
          <input
            type="checkbox"
            checked={form.rounding_enabled}
            onChange={(e) => setForm({ ...form, rounding_enabled: e.target.checked })}
          />
          Round total to nearest
        </label>
        {form.rounding_enabled && (
          <select
            value={form.rounding_nearest}
            onChange={(e) => setForm({ ...form, rounding_nearest: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          >
            <option value="100">Rp 100</option>
            <option value="500">Rp 500</option>
            <option value="1000">Rp 1,000</option>
          </select>
        )}

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('security')}</p>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('manager_pin')}</label>
          <input
            value={form.manager_pin}
            onChange={(e) => setForm({ ...form, manager_pin: e.target.value })}
            placeholder="Leave blank to keep the current PIN"
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <p className="text-xs text-ink/50 mt-1">
            PINs are stored as a one-way hash, not as plain text, so this field is always blank —
            type here only when you want to set a new PIN.
          </p>
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.pin_required_for_cancel}
            onChange={(e) => setForm({ ...form, pin_required_for_cancel: e.target.checked })}
          />
          {t('require_pin_cancel')}
        </label>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('receipt_queue')}</p>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.print_check_enabled}
            onChange={(e) => setForm({ ...form, print_check_enabled: e.target.checked })}
          />
          Show &quot;Print Check&quot; button in POS
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.queue_number_enabled}
            onChange={(e) => setForm({ ...form, queue_number_enabled: e.target.checked })}
          />
          Enable queue numbers on receipts
        </label>
        {form.queue_number_enabled && (
          <div>
            <label className="label-eyebrow block mb-1.5">Queue Start Number (daily)</label>
            <input
              type="number"
              value={form.queue_start_number}
              onChange={(e) => setForm({ ...form, queue_start_number: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        )}

        <button type="submit" className="rounded-full bg-navy text-white py-3 font-medium mt-2">
          {t('save_changes')}
        </button>
        {saved && <p className="text-sage text-sm text-center">{t('saved')}</p>}
      </form>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">{t('dashboard_language')}</p>
        <div className="flex gap-2 mt-3">
          <button
            type="button"
            onClick={() => setLang('en')}
            className={`flex-1 rounded-full px-4 py-2.5 text-sm font-medium border transition-colors ${
              lang === 'en' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
            }`}
          >
            English
          </button>
          <button
            type="button"
            onClick={() => setLang('id')}
            className={`flex-1 rounded-full px-4 py-2.5 text-sm font-medium border transition-colors ${
              lang === 'id' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
            }`}
          >
            Bahasa Indonesia
          </button>
        </div>
      </div>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">{t('sync')}</p>
        <h2 className="text-lg font-semibold mb-2">{t('connect_cashier_app')}</h2>
        <p className="text-sm text-ink/60 mb-4">
          Paste this code into the Tapply POS (Flutter) app used by your cashiers, once per device,
          so it can pull settings and push transactions automatically.
        </p>
        <div className="flex items-center gap-2 mb-3">
          <code className="flex-1 figure text-sm bg-cream border border-grey rounded-lg px-4 py-2.5 break-all">
            {syncApiKey || 'Loading...'}
          </code>
          <button
            type="button"
            onClick={() => {
              navigator.clipboard.writeText(syncApiKey);
              alert('Code copied!');
            }}
            className="rounded-lg border border-navy text-navy px-4 py-2.5 text-sm font-medium shrink-0"
          >
            Copy
          </button>
        </div>
        <button type="button" onClick={handleRegenerateKey} className="text-rust text-sm font-medium">
          Generate new code
        </button>
      </div>
    </div>
  );
}
SETEOF

cat > src/app/faq/page.tsx << 'FAQEOF'
'use client';

import { useState } from 'react';
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

const FAQS = [
  {
    q: 'Does Tapply work without internet?',
    a: 'Yes. The POS app stores everything locally on the device first, so checkout keeps working even if the connection drops. Once you\'re back online, transactions sync to your dashboard automatically.',
  },
  {
    q: 'What devices can I use it on?',
    a: 'Tapply POS runs on Android tablets and phones. The Dashboard is a website, so you can check it from any computer or phone browser.',
  },
  {
    q: 'Can I use it for more than one outlet?',
    a: 'Yes. Each register device connects to your account with a sync code from the dashboard, so you can run multiple registers — and eventually multiple outlets — under one account.',
  },
  {
    q: 'Who can change prices and settings?',
    a: 'Business settings, pricing, and product details are managed from the web dashboard by the business owner. Cashiers using the POS app can\'t change these, so pricing always stays consistent across every device.',
  },
  {
    q: 'Is my data safe?',
    a: 'Your data lives in a managed cloud database (not just on one device), protected by access rules that keep each business\'s data scoped to their own account when viewed through the dashboard. Cashier PINs are stored as one-way hashes, not as plain text. That said, Tapply is an early-stage product and hasn\'t been through a formal third-party security audit yet — treat it the way you would any young software product handling sensitive information.',
  },
  {
    q: 'How do I get started?',
    a: 'Create an account on the Dashboard, set up your business profile and products, then connect your first register device using the sync code from Settings.',
  },
];

export default function FaqPage() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <>
      <MarketingNav />
      <main className="max-w-2xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">FAQ</p>
        <h1 className="text-3xl font-semibold text-navy mb-10">Frequently Asked Questions</h1>

        <div className="flex flex-col gap-3">
          {FAQS.map((item, i) => (
            <div key={item.q} className="receipt-card !py-0 overflow-hidden">
              <button
                onClick={() => setOpenIndex(openIndex === i ? null : i)}
                className="w-full text-left py-5 flex items-center justify-between gap-4"
              >
                <span className="font-medium text-navy text-sm">{item.q}</span>
                <span className="text-navy text-lg shrink-0">{openIndex === i ? '−' : '+'}</span>
              </button>
              {openIndex === i && <p className="text-sm text-ink/60 pb-5 leading-relaxed">{item.a}</p>}
            </div>
          ))}
        </div>
      </main>
      <MarketingFooter />
    </>
  );
}
FAQEOF

cat > src/app/privacy/page.tsx << 'PRIVEOF'
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

export default function PrivacyPage() {
  return (
    <>
      <MarketingNav />
      <main className="max-w-2xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">Legal</p>
        <h1 className="text-3xl font-semibold text-navy mb-4">Privacy Policy</h1>
        <p className="text-xs text-ink/40 mb-10">Last updated: [date]</p>

        <div className="receipt-card mb-8 !bg-rust-light !border-rust/30">
          <p className="text-sm text-rust">
            This is a generic placeholder template, not legal advice. Have a qualified lawyer review
            and customize this before publishing it on a live product.
          </p>
        </div>

        <div className="flex flex-col gap-6 text-sm text-ink/70 leading-relaxed">
          <section>
            <h2 className="font-semibold text-navy mb-2">1. Information We Collect</h2>
            <p>
              We collect information you provide directly, such as your business name, contact details,
              and account information, as well as data generated through your use of Tapply, including
              product, transaction, and staff records you enter into the app or dashboard.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">2. How We Use Information</h2>
            <p>
              We use collected information to operate and improve Tapply, provide customer support,
              and communicate with you about your account and service updates.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">3. Data Storage &amp; Security</h2>
            <p>
              Your data is stored in a managed cloud database. Access controls scope each business&apos;s
              data to their own account when accessed through the dashboard, and cashier PINs are stored
              as one-way hashes rather than plain text. As with any software product, no system is
              completely immune to risk, and Tapply has not undergone a formal independent security audit.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">4. Data Sharing</h2>
            <p>
              We do not sell your data. We may share information with service providers who help us
              operate Tapply (such as our cloud hosting and database providers), under agreements that
              require them to protect your data.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">5. Your Choices</h2>
            <p>
              You can access, update, or delete your business data through the dashboard, or by
              contacting us directly.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">6. Contact</h2>
            <p>Questions about this policy? Reach out via our Contact Us page.</p>
          </section>
        </div>
      </main>
      <MarketingFooter />
    </>
  );
}
PRIVEOF

echo 'PENTING: jalanin migration_012 CUMA SEKALI. Lalu npm run dev'
