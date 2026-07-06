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
