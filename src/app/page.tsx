import Link from 'next/link';
import Image from 'next/image';
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

const HIGHLIGHTS = [
  { title: 'Point of Sale', desc: 'Fast checkout, variants, add-ons, promos, and shift management built for busy counters.' },
  { title: 'Cloud Dashboard', desc: 'Manage every outlet, product, and staff member from one place — updates sync automatically.' },
  { title: 'Works Offline', desc: 'Local-first storage keeps the register running even when the internet drops.' },
];

export default function LandingPage() {
  return (
    <>
      <MarketingNav />
      <main>
        <section className="max-w-3xl mx-auto text-center px-6 pt-24 pb-16">
          <Image src="/logo.png" alt="Tapply" width={320} height={104} className="mx-auto mb-8" priority />
          <h1 className="text-3xl md:text-4xl font-semibold text-navy mb-4">
            The point-of-sale system built for real F&amp;B businesses.
          </h1>
          <p className="text-ink/60 mb-10 max-w-xl mx-auto">
            Run your counter, manage every outlet, and see your sales — all in one connected system.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <Link
              href="/signup"
              className="rounded-full bg-navy text-white px-8 py-3 font-medium hover:bg-navy-soft transition-colors"
            >
              Get Started
            </Link>
            <Link
              href="/login"
              className="rounded-full border border-navy text-navy px-8 py-3 font-medium hover:bg-navy-50 transition-colors"
            >
              Log In
            </Link>
          </div>
        </section>

        <section className="max-w-5xl mx-auto px-6 py-16">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {HIGHLIGHTS.map((h) => (
              <div key={h.title} className="receipt-card">
                <p className="label-eyebrow mb-2">{h.title}</p>
                <p className="text-sm text-ink/70">{h.desc}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="max-w-3xl mx-auto text-center px-6 py-16">
          <h2 className="text-2xl font-semibold text-navy mb-3">Ready to see it in action?</h2>
          <p className="text-ink/60 mb-8">Set up your business in a few minutes — no card required to start.</p>
          <Link
            href="/signup"
            className="inline-block rounded-full bg-navy text-white px-8 py-3 font-medium hover:bg-navy-soft transition-colors"
          >
            Create Your Account
          </Link>
        </section>
      </main>
      <MarketingFooter />
    </>
  );
}
