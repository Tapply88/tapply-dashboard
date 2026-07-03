export function ReceiptStatCard({
  label,
  value,
  sublabel,
  accent = 'navy',
}: {
  label: string;
  value: string;
  sublabel?: string;
  accent?: 'navy' | 'sage' | 'rust';
}) {
  const accentClass = accent === 'sage' ? 'text-sage' : accent === 'rust' ? 'text-rust' : 'text-navy';

  return (
    <div className="receipt-card">
      <p className="label-eyebrow mb-3">{label}</p>
      <p className={`figure text-3xl font-semibold ${accentClass}`}>{value}</p>
      {sublabel && <p className="text-xs text-ink/50 mt-2">{sublabel}</p>}
    </div>
  );
}
