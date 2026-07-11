'use client';

import { useEffect, useState, useCallback, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { isProActive, planLabel, daysRemaining, type PlanInfo } from '@/lib/plan';

function formatRupiah(n: number) {
  return 'Rp ' + n.toLocaleString('id-ID');
}

const PRICES = {
  starter: { monthly: 58000, yearly: 580000 },
  pro: { monthly: 169000, yearly: 1690000 },
};

function BillingPageContent() {
  const supabase = createClient();
  const searchParams = useSearchParams();
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedPlan, setSelectedPlan] = useState<'starter' | 'pro'>('pro');
  const [selectedPeriod, setSelectedPeriod] = useState<'monthly' | 'yearly'>('monthly');
  const [paying, setPaying] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) {
        const { data: business } = await supabase.from('businesses').select('plan, plan_expires_at').eq('id', link.business_id).single();
        if (business) setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
      }
    }
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function handlePay() {
    setPaying(true);
    setError(null);
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session) {
        setError('Sesi login gak ketemu, coba refresh halaman.');
        setPaying(false);
        return;
      }

      const res = await fetch('https://tapply-production.up.railway.app/billing/create-payment', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ plan: selectedPlan, period: selectedPeriod }),
      });
      const data = await res.json();

      if (!res.ok) {
        setError(data.error || 'Gagal membuat pembayaran. Coba lagi nanti.');
        setPaying(false);
        return;
      }

      window.location.href = data.paymentUrl;
    } catch {
      setError('Terjadi kesalahan. Coba lagi nanti.');
      setPaying(false);
    }
  }

  const status = searchParams.get('status');

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  const active = isProActive(planInfo);
  const remaining = planInfo ? daysRemaining(planInfo.plan_expires_at) : null;

  return (
    <div className="max-w-2xl">
      <p className="label-eyebrow mb-2">Account</p>
      <h1 className="text-2xl font-semibold mb-8">Billing</h1>

      {status === 'success' && (
        <div className="receipt-card mb-6 border-sage border">
          <p className="text-sm text-sage font-medium">
            Pembayaran sedang diproses. Plan kamu akan aktif otomatis begitu pembayaran dikonfirmasi (biasanya
            beberapa menit).
          </p>
        </div>
      )}
      {status === 'cancel' && (
        <div className="receipt-card mb-6 border-rust border">
          <p className="text-sm text-rust font-medium">Pembayaran dibatalkan. Silakan coba lagi kapan saja.</p>
        </div>
      )}

      <div className="receipt-card mb-6">
        <p className="label-eyebrow mb-1">Plan Saat Ini</p>
        <p className="text-xl font-semibold text-navy mb-1">{planInfo ? planLabel(planInfo) : 'Unknown'}</p>
        {planInfo?.plan_expires_at && remaining !== null && (
          <p className="text-xs text-ink/50">
            {active ? `Berakhir dalam ${remaining} hari` : 'Sudah tidak aktif'}
          </p>
        )}
      </div>

      <div className="receipt-card">
        <p className="label-eyebrow mb-4">Upgrade / Perpanjang</p>

        <div className="flex gap-2 mb-4">
          {(['starter', 'pro'] as const).map((p) => (
            <button
              key={p}
              onClick={() => setSelectedPlan(p)}
              className={`flex-1 rounded-lg border px-4 py-3 text-sm font-medium capitalize transition-colors ${
                selectedPlan === p ? 'border-navy bg-navy text-white' : 'border-grey text-navy'
              }`}
            >
              {p}
            </button>
          ))}
        </div>

        <div className="flex gap-2 mb-6">
          {(['monthly', 'yearly'] as const).map((p) => (
            <button
              key={p}
              onClick={() => setSelectedPeriod(p)}
              className={`flex-1 rounded-lg border px-4 py-3 text-sm font-medium capitalize transition-colors ${
                selectedPeriod === p ? 'border-navy bg-navy text-white' : 'border-grey text-navy'
              }`}
            >
              {p === 'yearly' ? 'Yearly (2 bulan gratis)' : 'Monthly'}
            </button>
          ))}
        </div>

        <div className="flex items-center justify-between mb-6 pb-4 border-b border-grey-light">
          <span className="text-sm text-ink/60">Total</span>
          <span className="text-xl font-semibold text-navy">{formatRupiah(PRICES[selectedPlan][selectedPeriod])}</span>
        </div>

        {error && <p className="text-rust text-sm mb-4">{error}</p>}

        <button
          onClick={handlePay}
          disabled={paying}
          className="w-full rounded-full bg-navy text-white py-3 font-medium hover:bg-navy-soft transition-colors disabled:opacity-50"
        >
          {paying ? 'Menyiapkan pembayaran...' : 'Bayar Sekarang'}
        </button>
        <p className="text-xs text-ink/40 mt-3 text-center">
          Kamu akan diarahkan ke halaman pembayaran DOKU (QRIS, Virtual Account, kartu, dll).
        </p>
      </div>
    </div>
  );
}

export default function BillingPage() {
  return (
    <Suspense fallback={<p className="text-sm text-ink/50">Loading...</p>}>
      <BillingPageContent />
    </Suspense>
  );
}
