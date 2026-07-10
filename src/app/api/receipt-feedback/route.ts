import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export async function POST(request: Request) {
  try {
    const { transactionId, sentiment } = await request.json();

    if (!transactionId || (sentiment !== 'positive' && sentiment !== 'negative')) {
      return NextResponse.json({ error: 'Data gak valid' }, { status: 400 });
    }

    const supabase = createAdminClient();

    const { data: tx } = await supabase.from('transactions').select('business_id').eq('id', transactionId).single();
    if (!tx) {
      return NextResponse.json({ error: 'Transaksi gak ditemukan' }, { status: 404 });
    }

    await supabase.from('receipt_feedback').insert({
      transaction_id: transactionId,
      business_id: tx.business_id,
      sentiment,
    });

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: 'Gagal simpan feedback' }, { status: 500 });
  }
}
