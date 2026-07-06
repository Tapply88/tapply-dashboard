mkdir -p src/app/about src/app/products src/app/pricing src/app/faq src/app/contact src/app/privacy src/app/terms

cat > src/components/MarketingNav.tsx << 'NAVEOF'
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
NAVEOF

cat > src/components/MarketingFooter.tsx << 'FOOTEOF'
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
FOOTEOF

cat > src/app/page.tsx << 'PAGEEOF'
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
PAGEEOF

cat > src/app/about/page.tsx << 'ABOUTEOF'
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

export default function AboutPage() {
  return (
    <>
      <MarketingNav />
      <main className="max-w-3xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">About Us</p>
        <h1 className="text-3xl font-semibold text-navy mb-8">Built by people who run these businesses too.</h1>

        <div className="flex flex-col gap-6 text-ink/70 leading-relaxed">
          <p>
            Tapply started with a simple frustration: most point-of-sale systems are built for big
            retail chains, not for the independent F&amp;B businesses that actually make up most of
            the market — jamu kiosks, cafes, and small food stalls that need something fast, reliable,
            and genuinely easy to hand to a cashier on day one.
          </p>
          <p>
            We built Tapply from real, everyday operations — the kind of details you only learn by
            standing behind a counter. Things like what happens when the internet drops mid-transaction,
            how a shift actually gets closed out at the end of the night, and why a cashier shouldn&apos;t
            need a manual to ring up an order.
          </p>
          <p>
            Today, Tapply is a point-of-sale app paired with a cloud dashboard, so business owners can
            manage products, pricing, staff, and reports from anywhere, while the register keeps working
            even when the connection doesn&apos;t.
          </p>
        </div>

        <div className="receipt-card mt-12">
          <p className="label-eyebrow mb-2">Our Approach</p>
          <ul className="text-sm text-ink/70 flex flex-col gap-2 mt-3">
            <li>• Built offline-first, because a register that stops working when the wifi does isn&apos;t acceptable.</li>
            <li>• Designed for the counter first, not the back office — the cashier experience comes first.</li>
            <li>• Owner control lives in one dashboard, so pricing and policy changes are never stuck on a single device.</li>
          </ul>
        </div>
      </main>
      <MarketingFooter />
    </>
  );
}
ABOUTEOF

cat > src/app/products/page.tsx << 'PRODEOF'
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

const POS_FEATURES = [
  'Fast checkout with categories, variants, and add-ons',
  'Custom items for one-off charges not in your menu',
  'Member lookup and loyalty points',
  'Promos: storewide, per-product, or opt-in per item',
  'Shift management with starting cash and settlement',
  'Save Bill for dine-in tabs you come back to later',
  'QR & barcode label printing with SKU and expiry dates',
  'Manager PIN protection for canceling items or voiding receipts',
  'Works fully offline — syncs automatically when back online',
];

const DASHBOARD_FEATURES = [
  'Sales reports with daily trends and period comparisons',
  'Product, variant, and add-on management across every device',
  'Staff list with cashier and supervisor roles',
  'Business settings (tax, service, rounding) applied everywhere at once',
  'Member and promo management from anywhere',
  'CSV import for bulk menu setup, and CSV export for your records',
  'One sync code connects each register device to your account',
];

