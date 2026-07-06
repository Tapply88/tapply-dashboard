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
