'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) {
      setError('Email atau password salah. Coba lagi.');
      return;
    }
    router.push('/dashboard');
    router.refresh();
  }

  return (
    <main className="min-h-screen flex items-center justify-center px-6">
      <div className="max-w-sm w-full">
        <p className="font-serif text-3xl text-navy mb-1" style={{ fontStyle: 'italic' }}>
          Tapply
        </p>
        <h1 className="text-xl font-semibold mb-6">Masuk ke akun kamu</h1>

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
          <div>
            <label className="label-eyebrow block mb-1.5" htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              placeholder="••••••••"
            />
          </div>

          {error && <p className="text-rust text-sm">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-full bg-navy text-white py-3 font-medium hover:bg-navy-soft transition-colors disabled:opacity-50"
          >
            {loading ? 'Masuk...' : 'Masuk'}
          </button>
        </form>

        <p className="text-sm text-ink/60 mt-6 text-center">
          Belum punya akun?{' '}
          <Link href="/signup" className="text-navy font-medium">
            Daftar bisnis baru
          </Link>
        </p>
      </div>
    </main>
  );
}
