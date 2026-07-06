cat > src/app/page.tsx << 'PAGEEOF'
import Link from 'next/link';
import Image from 'next/image';

export default function LandingPage() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-6">
      <div className="max-w-md w-full text-center">
        <Image src="/logo.png" alt="Tapply" width={340} height={112} className="mx-auto mb-12" priority />
        <div className="flex flex-col gap-3">
          <Link
            href="/login"
            className="w-full rounded-full bg-navy text-white py-3 font-medium hover:bg-navy-soft transition-colors"
          >
            Masuk
          </Link>
          <Link
            href="/signup"
            className="w-full rounded-full border border-navy text-navy py-3 font-medium hover:bg-navy-50 transition-colors"
          >
            Daftar Bisnis Baru
          </Link>
        </div>
      </div>
    </main>
  );
}
PAGEEOF

echo 'Selesai. Restart: npm run dev'
