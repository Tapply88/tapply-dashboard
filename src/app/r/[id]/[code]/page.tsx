import { createAdminClient } from '@/lib/supabase/admin';
import { ReceiptFeedback } from './ReceiptFeedback';

export const dynamic = 'force-dynamic';

type TxItem = {
  productId: string;
  productName: string;
  price: number;
  qty: number;
  note?: string | null;
};

function formatRupiah(n: number) {
  return 'Rp' + Math.round(n).toLocaleString('id-ID');
}

function paymentLabel(code: string) {
  const map: Record<string, string> = {
    cash: 'Tunai',
    qris_manual: 'QRIS',
    qris_midtrans: 'QRIS / E-Wallet',
    edc_BCA: 'EDC BCA',
    edc_Mandiri: 'EDC Mandiri',
    edc_BNI: 'EDC BNI',
    gofood: 'GoFood',
    grabfood: 'GrabFood',
    shopeefood: 'ShopeeFood',
    bank_transfer: 'Transfer Bank',
  };
  return map[code] ?? code;
}

export default async function ReceiptPage({ params }: { params: { id: string; code: string } }) {
  const supabase = createAdminClient();

  const { data: tx } = await supabase
    .from('transactions')
    .select('*')
    .eq('id', params.id)
    .eq('receipt_number', params.code)
    .single();

  if (!tx) {
    return (
      <main className="min-h-screen flex items-center justify-center px-6 bg-cream">
        <div className="text-center">
          <p className="font-serif text-3xl text-navy mb-3" style={{ fontStyle: 'italic' }}>
            Tapply
          </p>
          <p className="text-ink/60">Struk tidak ditemukan.</p>
        </div>
      </main>
    );
  }

  const { data: business } = await supabase.from('businesses').select('*').eq('id', tx.business_id).single();

  const items: TxItem[] = tx.items ?? [];
  const businessName = business?.name ?? 'Tapply';
  const isVoided = tx.status === 'void';

  return (
    <main className="min-h-screen bg-cream px-4 py-10 flex justify-center">
      <div className="max-w-sm w-full">
        <div className="receipt-card">
          <div className="text-center mb-4">
            {business?.logo_base64 && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={`data:image/png;base64,${business.logo_base64}`}
                alt={businessName}
                className="h-14 mx-auto mb-2 object-contain"
              />
            )}
            <p className="font-semibold text-lg text-ink">{businessName}</p>
            {business?.address && <p className="text-xs text-ink/50 mt-1">{business.address}</p>}
            {business?.phone && <p className="text-xs text-ink/50">{business.phone}</p>}
          </div>

          {isVoided && (
            <div className="text-center mb-3">
              <span className="inline-block bg-rust/10 text-rust text-xs font-semibold px-3 py-1 rounded-full">
                DIBATALKAN
              </span>
            </div>
          )}

          <div className="border-t border-grey-light my-3" />

          <div className="text-xs text-ink/60 flex flex-col gap-0.5 mb-3">
            {tx.receipt_number && <p>No. Struk: {tx.receipt_number}</p>}
            <p>
              {new Date(tx.created_at).toLocaleString('id-ID', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
              })}
            </p>
            <p>{tx.sales_type}</p>
            {tx.guest_name && <p>Customer: {tx.guest_name}</p>}
            {tx.cashier_name && <p>Dilayani oleh: {tx.cashier_name}</p>}
          </div>

          <div className="border-t border-grey-light my-3" />

          <div className="flex flex-col gap-2 mb-3">
            {items.map((item, i) => (
              <div key={i} className="flex justify-between text-sm gap-3">
                <div className="flex-1">
                  <p className="text-ink">
                    {item.productName} × {item.qty}
                  </p>
                  {item.note && <p className="text-xs text-ink/50">{item.note}</p>}
                </div>
                <p className="text-ink shrink-0">{formatRupiah(item.price * item.qty)}</p>
              </div>
            ))}
          </div>

          <div className="border-t border-grey-light my-3" />

          <div className="flex flex-col gap-1 text-sm mb-2">
            <div className="flex justify-between text-ink/70">
              <span>Sub-Total</span>
              <span>{formatRupiah(tx.total - tx.tax_amount - tx.service_amount + tx.discount_amount - tx.rounding_adjustment)}</span>
            </div>
            {tx.tax_amount !== 0 && (
              <div className="flex justify-between text-ink/70">
                <span>Pajak</span>
                <span>{formatRupiah(tx.tax_amount)}</span>
              </div>
            )}
            {tx.service_amount !== 0 && (
              <div className="flex justify-between text-ink/70">
                <span>Service</span>
                <span>{formatRupiah(tx.service_amount)}</span>
              </div>
            )}
            {tx.discount_amount > 0 && (
              <div className="flex justify-between text-ink/70">
                <span>Diskon{tx.discount_label ? ` (${tx.discount_label})` : ''}</span>
                <span>-{formatRupiah(tx.discount_amount)}</span>
              </div>
            )}
            {tx.rounding_adjustment !== 0 && (
              <div className="flex justify-between text-ink/70">
                <span>Pembulatan</span>
                <span>{formatRupiah(tx.rounding_adjustment)}</span>
              </div>
            )}
          </div>

          <div className="border-t border-grey-light my-3" />

          <div className="flex justify-between font-semibold text-base mb-1">
            <span>Total</span>
            <span>{formatRupiah(tx.total)}</span>
          </div>
          <div className="flex justify-between text-xs text-ink/50">
            <span>Pembayaran</span>
            <span>{paymentLabel(tx.payment_method)}</span>
          </div>

          <div className="border-t border-grey-light my-4" />

          <ReceiptFeedback transactionId={tx.id} />
        </div>

        <p className="text-center text-xs text-ink/30 mt-4">
          powered by <span className="italic">Tapply</span>
        </p>
      </div>
    </main>
  );
}
