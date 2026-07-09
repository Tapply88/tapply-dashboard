import { SalesReportsSection } from '@/components/SalesReportsSection';

export default function ReportsPage() {
  return (
    <div className="max-w-4xl">
      <p className="label-eyebrow mb-2">Sales Reports</p>
      <h1 className="text-2xl font-semibold mb-6">Reports</h1>
      <SalesReportsSection />
    </div>
  );
}
