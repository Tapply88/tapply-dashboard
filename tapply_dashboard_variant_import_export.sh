cat > package.json << 'PKGEOF'
{
  "name": "tapply-dashboard",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@supabase/ssr": "^0.5.2",
    "@supabase/supabase-js": "^2.45.4",
    "next": "14.2.15",
    "papaparse": "^5.4.1",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "recharts": "^2.12.7"
  },
  "devDependencies": {
    "@types/node": "^20.14.9",
    "@types/papaparse": "^5.3.14",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.39",
    "tailwindcss": "^3.4.6",
    "typescript": "^5.5.3"
  }
}
PKGEOF

cat > supabase/migration_007_variant_price.sql << 'MIGEOF'
-- Migration: varian (mis. "Large") sekarang boleh punya harga tambahan opsional,
-- sama kayak add-ons. Default 0 = gratis, gak ngubah perilaku lama.
alter table variations
  add column if not exists price integer default 0;
MIGEOF

cat > src/app/dashboard/variants/page.tsx << 'VAREOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Variation = { id: string; name: string; sort_order: number; price: number };
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
  const [newVariationPrice, setNewVariationPrice] = useState('0');
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
    await supabase.from('variations').insert({
      name: newVariation.trim(),
      sort_order: variations.length,
      price: Number(newVariationPrice) || 0,
      business_id: businessId,
    });
    setNewVariation('');
    setNewVariationPrice('0');
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
          <p className="text-xs text-ink/50 mb-3">e.g. Hot / Cold, or Large (+Rp5.000) — pick one at checkout</p>
          <div className="flex flex-col gap-2 mb-4">
            {variations.length === 0 && <p className="text-xs text-ink/40">No variants yet.</p>}
            {variations.map((v) => (
              <div key={v.id} className="flex items-center justify-between text-sm border-b border-grey-light pb-2">
                <span>{v.name}{v.price > 0 ? ` (+${formatRupiah(v.price)})` : ''}</span>
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
              placeholder="e.g. Large"
              className="flex-1 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <input
              type="number"
              value={newVariationPrice}
              onChange={(e) => setNewVariationPrice(e.target.value)}
              placeholder="Rp (optional)"
              className="w-28 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
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

cat > src/app/dashboard/products/page.tsx << 'PRODEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Papa from 'papaparse';
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
  const [showImport, setShowImport] = useState(false);
  const [importPreview, setImportPreview] = useState<Record<string, string>[]>([]);
  const [importError, setImportError] = useState<string | null>(null);
  const [importing, setImporting] = useState(false);
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

  function handleImportFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setImportError(null);
    Papa.parse<Record<string, string>>(file, {
      header: true,
      skipEmptyLines: true,
      complete: (results) => {
        const rows = results.data.filter((r) => r.name && r.name.trim());
        if (rows.length === 0) {
          setImportError('No valid rows found. Make sure the CSV has a "name" column.');
          setImportPreview([]);
          return;
        }
        setImportPreview(rows);
      },
      error: (err) => setImportError(err.message),
    });
  }

  async function confirmImport() {
    if (!businessId || importPreview.length === 0) return;
    setImporting(true);
    const rows = importPreview.map((r) => ({
      business_id: businessId,
      name: r.name?.trim(),
      price: Number(r.price) || 0,
      category: r.category?.trim() || 'General',
      stock: Number(r.stock) || 0,
      sku: r.sku?.trim() || null,
      volume: r.volume?.trim() || null,
    }));
    const { error } = await supabase.from('products').insert(rows);
    setImporting(false);
    if (error) {
      setImportError(error.message);
      return;
    }
    setShowImport(false);
    setImportPreview([]);
    loadData();
  }

  function downloadTemplate() {
    const csv = 'name,price,category,stock,sku,volume\nKunyit Asam,15000,Jamu,50,KA-001,250ml\n';
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'tapply-menu-template.csv';
    a.click();
    URL.revokeObjectURL(url);
  }

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
        <div className="flex gap-2">
          <button
            onClick={() => setShowImport(true)}
            className="rounded-full border border-navy text-navy px-5 py-2.5 text-sm font-medium hover:bg-navy-50 transition-colors"
          >
            Import CSV
          </button>
          <button
            onClick={openAddForm}
            className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
          >
            + Add Product
          </button>
        </div>
      </div>

      {showImport && (
        <div className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">Import Menu from CSV</p>
          <p className="text-xs text-ink/50">
            Columns: <code>name</code> (required), <code>price</code>, <code>category</code>, <code>stock</code>,{' '}
            <code>sku</code>, <code>volume</code>.{' '}
            <button type="button" onClick={downloadTemplate} className="text-navy underline">
              Download template
            </button>
          </p>
          <input type="file" accept=".csv" onChange={handleImportFile} className="text-sm" />
          {importError && <p className="text-rust text-sm">{importError}</p>}
          {importPreview.length > 0 && (
            <div className="max-h-48 overflow-y-auto border border-grey rounded-lg p-2 text-xs">
              <p className="font-medium mb-2">{importPreview.length} product(s) ready to import:</p>
              {importPreview.slice(0, 10).map((r, i) => (
                <p key={i} className="text-ink/60">
                  {r.name} — {r.price ? formatRupiah(Number(r.price)) : 'Rp 0'}
                </p>
              ))}
              {importPreview.length > 10 && <p className="text-ink/40">...and {importPreview.length - 10} more</p>}
            </div>
          )}
          <div className="flex gap-3">
            <button
              onClick={confirmImport}
              disabled={importPreview.length === 0 || importing}
              className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium disabled:opacity-40"
            >
              {importing ? 'Importing...' : `Import ${importPreview.length || ''} Product(s)`}
            </button>
            <button
              type="button"
              onClick={() => {
                setShowImport(false);
                setImportPreview([]);
                setImportError(null);
              }}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

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

cat > src/app/dashboard/page.tsx << 'DASHEOF'
'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { createClient } from '@/lib/supabase/client';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { ReceiptStatCard } from '@/components/ReceiptStatCard';

type Period = 'today' | 'week' | 'month' | 'custom';

type TxItem = { productId: string; productName: string; qty: number };
type Tx = { id: string; total: number; payment_method: string; items: TxItem[]; created_at: string };
type ProductInfo = { id: string; category: string };

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

function toDateInputValue(d: Date) {
  return d.toISOString().slice(0, 10);
}

function dayKey(iso: string) {
  return iso.slice(0, 10);
}

function getPresetRange(period: Period): { from: Date; to: Date } {
  const now = new Date();
  const to = new Date(now);
  to.setHours(23, 59, 59, 999);
  const from = new Date(now);
  if (period === 'today') {
    from.setHours(0, 0, 0, 0);
  } else if (period === 'week') {
    from.setDate(now.getDate() - 6);
    from.setHours(0, 0, 0, 0);
  } else if (period === 'month') {
    from.setDate(now.getDate() - 29);
    from.setHours(0, 0, 0, 0);
  }
  return { from, to };
}

const CHART_NAVY = '#092762';
const CHART_SAGE = '#5B8266';
const CHART_RUST = '#B54834';

export default function DashboardHomePage() {
  const supabase = createClient();
  const [businessName, setBusinessName] = useState('');
  const [period, setPeriod] = useState<Period>('today');
  const [customFrom, setCustomFrom] = useState(toDateInputValue(new Date(Date.now() - 6 * 86400000)));
  const [customTo, setCustomTo] = useState(toDateInputValue(new Date()));
  const [transactions, setTransactions] = useState<Tx[]>([]);
  const [previousTransactions, setPreviousTransactions] = useState<Tx[]>([]);
  const [products, setProducts] = useState<ProductInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const range = useMemo(() => {
    if (period === 'custom') {
      return { from: new Date(customFrom + 'T00:00:00'), to: new Date(customTo + 'T23:59:59') };
    }
    return getPresetRange(period);
  }, [period, customFrom, customTo]);

  const previousRange = useMemo(() => {
    const spanMs = range.to.getTime() - range.from.getTime();
    const prevTo = new Date(range.from.getTime() - 1);
    const prevFrom = new Date(prevTo.getTime() - spanMs);
    return { from: prevFrom, to: prevTo };
  }, [range]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);

    if (period === 'custom') {
      const days = (range.to.getTime() - range.from.getTime()) / 86400000;
      if (days > 30) {
        setError('Rentang maksimal 30 hari. Persempit pilihan tanggalnya ya.');
        setLoading(false);
        return;
      }
      if (days < 0) {
        setError('Tanggal mulai harus sebelum tanggal selesai.');
        setLoading(false);
        return;
      }
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
      if (range.from < oneYearAgo) {
        setError('Data cuma bisa dilihat sampai 1 tahun ke belakang.');
        setLoading(false);
        return;
      }
    }

    const [{ data: current }, { data: previous }, { data: productData }] = await Promise.all([
      supabase
        .from('transactions')
        .select('id, total, payment_method, items, created_at')
        .eq('status', 'paid')
        .gte('created_at', range.from.toISOString())
        .lte('created_at', range.to.toISOString()),
      supabase
        .from('transactions')
        .select('id, total, payment_method, items, created_at')
        .eq('status', 'paid')
        .gte('created_at', previousRange.from.toISOString())
        .lte('created_at', previousRange.to.toISOString()),
      supabase.from('products').select('id, category'),
    ]);

    setTransactions((current as Tx[]) ?? []);
    setPreviousTransactions((previous as Tx[]) ?? []);
    setProducts((productData as ProductInfo[]) ?? []);
    setLoading(false);
  }, [supabase, range, previousRange, period]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  useEffect(() => {
    async function loadBusiness() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;
      const { data: business } = await supabase.from('businesses').select('name').eq('id', link.business_id).single();
      if (business) setBusinessName(business.name);
    }
    loadBusiness();
  }, [supabase]);

  const totalRevenue = transactions.reduce((sum, t) => sum + (t.total ?? 0), 0);
  const previousRevenue = previousTransactions.reduce((sum, t) => sum + (t.total ?? 0), 0);
  const revenueChangePct = previousRevenue > 0 ? ((totalRevenue - previousRevenue) / previousRevenue) * 100 : null;
  const txCount = transactions.length;

  const byPayment = new Map<string, number>();
  for (const t of transactions) {
    byPayment.set(t.payment_method, (byPayment.get(t.payment_method) ?? 0) + (t.total ?? 0));
  }
  const paymentData = Array.from(byPayment.entries())
    .map(([method, amount]) => ({ method: method.replace(/_/g, ' '), amount }))
    .sort((a, b) => b.amount - a.amount);

  const productQty = new Map<string, number>();
  const productIdByName = new Map<string, string>();
  for (const t of transactions) {
    for (const item of t.items ?? []) {
      productQty.set(item.productName, (productQty.get(item.productName) ?? 0) + (item.qty ?? 0));
      if (item.productId) productIdByName.set(item.productName, item.productId);
    }
  }
  const topProducts = Array.from(productQty.entries())
    .map(([name, qty]) => ({ name, qty }))
    .sort((a, b) => b.qty - a.qty)
    .slice(0, 10);

  const categoryById = new Map(products.map((p) => [p.id, p.category]));
  const byCategory = new Map<string, number>();
  for (const [name, qty] of productQty.entries()) {
    const id = productIdByName.get(name);
    const category = (id && categoryById.get(id)) || 'Lainnya';
    byCategory.set(category, (byCategory.get(category) ?? 0) + qty);
  }
  const categoryData = Array.from(byCategory.entries())
    .map(([category, qty]) => ({ category, qty }))
    .sort((a, b) => b.qty - a.qty);

  const byDay = new Map<string, number>();
  for (const t of transactions) {
    const key = dayKey(t.created_at);
    byDay.set(key, (byDay.get(key) ?? 0) + (t.total ?? 0));
  }
  const dailyTrend = Array.from(byDay.entries())
    .map(([date, total]) => ({ date: date.slice(5), total }))
    .sort((a, b) => (a.date > b.date ? 1 : -1));

  function exportCsv() {
    const header = 'Date,Payment Method,Items,Total\n';
    const rows = transactions
      .map((t) => {
        const itemsSummary = (t.items ?? []).map((i) => `${i.productName} x${i.qty}`).join('; ');
        const date = new Date(t.created_at).toLocaleString('id-ID');
        return `"${date}","${t.payment_method}","${itemsSummary.replace(/"/g, "'")}",${t.total}`;
      })
      .join('\n');
    const blob = new Blob([header + rows], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tapply-sales-${toDateInputValue(range.from)}-to-${toDateInputValue(range.to)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div>
      <p className="label-eyebrow mb-2">{businessName || 'Ringkasan'}</p>
      <h1 className="text-2xl font-semibold mb-6">Laporan Penjualan</h1>

      <div className="flex flex-wrap items-center gap-2 mb-8">
        {(['today', 'week', 'month', 'custom'] as Period[]).map((p) => (
          <button
            key={p}
            onClick={() => setPeriod(p)}
            className={`rounded-full px-4 py-2 text-sm font-medium transition-colors ${
              period === p ? 'bg-navy text-white' : 'border border-grey text-navy hover:bg-navy-50'
            }`}
          >
            {p === 'today' ? 'Hari Ini' : p === 'week' ? '7 Hari' : p === 'month' ? '30 Hari' : 'Pilih Periode'}
          </button>
        ))}
        {period === 'custom' && (
          <div className="flex items-center gap-2 ml-2">
            <input
              type="date"
              value={customFrom}
              onChange={(e) => setCustomFrom(e.target.value)}
              className="rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <span className="text-ink/40 text-sm">–</span>
            <input
              type="date"
              value={customTo}
              onChange={(e) => setCustomTo(e.target.value)}
              className="rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
          </div>
        )}
        <button
          onClick={exportCsv}
          disabled={transactions.length === 0}
          className="ml-auto rounded-full border border-navy text-navy px-4 py-2 text-sm font-medium hover:bg-navy-50 transition-colors disabled:opacity-40"
        >
          ⬇ Export CSV
        </button>
      </div>

      {error && (
        <div className="receipt-card max-w-lg mb-8 !bg-rust-light !border-rust/30">
          <p className="text-sm text-rust">{error}</p>
        </div>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5 mb-10">
            <ReceiptStatCard
              label="Total Penjualan"
              value={formatRupiah(totalRevenue)}
              sublabel={
                revenueChangePct === null
                  ? `${txCount} transaksi`
                  : `${revenueChangePct >= 0 ? '+' : ''}${revenueChangePct.toFixed(0)}% dari periode sebelumnya • ${txCount} transaksi`
              }
              accent={revenueChangePct !== null && revenueChangePct < 0 ? 'rust' : 'navy'}
            />
            <ReceiptStatCard
              label="Rata-rata per Transaksi"
              value={formatRupiah(txCount > 0 ? Math.round(totalRevenue / txCount) : 0)}
              accent="sage"
            />
          </div>

          <div className="receipt-card mb-8">
            <p className="label-eyebrow mb-4">Tren Penjualan Harian</p>
            {dailyTrend.length < 2 ? (
              <p className="text-sm text-ink/50">Butuh minimal 2 hari data buat nampilin tren.</p>
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <LineChart data={dailyTrend}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis tickFormatter={(v) => formatRupiah(v)} tick={{ fontSize: 10 }} width={70} />
                  <Tooltip formatter={(v: number) => [formatRupiah(v), 'Penjualan']} />
                  <Line type="monotone" dataKey="total" stroke={CHART_NAVY} strokeWidth={2} dot={{ r: 3 }} />
                </LineChart>
              </ResponsiveContainer>
            )}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <div className="receipt-card">
              <p className="label-eyebrow mb-4">Produk Terlaris (jumlah unit)</p>
              {topProducts.length === 0 ? (
                <p className="text-sm text-ink/50">Belum ada transaksi di periode ini.</p>
              ) : (
                <ResponsiveContainer width="100%" height={Math.max(200, topProducts.length * 34)}>
                  <BarChart data={topProducts} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11 }} />
                    <YAxis type="category" dataKey="name" width={110} tick={{ fontSize: 11 }} />
                    <Tooltip formatter={(v: number) => [`${v} unit`, 'Terjual']} />
                    <Bar dataKey="qty" fill={CHART_NAVY} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>

            <div className="receipt-card">
              <p className="label-eyebrow mb-4">Penjualan per Metode Bayar</p>
              {paymentData.length === 0 ? (
                <p className="text-sm text-ink/50">Belum ada transaksi di periode ini.</p>
              ) : (
                <ResponsiveContainer width="100%" height={Math.max(200, paymentData.length * 40)}>
                  <BarChart data={paymentData} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" tickFormatter={(v) => formatRupiah(v)} tick={{ fontSize: 10 }} />
                    <YAxis type="category" dataKey="method" width={100} tick={{ fontSize: 11 }} className="capitalize" />
                    <Tooltip formatter={(v: number) => [formatRupiah(v), 'Total']} />
                    <Bar dataKey="amount" fill={CHART_SAGE} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>

          <div className="receipt-card">
            <p className="label-eyebrow mb-4">Penjualan per Kategori (jumlah unit)</p>
            {categoryData.length === 0 ? (
              <p className="text-sm text-ink/50">Belum ada transaksi di periode ini.</p>
            ) : (
              <ResponsiveContainer width="100%" height={Math.max(160, categoryData.length * 40)}>
                <BarChart data={categoryData} layout="vertical" margin={{ left: 20 }}>
                  <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                  <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11 }} />
                  <YAxis type="category" dataKey="category" width={100} tick={{ fontSize: 11 }} />
                  <Tooltip formatter={(v: number) => [`${v} unit`, 'Terjual']} />
                  <Bar dataKey="qty" fill={CHART_RUST} radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </>
      )}
    </div>
  );
}
DASHEOF

echo 'Selesai. Jalankan npm install (buat papaparse), migration_007 di Supabase SQL Editor, lalu npm run dev'
