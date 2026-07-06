mkdir -p src/app/dashboard/members src/app/dashboard/promos src/app/dashboard/shifts

cat > src/components/Sidebar.tsx << 'SIDEBAREOF'
'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV_ITEMS = [
  { href: '/dashboard', label: 'Ringkasan', icon: '◧' },
  { href: '/dashboard/products', label: 'Produk', icon: '☰' },
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

cat > src/app/dashboard/members/page.tsx << 'MEMBEREOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Member = {
  id: string;
  name: string;
  phone: string;
  points: number;
};

export default function MembersPage() {
  const supabase = createClient();
  const [members, setMembers] = useState<Member[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Member | null>(null);
  const [form, setForm] = useState({ name: '', phone: '', points: '0' });

  const loadMembers = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase.from('members').select('*').order('name');
    setMembers(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

  function openAddForm() {
    setEditing(null);
    setForm({ name: '', phone: '', points: '0' });
    setShowForm(true);
  }

  function openEditForm(m: Member) {
    setEditing(m);
    setForm({ name: m.name, phone: m.phone, points: String(m.points) });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const payload = {
      name: form.name.trim(),
      phone: form.phone.trim(),
      points: Number(form.points) || 0,
    };
    if (!payload.name || !payload.phone) return;

    if (editing) {
      await supabase.from('members').update(payload).eq('id', editing.id);
    } else {
      await supabase.from('members').insert(payload);
    }
    setShowForm(false);
    loadMembers();
  }

  async function handleDelete(id: string) {
    if (!confirm('Hapus member ini?')) return;
    await supabase.from('members').delete().eq('id', id);
    loadMembers();
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Pelanggan</p>
          <h1 className="text-2xl font-semibold">Member</h1>
        </div>
        <button
          onClick={openAddForm}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          + Tambah Member
        </button>
      </div>

      <div className="receipt-card max-w-lg mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          Member yang kamu tambah di sini <strong>belum otomatis muncul</strong> di app kasir —
          sinkronisasi dua arah belum ada di versi ini. Data di sini berguna buat pantau
          dari jauh, sementara pencarian member pas transaksi tetap pakai data lokal di app.
        </p>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Member' : 'Member Baru'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Nama member"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <input
            required
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            placeholder="No. HP"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <input
            type="number"
            value={form.points}
            onChange={(e) => setForm({ ...form, points: e.target.value })}
            placeholder="Poin"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="flex gap-3">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Simpan
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Batal
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : members.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">Belum ada member.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Nama</th>
                <th className="label-eyebrow px-5 py-3 font-medium">No. HP</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Poin</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {members.map((m) => (
                <tr key={m.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{m.name}</td>
                  <td className="px-5 py-3 text-ink/60">{m.phone}</td>
                  <td className="px-5 py-3 figure">{m.points}</td>
                  <td className="px-5 py-3 text-right">
                    <button onClick={() => openEditForm(m)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(m.id)} className="text-rust text-xs font-medium">
                      Hapus
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
MEMBEREOF

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
};

export default function PromosPage() {
  const supabase = createClient();
  const [promos, setPromos] = useState<Promo[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Promo | null>(null);
  const [form, setForm] = useState(emptyForm);

  const loadData = useCallback(async () => {
    setLoading(true);
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
    });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;
    if (form.scope === 'product' && form.product_ids.length === 0) {
      alert('Pilih minimal 1 produk buat scope "Produk Tertentu".');
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
    };

    if (editing) {
      await supabase.from('promos').update(payload).eq('id', editing.id);
    } else {
      await supabase.from('promos').insert(payload);
    }
    setShowForm(false);
    loadData();
  }

  async function handleDelete(id: string) {
    if (!confirm('Hapus promo ini?')) return;
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
          + Promo Baru
        </button>
      </div>

      <div className="receipt-card max-w-lg mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          Promo di sini <strong>belum otomatis kepakai</strong> di app kasir — sinkronisasi dua
          arah belum ada di versi ini. Promo yang aktif di kasir tetap yang dikelola langsung
          dari app Flutter.
        </p>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Promo' : 'Promo Baru'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Nama promo, mis. Promo Ramadan"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <div>
            <p className="label-eyebrow mb-2">Jenis Diskon</p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setForm({ ...form, discount_type: 'percentage' })}
                className={`flex-1 rounded-lg border py-2 text-sm font-medium ${
                  form.discount_type === 'percentage' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
                }`}
              >
                Persen (%)
              </button>
              <button
                type="button"
                onClick={() => setForm({ ...form, discount_type: 'fixed' })}
                className={`flex-1 rounded-lg border py-2 text-sm font-medium ${
                  form.discount_type === 'fixed' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
                }`}
              >
                Nominal (Rp)
              </button>
            </div>
          </div>

          <input
            required
            type="number"
            value={form.value}
            onChange={(e) => setForm({ ...form, value: e.target.value })}
            placeholder={form.discount_type === 'percentage' ? 'Besaran diskon (%)' : 'Besaran diskon (Rp)'}
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <input
            type="number"
            value={form.min_purchase}
            onChange={(e) => setForm({ ...form, min_purchase: e.target.value })}
            placeholder="Minimum pembelian (Rp, 0 = tanpa minimum)"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label-eyebrow block mb-1.5">Tanggal Mulai</label>
              <input
                type="date"
                value={form.start_date}
                onChange={(e) => setForm({ ...form, start_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
            <div>
              <label className="label-eyebrow block mb-1.5">Tanggal Selesai</label>
              <input
                type="date"
                value={form.end_date}
                onChange={(e) => setForm({ ...form, end_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
          </div>
          <p className="text-xs text-ink/50 -mt-2">Kosongkan tanggal kalau mau berlaku terus-menerus.</p>

          <div>
            <p className="label-eyebrow mb-2">Berlaku Untuk</p>
            <div className="flex flex-col gap-2">
              {(['cart', 'product', 'item'] as const).map((scope) => (
                <label key={scope} className="flex items-center gap-2 text-sm">
                  <input
                    type="radio"
                    checked={form.scope === scope}
                    onChange={() => setForm({ ...form, scope })}
                  />
                  {scope === 'cart' && 'Seluruh Struk'}
                  {scope === 'product' && 'Produk Tertentu (preset, otomatis kepakai)'}
                  {scope === 'item' && 'Per Item (opsional, dicentang manual di kasir)'}
                </label>
              ))}
            </div>
          </div>

          {(form.scope === 'product' || form.scope === 'item') && (
            <div>
              <p className="text-xs text-ink/50 mb-2">
                {form.scope === 'item' ? 'Batasi ke produk tertentu (opsional):' : 'Pilih produk:'}
              </p>
              <div className="max-h-40 overflow-y-auto border border-grey rounded-lg p-2 flex flex-col gap-1">
                {products.length === 0 && <p className="text-xs text-ink/40 px-2 py-1">Belum ada produk.</p>}
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
            Aktif
          </label>

          <div className="flex gap-3">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Simpan
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Batal
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : promos.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">Belum ada promo. Tap + buat bikin.</p>
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
                  {p.scope === 'product' && ` • ${p.product_ids?.length ?? 0} produk (preset)`}
                  {p.scope === 'item' && ' • per item'}
                  {p.scope === 'cart' && ' • seluruh struk'}
                  {!p.active && ' • Nonaktif'}
                </p>
              </div>
              <div className="flex gap-3 shrink-0">
                <button onClick={() => openEditForm(p)} className="text-navy text-xs font-medium">
                  Edit
                </button>
                <button onClick={() => handleDelete(p.id)} className="text-rust text-xs font-medium">
                  Hapus
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

cat > src/app/dashboard/shifts/page.tsx << 'SHIFTEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Shift = {
  id: string;
  cashier_name: string | null;
  start_time: string;
  starting_cash: number;
  end_time: string | null;
  ending_cash_counted: number | null;
  status: 'open' | 'closed';
};

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export default function ShiftsPage() {
  const supabase = createClient();
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [loading, setLoading] = useState(true);

  const loadShifts = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase.from('shifts').select('*').order('start_time', { ascending: false });
    setShifts(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadShifts();
  }, [loadShifts]);

  return (
    <div>
      <p className="label-eyebrow mb-2">Operasional</p>
      <h1 className="text-2xl font-semibold mb-8">Shift</h1>

      <div className="receipt-card max-w-lg mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          Halaman ini nampilin shift yang di-sync dari app kasir. Kalau masih kosong padahal
          kamu udah mulai/akhirin shift di app, itu wajar — sinkronisasi shift belum
          disambungin di versi ini (baru transaksi yang otomatis ke-kirim).
        </p>
      </div>

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : shifts.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">Belum ada data shift.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0 max-w-3xl">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Kasir</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Mulai</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Modal Awal</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Cash Dihitung</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {shifts.map((s) => (
                <tr key={s.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{s.cashier_name || '-'}</td>
                  <td className="px-5 py-3 text-ink/60">{formatDate(s.start_time)}</td>
                  <td className="px-5 py-3 figure">{formatRupiah(s.starting_cash)}</td>
                  <td className="px-5 py-3 figure">{s.ending_cash_counted != null ? formatRupiah(s.ending_cash_counted) : '—'}</td>
                  <td className="px-5 py-3">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${
                      s.status === 'open' ? 'bg-sage-light text-sage' : 'bg-grey-light text-ink/60'
                    }`}>
                      {s.status === 'open' ? 'Aktif' : 'Selesai'}
                    </span>
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
SHIFTEOF

echo 'Selesai. Restart: Ctrl+C lalu npm run dev'
