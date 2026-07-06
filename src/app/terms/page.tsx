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
