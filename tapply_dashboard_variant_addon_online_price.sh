cat > supabase/migration_009_variant_addon_online_price.sql << 'MIGEOF'
-- Migration: varian & add-on juga bisa punya harga khusus buat Online Order,
-- sama konsepnya kayak produk. Kosong = pakai harga biasa.
alter table variations
  add column if not exists online_price integer;
alter table addons
  add column if not exists online_price integer;
MIGEOF

cat > src/app/dashboard/variants/page.tsx << 'VAREOF'
'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import { createClient } from '@/lib/supabase/client';

type Variation = { id: string; name: string; sort_order: number; price: number; online_price: number | null };
type Addon = { id: string; name: string; price: number; sort_order: number; online_price: number | null };

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
  const [newVariationOnlinePrice, setNewVariationOnlinePrice] = useState('');
  const [newAddonName, setNewAddonName] = useState('');
  const [newAddonPrice, setNewAddonPrice] = useState('0');
  const [newAddonOnlinePrice, setNewAddonOnlinePrice] = useState('');

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
      online_price: newVariationOnlinePrice.trim() === '' ? null : Number(newVariationOnlinePrice),
      business_id: businessId,
    });
    setNewVariation('');
    setNewVariationPrice('0');
    setNewVariationOnlinePrice('');
    loadData();
  }

  async function deleteVariation(id: string) {
    if (!confirm('Delete this variant? It stays on past labels/orders but disappears from new selections.')) return;
    await supabase.from('variations').delete().eq('id', id);
    loadData();
  }

  async function addAddon() {
    if (!newAddonName.trim() || !businessId) return;
    await supabase.from('addons').insert({
      name: newAddonName.trim(),
      price: Number(newAddonPrice) || 0,
      online_price: newAddonOnlinePrice.trim() === '' ? null : Number(newAddonOnlinePrice),
      sort_order: addons.length,
      business_id: businessId,
    });
    setNewAddonName('');
    setNewAddonPrice('0');
    setNewAddonOnlinePrice('');
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
                <span className="flex-1">
                  {v.name}{v.price > 0 ? ` (+${formatRupiah(v.price)})` : ''}
                  {v.online_price != null && <span className="text-xs text-sage"> · Online: {formatRupiah(v.online_price)}</span>}
                </span>
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
            <input
              type="number"
              value={newVariationOnlinePrice}
              onChange={(e) => setNewVariationOnlinePrice(e.target.value)}
              placeholder="Online Rp"
              className="w-24 shrink-0 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <button onClick={addVariation} className="shrink-0 rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
              Add
            </button>
          </div>
          <p className="text-xs text-ink/40 mt-2">&quot;Online Rp&quot; is optional — only used when the sales type is an Online Order.</p>
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
                <span className="flex-1">
                  {a.name}{a.price > 0 ? ` (+${formatRupiah(a.price)})` : ''}
                  {a.online_price != null && <span className="text-xs text-sage"> · Online: {formatRupiah(a.online_price)}</span>}
                </span>
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
            <input
              type="number"
              value={newAddonOnlinePrice}
              onChange={(e) => setNewAddonOnlinePrice(e.target.value)}
              placeholder="Online Rp"
              className="w-24 shrink-0 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <button onClick={addAddon} className="shrink-0 rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
              Add
            </button>
          </div>
          <p className="text-xs text-ink/40 mt-2">&quot;Online Rp&quot; is optional — only used when the sales type is an Online Order.</p>
        </div>
      </div>
    </div>
  );
}
VAREOF

echo 'Selesai. Jalankan migration_009 di Supabase SQL Editor, lalu npm run dev'
