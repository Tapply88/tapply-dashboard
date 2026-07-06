import Link from 'next/link';
import Image from 'next/image';

export function MarketingFooter() {
  return (
    <footer className="border-t border-grey-light mt-24">
      <div className="max-w-5xl mx-auto px-6 py-10 flex flex-col md:flex-row items-center justify-between gap-6">
        <Image src="/logo.png" alt="Tapply" width={90} height={30} />
        <nav className="flex flex-wrap justify-center gap-5 text-sm text-ink/60">
          <Link href="/about" className="hover:text-navy">About Us</Link>
          <Link href="/products" className="hover:text-navy">Products</Link>
          <Link href="/pricing" className="hover:text-navy">Pricing</Link>
          <Link href="/faq" className="hover:text-navy">FAQ</Link>
          <Link href="/contact" className="hover:text-navy">Contact Us</Link>
          <Link href="/privacy" className="hover:text-navy">Privacy Policy</Link>
          <Link href="/terms" className="hover:text-navy">Terms of Service</Link>
        </nav>
      </div>
      <p className="text-center text-xs text-ink/40 pb-6">© {new Date().getFullYear()} Tapply. All rights reserved.</p>
    </footer>
  );
}
