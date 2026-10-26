import {getSupabase} from './supabase-client.js';
export const USERNAME_RE=/^[a-z0-9_]{3,24}$/;
export const PHONE_RE=/^08[0-9]{8,11}$/;
const clean=(v)=>typeof v==='string'?v.trim():'';
export function validateProfile(form){
 const errors={};const data={display_name:clean(form.display_name),username:clean(form.username).toLowerCase(),bio:clean(form.bio),phone:clean(form.phone).replace(/[\s-]/g,''),province:clean(form.province),city:clean(form.city),skills:clean(form.skills).split(',').map(x=>x.trim()).filter(Boolean).slice(0,20),interests:clean(form.interests).split(',').map(x=>x.trim()).filter(Boolean).slice(0,20),languages:clean(form.languages).split(',').map(x=>x.trim()).filter(Boolean).slice(0,20),availability:form.availability==='busy'?'busy':'available',experience:clean(form.experience),education:clean(form.education),alternative_email:clean(form.alternative_email)||null,whatsapp:clean(form.whatsapp)||null,street_address:clean(form.street_address),postal_code:clean(form.postal_code),gender:clean(form.gender)||null,birth_date:clean(form.birth_date)||null};
 if(!data.display_name||data.display_name.length>80)errors.display_name='Nama wajib diisi (maksimal 80 karakter).';
 if(!USERNAME_RE.test(data.username))errors.username='Gunakan 3–24 huruf kecil, angka, atau underscore.';
 if(data.bio.length<20||data.bio.length>500)errors.bio='Bio harus 20–500 karakter.';
 if(!PHONE_RE.test(data.phone))errors.phone='Nomor HP harus 08 diikuti 8–11 digit.';
 if(!data.province)errors.province='Provinsi wajib diisi.';
 if(!data.city)errors.city='Kota/kabupaten wajib diisi.';
 if(!data.skills.length)errors.skills='Isi minimal satu keahlian.';
 if(data.experience.length>300)errors.experience='Maksimal 300 karakter.';
 if(data.alternative_email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.alternative_email))errors.alternative_email='Email alternatif tidak valid.';
 return {data,errors};
}
export async function loadProfile(userId){const client=await getSupabase();const {data,error}=await client.from('profiles').select('*').eq('id',userId).single();if(error)throw error;return data;}
export async function saveProfile(userId,profile){const client=await getSupabase();const {data,error}=await client.from('profiles').update(profile).eq('id',userId).select().single();if(error)throw error;return data;}
export async function usernameAvailable(username){const client=await getSupabase();const {data,error}=await client.rpc('username_available',{candidate:username});if(error)throw error;return data===true;}
export async function uploadProfileImage(userId,file,kind){if(!['avatar','banner'].includes(kind))throw Error('Jenis gambar tidak dikenal.');if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>2*1024*1024)throw Error('Gunakan JPG, PNG atau WebP maksimal 2 MB.');const client=await getSupabase();const ext=file.type==='image/png'?'png':file.type==='image/webp'?'webp':'jpg';const path=`${userId}/${kind}-${crypto.randomUUID()}.${ext}`;const {error}=await client.storage.from('profile-media').upload(path,file,{contentType:file.type,upsert:false});if(error)throw error;return path;}
export async function signedProfileImage(path){if(!path)return null;const client=await getSupabase();const {data,error}=await client.storage.from('profile-media').createSignedUrl(path,3600);if(error)throw error;return data.signedUrl;}
