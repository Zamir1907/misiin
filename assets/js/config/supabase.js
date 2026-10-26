// Public project URL and publishable/anon key only. NEVER place a service_role key here.
export const SUPABASE_URL = 'https://txdfnrjeiebmlyjvoxba.supabase.co';
export const SUPABASE_ANON_KEY = 'sb_publishable_90cxQOmJZaSERjagAkbEHA_ifVxFxgX';
export const isConfigured = () => SUPABASE_URL.startsWith('https://') && !SUPABASE_ANON_KEY.startsWith('PASTE_');
