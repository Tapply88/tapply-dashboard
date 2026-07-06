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
              Your data is stored in a managed cloud database. Access controls scope each business&apos;s
              data to their own account when accessed through the dashboard, and cashier PINs are stored
              as one-way hashes rather than plain text. As with any software product, no system is
              completely immune to risk, and Tapply has not undergone a formal independent security audit.
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
