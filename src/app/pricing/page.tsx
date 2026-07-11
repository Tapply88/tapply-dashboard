'use client';

import { useState } from 'react';
import Link from 'next/link';
import { MarketingNav } from '@/components/MarketingNav';
import { MarketingFooter } from '@/components/MarketingFooter';

function formatRupiah(n: number) {
  return 'Rp ' + n.toLocaleString('id-ID');
}

const TIERS = [
  {
    name: 'Starter',
    monthly: 58000,
    yearly: 580000,
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
    monthly: 169000,
    yearly: 1690000,
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
    monthly: null,
    yearly: null,
    desc: 'For businesses running several locations.',
    features: ['Unlimited register devices', 'Multiple outlets under one account', 'Priority support', 'Custom onboarding'],
    cta: 'Contact Us',
    href: '/contact',
  },
];

export default function PricingPage() {
  const [billing, setBilling] = useState<'monthly' | 'yearly'>('monthly');

  return (
    <>
      <MarketingNav />
      <main className="max-w-5xl mx-auto px-6 py-20">
        <p className="label-eyebrow mb-2">Pricing</p>
        <h1 className="text-3xl font-semibold text-navy mb-4">Simple pricing that grows with you.</h1>
        <p className="text-ink/60 mb-8 max-w-xl">No hidden fees. Cancel anytime.</p>

        <div className="inline-flex items-center gap-1 bg-cream rounded-full p-1 mb-12">
          <button
            onClick={() => setBilling('monthly')}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
              billing === 'monthly' ? 'bg-navy text-white' : 'text-navy'
            }`}
          >
            Monthly
          </button>
          <button
            onClick={() => setBilling('yearly')}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-colors flex items-center gap-2 ${
              billing === 'yearly' ? 'bg-navy text-white' : 'text-navy'
            }`}
          >
            Yearly
            <span className={`text-[10px] px-2 py-0.5 rounded-full ${billing === 'yearly' ? 'bg-white text-navy' : 'bg-sage text-white'}`}>
              2 months free
            </span>
          </button>
        </div>

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

              {tier.monthly === null ? (
                <p className="text-2xl font-semibold text-navy mb-1">Custom</p>
              ) : billing === 'monthly' ? (
                <p className="text-2xl font-semibold text-navy mb-1">
                  {formatRupiah(tier.monthly)}
                  <span className="text-sm font-normal text-ink/50">/month</span>
                </p>
              ) : (
                <div className="mb-1">
                  <p className="text-xs text-ink/40 line-through">{formatRupiah(tier.monthly * 12)}/year</p>
                  <p className="text-2xl font-semibold text-navy">
                    {formatRupiah(tier.yearly!)}
                    <span className="text-sm font-normal text-ink/50">/year</span>
                  </p>
                  <p className="text-xs text-sage">
                    Just {formatRupiah(Math.round(tier.yearly! / 12))}/month
                  </p>
                </div>
              )}

              <p className="text-xs text-ink/50 mb-5 mt-1">{tier.desc}</p>
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
