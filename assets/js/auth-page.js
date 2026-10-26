import {getSupabase} from './services/supabase-client.js';
const form=document.querySelector('form');const message=document.querySelector('#form-message');
const report=(txt,bad=false)=>{message.textContent=txt;message.dataset.error=bad?'true':'false';};
async function destination(client,user){const {data,error}=await client.from('roles').select('role').eq('user_id',user.id).eq('role','super_admin').maybeSingle();if(error)throw error;location.replace(data?'/admin.html':'/app.html');}
// Deliberately DO NOT auto-redirect logged-in users: switching accounts must remain possible.
// Clear browser-restored form values on entry and back/forward navigation.
function clearCredentials(){
 if(!['login-form','register-form'].includes(form.id))return;
 form.reset();
 for(const input of form.querySelectorAll('input')){input.value='';input.defaultValue='';}
}
clearCredentials();
window.addEventListener('pageshow',clearCredentials);
window.addEventListener('load',()=>{clearCredentials();setTimeout(clearCredentials,150);});
(async()=>{if(!['login-form','register-form'].includes(form.id))return;
 try{const client=await getSupabase();const {data:{user}}=await client.auth.getUser();
 if(user){report('Masih ada sesi akun sebelumnya. Untuk berganti akun, pilih Keluar dari akun lama atau masuk dengan akun lain.');}
 }catch(e){report(e.message,true);}
})();
form.addEventListener('submit',async e=>{e.preventDefault();const button=form.querySelector('[type=submit]');button.disabled=true;report('Memproses...');try{const client=await getSupabase();const email=form.elements.email?.value.trim().toLowerCase();const password=form.elements.password?.value;const origin=location.origin;
 if(form.id==='register-form'){
  if(password!==form.elements.confirm_password.value)throw Error('Konfirmasi password tidak sama.');
  const {data,error}=await client.auth.signUp({email,password,options:{emailRedirectTo:`${origin}/login.html`}});if(error)throw error;
  report(data.session?'Akun dibuat. Mengalihkan...':'Periksa email untuk verifikasi akun. Jika sudah terdaftar, gunakan halaman masuk.');if(data.session)await destination(client,data.user);
 }else if(form.id==='login-form'){
  const {data,error}=await client.auth.signInWithPassword({email,password});if(error)throw error;await destination(client,data.user);
 }else if(form.id==='reset-form'){
  const {error}=await client.auth.resetPasswordForEmail(email,{redirectTo:`${origin}/update-password.html`});if(error)throw error;report('Jika email terdaftar, tautan reset password akan dikirim.');
 }else if(form.id==='update-password-form'){
  if(password!==form.elements.confirm_password.value)throw Error('Konfirmasi password tidak sama.');
  const {data:{session}}=await client.auth.getSession();if(!session)throw Error('Buka tautan pemulihan terbaru dari email terlebih dahulu.');
  const {error}=await client.auth.updateUser({password});if(error)throw error;report('Password diperbarui. Silakan masuk kembali.');await client.auth.signOut();
 }
}catch(err){report(err.message||'Terjadi kesalahan.',true);}finally{button.disabled=false;}});
