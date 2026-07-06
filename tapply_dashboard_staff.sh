cat > supabase/migration_006_staff.sql << 'MIGEOF'
-- Migration: tabel staff (kasir & supervisor) dengan role dan PIN masing-masing.
-- Dikelola dari dashboard, di-pull ke app buat dropdown pilih kasir pas mulai
-- shift, dan buat verifikasi role (mis. cuma supervisor yang bisa void receipt).

create table staff (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid references businesses(id) on delete cascade not null,
  name text not null,
  role text not null default 'cashier', -- 'cashier' | 'supervisor'
  pin text not null,
  active boolean default true,
  created_at timestamptz default now()
);

alter table staff enable row level security;

create policy "tenant select" on staff for select
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant insert" on staff for insert
  with check (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant update" on staff for update
  using (business_id in (select business_id from business_users where user_id = auth.uid()));
create policy "tenant delete" on staff for delete
  using (business_id in (select business_id from business_users where user_id = auth.uid()));

create index idx_staff_business on staff(business_id);
MIGEOF

cat > src/components/Sidebar.tsx << 'SIDEBAREOF'
'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV_ITEMS = [
  { href: '/dashboard', label: 'Ringkasan', icon: '◧' },
  { href: '/dashboard/products', label: 'Produk', icon: '☰' },
  { href: '/dashboard/variants', label: 'Variants & Add-ons', icon: '⊕' },
  { href: '/dashboard/staff', label: 'Staff', icon: '☺' },
  { href: '/dashboard/promos', label: 'Promo', icon: '◈' },
  { href: '/dashboard/members', label: 'Member', icon: '◎' },
  { href: '/dashboard/shifts', label: 'Shift', icon: '◷' },
  { href: '/dashboard/settings', label: 'Setelan', icon: '⚙' },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-60 shrink-0 bg-navy text-white flex flex-col min-h-screen">
      <div className="px-6 py-7">
        <p className="font-serif text-2xl" style={{ fontStyle: 'italic' }}>
          Tapply
        </p>
      </div>
      <nav className="flex-1 px-3">
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.comingSoon ? '#' : item.href}
              aria-disabled={item.comingSoon}
              className={`flex items-center justify-between gap-3 px-4 py-2.5 rounded-lg text-sm mb-1 transition-colors ${
                active ? 'bg-white/15 font-medium' : 'text-white/70 hover:bg-white/10'
              } ${item.comingSoon ? 'cursor-default' : ''}`}
            >
              <span className="flex items-center gap-3">
                <span aria-hidden>{item.icon}</span>
                {item.label}
              </span>
              {item.comingSoon && (
                <span className="text-[10px] uppercase tracking-wide text-white/40">Segera</span>
              )}
            </Link>
          );
        })}
      </nav>
      <div className="px-6 py-5 text-xs text-white/40">v0.1 — Tapply Dashboard</div>
    </aside>
  );
}
SIDEBAREOF

mkdir -p src/app/dashboard/staff
cat > src/app/dashboard/staff/page.tsx << 'STAFFEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

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
    setForm({ name: s.name, role: s.role, pin: s.pin, active: s.active });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim() || !form.pin.trim()) return;
    const payload = { name: form.name.trim(), role: form.role, pin: form.pin.trim(), active: form.active };

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
          completed receipt — <strong>Cashier</strong> PINs cannot.
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
              required
              value={form.pin}
              onChange={(e) => setForm({ ...form, pin: e.target.value })}
              placeholder="PIN"
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
                  <td className="px-5 py-3 figure text-xs">{s.pin}</td>
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

echo 'Selesai. Jalankan migration_006_staff.sql di Supabase SQL Editor, lalu npm run dev'
