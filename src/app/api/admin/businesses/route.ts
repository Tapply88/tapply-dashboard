import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';

// Satu-satunya email yang boleh akses endpoint admin ini.
const ADMIN_EMAIL = 'sunita26sunita@gmail.com';

async function requireAdmin() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user || user.email !== ADMIN_EMAIL) return null;
  return user;
}

export async function GET() {
  const user = await requireAdmin();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });

  const admin = createAdminClient();
  const { data, error } = await admin
    .from('businesses')
    .select('id, name, plan, plan_expires_at, trial_started_at, created_at')
    .order('created_at', { ascending: false });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ businesses: data });
}

export async function PATCH(request: Request) {
  const user = await requireAdmin();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });

  const body = await request.json();
  const { businessId, plan, planExpiresAt } = body;
  if (!businessId || !plan) {
    return NextResponse.json({ error: 'businessId dan plan wajib diisi' }, { status: 400 });
  }

  const admin = createAdminClient();
  const updateData: Record<string, unknown> = { plan };
  if (planExpiresAt !== undefined) {
    updateData.plan_expires_at = planExpiresAt;
  }

  const { error } = await admin.from('businesses').update(updateData).eq('id', businessId);
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  return NextResponse.json({ success: true });
}
