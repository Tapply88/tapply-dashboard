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
