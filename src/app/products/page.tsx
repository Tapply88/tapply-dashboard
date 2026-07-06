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
