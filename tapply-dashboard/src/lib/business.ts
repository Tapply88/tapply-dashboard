import { createClient } from '@/lib/supabase/server';

export async function getCurrentBusiness() {
  const supabase = createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: link } = await supabase
    .from('business_users')
    .select('business_id')
    .eq('user_id', user.id)
    .single();

  if (!link) return null;

  const { data: business } = await supabase
    .from('businesses')
    .select('*')
    .eq('id', link.business_id)
    .single();

  return business;
}
