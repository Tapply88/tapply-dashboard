cat > supabase/migration_010_dashboard_language.sql << 'MIGEOF'
-- Migration: preferensi bahasa dashboard (per bisnis, bukan per user, biar
-- konsisten dilihat siapapun yang login ke akun bisnis yang sama).
alter table businesses
  add column if not exists dashboard_language text default 'en';
MIGEOF

cat > src/lib/i18n.tsx << 'I18NEOF'
'use client';

import { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Lang = 'en' | 'id';

const DICTIONARY: Record<string, { en: string; id: string }> = {
  // Sidebar
  nav_overview: { en: 'Overview', id: 'Ringkasan' },
  nav_products: { en: 'Products', id: 'Produk' },
  nav_variants: { en: 'Variants & Add-ons', id: 'Varian & Tambahan' },
  nav_staff: { en: 'Staff', id: 'Staf' },
  nav_promos: { en: 'Promo', id: 'Promo' },
  nav_members: { en: 'Members', id: 'Member' },
  nav_shifts: { en: 'Shifts', id: 'Shift' },
  nav_settings: { en: 'Settings', id: 'Setelan' },
  // Reports / dashboard home
  sales_report: { en: 'Sales Report', id: 'Laporan Penjualan' },
  today: { en: 'Today', id: 'Hari Ini' },
  seven_days: { en: '7 Days', id: '7 Hari' },
  thirty_days: { en: '30 Days', id: '30 Hari' },
  pick_period: { en: 'Pick Period', id: 'Pilih Periode' },
  export_csv: { en: '⬇ Export CSV', id: '⬇ Ekspor CSV' },
  total_sales: { en: 'Total Sales', id: 'Total Penjualan' },
  avg_per_transaction: { en: 'Average per Transaction', id: 'Rata-rata per Transaksi' },
  daily_sales_trend: { en: 'Daily Sales Trend', id: 'Tren Penjualan Harian' },
  best_selling_products: { en: 'Best-selling Products (units)', id: 'Produk Terlaris (jumlah unit)' },
  sales_by_payment: { en: 'Sales by Payment Method', id: 'Penjualan per Metode Bayar' },
  sales_by_category: { en: 'Sales by Category (units)', id: 'Penjualan per Kategori (jumlah unit)' },
  no_transactions_period: { en: 'No transactions in this period.', id: 'Belum ada transaksi di periode ini.' },
  // Settings
  business_settings: { en: 'Business Settings', id: 'Pengaturan Bisnis' },
  settings: { en: 'Settings', id: 'Setelan' },
  settings_intro: {
    en: 'Everything here syncs automatically to the cashier app — no action needed on the device.',
    id: 'Semua di sini otomatis ke-sync ke app kasir — gak perlu ngapa-ngapain di device.',
  },
  business_profile: { en: 'Business Profile', id: 'Profil Bisnis' },
  business_name: { en: 'Business Name', id: 'Nama Bisnis' },
  address: { en: 'Address', id: 'Alamat' },
  phone_number: { en: 'Phone Number', id: 'No. Telepon' },
  receipt_footer: { en: 'Receipt Footer Text', id: 'Teks Footer Struk' },
  tax_service_discount: { en: 'Tax, Service & Discount', id: 'Pajak, Layanan & Diskon' },
  security: { en: 'Security', id: 'Keamanan' },
  manager_pin: { en: 'Manager PIN (for canceling items)', id: 'PIN Manager (buat cancel item)' },
  require_pin_cancel: { en: 'Require PIN to cancel a cart item', id: 'Wajib PIN buat cancel item keranjang' },
  receipt_queue: { en: 'Receipt & Queue', id: 'Struk & Antrian' },
  save_changes: { en: 'Save Changes', id: 'Simpan Perubahan' },
  saved: { en: 'Saved.', id: 'Tersimpan.' },
  dashboard_language: { en: 'Dashboard Language', id: 'Bahasa Dashboard' },
  sync: { en: 'Sync', id: 'Sinkronisasi' },
  connect_cashier_app: { en: 'Connect the Cashier App', id: 'Hubungkan App Kasir' },
  // Common
  cancel: { en: 'Cancel', id: 'Batal' },
  save: { en: 'Save', id: 'Simpan' },
  delete: { en: 'Delete', id: 'Hapus' },
  edit: { en: 'Edit', id: 'Edit' },
  loading: { en: 'Loading...', id: 'Memuat...' },
};

type I18nContextType = {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: (key: string) => string;
};

const I18nContext = createContext<I18nContextType>({
  lang: 'en',
  setLang: () => {},
  t: (key: string) => DICTIONARY[key]?.en ?? key,
});

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const supabase = createClient();
  const [lang, setLangState] = useState<Lang>('en');

  useEffect(() => {
    async function loadLang() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;
      const { data: business } = await supabase.from('businesses').select('dashboard_language').eq('id', link.business_id).single();
      if (business?.dashboard_language) setLangState(business.dashboard_language as Lang);
    }
    loadLang();
  }, [supabase]);

  const setLang = useCallback(
    async (l: Lang) => {
      setLangState(l);
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;
      await supabase.from('businesses').update({ dashboard_language: l }).eq('id', link.business_id);
    },
    [supabase]
  );

  const t = useCallback((key: string) => DICTIONARY[key]?.[lang] ?? key, [lang]);

  return <I18nContext.Provider value={{ lang, setLang, t }}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  return useContext(I18nContext);
}
I18NEOF

