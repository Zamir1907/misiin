export function json(data,status=200){return Response.json(data,{status,headers:{'cache-control':'no-store'}})}
export function config(env){if(!env.SUPABASE_URL||!env.SUPABASE_SERVICE_ROLE_KEY||!env.SUPABASE_PUBLISHABLE_KEY)throw Error('Backend belum dikonfigurasi');return {url:env.SUPABASE_URL.replace(/\/$/,''),service:env.SUPABASE_SERVICE_ROLE_KEY,pub:env.SUPABASE_PUBLISHABLE_KEY}}
export async function supa(cfg,path,token,body,method='POST'){
 const res=await fetch(`${cfg.url}/rest/v1/${path}`,{method,headers:{apikey:cfg.service,authorization:`Bearer ${token}`, 'content-type':'application/json',...(path.startsWith('rpc/')?{}:{prefer:'return=representation'})},...(body===undefined?{}:{body:JSON.stringify(body)})});
 const data=await res.json().catch(()=>null);if(!res.ok)throw Error(data?.message||data?.error_description||`Supabase ${res.status}`);return data;
}
export async function currentUser(request,cfg){const bearer=request.headers.get('authorization')||'';if(!/^Bearer [A-Za-z0-9._-]+$/.test(bearer))throw Error('Sesi diperlukan');const token=bearer.slice(7);const res=await fetch(`${cfg.url}/auth/v1/user`,{headers:{apikey:cfg.pub,authorization:`Bearer ${token}`}});if(!res.ok)throw Error('Sesi tidak valid');const user=await res.json();if(!user.id)throw Error('Sesi tidak valid');return user;}
export function fail(err){return json({error:err.message||'Kesalahan server'},/Sesi/.test(err.message)?401:400)}
