cat > src/app/page.tsx << 'PAGEEOF'
import Link from 'next/link';
import Image from 'next/image';

export default function LandingPage() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-6">
      <div className="max-w-md w-full text-center">
        <Image src="/logo.png" alt="Tapply" width={220} height={72} className="mx-auto mb-3" priority />
        <p className="text-ink/60 mb-10">
          Satu tempat buat pantau semua kedai kamu yang pakai Tapply POS.
        </p>
        <div className="flex flex-col gap-3">
          <Link
            href="/login"
            className="w-full rounded-full bg-navy text-white py-3 font-medium hover:bg-navy-soft transition-colors"
          >
            Masuk
          </Link>
          <Link
            href="/signup"
            className="w-full rounded-full border border-navy text-navy py-3 font-medium hover:bg-navy-50 transition-colors"
          >
            Daftar Bisnis Baru
          </Link>
        </div>
      </div>
    </main>
  );
}
PAGEEOF

cat > src/components/Sidebar.tsx << 'SIDEBAREOF'
'use client';

import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import { useI18n } from '@/lib/i18n';

export function Sidebar() {
  const pathname = usePathname();
  const { t } = useI18n();

  const NAV_ITEMS = [
    { href: '/dashboard', label: t('nav_overview'), icon: '◧' },
    { href: '/dashboard/products', label: t('nav_products'), icon: '☰' },
    { href: '/dashboard/variants', label: t('nav_variants'), icon: '⊕' },
    { href: '/dashboard/staff', label: t('nav_staff'), icon: '☺' },
    { href: '/dashboard/promos', label: t('nav_promos'), icon: '◈' },
    { href: '/dashboard/members', label: t('nav_members'), icon: '◎' },
    { href: '/dashboard/shifts', label: t('nav_shifts'), icon: '◷' },
    { href: '/dashboard/settings', label: t('nav_settings'), icon: '⚙' },
  ];

  return (
    <aside className="w-60 shrink-0 bg-navy text-white flex flex-col min-h-screen">
      <div className="px-6 py-7">
        <Image
          src="/logo.png"
          alt="Tapply"
          width={130}
          height={42}
          style={{ filter: 'brightness(0) invert(1)' }}
          priority
        />
      </div>
      <nav className="flex-1 px-3">
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center justify-between gap-3 px-4 py-2.5 rounded-lg text-sm mb-1 transition-colors ${
                active ? 'bg-white/15 font-medium' : 'text-white/70 hover:bg-white/10'
              }`}
            >
              <span className="flex items-center gap-3">
                <span aria-hidden>{item.icon}</span>
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
      <div className="px-6 py-5 text-xs text-white/40">v0.1 — Tapply Dashboard</div>
    </aside>
  );
}
SIDEBAREOF

echo 'Selesai. Jangan lupa taro logo.png ke folder public/ juga (file terpisah). Restart: npm run dev'
