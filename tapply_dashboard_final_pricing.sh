cat > src/app/pricing/page.tsx << 'PRICEEOF'
import Link from 'next/link';
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

const TIERS = [
  {
    name: 'Starter',
    price: 'Rp 39,000',
    period: '/month',
    desc: 'For a single outlet running day-to-day operations.',
    features: [
      '1 register device',
      '1 staff account',
      'Core POS features',
      'Basic stock tracking & low stock alerts',
      'Basic sales reports (today\'s sales)',
    ],
    cta: 'Get Started',
    href: '/signup',
  },
  {
    name: 'Pro',
    price: 'Rp 159,000',
    period: '/month',
    desc: 'For a growing business with more than one cashier.',
    features: [
      'Up to 3 register devices',
      'Unlimited staff accounts',
      'Full reporting: trends, period comparison & CSV export',
      'Member accounts & loyalty points',
      'Label printing & CSV menu import',
    ],
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
          Need something different? <a href="/contact" className="text-navy underline">Get in touch</a> and we&apos;ll work it out.
        </p>
      </main>
      <MarketingFooter />
    </>
  );
}
PRICEEOF

echo 'Selesai. Restart: npm run dev'
