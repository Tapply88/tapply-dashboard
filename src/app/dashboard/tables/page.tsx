'use client';
import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

type DiningTable = {
  id: string;
  name: string;
  sort_order: number;
};

export default function TablesPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [tables, setTables] = useState<DiningTable[]>([]);
  const [loading, setLoading] = useState(true);
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const [newName, setNewName] = useState('');

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
    const { data } = await supabase.from('dining_tables').select('*').order('sort_order');
    setTables(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function addTable() {
    if (!newName.trim() || !businessId) return;
    const nextOrder = tables.length > 0 ? Math.max(...tables.map((t) => t.sort_order)) + 1 : 1;
    await supabase.from('dining_tables').insert({
      name: newName.trim(),
      sort_order: nextOrder,
      business_id: businessId,
    });
    setNewName('');
    loadData();
  }

  async function renameTable(id: string, name: string) {
    await supabase.from('dining_tables').update({ name }).eq('id', id);
    setTables((prev) => prev.map((t) => (t.id === id ? { ...t, name } : t)));
  }

  async function deleteTable(id: string) {
    await supabase.from('dining_tables').delete().eq('id', id);
    loadData();
  }

  async function moveTable(id: string, direction: 'up' | 'down') {
    const idx = tables.findIndex((t) => t.id === id);
    if (idx === -1) return;
    const swapIdx = direction === 'up' ? idx - 1 : idx + 1;
    if (swapIdx < 0 || swapIdx >= tables.length) return;

    const a = tables[idx];
    const b = tables[swapIdx];
    await Promise.all([
      supabase.from('dining_tables').update({ sort_order: b.sort_order }).eq('id', a.id),
      supabase.from('dining_tables').update({ sort_order: a.sort_order }).eq('id', b.id),
    ]);
    loadData();
  }

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  if (planInfo && !isProActive(planInfo)) {
    return (
      <div className="max-w-2xl">
        <p className="label-eyebrow mb-2">Dine-In</p>
        <h1 className="text-2xl font-semibold mb-8">Tables</h1>
        <UpgradeLock feature="Table management" />
      </div>
    );
  }

  return (
    <div className="max-w-2xl">
      <p className="label-eyebrow mb-2">Dine-In</p>
      <h1 className="text-2xl font-semibold mb-2">Tables</h1>
      <p className="text-sm text-ink/60 mb-6">
        Set up your dining tables here. Cashiers will see these as a table grid on the POS app to open and save
        bills per table — no need to type a table name manually anymore.
      </p>

      <div className="receipt-card">
        <p className="label-eyebrow mb-4">Table List</p>
        <div className="flex flex-col mb-4">
          {tables.length === 0 && <p className="text-xs text-ink/40">No tables yet.</p>}
          {tables.map((t, i) => (
            <div key={t.id} className="flex items-center gap-3 text-sm border-b border-grey-light py-2.5">
              <div className="flex flex-col shrink-0">
                <button
                  onClick={() => moveTable(t.id, 'up')}
                  disabled={i === 0}
                  className="text-ink/40 disabled:opacity-20 leading-none text-xs"
                >
                  ▲
                </button>
                <button
                  onClick={() => moveTable(t.id, 'down')}
                  disabled={i === tables.length - 1}
                  className="text-ink/40 disabled:opacity-20 leading-none text-xs"
                >
                  ▼
                </button>
              </div>
              <input
                value={t.name}
                onChange={(e) => renameTable(t.id, e.target.value)}
                className="flex-1 rounded-lg border border-grey px-2 py-1.5 text-sm outline-none focus:border-navy"
              />
              <button onClick={() => deleteTable(t.id)} className="text-rust text-xs font-medium shrink-0">
                Delete
              </button>
            </div>
          ))}
        </div>
        <div className="flex gap-2">
          <input
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && addTable()}
            placeholder="e.g. Meja 1, VIP 1"
            className="flex-1 rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
          />
          <button onClick={addTable} className="shrink-0 rounded-lg bg-navy text-white px-4 py-2 text-sm font-medium">
            Add
          </button>
        </div>
      </div>
    </div>
  );
}
