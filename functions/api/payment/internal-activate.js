// Test-only activation, enabled solely for explicitly allowlisted test accounts.
// Do not enable MISIIN_INTERNAL_TEST_MODE on a public production deployment.
export async function onRequestPost({request,env}) {
 if(env.MISIIN_INTERNAL_TEST_MODE!=='enabled') return Response.json({error:'Aktivasi pengujian belum diaktifkan di server.'},{status:403});
 const token=(request.headers.get('authorization')||'').replace(/^Bearer\s+/i,'');
 if(!token||!env.SUPABASE_URL||!env.SUPABASE_SERVICE_ROLE_KEY||!env.MISIIN_TEST_USER_ID) return Response.json({error:'Pengaturan akun penguji belum lengkap.'},{status:400});
 const base=env.SUPABASE_URL.replace(/\/$/,'');const key=env.SUPABASE_SERVICE_ROLE_KEY;
 const who=await fetch(base+'/auth/v1/user',{headers:{apikey:key,authorization:'Bearer '+token}});
 if(!who.ok)return Response.json({error:'Silakan login kembali.'},{status:401});
 const user=await who.json();if(user.id!==env.MISIIN_TEST_USER_ID)return Response.json({error:'Akun ini belum terdaftar sebagai akun penguji.'},{status:403});
 const headers={apikey:key,authorization:'Bearer '+key,'content-type':'application/json',prefer:'resolution=merge-duplicates,return=representation'};
 const r=await fetch(base+'/rest/v1/memberships?on_conflict=user_id',{method:'POST',headers,body:JSON.stringify({user_id:user.id,tier:'plus_lifetime',status:'active',activated_at:new Date().toISOString()})});
 if(!r.ok)return Response.json({error:'Aktivasi gagal: '+(await r.text()).slice(0,180)},{status:500});
 return Response.json({message:'Misiin Plus Lifetime aktif',active:true});
}
