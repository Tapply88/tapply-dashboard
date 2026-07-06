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
