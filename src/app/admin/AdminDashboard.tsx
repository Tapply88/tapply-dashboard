'use client';
import { useEffect, useState } from 'react';

type Business = {
  id: string;
  name: string;
  plan: string;
  plan_expires_at: string | null;
  trial_started_at: string | null;
  created_at: string;
};

const navy = '#623609';

export default function AdminDashboard() {
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [savingId, setSavingId] = useState<string | null>(null);

  async function loadBusinesses() {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/businesses');
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Gagal memuat data');
      setBusinesses(data.businesses);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat data');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadBusinesses();
  }, []);

  async function updatePlan(businessId: string, plan: string, extendDays?: number) {
    setSavingId(businessId);
    try {
      const body: Record<string, unknown> = { businessId, plan };
      if (extendDays) {
        const newExpiry = new Date();
        newExpiry.setDate(newExpiry.getDate() + extendDays);
        body.planExpiresAt = newExpiry.toISOString();
      } else {
        body.planExpiresAt = null;
      }
      const res = await fetch('/api/admin/businesses', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Gagal update');
      await loadBusinesses();
    } catch (e) {
      alert('Error: ' + (e instanceof Error ? e.message : 'Gagal update'));
    } finally {
      setSavingId(null);
    }
  }

  if (loading) return <div style={{ padding: 32 }}>Loading...</div>;
  if (error) return <div style={{ padding: 32, color: 'red' }}>Error: {error}</div>;

  return (
    <div style={{ padding: 32, fontFamily: 'sans-serif' }}>
      <h1 style={{ color: navy, marginBottom: 24, fontSize: 24, fontWeight: 700 }}>
        Admin — Manage Business Plans
      </h1>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr style={{ textAlign: 'left', borderBottom: `2px solid ${navy}` }}>
            <th style={{ padding: 8 }}>Business</th>
            <th style={{ padding: 8 }}>Plan</th>
            <th style={{ padding: 8 }}>Expires</th>
            <th style={{ padding: 8 }}>Created</th>
            <th style={{ padding: 8 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {businesses.map((b) => (
            <tr key={b.id} style={{ borderBottom: '1px solid #ddd' }}>
              <td style={{ padding: 8 }}>{b.name}</td>
              <td style={{ padding: 8, textTransform: 'capitalize' }}>{b.plan}</td>
              <td style={{ padding: 8 }}>
                {b.plan_expires_at ? new Date(b.plan_expires_at).toLocaleDateString('id-ID') : '—'}
              </td>
              <td style={{ padding: 8 }}>{new Date(b.created_at).toLocaleDateString('id-ID')}</td>
              <td style={{ padding: 8 }}>
                <select
                  disabled={savingId === b.id}
                  defaultValue=""
                  onChange={(e) => {
                    const val = e.target.value;
                    if (!val) return;
                    if (val === 'extend_trial') {
                      updatePlan(b.id, 'trial', 14);
                    } else {
                      updatePlan(b.id, val);
                    }
                    e.target.value = '';
                  }}
                >
                  <option value="">{savingId === b.id ? 'Saving...' : 'Change plan...'}</option>
                  <option value="starter">Set: Starter</option>
                  <option value="pro">Set: Pro</option>
                  <option value="multi_outlet">Set: Multi-Outlet</option>
                  <option value="extend_trial">Extend Trial +14 days</option>
                </select>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
