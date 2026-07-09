'use client';
import { useEffect, useState, useCallback, useMemo } from 'react';
import { createClient } from '@/lib/supabase/client';

type Tx = { id: string; total: number; payment_method: string; sales_type: string; created_at: string };
type Period = 'today' | 'week' | 'month' | 'custom';

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
  if (period === 'today') from.setHours(0, 0, 0, 0);
  else if (period === 'week') { from.setDate(now.getDate() - 6); from.setHours(0, 0, 0, 0); }
  else if (period === 'month') { from.setDate(now.getDate() - 29); from.setHours(0, 0, 0, 0); }
  return { from, to };
}

const PLATFORMS = [
  { key: 'GoFood', label: 'GoFood', field: 'gofood_commission_percent' },
  { key: 'GrabFood', label: 'GrabFood', field: 'grabfood_commission_percent' },
  { key: 'ShopeeFood', label: 'ShopeeFood', field: 'shopeefood_commission_percent' },
] as const;

export function SalesReportsSection() {
  const supabase = createClient();
  const [period, setPeriod] = useState<Period>('week');
  const [customFrom, setCustomFrom] = useState(toDateInputValue(new Date(Date.now() - 6 * 86400000)));
  const [customTo, setCustomTo] = useState(toDateInputValue(new Date()));
  const [transactions, setTransactions] = useState<Tx[]>([]);
  const [loading, setLoading] = useState(true);
  const [commissions, setCommissions] = useState({ gofood_commission_percent: 20, grabfood_commission_percent: 20, shopeefood_commission_percent: 20 });
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [savingCommission, setSavingCommission] = useState(false);

  const range = useMemo(() => {
    if (period === 'custom') {
      return { from: new Date(customFrom + 'T00:00:00'), to: new Date(customTo + 'T23:59:59') };
    }
    return getPresetRange(period);
  }, [period, customFrom, customTo]);

  const loadData = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) {
        setBusinessId(link.business_id);
        const { data: biz } = await supabase
          .from('businesses')
          .select('gofood_commission_percent, grabfood_commission_percent, shopeefood_commission_percent')
          .eq('id', link.business_id)
          .single();
        if (biz) setCommissions(biz);
      }
    }
    const { data } = await supabase
      .from('transactions')
      .select('id, total, payment_method, sales_type, created_at')
      .eq('status', 'paid')
      .gte('created_at', range.from.toISOString())
      .lte('created_at', range.to.toISOString());
    setTransactions((data as Tx[]) ?? []);
    setLoading(false);
  }, [supabase, range]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function saveCommissions() {
    if (!businessId) return;
    setSavingCommission(true);
    await supabase.from('businesses').update(commissions).eq('id', businessId);
    setSavingCommission(false);
  }

  const dailyRows = useMemo(() => {
    const map: Record<string, { date: string; count: number; total: number; cash: number; nonCash: number }> = {};
    for (const tx of transactions) {
      const key = dayKey(tx.created_at);
      if (!map[key]) map[key] = { date: key, count: 0, total: 0, cash: 0, nonCash: 0 };
      map[key].count += 1;
      map[key].total += tx.total;
      if (tx.payment_method === 'cash') map[key].cash += tx.total;
      else map[key].nonCash += tx.total;
    }
    return Object.values(map).sort((a, b) => b.date.localeCompare(a.date));
  }, [transactions]);

  const dailyTotal = useMemo(() => dailyRows.reduce((sum, r) => sum + r.total, 0), [dailyRows]);

  const onlineRows = useMemo(() => {
    return PLATFORMS.map((p) => {
      const matching = transactions.filter((tx) => tx.sales_type === 'Online - ' + p.key);
      const gross = matching.reduce((sum, tx) => sum + tx.total, 0);
      const commissionPercent = commissions[p.field as keyof typeof commissions] ?? 20;
      const commissionAmount = Math.round(gross * (commissionPercent / 100));
      const net = gross - commissionAmount;
      return { platform: p.label, count: matching.length, gross, commissionPercent, commissionAmount, net };
    });
  }, [transactions, commissions]);

  const dineInTakeAwayGross = useMemo(() => {
    return transactions
      .filter((tx) => tx.sales_type === 'Dine In' || tx.sales_type === 'Take Away')
      .reduce((sum, tx) => sum + tx.total, 0);
  }, [transactions]);

  const onlineGrossTotal = onlineRows.reduce((sum, r) => sum + r.gross, 0);
  const onlineNetTotal = onlineRows.reduce((sum, r) => sum + r.net, 0);

  function exportDailyCsv() {
    const header = 'Tanggal,Jumlah Transaksi,Total Penjualan,Cash,Non-Cash\n';
    const rows = dailyRows.map((r) => [r.date, r.count, r.total, r.cash, r.nonCash].join(',')).join('\n');
    const blob = new Blob([header + rows], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'laporan-harian.csv';
    a.click();
    URL.revokeObjectURL(url);
  }

  if (loading) return <p className="text-sm text-ink/50">Loading reports...</p>;

  return (
    <div>
      <div className="flex flex-wrap items-center gap-2 mb-8">
        {(['today', 'week', 'month', 'custom'] as Period[]).map((p) => (
          <button
            key={p}
            onClick={() => setPeriod(p)}
            className={`rounded-full px-4 py-1.5 text-sm font-medium border transition-colors ${
              period === p ? 'bg-navy text-white border-navy' : 'border-grey text-ink/70'
            }`}
          >
            {p === 'today' ? 'Today' : p === 'week' ? '7 Days' : p === 'month' ? '30 Days' : 'Custom'}
          </button>
        ))}
        {period === 'custom' && (
          <>
            <input type="date" value={customFrom} onChange={(e) => setCustomFrom(e.target.value)} className="rounded-lg border border-grey px-3 py-1.5 text-sm" />
            <span className="text-ink/40">to</span>
            <input type="date" value={customTo} onChange={(e) => setCustomTo(e.target.value)} className="rounded-lg border border-grey px-3 py-1.5 text-sm" />
          </>
        )}
      </div>

      <div className="receipt-card mb-8">
        <div className="flex items-center justify-between mb-4">
          <p className="label-eyebrow">Daily Sales Report</p>
          <button onClick={exportDailyCsv} className="text-xs font-medium text-navy border border-navy rounded-full px-3 py-1.5">
            Export CSV
          </button>
        </div>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-grey-light text-left">
              <th className="py-2 font-medium text-ink/60">Date</th>
              <th className="py-2 font-medium text-ink/60">Transactions</th>
              <th className="py-2 font-medium text-ink/60 text-right">Cash</th>
              <th className="py-2 font-medium text-ink/60 text-right">Non-Cash</th>
              <th className="py-2 font-medium text-ink/60 text-right">Total</th>
            </tr>
          </thead>
          <tbody>
            {dailyRows.length === 0 && (
              <tr>
                <td colSpan={5} className="py-6 text-center text-ink/40">No transactions in this period.</td>
              </tr>
            )}
            {dailyRows.map((r) => (
              <tr key={r.date} className="border-b border-grey-light last:border-0">
                <td className="py-2">{r.date}</td>
                <td className="py-2">{r.count}</td>
                <td className="py-2 text-right figure">{formatRupiah(r.cash)}</td>
                <td className="py-2 text-right figure">{formatRupiah(r.nonCash)}</td>
                <td className="py-2 text-right figure font-medium">{formatRupiah(r.total)}</td>
              </tr>
            ))}
          </tbody>
          {dailyRows.length > 0 && (
            <tfoot>
              <tr className="border-t-2 border-navy font-semibold">
                <td className="py-2" colSpan={4}>Total</td>
                <td className="py-2 text-right figure">{formatRupiah(dailyTotal)}</td>
              </tr>
            </tfoot>
          )}
        </table>
      </div>

      <div className="receipt-card">
        <p className="label-eyebrow mb-1">Online Order Report</p>
        <p className="text-xs text-ink/50 mb-4">
          Commission percentages are estimates you set below — adjust to match your actual platform agreements.
        </p>

        <div className="flex flex-wrap gap-4 mb-5 pb-5 border-b border-grey-light">
          {PLATFORMS.map((p) => (
            <div key={p.key} className="flex items-center gap-2">
              <label className="text-xs text-ink/60">{p.label} commission %</label>
              <input
                type="number"
                value={commissions[p.field as keyof typeof commissions]}
                onChange={(e) => setCommissions((c) => ({ ...c, [p.field]: Number(e.target.value) || 0 }))}
                className="w-16 rounded-lg border border-grey px-2 py-1 text-sm text-right"
              />
            </div>
          ))}
          <button
            onClick={saveCommissions}
            disabled={savingCommission}
            className="rounded-full bg-navy text-white px-4 py-1.5 text-xs font-medium disabled:opacity-50"
          >
            {savingCommission ? 'Saving...' : 'Save %'}
          </button>
        </div>

        <table className="w-full text-sm mb-4">
          <thead>
            <tr className="border-b border-grey-light text-left">
              <th className="py-2 font-medium text-ink/60">Platform</th>
              <th className="py-2 font-medium text-ink/60">Orders</th>
              <th className="py-2 font-medium text-ink/60 text-right">Gross Sales</th>
              <th className="py-2 font-medium text-ink/60 text-right">Commission</th>
              <th className="py-2 font-medium text-ink/60 text-right">Net (You Receive)</th>
            </tr>
          </thead>
          <tbody>
            {onlineRows.map((r) => (
              <tr key={r.platform} className="border-b border-grey-light last:border-0">
                <td className="py-2">{r.platform}</td>
                <td className="py-2">{r.count}</td>
                <td className="py-2 text-right figure">{formatRupiah(r.gross)}</td>
                <td className="py-2 text-right figure text-rust">-{formatRupiah(r.commissionAmount)} ({r.commissionPercent}%)</td>
                <td className="py-2 text-right figure font-medium">{formatRupiah(r.net)}</td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr className="border-t-2 border-navy font-semibold">
              <td className="py-2" colSpan={2}>Total Online</td>
              <td className="py-2 text-right figure">{formatRupiah(onlineGrossTotal)}</td>
              <td className="py-2 text-right figure text-rust">-{formatRupiah(onlineGrossTotal - onlineNetTotal)}</td>
              <td className="py-2 text-right figure">{formatRupiah(onlineNetTotal)}</td>
            </tr>
          </tfoot>
        </table>

        <div className="flex items-center justify-between text-sm bg-cream rounded-lg px-4 py-3">
          <span className="text-ink/70">Dine In / Take Away sales (for comparison)</span>
          <span className="figure font-medium">{formatRupiah(dineInTakeAwayGross)}</span>
        </div>
      </div>
    </div>
  );
}
