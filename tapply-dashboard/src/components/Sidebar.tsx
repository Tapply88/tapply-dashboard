'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV_ITEMS = [
  { href: '/dashboard', label: 'Ringkasan', icon: '◧' },
  { href: '/dashboard/products', label: 'Produk', icon: '☰' },
  { href: '/dashboard/promos', label: 'Promo', icon: '◈', comingSoon: true },
  { href: '/dashboard/members', label: 'Member', icon: '◎', comingSoon: true },
  { href: '/dashboard/shifts', label: 'Shift', icon: '◷', comingSoon: true },
  { href: '/dashboard/settings', label: 'Setelan', icon: '⚙' },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-60 shrink-0 bg-navy text-white flex flex-col min-h-screen">
      <div className="px-6 py-7">
        <p className="font-serif text-2xl" style={{ fontStyle: 'italic' }}>
          Tapply
        </p>
      </div>
      <nav className="flex-1 px-3">
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.comingSoon ? '#' : item.href}
              aria-disabled={item.comingSoon}
              className={`flex items-center justify-between gap-3 px-4 py-2.5 rounded-lg text-sm mb-1 transition-colors ${
                active ? 'bg-white/15 font-medium' : 'text-white/70 hover:bg-white/10'
              } ${item.comingSoon ? 'cursor-default' : ''}`}
            >
              <span className="flex items-center gap-3">
                <span aria-hidden>{item.icon}</span>
                {item.label}
              </span>
              {item.comingSoon && (
                <span className="text-[10px] uppercase tracking-wide text-white/40">Segera</span>
              )}
            </Link>
          );
        })}
      </nav>
      <div className="px-6 py-5 text-xs text-white/40">v0.1 — Tapply Dashboard</div>
    </aside>
  );
}
