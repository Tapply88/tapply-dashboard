cat > supabase/migration_014_redemption_multiple.sql << 'MIGEOF'
-- Poin cuma bisa ditukar dalam kelipatan tertentu (default 300), biar gak ada
-- angka aneh kayak 37 poin. Default rate juga disesuaikan: 1 poin = Rp100
-- (jadi 300 poin = Rp30.000), bisa diubah lagi di Setelan kalau perlu.
alter table businesses
  add column if not exists points_redemption_multiple integer default 300;

alter table businesses
  alter column points_redemption_value set default 100;
MIGEOF

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
    points_redemption_value: '100',
    points_redemption_multiple: '300',
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
          points_redemption_value: String(business.points_redemption_value ?? 100),
          points_redemption_multiple: String(business.points_redemption_multiple ?? 300),
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
      points_redemption_value: Number(form.points_redemption_value) || 100,
      points_redemption_multiple: Number(form.points_redemption_multiple) || 300,
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

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">Loyalty Points</p>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label-eyebrow block mb-1.5">Redemption Value (Rp per point)</label>
            <input
              type="number"
              value={form.points_redemption_value}
              onChange={(e) => setForm({ ...form, points_redemption_value: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Redeem in Multiples of</label>
            <input
              type="number"
              value={form.points_redemption_multiple}
              onChange={(e) => setForm({ ...form, points_redemption_multiple: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        </div>
        <p className="text-xs text-ink/50 -mt-2">
          e.g. value 100 + multiple 300 means members redeem 300 points at a time for Rp 30,000 (10 points = Rp 1,000).
        </p>

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

cat > src/app/dashboard/members/page.tsx << 'MEMEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Member = {
  id: string;
  name: string;
  phone: string;
  points: number;
  birth_date: string | null;
};

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

export default function MembersPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [redemptionValue, setRedemptionValue] = useState(100);
  const [redemptionMultiple, setRedemptionMultiple] = useState(300);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Member | null>(null);
  const [form, setForm] = useState({ name: '', phone: '', points: '0', birth_date: '' });
  const [redeemTarget, setRedeemTarget] = useState<Member | null>(null);
  const [redeemPoints, setRedeemPoints] = useState('');

  const loadMembers = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) {
        setBusinessId(link.business_id);
        const { data: business } = await supabase.from('businesses').select('points_redemption_value, points_redemption_multiple').eq('id', link.business_id).single();
        if (business?.points_redemption_value) setRedemptionValue(business.points_redemption_value);
        if (business?.points_redemption_multiple) setRedemptionMultiple(business.points_redemption_multiple);
      }
    }
    const { data } = await supabase.from('members').select('*').order('name');
    setMembers(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

  function openAddForm() {
    setEditing(null);
    setForm({ name: '', phone: '', points: '0', birth_date: '' });
    setShowForm(true);
  }

  function openEditForm(m: Member) {
    setEditing(m);
    setForm({ name: m.name, phone: m.phone, points: String(m.points), birth_date: m.birth_date ?? '' });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const payload = {
      name: form.name.trim(),
      phone: form.phone.trim(),
      points: Number(form.points) || 0,
      birth_date: form.birth_date || null,
    };
    if (!payload.name || !payload.phone) return;

    if (editing) {
      await supabase.from('members').update(payload).eq('id', editing.id);
    } else {
      if (!businessId) return;
      await supabase.from('members').insert({ ...payload, business_id: businessId });
    }
    setShowForm(false);
    loadMembers();
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this member?')) return;
    await supabase.from('members').delete().eq('id', id);
    loadMembers();
  }

  function openRedeemModal(m: Member) {
    setRedeemTarget(m);
    setRedeemPoints('');
  }

  async function confirmRedeem() {
    if (!redeemTarget || !businessId) return;
    const points = Number(redeemPoints) || 0;
    if (points <= 0 || points > redeemTarget.points) {
      alert('Enter a valid number of points (up to what the member has).');
      return;
    }
    if (redemptionMultiple > 0 && points % redemptionMultiple !== 0) {
      alert(`Points must be redeemed in multiples of ${redemptionMultiple}.`);
      return;
    }
    const valueRupiah = points * redemptionValue;
    await supabase.from('members').update({ points: redeemTarget.points - points }).eq('id', redeemTarget.id);
    await supabase.from('point_redemptions').insert({
      business_id: businessId,
      member_id: redeemTarget.id,
      points_redeemed: points,
      value_rupiah: valueRupiah,
    });
    setRedeemTarget(null);
    loadMembers();
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Customers</p>
          <h1 className="text-2xl font-semibold">Members</h1>
        </div>
        <button
          onClick={openAddForm}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          + Add Member
        </button>
      </div>

      <div className="receipt-card max-w-lg mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          Members sync automatically with the cashier app. Redemption rate is currently{' '}
          <strong>{formatRupiah(redemptionValue)} per point</strong>, redeemed in multiples of{' '}
          <strong>{redemptionMultiple}</strong> — change it in Settings.
        </p>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Member' : 'New Member'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Member name"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <input
            required
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            placeholder="Phone number"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="grid grid-cols-2 gap-3">
            <input
              type="number"
              value={form.points}
              onChange={(e) => setForm({ ...form, points: e.target.value })}
              placeholder="Points"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
            <div>
              <input
                type="date"
                value={form.birth_date}
                onChange={(e) => setForm({ ...form, birth_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
              <p className="text-xs text-ink/40 mt-1">Birthday (optional)</p>
            </div>
          </div>
          <div className="flex gap-3">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Save
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {redeemTarget && (
        <div className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">Redeem Points — {redeemTarget.name}</p>
          <p className="text-sm text-ink/60">
            Balance: <strong>{redeemTarget.points} points</strong> ({formatRupiah(redeemTarget.points * redemptionValue)})
          </p>
          <input
            type="number"
            value={redeemPoints}
            onChange={(e) => setRedeemPoints(e.target.value)}
            placeholder="Points to redeem"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          {redeemPoints && Number(redeemPoints) > 0 && (
            <p className="text-sm text-sage">
              = {formatRupiah(Number(redeemPoints) * redemptionValue)} discount value
            </p>
          )}
          <div className="flex gap-3">
            <button onClick={confirmRedeem} className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Confirm Redemption
            </button>
            <button onClick={() => setRedeemTarget(null)} className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium">
              Cancel
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Loading...</p>
      ) : members.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">No members yet.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Name</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Phone</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Birthday</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Points</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {members.map((m) => (
                <tr key={m.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{m.name}</td>
                  <td className="px-5 py-3 text-ink/60">{m.phone}</td>
                  <td className="px-5 py-3 text-ink/60 text-xs">
                    {m.birth_date ? new Date(m.birth_date).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }) : '—'}
                  </td>
                  <td className="px-5 py-3 figure">{m.points}</td>
                  <td className="px-5 py-3 text-right whitespace-nowrap">
                    <button onClick={() => openRedeemModal(m)} disabled={m.points <= 0} className="text-sage text-xs font-medium mr-3 disabled:opacity-30">
                      Redeem
                    </button>
                    <button onClick={() => openEditForm(m)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(m.id)} className="text-rust text-xs font-medium">
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
MEMEOF

echo 'Selesai. Jalankan migration_014 di Supabase SQL Editor, lalu npm run dev'
