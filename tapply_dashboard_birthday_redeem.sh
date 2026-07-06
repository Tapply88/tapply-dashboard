cat > supabase/migration_013_birthday_redeem.sql << 'MIGEOF'
-- Tanggal lahir member, buat promo ulang tahun otomatis.
alter table members
  add column if not exists birth_date date;

-- Promo bisa "nyala" cuma pas ulang tahun member atau tanggal tertentu tiap tahun
-- (mis. ulang tahun toko). trigger_month_day formatnya 'MM-DD', tahun diabaikan.
alter table promos
  add column if not exists trigger_type text default 'always', -- 'always' | 'birthday' | 'specific_date'
  add column if not exists trigger_month_day text;

-- Redeem poin: nilai tukar (Rp per 1 poin) + riwayat redeem-nya.
alter table businesses
  add column if not exists points_redemption_value integer default 1000;

create table if not exists point_redemptions (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  member_id uuid references members(id) on delete cascade not null,
  points_redeemed integer not null,
  value_rupiah integer not null,
  redeemed_at timestamptz default now()
);

alter table point_redemptions enable row level security;
create policy "tenant select" on point_redemptions for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on point_redemptions for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));

create index idx_point_redemptions_business on point_redemptions(business_id);
MIGEOF

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
  const [redemptionValue, setRedemptionValue] = useState(1000);
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
        const { data: business } = await supabase.from('businesses').select('points_redemption_value').eq('id', link.business_id).single();
        if (business?.points_redemption_value) setRedemptionValue(business.points_redemption_value);
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
          <strong>{formatRupiah(redemptionValue)} per point</strong> — change it in Settings.
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
    points_redemption_value: '1000',
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
          points_redemption_value: String(business.points_redemption_value ?? 1000),
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
      points_redemption_value: Number(form.points_redemption_value) || 1000,
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
        <div>
          <label className="label-eyebrow block mb-1.5">Redemption Value (Rp per point)</label>
          <input
            type="number"
            value={form.points_redemption_value}
            onChange={(e) => setForm({ ...form, points_redemption_value: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <p className="text-xs text-ink/50 mt-1">
            How much one point is worth when a member redeems it, e.g. 1000 = 100 points redeem for Rp 100,000.
          </p>
        </div>

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

cat > src/app/dashboard/promos/page.tsx << 'PROMOEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Product = { id: string; name: string };

type Promo = {
  id: string;
  name: string;
  discount_type: 'percentage' | 'fixed';
  value: number;
  scope: 'cart' | 'product' | 'item';
  product_ids: string[];
  start_date: string | null;
  end_date: string | null;
  min_purchase: number;
  active: boolean;
  trigger_type: 'always' | 'birthday' | 'specific_date';
  trigger_month_day: string | null;
};

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

const emptyForm = {
  name: '',
  discount_type: 'percentage' as 'percentage' | 'fixed',
  value: '',
  scope: 'cart' as 'cart' | 'product' | 'item',
  product_ids: [] as string[],
  start_date: '',
  end_date: '',
  min_purchase: '0',
  active: true,
  trigger_type: 'always' as 'always' | 'birthday' | 'specific_date',
  trigger_month_day: '',
};

export default function PromosPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [promos, setPromos] = useState<Promo[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Promo | null>(null);
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
    const [{ data: promoData }, { data: productData }] = await Promise.all([
      supabase.from('promos').select('*').order('created_at', { ascending: false }),
      supabase.from('products').select('id, name').order('name'),
    ]);
    setPromos(promoData ?? []);
    setProducts(productData ?? []);
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

  function openEditForm(p: Promo) {
    setEditing(p);
    setForm({
      name: p.name,
      discount_type: p.discount_type,
      value: String(p.value),
      scope: p.scope,
      product_ids: p.product_ids ?? [],
      start_date: p.start_date ?? '',
      end_date: p.end_date ?? '',
      min_purchase: String(p.min_purchase),
      active: p.active,
      trigger_type: p.trigger_type ?? 'always',
      trigger_month_day: p.trigger_month_day ?? '',
    });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;
    if (form.scope === 'product' && form.product_ids.length === 0) {
      alert('Select at least 1 product for "Specific Products" scope.');
      return;
    }
    if (form.trigger_type === 'specific_date' && !form.trigger_month_day) {
      alert('Pick a date for the "specific date every year" trigger.');
      return;
    }

    const payload = {
      name: form.name.trim(),
      discount_type: form.discount_type,
      value: Number(form.value) || 0,
      scope: form.scope,
      product_ids: form.scope === 'cart' ? [] : form.product_ids,
      start_date: form.start_date || null,
      end_date: form.end_date || null,
      min_purchase: Number(form.min_purchase) || 0,
      active: form.active,
      trigger_type: form.trigger_type,
      trigger_month_day: form.trigger_type === 'specific_date' ? form.trigger_month_day : null,
    };

    if (editing) {
      await supabase.from('promos').update(payload).eq('id', editing.id);
    } else {
      if (!businessId) return;
      await supabase.from('promos').insert({ ...payload, business_id: businessId });
    }
    setShowForm(false);
    loadData();
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this promo?')) return;
    await supabase.from('promos').delete().eq('id', id);
    loadData();
  }

  function toggleProduct(id: string) {
    setForm((f) => ({
      ...f,
      product_ids: f.product_ids.includes(id) ? f.product_ids.filter((p) => p !== id) : [...f.product_ids, id],
    }));
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Marketing</p>
          <h1 className="text-2xl font-semibold">Promo</h1>
        </div>
        <button
          onClick={openAddForm}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          + New Promo
        </button>
      </div>

      <div className="receipt-card max-w-lg mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          Promos sync automatically with the cashier app in both directions. For a &quot;free
          product&quot; promo, set scope to a specific product with a 100% discount.
        </p>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Promo' : 'New Promo'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Promo name, e.g. Ramadan Special"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <div>
            <p className="label-eyebrow mb-2">Discount Type</p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setForm({ ...form, discount_type: 'percentage' })}
                className={`flex-1 rounded-lg border py-2 text-sm font-medium ${
                  form.discount_type === 'percentage' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
                }`}
              >
                Percentage (%)
              </button>
              <button
                type="button"
                onClick={() => setForm({ ...form, discount_type: 'fixed' })}
                className={`flex-1 rounded-lg border py-2 text-sm font-medium ${
                  form.discount_type === 'fixed' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
                }`}
              >
                Fixed (Rp)
              </button>
            </div>
          </div>

          <input
            required
            type="number"
            value={form.value}
            onChange={(e) => setForm({ ...form, value: e.target.value })}
            placeholder={form.discount_type === 'percentage' ? 'Discount amount (%) — use 100 for free' : 'Discount amount (Rp)'}
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <input
            type="number"
            value={form.min_purchase}
            onChange={(e) => setForm({ ...form, min_purchase: e.target.value })}
            placeholder="Minimum purchase (Rp, 0 = no minimum)"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label-eyebrow block mb-1.5">Start Date</label>
              <input
                type="date"
                value={form.start_date}
                onChange={(e) => setForm({ ...form, start_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
            <div>
              <label className="label-eyebrow block mb-1.5">End Date</label>
              <input
                type="date"
                value={form.end_date}
                onChange={(e) => setForm({ ...form, end_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
          </div>
          <p className="text-xs text-ink/50 -mt-2">Leave dates blank to run indefinitely.</p>

          <div>
            <p className="label-eyebrow mb-2">When Does This Apply</p>
            <div className="flex flex-col gap-2">
              <label className="flex items-center gap-2 text-sm">
                <input type="radio" checked={form.trigger_type === 'always'} onChange={() => setForm({ ...form, trigger_type: 'always' })} />
                Always (within the date range above)
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input type="radio" checked={form.trigger_type === 'birthday'} onChange={() => setForm({ ...form, trigger_type: 'birthday' })} />
                Only on the member&apos;s birthday
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input type="radio" checked={form.trigger_type === 'specific_date'} onChange={() => setForm({ ...form, trigger_type: 'specific_date' })} />
                Only on a specific date every year
              </label>
              {form.trigger_type === 'specific_date' && (
                <input
                  type="date"
                  value={form.trigger_month_day ? `2024-${form.trigger_month_day}` : ''}
                  onChange={(e) => {
                    const [, month, day] = e.target.value.split('-');
                    setForm({ ...form, trigger_month_day: `${month}-${day}` });
                  }}
                  className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none ml-6"
                  style={{ width: 'calc(100% - 1.5rem)' }}
                />
              )}
            </div>
          </div>

          <div>
            <p className="label-eyebrow mb-2">Applies To</p>
            <div className="flex flex-col gap-2">
              {(['cart', 'product', 'item'] as const).map((scope) => (
                <label key={scope} className="flex items-center gap-2 text-sm">
                  <input
                    type="radio"
                    checked={form.scope === scope}
                    onChange={() => setForm({ ...form, scope })}
                  />
                  {scope === 'cart' && 'Entire Receipt'}
                  {scope === 'product' && 'Specific Products (preset, applies automatically)'}
                  {scope === 'item' && 'Per Item (optional, checked manually at checkout)'}
                </label>
              ))}
            </div>
          </div>

          {(form.scope === 'product' || form.scope === 'item') && (
            <div>
              <p className="text-xs text-ink/50 mb-2">
                {form.scope === 'item' ? 'Limit to specific products (optional):' : 'Select products:'}
              </p>
              <div className="max-h-40 overflow-y-auto border border-grey rounded-lg p-2 flex flex-col gap-1">
                {products.length === 0 && <p className="text-xs text-ink/40 px-2 py-1">No products yet.</p>}
                {products.map((p) => (
                  <label key={p.id} className="flex items-center gap-2 text-sm px-2 py-1 rounded hover:bg-cream">
                    <input type="checkbox" checked={form.product_ids.includes(p.id)} onChange={() => toggleProduct(p.id)} />
                    {p.name}
                  </label>
                ))}
              </div>
            </div>
          )}

          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={form.active} onChange={(e) => setForm({ ...form, active: e.target.checked })} />
            Active
          </label>

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

      {loading ? (
        <p className="text-sm text-ink/50">Loading...</p>
      ) : promos.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">No promos yet. Tap + to create one.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3 max-w-2xl">
          {promos.map((p) => (
            <div key={p.id} className="receipt-card flex items-center justify-between">
              <div>
                <p className={`font-medium ${p.active ? 'text-navy' : 'text-ink/40'}`}>{p.name}</p>
                <p className="text-xs text-ink/50 mt-1">
                  {p.discount_type === 'percentage' ? `${p.value}%` : formatRupiah(p.value)}
                  {p.min_purchase > 0 && ` • min. ${formatRupiah(p.min_purchase)}`}
                  {p.scope === 'product' && ` • ${p.product_ids?.length ?? 0} products (preset)`}
                  {p.scope === 'item' && ' • per item'}
                  {p.scope === 'cart' && ' • entire receipt'}
                  {p.trigger_type === 'birthday' && ' • 🎂 birthday only'}
                  {p.trigger_type === 'specific_date' && ` • 📅 ${p.trigger_month_day} only`}
                  {!p.active && ' • Inactive'}
                </p>
              </div>
              <div className="flex gap-3 shrink-0">
                <button onClick={() => openEditForm(p)} className="text-navy text-xs font-medium">
                  Edit
                </button>
                <button onClick={() => handleDelete(p.id)} className="text-rust text-xs font-medium">
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
PROMOEOF

echo 'Selesai. Jalankan migration_013 di Supabase SQL Editor, lalu npm run dev'
