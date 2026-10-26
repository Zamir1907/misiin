/** Explicit sign-out shared by user and admin dashboards. */
export async function logoutAndGo(client, button){
 if(!client) throw new Error('Koneksi autentikasi belum siap. Muat ulang halaman.');
 if(button){button.disabled=true;button.textContent='Sedang keluar…';}
 try {
   const {error}=await client.auth.signOut({scope:'local'});
   if(error) throw error;
   // Prevent browser back/forward cache from reviving the authenticated screen.
   window.location.replace('/login.html?logged_out=1');
 } catch(error){
   if(button){button.disabled=false;button.textContent='Keluar';}
   throw error;
 }
}