export default function ProductsPage() {
  return (
    <>
      <MarketingNav />
      <main className="max-w-4xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">Products</p>
        <h1 className="text-3xl font-semibold text-navy mb-4">Two products, one connected system.</h1>
        <p className="text-ink/60 mb-12 max-w-xl">
          Tapply POS runs on the counter. Tapply Dashboard runs your business. They stay in sync automatically.
        </p>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="receipt-card">
            <p className="label-eyebrow mb-2">Tapply POS</p>
            <h2 className="text-xl font-semibold text-navy mb-4">For the counter</h2>
            <ul className="text-sm text-ink/70 flex flex-col gap-2.5">
              {POS_FEATURES.map((f) => (
                <li key={f} className="flex gap-2">
                  <span className="text-sage">✓</span>
                  <span>{f}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="receipt-card">
            <p className="label-eyebrow mb-2">Tapply Dashboard</p>
            <h2 className="text-xl font-semibold text-navy mb-4">For the owner</h2>
            <ul className="text-sm text-ink/70 flex flex-col gap-2.5">
              {DASHBOARD_FEATURES.map((f) => (
                <li key={f} className="flex gap-2">
                  <span className="text-sage">✓</span>
                  <span>{f}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </main>
      <MarketingFooter />
    </>
  );
}
PRODEOF

cat > src/app/pricing/page.tsx << 'PRICEEOF'
import Link from 'next/link';
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

const TIERS = [
  {
    name: 'Starter',
    price: 'Rp 0',
    period: '/month',
    desc: 'For a single outlet just getting started.',
    features: ['1 register device', '1 staff account', 'Core POS features', 'Basic sales reports'],
    cta: 'Get Started',
    href: '/signup',
  },
  {
    name: 'Pro',
    price: 'Rp XXX,XXX',
    period: '/month',
    desc: 'For a growing business with more than one cashier.',
    features: ['Up to 3 register devices', 'Unlimited staff accounts', 'Label printing & CSV import/export', 'Full reporting & CSV export'],
    cta: 'Get Started',
    href: '/signup',
    highlighted: true,
  },
  {
    name: 'Multi-Outlet',
    price: 'Custom',
    period: '',
    desc: 'For businesses running several locations.',
    features: ['Unlimited register devices', 'Multiple outlets under one account', 'Priority support', 'Custom onboarding'],
    cta: 'Contact Us',
    href: '/contact',
  },
];

export default function PricingPage() {
  return (
    <>
      <MarketingNav />
      <main className="max-w-5xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">Pricing</p>
        <h1 className="text-3xl font-semibold text-navy mb-4">Simple pricing that grows with you.</h1>
        <p className="text-ink/60 mb-12 max-w-xl">No hidden fees. Cancel anytime.</p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {TIERS.map((tier) => (
            <div
              key={tier.name}
              className={`receipt-card flex flex-col ${tier.highlighted ? 'border-navy border-2' : ''}`}
            >
              {tier.highlighted && (
                <span className="self-start bg-navy text-white text-[10px] uppercase tracking-wide px-2.5 py-1 rounded-full mb-3">
                  Most Popular
                </span>
              )}
              <p className="label-eyebrow mb-1">{tier.name}</p>
              <p className="text-2xl font-semibold text-navy mb-1">
                {tier.price}
                <span className="text-sm font-normal text-ink/50">{tier.period}</span>
              </p>
              <p className="text-xs text-ink/50 mb-5">{tier.desc}</p>
              <ul className="text-sm text-ink/70 flex flex-col gap-2 mb-6 flex-1">
                {tier.features.map((f) => (
                  <li key={f} className="flex gap-2">
                    <span className="text-sage">✓</span>
                    <span>{f}</span>
                  </li>
                ))}
              </ul>
              <Link
                href={tier.href}
                className={`text-center rounded-full py-2.5 text-sm font-medium transition-colors ${
                  tier.highlighted ? 'bg-navy text-white hover:bg-navy-soft' : 'border border-navy text-navy hover:bg-navy-50'
                }`}
              >
                {tier.cta}
              </Link>
            </div>
          ))}
        </div>

        <p className="text-xs text-ink/40 mt-8 text-center">
          Pricing shown here is a placeholder — update it in <code>src/app/pricing/page.tsx</code> once your plans are finalized.
        </p>
      </main>
      <MarketingFooter />
    </>
  );
}
PRICEEOF

cat > src/app/faq/page.tsx << 'FAQEOF'
'use client';

import { useState } from 'react';
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

const FAQS = [
  {
    q: 'Does Tapply work without internet?',
    a: 'Yes. The POS app stores everything locally on the device first, so checkout keeps working even if the connection drops. Once you\'re back online, transactions sync to your dashboard automatically.',
  },
  {
    q: 'What devices can I use it on?',
    a: 'Tapply POS runs on Android tablets and phones. The Dashboard is a website, so you can check it from any computer or phone browser.',
  },
  {
    q: 'Can I use it for more than one outlet?',
    a: 'Yes. Each register device connects to your account with a sync code from the dashboard, so you can run multiple registers — and eventually multiple outlets — under one account.',
  },
  {
    q: 'Who can change prices and settings?',
    a: 'Business settings, pricing, and product details are managed from the web dashboard by the business owner. Cashiers using the POS app can\'t change these, so pricing always stays consistent across every device.',
  },
  {
    q: 'Is my data safe?',
    a: 'Your data is stored in a secured cloud database, with each business\'s data kept completely separate from every other business on Tapply.',
  },
  {
    q: 'How do I get started?',
    a: 'Create an account on the Dashboard, set up your business profile and products, then connect your first register device using the sync code from Settings.',
  },
];

export default function FaqPage() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <>
      <MarketingNav />
      <main className="max-w-2xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">FAQ</p>
        <h1 className="text-3xl font-semibold text-navy mb-10">Frequently Asked Questions</h1>

        <div className="flex flex-col gap-3">
          {FAQS.map((item, i) => (
            <div key={item.q} className="receipt-card !py-0 overflow-hidden">
              <button
                onClick={() => setOpenIndex(openIndex === i ? null : i)}
                className="w-full text-left py-5 flex items-center justify-between gap-4"
              >
                <span className="font-medium text-navy text-sm">{item.q}</span>
                <span className="text-navy text-lg shrink-0">{openIndex === i ? '−' : '+'}</span>
              </button>
              {openIndex === i && <p className="text-sm text-ink/60 pb-5 leading-relaxed">{item.a}</p>}
            </div>
          ))}
        </div>
      </main>
      <MarketingFooter />
    </>
  );
}
FAQEOF

cat > src/app/contact/page.tsx << 'CONTACTEOF'
'use client';

import { useState } from 'react';
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

const CONTACT_EMAIL = 'hello@tapply.example.com';

export default function ContactPage() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const subject = encodeURIComponent(`Message from ${name || 'Tapply website'}`);
    const body = encodeURIComponent(`${message}\n\n— ${name} (${email})`);
    window.location.href = `mailto:${CONTACT_EMAIL}?subject=${subject}&body=${body}`;
  }

  return (
    <>
      <MarketingNav />
      <main className="max-w-lg mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">Contact Us</p>
        <h1 className="text-3xl font-semibold text-navy mb-4">Let&apos;s talk.</h1>
        <p className="text-ink/60 mb-10">
          Questions about pricing, setup, or anything else — reach out and we&apos;ll get back to you.
        </p>

        <div className="receipt-card mb-8">
          <p className="text-sm text-ink/70">
            Email us directly at{' '}
            <a href={`mailto:${CONTACT_EMAIL}`} className="text-navy font-medium underline">
              {CONTACT_EMAIL}
            </a>
            , or use the form below.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="receipt-card flex flex-col gap-4">
          <input
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Your name"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <input
            required
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Your email"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <textarea
            required
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="How can we help?"
            rows={5}
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none resize-none"
          />
          <button type="submit" className="rounded-full bg-navy text-white py-3 font-medium hover:bg-navy-soft transition-colors">
            Send Message
          </button>
        </form>
      </main>
      <MarketingFooter />
    </>
  );
}
CONTACTEOF

cat > src/app/privacy/page.tsx << 'PRIVEOF'
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

export default function PrivacyPage() {
  return (
    <>
      <MarketingNav />
      <main className="max-w-2xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">Legal</p>
        <h1 className="text-3xl font-semibold text-navy mb-4">Privacy Policy</h1>
        <p className="text-xs text-ink/40 mb-10">Last updated: [date]</p>

        <div className="receipt-card mb-8 !bg-rust-light !border-rust/30">
          <p className="text-sm text-rust">
            This is a generic placeholder template, not legal advice. Have a qualified lawyer review
            and customize this before publishing it on a live product.
          </p>
        </div>

        <div className="flex flex-col gap-6 text-sm text-ink/70 leading-relaxed">
          <section>
            <h2 className="font-semibold text-navy mb-2">1. Information We Collect</h2>
            <p>
              We collect information you provide directly, such as your business name, contact details,
              and account information, as well as data generated through your use of Tapply, including
              product, transaction, and staff records you enter into the app or dashboard.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">2. How We Use Information</h2>
            <p>
              We use collected information to operate and improve Tapply, provide customer support,
              and communicate with you about your account and service updates.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">3. Data Storage &amp; Security</h2>
            <p>
              Your data is stored in a secured cloud database, with row-level access controls that
              keep each business&apos;s data separate from every other business using Tapply.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">4. Data Sharing</h2>
            <p>
              We do not sell your data. We may share information with service providers who help us
              operate Tapply (such as our cloud hosting and database providers), under agreements that
              require them to protect your data.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">5. Your Choices</h2>
            <p>
              You can access, update, or delete your business data through the dashboard, or by
              contacting us directly.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">6. Contact</h2>
            <p>Questions about this policy? Reach out via our Contact Us page.</p>
          </section>
        </div>
      </main>
      <MarketingFooter />
    </>
  );
}
PRIVEOF

cat > src/app/terms/page.tsx << 'TERMSEOF'
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

export default function TermsPage() {
  return (
    <>
      <MarketingNav />
      <main className="max-w-2xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">Legal</p>
        <h1 className="text-3xl font-semibold text-navy mb-4">Terms of Service</h1>
        <p className="text-xs text-ink/40 mb-10">Last updated: [date]</p>

        <div className="receipt-card mb-8 !bg-rust-light !border-rust/30">
          <p className="text-sm text-rust">
            This is a generic placeholder template, not legal advice. Have a qualified lawyer review
            and customize this before publishing it on a live product.
          </p>
        </div>

        <div className="flex flex-col gap-6 text-sm text-ink/70 leading-relaxed">
          <section>
            <h2 className="font-semibold text-navy mb-2">1. Using Tapply</h2>
            <p>
              By creating an account, you agree to use Tapply for legitimate business purposes and to
              keep your login credentials and sync codes confidential.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">2. Your Data</h2>
            <p>
              You retain ownership of the business data you enter into Tapply. We store and process
              it solely to provide the service to you.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">3. Availability</h2>
            <p>
              We aim to keep Tapply available and reliable, but we don&apos;t guarantee uninterrupted
              service. The POS app is designed to keep working offline for core functions even during
              connectivity issues.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">4. Payment &amp; Billing</h2>
            <p>
              Paid plans are billed according to the plan you select. Details will be provided at
              checkout or in your dashboard billing settings.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">5. Termination</h2>
            <p>
              You may cancel your account at any time. We may suspend accounts that violate these
              terms or misuse the service.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">6. Limitation of Liability</h2>
            <p>
              Tapply is provided &quot;as is&quot;. We are not liable for indirect or consequential
              damages arising from use of the service, to the extent permitted by law.
            </p>
          </section>
          <section>
            <h2 className="font-semibold text-navy mb-2">7. Changes</h2>
            <p>We may update these terms from time to time. Continued use of Tapply means you accept the updated terms.</p>
          </section>
        </div>
      </main>
      <MarketingFooter />
    </>
  );
}
TERMSEOF

echo 'Selesai. Restart: npm run dev'
