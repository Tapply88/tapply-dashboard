cat > src/app/onboarding/page.tsx << 'ONBOARDEOF'
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export default function OnboardingPage() {
  const router = useRouter();
  const supabase = createClient();
  const [name, setName] = useState('');
  const [address, setAddress] = useState('');
  const [phone, setPhone] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      setError('Sesi kamu habis, coba masuk lagi.');
      setLoading(false);
      return;
    }

    const businessId = crypto.randomUUID();

    const { error: businessError } = await supabase
      .from('businesses')
      .insert({ id: businessId, name, address, phone });

    if (businessError) {
      setError('Gagal bikin profil bisnis. Coba lagi.');
      setLoading(false);
      return;
    }

    const { error: linkError } = await supabase
      .from('business_users')
      .insert({ business_id: businessId, user_id: user.id, role: 'owner' });

    setLoading(false);

    if (linkError) {
      setError('Gagal ngaitin akun ke bisnis. Coba lagi.');
      return;
    }

    router.push('/dashboard');
    router.refresh();
  }

  return (
    <main className="min-h-screen flex items-center justify-center px-6">
      <div className="max-w-md w-full">
        <p className="label-eyebrow mb-2">Langkah terakhir</p>
        <h1 className="text-2xl font-semibold mb-1">Ceritain tentang bisnis kamu</h1>
        <p className="text-sm text-ink/60 mb-8">
          Ini yang bakal muncul di struk dan laporan. Bisa diubah kapan aja nanti di Setelan.
        </p>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div>
            <label className="label-eyebrow block mb-1.5" htmlFor="name">Nama Bisnis</label>
            <input
              id="name"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              placeholder="Jamu Mbak Suni"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5" htmlFor="address">Alamat</label>
            <textarea
              id="address"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              rows={2}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none resize-none"
              placeholder="Jl. Kenanga No. 12, BSD City"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5" htmlFor="phone">No. Telepon</label>
            <input
              id="phone"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              placeholder="0812-3456-7890"
            />
          </div>

          {error && <p className="text-rust text-sm">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-full bg-navy text-white py-3 font-medium hover:bg-navy-soft transition-colors disabled:opacity-50 mt-2"
          >
            {loading ? 'Menyiapkan...' : 'Masuk ke Dashboard'}
          </button>
        </form>
      </div>
    </main>
  );
}
ONBOARDEOF

echo 'Selesai. Restart server: Ctrl+C lalu npm run dev'
