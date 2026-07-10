'use client';

import { useState } from 'react';

export function ReceiptFeedback({ transactionId }: { transactionId: string }) {
  const [sent, setSent] = useState<'positive' | 'negative' | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit(sentiment: 'positive' | 'negative') {
    if (sent || loading) return;
    setLoading(true);
    try {
      await fetch('/api/receipt-feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ transactionId, sentiment }),
      });
      setSent(sentiment);
    } catch {
      // Diam-diam gagal — gak penting banget buat customer, gak perlu ganggu UX.
    } finally {
      setLoading(false);
    }
  }

  if (sent) {
    return (
      <p className="text-center text-sm text-ink/60 py-2">
        Makasih atas masukannya! {sent === 'positive' ? '🙏' : '🙏'}
      </p>
    );
  }

  return (
    <div>
      <p className="text-center text-xs text-ink/50 mb-2">Gimana pengalaman kamu?</p>
      <div className="flex justify-center gap-4">
        <button
          onClick={() => submit('positive')}
          disabled={loading}
          className="text-2xl disabled:opacity-40 hover:scale-110 transition-transform"
          aria-label="Puas"
        >
          👍
        </button>
        <button
          onClick={() => submit('negative')}
          disabled={loading}
          className="text-2xl disabled:opacity-40 hover:scale-110 transition-transform"
          aria-label="Kurang puas"
        >
          👎
        </button>
      </div>
    </div>
  );
}
