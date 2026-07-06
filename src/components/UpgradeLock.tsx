import Link from 'next/link';

export function UpgradeLock({ feature }: { feature: string }) {
  return (
    <div className="receipt-card max-w-md text-center py-12">
      <p className="text-3xl mb-3">🔒</p>
      <p className="font-semibold text-navy mb-2">{feature} is a Pro feature</p>
      <p className="text-sm text-ink/60 mb-6">
        Upgrade your plan to unlock this, or contact us to arrange payment.
      </p>
      <div className="flex gap-3 justify-center">
        <Link href="/pricing" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
          See Plans
        </Link>
        <Link href="/contact" className="rounded-full border border-navy text-navy px-5 py-2.5 text-sm font-medium">
          Contact Us
        </Link>
      </div>
    </div>
  );
}
