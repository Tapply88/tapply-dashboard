import Link from 'next/link';

export default function LandingPage() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-6">
      <div className="max-w-md w-full text-center">
        <p className="font-serif text-5xl text-navy mb-3" style={{ fontStyle: 'italic' }}>
          Tapply
        </p>
        <p className="text-ink/60 mb-10">
          Satu tempat buat pantau semua kedai kamu yang pakai Tapply POS.
        </p>
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