cat > src/app/dashboard/layout.tsx << 'LAYOUTEOF'
import { redirect } from 'next/navigation';
import { Sidebar } from '@/components/Sidebar';
import { Topbar } from '@/components/Topbar';
import { getCurrentBusiness } from '@/lib/business';
import { I18nProvider } from '@/lib/i18n';

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const business = await getCurrentBusiness();

  if (!business) {
    redirect('/onboarding');
  }

  return (
    <I18nProvider>
      <div className="flex min-h-screen">
        <Sidebar />
        <div className="flex-1 flex flex-col">
          <Topbar businessName={business.name} />
          <main className="flex-1 p-8">{children}</main>
        </div>
      </div>
    </I18nProvider>
  );
}
LAYOUTEOF

cat > src/components/Sidebar.tsx << 'SIDEBAREOF'
'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useI18n } from '@/lib/i18n';

export function Sidebar() {
  const pathname = usePathname();
  const { t } = useI18n();

  const NAV_ITEMS = [
    { href: '/dashboard', label: t('nav_overview'), icon: '◧' },
    { href: '/dashboard/products', label: t('nav_products'), icon: '☰' },
    { href: '/dashboard/variants', label: t('nav_variants'), icon: '⊕' },
    { href: '/dashboard/staff', label: t('nav_staff'), icon: '☺' },
    { href: '/dashboard/promos', label: t('nav_promos'), icon: '◈' },
    { href: '/dashboard/members', label: t('nav_members'), icon: '◎' },
    { href: '/dashboard/shifts', label: t('nav_shifts'), icon: '◷' },
    { href: '/dashboard/settings', label: t('nav_settings'), icon: '⚙' },
  ];

  return (
    <aside className="w-60 shrink-0 bg-navy text-white flex flex-col min-h-screen">
      <div className="px-6 py-7">
        <p className="font-serif text-2xl" style={{ fontStyle: 'italic' }}>
          Tapply
        </p>
      </div>
      <nav className="flex-1 px-3">
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center justify-between gap-3 px-4 py-2.5 rounded-lg text-sm mb-1 transition-colors ${
                active ? 'bg-white/15 font-medium' : 'text-white/70 hover:bg-white/10'
              }`}
            >
              <span className="flex items-center gap-3">
                <span aria-hidden>{item.icon}</span>
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
      <div className="px-6 py-5 text-xs text-white/40">v0.1 — Tapply Dashboard</div>
    </aside>
  );
}
SIDEBAREOF

cat > src/app/dashboard/settings/page.tsx << 'SETEOF'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useI18n } from '@/lib/i18n';

export default function SettingsPage() {
  const supabase = createClient();
  const { t, lang, setLang } = useI18n();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [syncApiKey, setSyncApiKey] = useState<string>('');
  const [form, setForm] = useState({
    name: '',
    address: '',
    phone: '',
    footer_text: '',
    tax_percent: '0',
    service_percent: '0',
    discount_percent: '0',
    rounding_enabled: false,
    rounding_nearest: '100',
    manager_pin: '1234',
    pin_required_for_cancel: true,
    print_check_enabled: true,
    queue_number_enabled: false,
    queue_start_number: '1',
  });
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;

      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;

      const { data: business } = await supabase.from('businesses').select('*').eq('id', link.business_id).single();
      if (business) {
        setBusinessId(business.id);
        setSyncApiKey(business.sync_api_key ?? '');
        setForm({
          name: business.name ?? '',
          address: business.address ?? '',
          phone: business.phone ?? '',
          footer_text: business.footer_text ?? '',
          tax_percent: String(business.tax_percent ?? 0),
          service_percent: String(business.service_percent ?? 0),
          discount_percent: String(business.discount_percent ?? 0),
          rounding_enabled: business.rounding_enabled ?? false,
          rounding_nearest: String(business.rounding_nearest ?? 100),
          manager_pin: business.manager_pin ?? '1234',
          pin_required_for_cancel: business.pin_required_for_cancel ?? true,
          print_check_enabled: business.print_check_enabled ?? true,
          queue_number_enabled: business.queue_number_enabled ?? false,
          queue_start_number: String(business.queue_start_number ?? 1),
        });
      }
      setLoading(false);
    }
    load();
  }, [supabase]);

  async function handleRegenerateKey() {
    if (!businessId) return;
    if (!confirm('Generate a new API key? The old key will stop working — any Flutter app still using it will need to be updated.')) return;
    const newKey = crypto.randomUUID().replace(/-/g, '');
    await supabase.from('businesses').update({ sync_api_key: newKey }).eq('id', businessId);
    setSyncApiKey(newKey);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!businessId) return;
    await supabase
      .from('businesses')
      .update({
        name: form.name,
        address: form.address,
        phone: form.phone,
        footer_text: form.footer_text,
        tax_percent: Number(form.tax_percent) || 0,
        service_percent: Number(form.service_percent) || 0,
        discount_percent: Number(form.discount_percent) || 0,
        rounding_enabled: form.rounding_enabled,
        rounding_nearest: Number(form.rounding_nearest) || 100,
        manager_pin: form.manager_pin || '1234',
        pin_required_for_cancel: form.pin_required_for_cancel,
        print_check_enabled: form.print_check_enabled,
        queue_number_enabled: form.queue_number_enabled,
        queue_start_number: Number(form.queue_start_number) || 1,
      })
      .eq('id', businessId);
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  }

  if (loading) return <p className="text-sm text-ink/50">{t('loading')}</p>;

  return (
    <div className="max-w-lg">
      <p className="label-eyebrow mb-2">{t('business_settings')}</p>
      <h1 className="text-2xl font-semibold mb-2">{t('settings')}</h1>
      <p className="text-sm text-ink/60 mb-8">
        {t('settings_intro')}
      </p>

      <form onSubmit={handleSave} className="receipt-card flex flex-col gap-4">
        <p className="label-eyebrow">{t('business_profile')}</p>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('business_name')}</label>
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('address')}</label>
          <textarea
            value={form.address}
            onChange={(e) => setForm({ ...form, address: e.target.value })}
            rows={2}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none resize-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('phone_number')}</label>
          <input
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('receipt_footer')}</label>
          <input
            value={form.footer_text}
            onChange={(e) => setForm({ ...form, footer_text: e.target.value })}
            placeholder="Thank you!"
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('tax_service_discount')}</p>
        <div className="grid grid-cols-3 gap-3">
          <div>
            <label className="label-eyebrow block mb-1.5">Tax (%)</label>
            <input
              type="number"
              value={form.tax_percent}
              onChange={(e) => setForm({ ...form, tax_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Service (%)</label>
            <input
              type="number"
              value={form.service_percent}
              onChange={(e) => setForm({ ...form, service_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Discount (%)</label>
            <input
              type="number"
              value={form.discount_percent}
              onChange={(e) => setForm({ ...form, discount_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        </div>

        <label className="flex items-center gap-2 text-sm pt-2">
          <input
            type="checkbox"
            checked={form.rounding_enabled}
            onChange={(e) => setForm({ ...form, rounding_enabled: e.target.checked })}
          />
          Round total to nearest
        </label>
        {form.rounding_enabled && (
          <select
            value={form.rounding_nearest}
            onChange={(e) => setForm({ ...form, rounding_nearest: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          >
            <option value="100">Rp 100</option>
            <option value="500">Rp 500</option>
            <option value="1000">Rp 1,000</option>
          </select>
        )}

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('security')}</p>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('manager_pin')}</label>
          <input
            value={form.manager_pin}
            onChange={(e) => setForm({ ...form, manager_pin: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.pin_required_for_cancel}
            onChange={(e) => setForm({ ...form, pin_required_for_cancel: e.target.checked })}
          />
          {t('require_pin_cancel')}
        </label>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('receipt_queue')}</p>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.print_check_enabled}
            onChange={(e) => setForm({ ...form, print_check_enabled: e.target.checked })}
          />
          Show &quot;Print Check&quot; button in POS
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.queue_number_enabled}
            onChange={(e) => setForm({ ...form, queue_number_enabled: e.target.checked })}
          />
          Enable queue numbers on receipts
        </label>
        {form.queue_number_enabled && (
          <div>
            <label className="label-eyebrow block mb-1.5">Queue Start Number (daily)</label>
            <input
              type="number"
              value={form.queue_start_number}
              onChange={(e) => setForm({ ...form, queue_start_number: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        )}

        <button type="submit" className="rounded-full bg-navy text-white py-3 font-medium mt-2">
          {t('save_changes')}
        </button>
        {saved && <p className="text-sage text-sm text-center">{t('saved')}</p>}
      </form>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">{t('dashboard_language')}</p>
        <div className="flex gap-2 mt-3">
          <button
            type="button"
            onClick={() => setLang('en')}
            className={`flex-1 rounded-full px-4 py-2.5 text-sm font-medium border transition-colors ${
              lang === 'en' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
            }`}
          >
            English
          </button>
          <button
            type="button"
            onClick={() => setLang('id')}
            className={`flex-1 rounded-full px-4 py-2.5 text-sm font-medium border transition-colors ${
              lang === 'id' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
            }`}
          >
            Bahasa Indonesia
          </button>
        </div>
      </div>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">{t('sync')}</p>
        <h2 className="text-lg font-semibold mb-2">{t('connect_cashier_app')}</h2>
        <p className="text-sm text-ink/60 mb-4">
          Paste this code into the Tapply POS (Flutter) app used by your cashiers, once per device,
          so it can pull settings and push transactions automatically.
        </p>
        <div className="flex items-center gap-2 mb-3">
          <code className="flex-1 figure text-sm bg-cream border border-grey rounded-lg px-4 py-2.5 break-all">
            {syncApiKey || 'Loading...'}
          </code>
          <button
            type="button"
            onClick={() => {
              navigator.clipboard.writeText(syncApiKey);
              alert('Code copied!');
            }}
            className="rounded-lg border border-navy text-navy px-4 py-2.5 text-sm font-medium shrink-0"
          >
            Copy
          </button>
        </div>
        <button type="button" onClick={handleRegenerateKey} className="text-rust text-sm font-medium">
          Generate new code
        </button>
      </div>
    </div>
  );
}
SETEOF

cat > src/app/dashboard/page.tsx << 'DASHEOF'
'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { createClient } from '@/lib/supabase/client';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { ReceiptStatCard } from '@/components/ReceiptStatCard';
import { useI18n } from '@/lib/i18n';

type Period = 'today' | 'week' | 'month' | 'custom';

type TxItem = { productId: string; productName: string; qty: number };
type Tx = { id: string; total: number; payment_method: string; items: TxItem[]; created_at: string };
type ProductInfo = { id: string; category: string };

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

function toDateInputValue(d: Date) {
  return d.toISOString().slice(0, 10);
}

function dayKey(iso: string) {
  return iso.slice(0, 10);
}

function getPresetRange(period: Period): { from: Date; to: Date } {
  const now = new Date();
  const to = new Date(now);
  to.setHours(23, 59, 59, 999);
  const from = new Date(now);
  if (period === 'today') {
    from.setHours(0, 0, 0, 0);
  } else if (period === 'week') {
    from.setDate(now.getDate() - 6);
    from.setHours(0, 0, 0, 0);
  } else if (period === 'month') {
    from.setDate(now.getDate() - 29);
    from.setHours(0, 0, 0, 0);
  }
  return { from, to };
}

const CHART_NAVY = '#092762';
const CHART_SAGE = '#5B8266';
const CHART_RUST = '#B54834';

export default function DashboardHomePage() {
  const supabase = createClient();
  const { t } = useI18n();
  const [businessName, setBusinessName] = useState('');
  const [period, setPeriod] = useState<Period>('today');
  const [customFrom, setCustomFrom] = useState(toDateInputValue(new Date(Date.now() - 6 * 86400000)));
  const [customTo, setCustomTo] = useState(toDateInputValue(new Date()));
  const [transactions, setTransactions] = useState<Tx[]>([]);
  const [previousTransactions, setPreviousTransactions] = useState<Tx[]>([]);
  const [products, setProducts] = useState<ProductInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const range = useMemo(() => {
    if (period === 'custom') {
      return { from: new Date(customFrom + 'T00:00:00'), to: new Date(customTo + 'T23:59:59') };
    }
    return getPresetRange(period);
  }, [period, customFrom, customTo]);

  const previousRange = useMemo(() => {
    const spanMs = range.to.getTime() - range.from.getTime();
    const prevTo = new Date(range.from.getTime() - 1);
    const prevFrom = new Date(prevTo.getTime() - spanMs);
    return { from: prevFrom, to: prevTo };
  }, [range]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);

    if (period === 'custom') {
      const days = (range.to.getTime() - range.from.getTime()) / 86400000;
      if (days > 30) {
        setError('Rentang maksimal 30 hari. Persempit pilihan tanggalnya ya.');
        setLoading(false);
        return;
      }
      if (days < 0) {
        setError('Tanggal mulai harus sebelum tanggal selesai.');
        setLoading(false);
        return;
      }
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
      if (range.from < oneYearAgo) {
        setError('Data cuma bisa dilihat sampai 1 tahun ke belakang.');
        setLoading(false);
        return;
      }
    }

    const [{ data: current }, { data: previous }, { data: productData }] = await Promise.all([
      supabase
        .from('transactions')
        .select('id, total, payment_method, items, created_at')
        .eq('status', 'paid')
        .gte('created_at', range.from.toISOString())
        .lte('created_at', range.to.toISOString()),
      supabase
        .from('transactions')
        .select('id, total, payment_method, items, created_at')
        .eq('status', 'paid')
        .gte('created_at', previousRange.from.toISOString())
        .lte('created_at', previousRange.to.toISOString()),
      supabase.from('products').select('id, category'),
    ]);

    setTransactions((current as Tx[]) ?? []);
    setPreviousTransactions((previous as Tx[]) ?? []);
    setProducts((productData as ProductInfo[]) ?? []);
    setLoading(false);
  }, [supabase, range, previousRange, period]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  useEffect(() => {
    async function loadBusiness() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;
      const { data: business } = await supabase.from('businesses').select('name').eq('id', link.business_id).single();
      if (business) setBusinessName(business.name);
    }
    loadBusiness();
  }, [supabase]);

  const totalRevenue = transactions.reduce((sum, t) => sum + (t.total ?? 0), 0);
  const previousRevenue = previousTransactions.reduce((sum, t) => sum + (t.total ?? 0), 0);
  const revenueChangePct = previousRevenue > 0 ? ((totalRevenue - previousRevenue) / previousRevenue) * 100 : null;
  const txCount = transactions.length;

  const byPayment = new Map<string, number>();
  for (const t of transactions) {
    byPayment.set(t.payment_method, (byPayment.get(t.payment_method) ?? 0) + (t.total ?? 0));
  }
  const paymentData = Array.from(byPayment.entries())
    .map(([method, amount]) => ({ method: method.replace(/_/g, ' '), amount }))
    .sort((a, b) => b.amount - a.amount);

  const productQty = new Map<string, number>();
  const productIdByName = new Map<string, string>();
  for (const t of transactions) {
    for (const item of t.items ?? []) {
      productQty.set(item.productName, (productQty.get(item.productName) ?? 0) + (item.qty ?? 0));
      if (item.productId) productIdByName.set(item.productName, item.productId);
    }
  }
  const topProducts = Array.from(productQty.entries())
    .map(([name, qty]) => ({ name, qty }))
    .sort((a, b) => b.qty - a.qty)
    .slice(0, 10);

  const categoryById = new Map(products.map((p) => [p.id, p.category]));
  const byCategory = new Map<string, number>();
  for (const [name, qty] of productQty.entries()) {
    const id = productIdByName.get(name);
    const category = (id && categoryById.get(id)) || 'Lainnya';
    byCategory.set(category, (byCategory.get(category) ?? 0) + qty);
  }
  const categoryData = Array.from(byCategory.entries())
    .map(([category, qty]) => ({ category, qty }))
    .sort((a, b) => b.qty - a.qty);

  const byDay = new Map<string, number>();
  for (const t of transactions) {
    const key = dayKey(t.created_at);
    byDay.set(key, (byDay.get(key) ?? 0) + (t.total ?? 0));
  }
  const dailyTrend = Array.from(byDay.entries())
    .map(([date, total]) => ({ date: date.slice(5), total }))
    .sort((a, b) => (a.date > b.date ? 1 : -1));

  function exportCsv() {
    const header = 'Date,Payment Method,Items,Total\n';
    const rows = transactions
      .map((t) => {
        const itemsSummary = (t.items ?? []).map((i) => `${i.productName} x${i.qty}`).join('; ');
        const date = new Date(t.created_at).toLocaleString('id-ID');
        return `"${date}","${t.payment_method}","${itemsSummary.replace(/"/g, "'")}",${t.total}`;
      })
      .join('\n');
    const blob = new Blob([header + rows], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tapply-sales-${toDateInputValue(range.from)}-to-${toDateInputValue(range.to)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div>
      <p className="label-eyebrow mb-2">{businessName || 'Ringkasan'}</p>
      <h1 className="text-2xl font-semibold mb-6">{t('sales_report')}</h1>

      <div className="flex flex-wrap items-center gap-2 mb-8">
        {(['today', 'week', 'month', 'custom'] as Period[]).map((p) => (
          <button
            key={p}
            onClick={() => setPeriod(p)}
            className={`rounded-full px-4 py-2 text-sm font-medium transition-colors ${
              period === p ? 'bg-navy text-white' : 'border border-grey text-navy hover:bg-navy-50'
            }`}
          >
            {p === 'today' ? t('today') : p === 'week' ? t('seven_days') : p === 'month' ? t('thirty_days') : t('pick_period')}
          </button>
        ))}
        {period === 'custom' && (
          <div className="flex items-center gap-2 ml-2">
            <input
              type="date"
              value={customFrom}
              onChange={(e) => setCustomFrom(e.target.value)}
              className="rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <span className="text-ink/40 text-sm">–</span>
            <input
              type="date"
              value={customTo}
              onChange={(e) => setCustomTo(e.target.value)}
              className="rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
          </div>
        )}
        <button
          onClick={exportCsv}
          disabled={transactions.length === 0}
          className="ml-auto rounded-full border border-navy text-navy px-4 py-2 text-sm font-medium hover:bg-navy-50 transition-colors disabled:opacity-40"
        >
          {t('export_csv')}
        </button>
      </div>

      {error && (
        <div className="receipt-card max-w-lg mb-8 !bg-rust-light !border-rust/30">
          <p className="text-sm text-rust">{error}</p>
        </div>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5 mb-10">
            <ReceiptStatCard
              label={t('total_sales')}
              value={formatRupiah(totalRevenue)}
              sublabel={
                revenueChangePct === null
                  ? `${txCount} transaksi`
                  : `${revenueChangePct >= 0 ? '+' : ''}${revenueChangePct.toFixed(0)}% dari periode sebelumnya • ${txCount} transaksi`
              }
              accent={revenueChangePct !== null && revenueChangePct < 0 ? 'rust' : 'navy'}
            />
            <ReceiptStatCard
              label={t('avg_per_transaction')}
              value={formatRupiah(txCount > 0 ? Math.round(totalRevenue / txCount) : 0)}
              accent="sage"
            />
          </div>

          <div className="receipt-card mb-8">
            <p className="label-eyebrow mb-4">{t('daily_sales_trend')}</p>
            {dailyTrend.length < 2 ? (
              <p className="text-sm text-ink/50">Butuh minimal 2 hari data buat nampilin tren.</p>
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <LineChart data={dailyTrend}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                  <YAxis tickFormatter={(v) => formatRupiah(v)} tick={{ fontSize: 10 }} width={70} />
                  <Tooltip formatter={(v: number) => [formatRupiah(v), 'Penjualan']} />
                  <Line type="monotone" dataKey="total" stroke={CHART_NAVY} strokeWidth={2} dot={{ r: 3 }} />
                </LineChart>
              </ResponsiveContainer>
            )}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <div className="receipt-card">
              <p className="label-eyebrow mb-4">{t('best_selling_products')}</p>
              {topProducts.length === 0 ? (
                <p className="text-sm text-ink/50">{t('no_transactions_period')}</p>
              ) : (
                <ResponsiveContainer width="100%" height={Math.max(200, topProducts.length * 34)}>
                  <BarChart data={topProducts} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11 }} />
                    <YAxis type="category" dataKey="name" width={110} tick={{ fontSize: 11 }} />
                    <Tooltip formatter={(v: number) => [`${v} unit`, 'Terjual']} />
                    <Bar dataKey="qty" fill={CHART_NAVY} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>

            <div className="receipt-card">
              <p className="label-eyebrow mb-4">{t('sales_by_payment')}</p>
              {paymentData.length === 0 ? (
                <p className="text-sm text-ink/50">{t('no_transactions_period')}</p>
              ) : (
                <ResponsiveContainer width="100%" height={Math.max(200, paymentData.length * 40)}>
                  <BarChart data={paymentData} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" tickFormatter={(v) => formatRupiah(v)} tick={{ fontSize: 10 }} />
                    <YAxis type="category" dataKey="method" width={100} tick={{ fontSize: 11 }} className="capitalize" />
                    <Tooltip formatter={(v: number) => [formatRupiah(v), 'Total']} />
                    <Bar dataKey="amount" fill={CHART_SAGE} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>

          <div className="receipt-card">
            <p className="label-eyebrow mb-4">{t('sales_by_category')}</p>
            {categoryData.length === 0 ? (
              <p className="text-sm text-ink/50">{t('no_transactions_period')}</p>
            ) : (
              <ResponsiveContainer width="100%" height={Math.max(160, categoryData.length * 40)}>
                <BarChart data={categoryData} layout="vertical" margin={{ left: 20 }}>
                  <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                  <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11 }} />
                  <YAxis type="category" dataKey="category" width={100} tick={{ fontSize: 11 }} />
                  <Tooltip formatter={(v: number) => [`${v} unit`, 'Terjual']} />
                  <Bar dataKey="qty" fill={CHART_RUST} radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </>
      )}
    </div>
  );
}
DASHEOF

echo 'Selesai. Jalankan migration_010 di Supabase SQL Editor, lalu npm run dev'
