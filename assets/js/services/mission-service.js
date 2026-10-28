import {getSupabase} from './supabase-client.js';
const client=()=>getSupabase();
export async function getMembership(userId){const s=await client();const {data,error}=await s.from('memberships').select('tier,status').eq('user_id',userId).maybeSingle();if(error)throw error;return data?.tier==='plus_lifetime'&&data.status==='active';}
// Rotasi stabil per tanggal WITA; filter/paginasi diterapkan setelah urutan harian.
const witaDay=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Makassar',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
function dailyScore(id,day){let h=2166136261;for(const c of day+':'+id){h=Math.imul(h^c.charCodeAt(0),16777619);}return h>>>0;}
export async function listMissions({search='',category='',difficulty='',sort='newest',min=0,max=150000,page=0,size=12}={}){
 const s=await client();let q=s.from('missions').select('id,title,category,difficulty,description,reward,duration_minutes,deadline,quota,plus_only,submission_type,created_at',{count:'exact'}).eq('status','published').gte('reward',min).lte('reward',max);
 if(category)q=q.eq('category',category);if(difficulty)q=q.eq('difficulty',difficulty);
 if(search)q=q.ilike('title',`%${search.replace(/[%_,]/g,'')}%`);
 // Supabase membatasi jumlah baris per permintaan; ambil bertahap.
 const all=[];for(let start=0;;start+=500){const {data,error}=await q.range(start,start+499);if(error)throw error;all.push(...(data||[]));if(!data||data.length<500)break;}
 const {data:stock,error:stockError}=await s.rpc('mission_availability');if(stockError)throw stockError;
 const availability=new Map((stock||[]).map(x=>[x.mission_id,{remaining:Number(x.remaining),claimed:Number(x.claimed)}]));
 const now=Date.now();const eligible=all.filter(m=>(!m.deadline||new Date(m.deadline).getTime()>now)&&(availability.get(m.id)?.remaining??0)>0).map(m=>({...m,remaining:availability.get(m.id).remaining}));
 const day=witaDay();eligible.sort((a,b)=>sort==='reward'?b.reward-a.reward:sort==='deadline'?(a.deadline?new Date(a.deadline).getTime():Infinity)-(b.deadline?new Date(b.deadline).getTime():Infinity):dailyScore(a.id,day)-dailyScore(b.id,day));
 return {data:eligible.slice(page*size,(page+1)*size),count:eligible.length};
}
export async function getMission(id){const s=await client();const {data,error}=await s.from('missions').select('*').eq('id',id).eq('status','published').single();if(error)throw error;return data;}
export async function listClaims(userId){const s=await client();const {data,error}=await s.from('mission_claims').select('id,mission_id,status,claimed_at,missions(id,title,deadline,reward,submission_type),mission_submissions(answer,result_url,file_path,is_draft,updated_at)').eq('user_id',userId).order('claimed_at',{ascending:false});if(error)throw error;return data||[];}
export async function claimMission(id){const s=await client();const {data,error}=await s.rpc('claim_mission',{p_mission:id});if(error)throw error;return data;}
export async function saveAnswer(claimId,answer,url,path,submit=false){const s=await client();const {data,error}=await s.rpc('save_mission_answer',{p_claim:claimId,p_answer:answer,p_url:url||null,p_path:path||null,p_submit:submit});if(error)throw error;return data;}
export async function getBookmarks(userId){const s=await client();const {data,error}=await s.from('bookmarks').select('mission_id').eq('user_id',userId);if(error)throw error;return new Set((data||[]).map(x=>x.mission_id));}
export async function toggleBookmark(userId,missionId,has){const s=await client();const {error}=has?await s.from('bookmarks').delete().eq('user_id',userId).eq('mission_id',missionId):await s.from('bookmarks').insert({user_id:userId,mission_id:missionId});if(error)throw error;}
export async function uploadEvidence(userId,claimId,file){if(file.size>5*1024*1024)throw Error('Ukuran maksimum 5 MB');if(!['image/png','image/jpeg','image/webp','application/pdf'].includes(file.type))throw Error('Format harus PNG, JPG, WebP, atau PDF');const s=await client();const ext={'image/png':'png','image/jpeg':'jpg','image/webp':'webp','application/pdf':'pdf'}[file.type];const path=`${userId}/${claimId}/${crypto.randomUUID()}.${ext}`;const {error}=await s.storage.from('mission-evidence').upload(path,file,{contentType:file.type,upsert:false});if(error)throw error;return path;}
