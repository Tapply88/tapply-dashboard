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
    a: 'Your data lives in a managed cloud database (not just on one device), protected by access rules that keep each business\'s data scoped to their own account when viewed through the dashboard. Cashier PINs are stored as one-way hashes, not as plain text. That said, Tapply is an early-stage product and hasn\'t been through a formal third-party security audit yet — treat it the way you would any young software product handling sensitive information.',
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
