cat > supabase/migration_004_label_variant_dates.sql << 'MIG4EOF'
-- Migration: kolom tambahan buat konfigurasi label produk dari dashboard
-- (varian default, tambahan default, tanggal produksi/expiry default).

alter table products
  add column if not exists label_variant text,
  add column if not exists label_addons text[] default '{}',
  add column if not exists expiry_date date,
  add column if not exists production_date date;
MIG4EOF

cat > supabase/migration_005_product_image.sql << 'MIG5EOF'
-- Migration: simpan foto produk sebagai base64 (konsisten sama app Flutter),
-- daripada setup Supabase Storage bucket buat MVP ini.
alter table products
  add column if not exists image_base64 text;
MIG5EOF

cat > src/components/Sidebar.tsx << 'SIDEBAREOF'
'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV_ITEMS = [
  { href: '/dashboard', label: 'Ringkasan', icon: '◧' },
  { href: '/dashboard/products', label: 'Produk', icon: '☰' },
  { href: '/dashboard/variants', label: 'Variants & Add-ons', icon: '⊕' },
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
    footer_text: '',
    tax_percent: '0',
    service_percent: '0',
    discount_percent: '0',
    rounding_enabled: false,
    rounding_nearest: '100',
    manager_pin: '1234',
    pin_required_for_cancel: true,
    print_check_enabled: true,
    queue_number_enabled: false,
    queue_start_number: '1',
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
          manager_pin: business.manager_pin ?? '1234',
          pin_required_for_cancel: business.pin_required_for_cancel ?? true,
          print_check_enabled: business.print_check_enabled ?? true,
          queue_number_enabled: business.queue_number_enabled ?? false,
          queue_start_number: String(business.queue_start_number ?? 1),
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

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!businessId) return;
    await supabase
      .from('businesses')
      .update({
        name: form.name,
        address: form.address,
        phone: form.phone,
        footer_text: form.footer_text,
        tax_percent: Number(form.tax_percent) || 0,
        service_percent: Number(form.service_percent) || 0,
        discount_percent: Number(form.discount_percent) || 0,
        rounding_enabled: form.rounding_enabled,
        rounding_nearest: Number(form.rounding_nearest) || 100,
        manager_pin: form.manager_pin || '1234',
        pin_required_for_cancel: form.pin_required_for_cancel,
        print_check_enabled: form.print_check_enabled,
        queue_number_enabled: form.queue_number_enabled,
        queue_start_number: Number(form.queue_start_number) || 1,
      })
      .eq('id', businessId);
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  }

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  return (
    <div className="max-w-lg">
      <p className="label-eyebrow mb-2">Business Settings</p>
      <h1 className="text-2xl font-semibold mb-2">Settings</h1>
      <p className="text-sm text-ink/60 mb-8">
        Everything here syncs automatically to the cashier app — no action needed on the device.
      </p>

      <form onSubmit={handleSave} className="receipt-card flex flex-col gap-4">
        <p className="label-eyebrow">Business Profile</p>
        <div>
          <label className="label-eyebrow block mb-1.5">Business Name</label>
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">Address</label>
          <textarea
            value={form.address}
            onChange={(e) => setForm({ ...form, address: e.target.value })}
            rows={2}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none resize-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">Phone Number</label>
          <input
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">Receipt Footer Text</label>
          <input
            value={form.footer_text}
            onChange={(e) => setForm({ ...form, footer_text: e.target.value })}
            placeholder="Thank you!"
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">Tax, Service &amp; Discount</p>
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

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">Security</p>
        <div>
          <label className="label-eyebrow block mb-1.5">Manager PIN (for canceling items)</label>
          <input
            value={form.manager_pin}
            onChange={(e) => setForm({ ...form, manager_pin: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.pin_required_for_cancel}
            onChange={(e) => setForm({ ...form, pin_required_for_cancel: e.target.checked })}
          />
          Require PIN to cancel a cart item
        </label>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">Receipt &amp; Queue</p>
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
          Save Changes
        </button>
        {saved && <p className="text-sage text-sm text-center">Saved.</p>}
      </form>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">Sync</p>
        <h2 className="text-lg font-semibold mb-2">Connect the Cashier App</h2>
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

cat > src/app/dashboard/products/page.tsx << 'PRODEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Product = {
  id: string;
  name: string;
  price: number;
  category: string;
  stock: number;
  is_active: boolean;
  sku: string | null;
  volume: string | null;
  label_size: string | null;
  show_price_on_label: boolean;
  label_variant: string | null;
  label_addons: string[] | null;
  expiry_date: string | null;
  production_date: string | null;
  image_base64: string | null;
};

type Variation = { id: string; name: string };
type Addon = { id: string; name: string; price: number };

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

const emptyForm = {
  name: '',
  price: '',
  category: 'General',
  stock: '0',
  sku: '',
  volume: '',
  label_size: '60x40mm',
  show_price_on_label: true,
  label_variant: '',
  label_addons: [] as string[],
  expiry_date: '',
  production_date: '',
  image_base64: '' as string | null,
};

export default function ProductsPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [variations, setVariations] = useState<Variation[]>([]);
  const [addons, setAddons] = useState<Addon[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Product | null>(null);
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
    const [{ data: productData }, { data: variationData }, { data: addonData }] = await Promise.all([
      supabase.from('products').select('*').order('name'),
      supabase.from('variations').select('id, name').order('sort_order'),
      supabase.from('addons').select('id, name, price').order('sort_order'),
    ]);
    setProducts(productData ?? []);
    setVariations(variationData ?? []);
    setAddons(addonData ?? []);
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

  function openEditForm(p: Product) {
    setEditing(p);
    setForm({
      name: p.name,
      price: String(p.price),
      category: p.category,
      stock: String(p.stock),
      sku: p.sku ?? '',
      volume: p.volume ?? '',
      label_size: p.label_size ?? '60x40mm',
      show_price_on_label: p.show_price_on_label ?? true,
      label_variant: p.label_variant ?? '',
      label_addons: p.label_addons ?? [],
      expiry_date: p.expiry_date ?? '',
      production_date: p.production_date ?? '',
      image_base64: p.image_base64,
    });
    setShowForm(true);
  }

  function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      const base64 = result.split(',')[1];
      setForm((f) => ({ ...f, image_base64: base64 }));
    };
    reader.readAsDataURL(file);
  }

  function toggleAddon(name: string) {
    setForm((f) => ({
      ...f,
      label_addons: f.label_addons.includes(name) ? f.label_addons.filter((a) => a !== name) : [...f.label_addons, name],
    }));
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const payload = {
      name: form.name.trim(),
      price: Number(form.price) || 0,
      category: form.category.trim() || 'General',
      stock: Number(form.stock) || 0,
      sku: form.sku.trim() || null,
      volume: form.volume.trim() || null,
      label_size: form.label_size,
      show_price_on_label: form.show_price_on_label,
      label_variant: form.label_variant || null,
      label_addons: form.label_addons,
      expiry_date: form.expiry_date || null,
      production_date: form.production_date || null,
      image_base64: form.image_base64 || null,
    };
    if (!payload.name) return;

    if (editing) {
      await supabase.from('products').update(payload).eq('id', editing.id);
    } else {
      if (!businessId) return;
      await supabase.from('products').insert({ ...payload, business_id: businessId });
    }
    setShowForm(false);
    loadData();
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this product?')) return;
    await supabase.from('products').delete().eq('id', id);
    loadData();
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Catalog</p>
          <h1 className="text-2xl font-semibold">Products</h1>
        </div>
        <button
          onClick={openAddForm}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          + Add Product
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Product' : 'New Product'}</p>

          <div className="flex items-center gap-4">
            <div className="w-20 h-20 rounded-lg bg-cream border border-grey flex items-center justify-center overflow-hidden shrink-0">
              {form.image_base64 ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={`data:image/jpeg;base64,${form.image_base64}`} alt="" className="w-full h-full object-cover" />
              ) : (
                <span className="text-xs text-ink/40">No photo</span>
              )}
            </div>
            <input type="file" accept="image/*" onChange={handlePhotoChange} className="text-xs" />
          </div>

          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Product name"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="grid grid-cols-2 gap-3">
            <input
              required
              type="number"
              value={form.price}
              onChange={(e) => setForm({ ...form, price: e.target.value })}
              placeholder="Price (Rp)"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
            <input
              type="number"
              value={form.stock}
              onChange={(e) => setForm({ ...form, stock: e.target.value })}
              placeholder="Stock"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <input
            value={form.category}
            onChange={(e) => setForm({ ...form, category: e.target.value })}
            placeholder="Category"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <div className="grid grid-cols-2 gap-3 pt-2 border-t border-grey-light">
            <div>
              <label className="label-eyebrow block mb-1.5 mt-3">SKU</label>
              <input
                value={form.sku}
                onChange={(e) => setForm({ ...form, sku: e.target.value })}
                placeholder="Auto-generated if blank"
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
            <div>
              <label className="label-eyebrow block mb-1.5 mt-3">Volume/Size</label>
              <input
                value={form.volume}
                onChange={(e) => setForm({ ...form, volume: e.target.value })}
                placeholder="e.g. 250ml"
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
          </div>

          <div>
            <label className="label-eyebrow block mb-1.5">Label Size</label>
            <select
              value={form.label_size}
              onChange={(e) => setForm({ ...form, label_size: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            >
              <option value="60x40mm">60x40mm</option>
              <option value="50x30mm">50x30mm</option>
              <option value="40x30mm">40x30mm</option>
            </select>
          </div>

          {variations.length > 0 && (
            <div>
              <label className="label-eyebrow block mb-1.5">Default Label Variant</label>
              <select
                value={form.label_variant}
                onChange={(e) => setForm({ ...form, label_variant: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              >
                <option value="">None</option>
                {variations.map((v) => (
                  <option key={v.id} value={v.name}>{v.name}</option>
                ))}
              </select>
            </div>
          )}

          {addons.length > 0 && (
            <div>
              <p className="label-eyebrow mb-2">Default Label Add-ons</p>
              <div className="flex flex-wrap gap-2">
                {addons.map((a) => (
                  <label key={a.id} className="flex items-center gap-1.5 text-xs border border-grey rounded-full px-3 py-1.5 cursor-pointer">
                    <input type="checkbox" checked={form.label_addons.includes(a.name)} onChange={() => toggleAddon(a.name)} />
                    {a.name}{a.price > 0 ? ` (+${formatRupiah(a.price)})` : ''}
                  </label>
                ))}
              </div>
            </div>
          )}

          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.show_price_on_label}
              onChange={(e) => setForm({ ...form, show_price_on_label: e.target.checked })}
            />
            Show price on printed label
          </label>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label-eyebrow block mb-1.5">Production Date</label>
              <input
                type="date"
                value={form.production_date}
                onChange={(e) => setForm({ ...form, production_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
            <div>
              <label className="label-eyebrow block mb-1.5">Expiry Date</label>
              <input
                type="date"
                value={form.expiry_date}
                onChange={(e) => setForm({ ...form, expiry_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
          </div>

          <div className="flex gap-3 pt-2">
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
      ) : products.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">No products yet. Add your first one.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Name</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Category</th>
                <th className="label-eyebrow px-5 py-3 font-medium">SKU</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Price</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Stock</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {products.map((p) => (
                <tr key={p.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{p.name}</td>
                  <td className="px-5 py-3 text-ink/60">{p.category}</td>
                  <td className="px-5 py-3 figure text-xs">{p.sku || '—'}</td>
                  <td className="px-5 py-3 figure">{formatRupiah(p.price)}</td>
                  <td className="px-5 py-3">
                    <span className={p.stock <= 5 ? 'text-rust font-medium' : ''}>{p.stock}</span>
                  </td>
                  <td className="px-5 py-3 text-right">
                    <button onClick={() => openEditForm(p)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(p.id)} className="text-rust text-xs font-medium">
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
PRODEOF

mkdir -p src/app/dashboard/variants
cat > src/app/dashboard/variants/page.tsx << 'VAREOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Variation = { id: string; name: string; sort_order: number };
type Addon = { id: string; name: string; price: number; sort_order: number };

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

export default function VariantsPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [variations, setVariations] = useState<Variation[]>([]);
  const [addons, setAddons] = useState<Addon[]>([]);
  const [loading, setLoading] = useState(true);
  const [newVariation, setNewVariation] = useState('');
  const [newAddonName, setNewAddonName] = useState('');
  const [newAddonPrice, setNewAddonPrice] = useState('0');

  const loadData = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) setBusinessId(link.business_id);
    }
    const [{ data: v }, { data: a }] = await Promise.all([
      supabase.from('variations').select('*').order('sort_order'),
      supabase.from('addons').select('*').order('sort_order'),
    ]);
    setVariations(v ?? []);
    setAddons(a ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function addVariation() {
    if (!newVariation.trim() || !businessId) return;
    await supabase.from('variations').insert({ name: newVariation.trim(), sort_order: variations.length, business_id: businessId });
    setNewVariation('');
    loadData();
  }

  async function deleteVariation(id: string) {
    if (!confirm('Delete this variant? It stays on past labels/orders but disappears from new selections.')) return;
    await supabase.from('variations').delete().eq('id', id);
    loadData();
  }

  async function addAddon() {
    if (!newAddonName.trim() || !businessId) return;
    await supabase.from('addons').insert({ name: newAddonName.trim(), price: Number(newAddonPrice) || 0, sort_order: addons.length, business_id: businessId });
    setNewAddonName('');
    setNewAddonPrice('0');
    loadData();
  }

  async function deleteAddon(id: string) {
    if (!confirm('Delete this add-on?')) return;
    await supabase.from('addons').delete().eq('id', id);
    loadData();
  }

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  return (
    <div className="max-w-2xl">
      <p className="label-eyebrow mb-2">Product Options</p>
      <h1 className="text-2xl font-semibold mb-2">Variants &amp; Add-ons</h1>
      <p className="text-sm text-ink/60 mb-8">
        These sync automatically to the cashier app and are used when adding items to the cart, and as
        defaults on printed labels.
      </p>

      <div className="grid grid-cols-2 gap-6">
        <div className="receipt-card">
          <p className="label-eyebrow mb-4">Variants</p>
          <p className="text-xs text-ink/50 mb-3">e.g. Hot / Cold — pick one at checkout</p>
          <div className="flex flex-col gap-2 mb-4">
            {variations.length === 0 && <p className="text-xs text-ink/40">No variants yet.</p>}
            {variations.map((v) => (
              <div key={v.id} className="flex items-center justify-between text-sm border-b border-grey-light pb-2">
                <span>{v.name}</span>
                <button onClick={() => deleteVariation(v.id)} className="text-rust text-xs font-medium">
                  Delete
                </button>
              </div>
            ))}
          </div>
          <div className="flex gap-2">
            <input
              value={newVariation}
              onChange={(e) => setNewVariation(e.target.value)}
              placeholder="e.g. Hot"
              className="flex-1 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <button onClick={addVariation} className="rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
              Add
            </button>
          </div>
        </div>

        <div className="receipt-card">
          <p className="label-eyebrow mb-4">Add-ons</p>
          <p className="text-xs text-ink/50 mb-3">e.g. Less Sugar, Extra Honey — pick multiple, optional price</p>
          <div className="flex flex-col gap-2 mb-4">
            {addons.length === 0 && <p className="text-xs text-ink/40">No add-ons yet.</p>}
            {addons.map((a) => (
              <div key={a.id} className="flex items-center justify-between text-sm border-b border-grey-light pb-2">
                <span>{a.name}{a.price > 0 ? ` (+${formatRupiah(a.price)})` : ''}</span>
                <button onClick={() => deleteAddon(a.id)} className="text-rust text-xs font-medium">
                  Delete
                </button>
              </div>
            ))}
          </div>
          <div className="flex gap-2">
            <input
              value={newAddonName}
              onChange={(e) => setNewAddonName(e.target.value)}
              placeholder="e.g. Less Sugar"
              className="flex-1 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <input
              type="number"
              value={newAddonPrice}
              onChange={(e) => setNewAddonPrice(e.target.value)}
              placeholder="Rp"
              className="w-20 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <button onClick={addAddon} className="rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
              Add
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
VAREOF

cat > src/app/dashboard/members/page.tsx << 'MEMEOF'
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
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Member | null>(null);
  const [form, setForm] = useState({ name: '', phone: '', points: '0' });

  const loadMembers = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) setBusinessId(link.business_id);
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
      if (!businessId) return;
      await supabase.from('members').insert({ ...payload, business_id: businessId });
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
MEMEOF

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
      if (!businessId) return;
      await supabase.from('promos').insert({ ...payload, business_id: businessId });
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

echo 'Selesai. Jalankan migration_004 dan migration_005 di Supabase SQL Editor, lalu npm run dev'
