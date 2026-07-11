'use client';
import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

type Ingredient = {
  id: string;
  name: string;
  unit: string;
  stock: number;
  low_stock_threshold: number;
};

const UNITS = ['gram', 'ml', 'pcs'];

export default function IngredientsPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [ingredients, setIngredients] = useState<Ingredient[]>([]);
  const [loading, setLoading] = useState(true);
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const [newName, setNewName] = useState('');
  const [newUnit, setNewUnit] = useState('gram');
  const [newStock, setNewStock] = useState('0');
  const [newThreshold, setNewThreshold] = useState('0');

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
    const { data } = await supabase.from('ingredients').select('*').order('name');
    setIngredients(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function addIngredient() {
    if (!newName.trim() || !businessId) return;
    await supabase.from('ingredients').insert({
      name: newName.trim(),
      unit: newUnit,
      stock: Number(newStock) || 0,
      low_stock_threshold: Number(newThreshold) || 0,
      business_id: businessId,
    });
    setNewName('');
    setNewStock('0');
    setNewThreshold('0');
    loadData();
  }

  async function updateStock(id: string, stock: number) {
    await supabase.from('ingredients').update({ stock }).eq('id', id);
    setIngredients((prev) => prev.map((i) => (i.id === id ? { ...i, stock } : i)));
  }

  async function deleteIngredient(id: string) {
    await supabase.from('ingredients').delete().eq('id', id);
    loadData();
  }

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  if (planInfo && !isProActive(planInfo)) {
    return (
      <div className="max-w-2xl">
        <p className="label-eyebrow mb-2">Raw Materials</p>
        <h1 className="text-2xl font-semibold mb-8">Ingredients</h1>
        <UpgradeLock feature="Recipe & ingredient management" />
      </div>
    );
  }

  return (
    <div className="max-w-2xl">
      <p className="label-eyebrow mb-2">Raw Materials</p>
      <h1 className="text-2xl font-semibold mb-2">Ingredients</h1>
      <p className="text-sm text-ink/60 mb-6">
        Track raw material stock here. Link ingredients to a product&apos;s recipe on the Products page — stock will
        deduct automatically when that product is sold.
      </p>

      <div className="receipt-card">
        <p className="label-eyebrow mb-4">Ingredient List</p>
        <div className="flex flex-col mb-4">
          {ingredients.length === 0 && <p className="text-xs text-ink/40">No ingredients yet.</p>}
          {ingredients.map((ing) => {
            const low = ing.stock <= ing.low_stock_threshold;
            return (
              <div key={ing.id} className="flex items-center gap-3 text-sm border-b border-grey-light py-2.5">
                <span className="flex-1">{ing.name}</span>
                <input
                  type="number"
                  value={ing.stock}
                  onChange={(e) => updateStock(ing.id, Number(e.target.value) || 0)}
                  className={`w-24 rounded-lg border px-2 py-1.5 text-sm text-right outline-none ${
                    low ? 'border-rust text-rust' : 'border-grey focus:border-navy'
                  }`}
                />
                <span className="text-xs text-ink/50 w-10">{ing.unit}</span>
                {low && <span className="text-xs text-rust font-medium">Low</span>}
                <button onClick={() => deleteIngredient(ing.id)} className="text-rust text-xs font-medium">
                  Delete
                </button>
              </div>
            );
          })}
        </div>
        <div className="flex flex-wrap gap-2">
          <input
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            placeholder="e.g. Kunyit"
            className="flex-1 min-w-[120px] rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
          />
          <select
            value={newUnit}
            onChange={(e) => setNewUnit(e.target.value)}
            className="rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
          >
            {UNITS.map((u) => (
              <option key={u} value={u}>
                {u}
              </option>
            ))}
          </select>
          <input
            type="number"
            value={newStock}
            onChange={(e) => setNewStock(e.target.value)}
            placeholder="Stock"
            className="w-24 shrink-0 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
          />
          <input
            type="number"
            value={newThreshold}
            onChange={(e) => setNewThreshold(e.target.value)}
            placeholder="Low stock alert"
            className="w-32 shrink-0 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
          />
          <button onClick={addIngredient} className="shrink-0 rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
            Add
          </button>
        </div>
      </div>
    </div>
  );
}
