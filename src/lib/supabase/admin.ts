import { createClient } from '@supabase/supabase-js';

// Client khusus admin — pakai Service Role Key, BYPASS semua Row Level
// Security. Cuma boleh dipanggil dari API routes server-side (folder
// src/app/api/admin/), JANGAN PERNAH diimport dari client component atau
// dikirim ke browser.
export function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}
