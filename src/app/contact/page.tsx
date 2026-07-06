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
