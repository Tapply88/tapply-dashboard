import { createClient } from '@/lib/supabase/server';
import { getCurrentBusiness } from '@/lib/business';
import { ReceiptStatCard } from '@/components/ReceiptStatCard';

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

export default async function DashboardHomePage() {
  const supabase = createClient();
  const business = await getCurrentBusiness();

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const { data: todaysTx } = await supabase
    .from('transactions')
    .select('total, payment_method, created_at')
    .eq('business_id', business!.id)
    .eq('status', 'paid')
    .gte('created_at', todayStart.toISOString());

  const todaysTotal = (todaysTx ?? []).reduce((sum, t) => sum + (t.total ?? 0), 0);
  const todaysCount = todaysTx?.length ?? 0;

  const byMethod = new Map<string, number>();
  for (const t of todaysTx ?? []) {
    byMethod.set(t.payment_method, (byMethod.get(t.payment_method) ?? 0) + t.total);
  }

  const { data: openShift } = await supabase
    .from('shifts')
    .select('id, cashier_name, start_time, starting_cash')
    .eq('business_id', business!.id)
    .eq('status', 'open')
    .maybeSingle();

  const hasData = todaysCount > 0;

  return (
    <div>
      <p className="label-eyebrow mb-2">Hari ini</p>
      <h1 className="text-2xl font-semibold mb-8">
        {new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long' })}
      </h1>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5 mb-10">
        <ReceiptStatCard label="Total Penjualan" value={formatRupiah(todaysTotal)} sublabel={`${todaysCount} transaksi`} />
        <ReceiptStatCard
          label="Status Shift"
          value={openShift ? 'Aktif' : 'Belum Mulai'}
          sublabel={openShift ? `Kasir: ${openShift.cashier_name || '-'}` : 'Belum ada shift hari ini'}
          accent={openShift ? 'sage' : 'rust'}
        />
        <ReceiptStatCard
          label="Modal Awal Shift"
          value={openShift ? formatRupiah(openShift.starting_cash) : '—'}
        />
      </div>

      <div className="receipt-card max-w-md">
        <p className="label-eyebrow mb-4">Penjualan per Metode Bayar</p>
        {!hasData ? (
          <p className="text-sm text-ink/50">Belum ada transaksi hari ini.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {Array.from(byMethod.entries())
              .sort((a, b) => b[1] - a[1])
              .map(([method, amount]) => (
                <div key={method} className="flex justify-between text-sm">
                  <span className="text-ink/70 capitalize">{method.replace(/_/g, ' ')}</span>
                  <span className="figure font-medium">{formatRupiah(amount)}</span>
                </div>
              ))}
          </div>
        )}
      </div>
    </div>
  );
}
