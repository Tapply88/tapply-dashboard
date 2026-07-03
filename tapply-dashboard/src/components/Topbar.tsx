'use client';

import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export function Topbar({ businessName }: { businessName: string }) {
  const router = useRouter();
  const supabase = createClient();

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  return (
    <header className="h-16 flex items-center justify-between px-8 border-b border-grey-light bg-paper">
      <p className="font-medium text-ink">{businessName}</p>
      <button
        onClick={handleSignOut}
        className="text-sm text-ink/60 hover:text-navy transition-colors"
      >
        Keluar
      </button>
    </header>
  );
}
