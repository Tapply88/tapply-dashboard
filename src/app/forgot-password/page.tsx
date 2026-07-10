'use client';

import { useState } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';

export default function ForgotPasswordPage() {
  const supabase = createClient();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    setLoading(false);
    if (error) {
      setError('Gagal mengirim email reset. Coba lagi.');
      return;
    }
    setSent(true);
  }

  return (
    <main className="min-h-screen flex items-center justify-center px-6">
      <div className="max-w-sm w-full">
        <p className="font-serif text-3xl text-navy mb-1" style={{ fontStyle: 'italic' }}>
          Tapply
        </p>
        <h1 className="text-xl font-semibold mb-2">Lupa Password</h1>

        {sent ? (
          <>
            <p className="text-sm text-ink/60 mb-6">
              Kalau email <span className="font-medium text-ink">{email}</span> terdaftar, link buat reset password
              udah dikirim. Cek inbox (atau folder Spam) kamu.
            </p>
            <Link href="/login" className="text-sm text-navy font-medium">
              ← Kembali ke halaman Masuk
            </Link>
          </>
        ) : (
          <>
            <p className="text-sm text-ink/60 mb-6">
              Masukkan email akun kamu, nanti kami kirim link buat bikin password baru.
            </p>
            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div>
                <label className="label-eyebrow block mb-1.5" htmlFor="email">Email</label>
                <input
                  id="email"
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
                  placeholder="kamu@bisnis.com"
                />
              </div>

              {error && <p className="text-rust text-sm">{error}</p>}

              <button
                type="submit"
                disabled={loading}
                className="w-full rounded-full bg-navy text-white py-3 font-medium hover:bg-navy-soft transition-colors disabled:opacity-50"
              >
                {loading ? 'Mengirim...' : 'Kirim Link Reset'}
              </button>
            </form>

            <p className="text-sm text-ink/60 mt-6 text-center">
              <Link href="/login" className="text-navy font-medium">
                ← Kembali ke halaman Masuk
              </Link>
            </p>
          </>
        )}
      </div>
    </main>
  );
}
