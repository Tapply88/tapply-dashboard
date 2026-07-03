import type { Metadata } from 'next';
import { Inter, Fraunces, IBM_Plex_Mono } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' });
const fraunces = Fraunces({ subsets: ['latin'], variable: '--font-serif', weight: ['500', '600'] });
const plexMono = IBM_Plex_Mono({ subsets: ['latin'], variable: '--font-mono', weight: ['400', '500', '600'] });

export const metadata: Metadata = {
  title: 'Tapply Dashboard',
  description: 'Kelola bisnis kamu yang pakai Tapply POS — laporan, produk, promo, dan member dalam satu tempat.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body className={`${inter.variable} ${fraunces.variable} ${plexMono.variable} font-sans bg-cream text-ink antialiased`}>
        {children}
      </body>
    </html>
  );
}
