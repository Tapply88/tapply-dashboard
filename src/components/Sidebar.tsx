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
    { href: '/dashboard/reports', label: t('nav_reports'), icon: '📊' },
    { href: '/dashboard/products', label: t('nav_products'), icon: '☰' },
    { href: '/dashboard/variants', label: t('nav_variants'), icon: '⊕' },
    { href: '/dashboard/ingredients', label: t('nav_ingredients'), icon: '🌿' },
    { href: '/dashboard/tables', label: t('nav_tables'), icon: '🍽' },
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
