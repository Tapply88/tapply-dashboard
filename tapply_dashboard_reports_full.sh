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

echo 'Selesai. Restart: Ctrl+C lalu npm run dev'
