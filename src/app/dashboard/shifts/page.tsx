'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Shift = {
  id: string;
  cashier_name: string | null;
  start_time: string;
  starting_cash: number;
  end_time: string | null;
  ending_cash_counted: number | null;
  status: 'open' | 'closed';
};

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export default function ShiftsPage() {
  const supabase = createClient();
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [loading, setLoading] = useState(true);

  const loadShifts = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase.from('shifts').select('*').order('start_time', { ascending: false });
    setShifts(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadShifts();
  }, [loadShifts]);

  return (
    <div>
      <p className="label-eyebrow mb-2">Operasional</p>
      <h1 className="text-2xl font-semibold mb-8">Shift</h1>

      <div className="receipt-card max-w-lg mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          Halaman ini nampilin shift yang di-sync dari app kasir. Kalau masih kosong padahal
          kamu udah mulai/akhirin shift di app, itu wajar — sinkronisasi shift belum
          disambungin di versi ini (baru transaksi yang otomatis ke-kirim).
        </p>
      </div>

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : shifts.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">Belum ada data shift.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0 max-w-3xl">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Kasir</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Mulai</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Modal Awal</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Cash Dihitung</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {shifts.map((s) => (
                <tr key={s.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{s.cashier_name || '-'}</td>
                  <td className="px-5 py-3 text-ink/60">{formatDate(s.start_time)}</td>
                  <td className="px-5 py-3 figure">{formatRupiah(s.starting_cash)}</td>
                  <td className="px-5 py-3 figure">{s.ending_cash_counted != null ? formatRupiah(s.ending_cash_counted) : '—'}</td>
                  <td className="px-5 py-3">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${
                      s.status === 'open' ? 'bg-sage-light text-sage' : 'bg-grey-light text-ink/60'
                    }`}>
                      {s.status === 'open' ? 'Aktif' : 'Selesai'}
                    </span>
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
