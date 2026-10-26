import {getSupabase} from './services/supabase-client.js';
import {loadProfile,saveProfile,validateProfile,usernameAvailable,USERNAME_RE,uploadProfileImage,signedProfileImage} from './services/profile-service.js';
const status=document.querySelector('#session-status');const admin=location.pathname.endsWith('/admin.html');
const setStatus=(t,error=false)=>{status.textContent=t;status.dataset.error=error?'true':'false';};
async function init(){try{const client=await getSupabase();const {data:{user},error}=await client.auth.getUser();if(error||!user){location.replace('/login.html');return;}
 const {data:role,error:roleError}=await client.from('roles').select('role').eq('user_id',user.id).eq('role','super_admin').maybeSingle();if(roleError)throw roleError;if(admin&&!role){location.replace('/app.html');return;}if(!admin&&role){location.replace('/admin.html');return;}
 setStatus(`Masuk sebagai ${user.email}`);document.querySelector('#logout').addEventListener('click',async()=>{await client.auth.signOut();location.replace('/login.html');});
 if(admin)return;
 const form=document.querySelector('#profile-form');const profile=await loadProfile(user.id);
 for(const [key,val] of Object.entries(profile)){const field=form.elements.namedItem(key);if(field&&'value'in field)field.value=Array.isArray(val)?val.join(', '):(val??'');}
 const userField=form.elements.username;const usernameStatus=document.querySelector('#username-status');let seq=0;
 userField.addEventListener('input',async()=>{const n=++seq;const v=userField.value.trim().toLowerCase();if(!USERNAME_RE.test(v)){usernameStatus.textContent='Username: 3–24 huruf kecil, angka, underscore.';return;}usernameStatus.textContent='Memeriksa...';try{const available=await usernameAvailable(v);if(n===seq)usernameStatus.textContent=available?'Username tersedia.':'Username sudah digunakan.';}catch(e){if(n===seq)usernameStatus.textContent='Pengecekan gagal: '+e.message;}});
 const avatar=document.querySelector('#avatar-preview');if(profile.avatar_path){try{avatar.src=await signedProfileImage(profile.avatar_path);avatar.hidden=false;}catch(e){console.warn(e);}}
 form.addEventListener('submit',async e=>{e.preventDefault();const btn=form.querySelector('[type=submit]');const feedback=document.querySelector('#profile-message');const raw=Object.fromEntries(new FormData(form));const {data,errors}=validateProfile(raw);const inputs=form.querySelectorAll('[aria-invalid]');inputs.forEach(x=>x.removeAttribute('aria-invalid'));
 if(Object.keys(errors).length){feedback.textContent=Object.values(errors).join(' ');feedback.dataset.error='true';for(const key of Object.keys(errors)){const el=form.elements.namedItem(key);el?.setAttribute('aria-invalid','true');}return;}
 btn.disabled=true;feedback.textContent='Menyimpan...';feedback.dataset.error='false';try{
  if(data.username!==profile.username&&!await usernameAvailable(data.username))throw Error('Username sudah digunakan.');
  const file=form.elements.avatar_file.files[0];if(file)data.avatar_path=await uploadProfileImage(user.id,file,'avatar');
  const saved=await saveProfile(user.id,data);Object.assign(profile,saved);feedback.textContent='Profil tersimpan.';if(file){avatar.src=await signedProfileImage(saved.avatar_path);avatar.hidden=false;}
 }catch(err){const msg=err.code==='23505'?(err.message.includes('phone')?'Nomor HP sudah terdaftar.':'Username sudah digunakan.'):err.message;feedback.textContent=msg;feedback.dataset.error='true';}finally{btn.disabled=false;}
 });
 }catch(err){setStatus(err.message||'Gagal memuat halaman.',true);}}
init();
