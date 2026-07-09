'use client';

import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';

const LINKS = [
  { href: '/about', label: 'About Us' },
  { href: '/products', label: 'Products' },
  { href: '/pricing', label: 'Pricing' },
  { href: '/faq', label: 'FAQ' },
  { href: '/contact', label: 'Contact Us' },
];

export function MarketingNav() {
  const pathname = usePathname();

  return (
    <header className="border-b border-grey-light bg-paper sticky top-0 z-10">
      <div className="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
        <Link href="/">
          <Image src="/logo.png" alt="Tapply" width={110} height={36} priority />
        </Link>
        <nav className="hidden md:flex items-center gap-6">
          {LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={`text-sm font-medium transition-colors ${
                pathname === l.href ? 'text-navy' : 'text-ink/60 hover:text-navy'
              }`}
            >
              {l.label}
            </Link>
          ))}
        </nav>
        <Link
          href="/login"
          className="rounded-full bg-navy text-white px-5 py-2 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          Dashboard
        </Link>
      </div>
    </header>
  );
}
