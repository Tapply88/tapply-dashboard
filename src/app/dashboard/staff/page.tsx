'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { hashPin } from '@/lib/hash';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

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
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
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
      if (link) {
        setBusinessId(link.business_id);
        const { data: business } = await supabase.from('businesses').select('plan, plan_expires_at').eq('id', link.business_id).single();
        if (business) setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
      }
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

  const isPro = isProActive(planInfo);
  const staffLimitReached = !isPro && staff.length >= 1;

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Team</p>
          <h1 className="text-2xl font-semibold">Staff</h1>
        </div>
        <button
          onClick={() => (staffLimitReached ? undefined : openAddForm())}
          disabled={staffLimitReached}
          title={staffLimitReached ? 'Starter plan is limited to 1 staff account' : undefined}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors disabled:opacity-40"
        >
          + Add Staff {staffLimitReached && '🔒'}
        </button>
      </div>

      {staffLimitReached && (
        <div className="mb-8">
          <UpgradeLock feature="Multiple staff accounts" />
        </div>
      )}

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
