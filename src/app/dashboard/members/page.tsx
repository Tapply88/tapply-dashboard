'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

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
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
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
        const { data: business } = await supabase.from('businesses').select('points_redemption_value, points_redemption_multiple, plan, plan_expires_at').eq('id', link.business_id).single();
        if (business?.points_redemption_value) setRedemptionValue(business.points_redemption_value);
        if (business?.points_redemption_multiple) setRedemptionMultiple(business.points_redemption_multiple);
        if (business) setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
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

  if (!loading && planInfo && !isProActive(planInfo)) {
    return (
      <div>
        <p className="label-eyebrow mb-2">Customers</p>
        <h1 className="text-2xl font-semibold mb-8">Members</h1>
        <UpgradeLock feature="Member accounts & loyalty points" />
      </div>
    );
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
