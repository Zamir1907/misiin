import { SUPABASE_URL, SUPABASE_ANON_KEY, isConfigured } from '../config/supabase.js';
let cached;
export async function getSupabase(){
 if(!isConfigured()) throw new Error('Supabase belum dikonfigurasi. Buka assets/js/config/supabase.js dan isi URL serta publishable key.');
 if(!cached){const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.49.4');cached=createClient(SUPABASE_URL,SUPABASE_ANON_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}})}
 return cached;
}
