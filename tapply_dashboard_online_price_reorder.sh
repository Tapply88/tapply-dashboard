cat > supabase/migration_008_online_price.sql << 'MIGEOF'
-- Migration: harga khusus buat online order (GoFood/GrabFood/ShopeeFood/dll),
-- opsional. Kalau kosong (null), online order pakai harga biasa.
alter table products
  add column if not exists online_price integer;
MIGEOF

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
  online_price: number | null;
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
  online_price: '',
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
      online_price: p.online_price != null ? String(p.online_price) : '',
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
      online_price: form.online_price.trim() === '' ? null : Number(form.online_price),
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

          <div>
            <label className="label-eyebrow block mb-1.5">Online Order Price (optional)</label>
            <input
              type="number"
              value={form.online_price}
              onChange={(e) => setForm({ ...form, online_price: e.target.value })}
              placeholder="Leave blank to use the regular price above"
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
            <p className="text-xs text-ink/50 mt-1">Used when the sales type is any Online Order (GoFood, GrabFood, ShopeeFood, etc).</p>
          </div>

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

cat > src/app/dashboard/variants/page.tsx << 'VAREOF'
'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
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

  const dragVariationIndex = useRef<number | null>(null);
  const dragAddonIndex = useRef<number | null>(null);
  const [dragOverVariation, setDragOverVariation] = useState<number | null>(null);
  const [dragOverAddon, setDragOverAddon] = useState<number | null>(null);

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

  async function importDefaults() {
    if (!businessId) return;
    const existingVariationNames = new Set(variations.map((v) => v.name));
    const existingAddonNames = new Set(addons.map((a) => a.name));

    const defaultVariations = ['Hangat', 'Dingin'].filter((n) => !existingVariationNames.has(n));
    const defaultAddons = [
      { name: 'Extra Madu', price: 3000 },
      { name: 'Extra Jahe', price: 2000 },
      { name: 'Kurang Gula', price: 0 },
    ].filter((a) => !existingAddonNames.has(a.name));

    if (defaultVariations.length === 0 && defaultAddons.length === 0) {
      alert('These defaults are already in your list.');
      return;
    }

    if (defaultVariations.length > 0) {
      await supabase.from('variations').insert(
        defaultVariations.map((name, i) => ({ name, sort_order: variations.length + i, price: 0, business_id: businessId }))
      );
    }
    if (defaultAddons.length > 0) {
      await supabase.from('addons').insert(
        defaultAddons.map((a, i) => ({ name: a.name, price: a.price, sort_order: addons.length + i, business_id: businessId }))
      );
    }
    loadData();
  }

  // ---- Drag & drop reorder (persists sort_order for the whole list on drop) ----
  async function persistVariationOrder(list: Variation[]) {
    setVariations(list);
    await Promise.all(list.map((v, i) => supabase.from('variations').update({ sort_order: i }).eq('id', v.id)));
  }

  async function persistAddonOrder(list: Addon[]) {
    setAddons(list);
    await Promise.all(list.map((a, i) => supabase.from('addons').update({ sort_order: i }).eq('id', a.id)));
  }

  function handleVariationDrop(dropIndex: number) {
    const dragIndex = dragVariationIndex.current;
    setDragOverVariation(null);
    if (dragIndex === null || dragIndex === dropIndex) return;
    const list = [...variations];
    const [moved] = list.splice(dragIndex, 1);
    list.splice(dropIndex, 0, moved);
    persistVariationOrder(list);
    dragVariationIndex.current = null;
  }

  function handleAddonDrop(dropIndex: number) {
    const dragIndex = dragAddonIndex.current;
    setDragOverAddon(null);
    if (dragIndex === null || dragIndex === dropIndex) return;
    const list = [...addons];
    const [moved] = list.splice(dragIndex, 1);
    list.splice(dropIndex, 0, moved);
    persistAddonOrder(list);
    dragAddonIndex.current = null;
  }

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  return (
    <div className="max-w-2xl">
      <p className="label-eyebrow mb-2">Product Options</p>
      <h1 className="text-2xl font-semibold mb-2">Variants &amp; Add-ons</h1>
      <p className="text-sm text-ink/60 mb-4">
        These sync automatically to the cashier app and are used when adding items to the cart, and as
        defaults on printed labels. Drag the ⠿ handle to change which one shows first in the app.
      </p>
      <button
        onClick={importDefaults}
        className="rounded-full border border-navy text-navy px-4 py-2 text-sm font-medium hover:bg-navy-50 transition-colors mb-8"
      >
        Import Default Options (Hangat/Dingin, Extra Madu, etc.)
      </button>

      <div className="grid grid-cols-2 gap-6">
        <div className="receipt-card">
          <p className="label-eyebrow mb-4">Variants</p>
          <p className="text-xs text-ink/50 mb-3">e.g. Hot / Cold, or Large (+Rp5.000) — pick one at checkout</p>
          <div className="flex flex-col mb-4">
            {variations.length === 0 && <p className="text-xs text-ink/40">No variants yet.</p>}
            {variations.map((v, i) => (
              <div
                key={v.id}
                draggable
                onDragStart={() => (dragVariationIndex.current = i)}
                onDragOver={(e) => {
                  e.preventDefault();
                  setDragOverVariation(i);
                }}
                onDragLeave={() => setDragOverVariation((cur) => (cur === i ? null : cur))}
                onDrop={() => handleVariationDrop(i)}
                className={`flex items-center gap-2 text-sm border-b border-grey-light py-2 cursor-grab active:cursor-grabbing ${
                  dragOverVariation === i ? 'bg-navy-50' : ''
                }`}
              >
                <span className="text-ink/30 select-none" aria-hidden>⠿</span>
                <span className="flex-1">{v.name}{v.price > 0 ? ` (+${formatRupiah(v.price)})` : ''}</span>
                <button onClick={() => deleteVariation(v.id)} className="text-rust text-xs font-medium">
                  Delete
                </button>
              </div>
            ))}
          </div>
          <div className="flex flex-wrap gap-2">
            <input
              value={newVariation}
              onChange={(e) => setNewVariation(e.target.value)}
              placeholder="e.g. Large"
              className="flex-1 min-w-[120px] rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <input
              type="number"
              value={newVariationPrice}
              onChange={(e) => setNewVariationPrice(e.target.value)}
              placeholder="Rp (optional)"
              className="w-24 shrink-0 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <button onClick={addVariation} className="shrink-0 rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
              Add
            </button>
          </div>
        </div>

        <div className="receipt-card">
          <p className="label-eyebrow mb-4">Add-ons</p>
          <p className="text-xs text-ink/50 mb-3">e.g. Less Sugar, Extra Honey — pick multiple, optional price</p>
          <div className="flex flex-col mb-4">
            {addons.length === 0 && <p className="text-xs text-ink/40">No add-ons yet.</p>}
            {addons.map((a, i) => (
              <div
                key={a.id}
                draggable
                onDragStart={() => (dragAddonIndex.current = i)}
                onDragOver={(e) => {
                  e.preventDefault();
                  setDragOverAddon(i);
                }}
                onDragLeave={() => setDragOverAddon((cur) => (cur === i ? null : cur))}
                onDrop={() => handleAddonDrop(i)}
                className={`flex items-center gap-2 text-sm border-b border-grey-light py-2 cursor-grab active:cursor-grabbing ${
                  dragOverAddon === i ? 'bg-navy-50' : ''
                }`}
              >
                <span className="text-ink/30 select-none" aria-hidden>⠿</span>
                <span className="flex-1">{a.name}{a.price > 0 ? ` (+${formatRupiah(a.price)})` : ''}</span>
                <button onClick={() => deleteAddon(a.id)} className="text-rust text-xs font-medium">
                  Delete
                </button>
              </div>
            ))}
          </div>
          <div className="flex flex-wrap gap-2">
            <input
              value={newAddonName}
              onChange={(e) => setNewAddonName(e.target.value)}
              placeholder="e.g. Less Sugar"
              className="flex-1 min-w-[120px] rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <input
              type="number"
              value={newAddonPrice}
              onChange={(e) => setNewAddonPrice(e.target.value)}
              placeholder="Rp"
              className="w-20 shrink-0 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <button onClick={addAddon} className="shrink-0 rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
              Add
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
VAREOF

echo 'Selesai. Jalankan migration_008_online_price.sql di Supabase SQL Editor, lalu npm run dev'
