import {logoutAndGo} from './services/auth-session.js';
import {getSupabase} from './services/supabase-client.js';
const $=s=>document.querySelector(s), root=$('#admin-content'), status=$('#admin-status');let db,user,section='overview';
let reviewState={pending:[],history:[],page:0,pageSize:20,selected:new Set()};
document.querySelector('#logout')?.addEventListener('click',async e=>{
 try{await logoutAndGo(db||await getSupabase(),e.currentTarget);}
 catch(error){info('Tidak dapat keluar: '+error.message,true);}
});
const sections={overview:'Ringkasan',users:'Pengguna',missions:'Misi',reviews:'Review',payments:'Pembayaran',memberships:'Keanggotaan',withdrawals:'Withdraw',announcements:'Pengumuman',audit:'Audit Log',settings:'Pengaturan Website'};
const esc=v=>String(v??'—').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const rup=v=>new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(Number(v||0));
const date=v=>v?new Date(v).toLocaleString('id-ID'):'—';
function info(t,bad=false){status.textContent=t;status.className=bad?'admin-error':'admin-success';}
async function query(table,cols='*',limit=40){let {data,error}=await db.from(table).select(cols).limit(limit);if(error)throw error;return data||[];}
async function queryAll(table,cols='*',pageSize=1000){let out=[],from=0;while(true){const {data,error}=await db.from(table).select(cols).range(from,from+pageSize-1);if(error)throw error;const batch=data||[];out.push(...batch);if(batch.length<pageSize)break;from+=pageSize;}return out;}
async function queryInChunks(table,cols,column,ids,chunkSize=100){const out=[];for(let i=0;i<ids.length;i+=chunkSize){const {data,error}=await db.from(table).select(cols).in(column,ids.slice(i,i+chunkSize));if(error)throw error;out.push(...(data||[]));}return out;}
async function rpc(name,args){const {error,data}=await db.rpc(name,args);if(error)throw error;return data;}
function table(headers,rows){return `<div class="admin-table-wrap"><table class="admin-table"><thead><tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${rows.length?rows.map(row=>`<tr>${row.map((c,i)=>`<td data-label="${esc(headers[i])}">${c}</td>`).join('')}</tr>`).join(''):`<tr><td colspan="${headers.length}" class="admin-empty">Belum ada data.</td></tr>`}</tbody></table></div>`;}
const btn=(action,id,label)=>`<button data-action="${esc(action)}" data-id="${esc(id)}" type="button">${esc(label)}</button>`;
const short=id=>esc(String(id||'').slice(0,8));
function page(title,html){$('#page-title').textContent=title;root.innerHTML=`<section class="admin-section"><h1>${esc(title)}</h1>${html}</section>`;}
async function render(){info('Memuat data...');try{
 if(section==='settings'){const {mountAdminSettings}=await import('./admin-settings.js');await mountAdminSettings(root);info('Pengaturan dimuat.');return;}
 if(section==='overview'){
 const names=['profiles','missions','mission_claims','payment_orders','withdrawal_requests'];const values=await Promise.all(names.map(async n=>{const {count,error}=await db.from(n).select('*',{count:'exact',head:true});return error?'—':count}));
 page('Ringkasan',`<div class="admin-grid">${names.map((n,i)=>`<article class="admin-card"><div>${esc(n.replaceAll('_',' '))}</div><div class="value">${esc(values[i])}</div></article>`).join('')}</div><p class="admin-note">Statistik mengikuti hak akses RLS dan data yang tersedia.</p>`);
 }else if(section==='users'){
 const rows=await query('profiles','id,display_name,username,created_at');const restrictions=await query('user_restrictions');const suspended=new Set(restrictions.filter(r=>r.suspended).map(r=>r.user_id));
 page('Pengguna',table(['Nama','Username','ID','Status','Aksi'],rows.map(r=>[esc(r.display_name),esc(r.username),short(r.id),suspended.has(r.id)?'Dibatasi':'Aktif',`<div class="admin-actions">${btn('restrict',r.id,suspended.has(r.id)?'Pulihkan':'Batasi')}</div>`])));
 }else if(section==='missions'){
 const rows=await query('missions','id,title,category,reward,quota,deadline,status,plus_only',100);
 page('Kelola Misi',`<div class="admin-toolbar">${btn('new-mission','','+ Tambah misi')}<span class="admin-note">CRUD tersimpan langsung ke Supabase dengan RLS admin dan audit trigger.</span></div>`+table(['Judul','Kategori','Imbalan','Status','Aksi'],rows.map(r=>[esc(r.title),esc(r.category),rup(r.reward),esc(r.status),`<div class="admin-actions">${btn('edit-mission',r.id,'Edit')} ${btn('duplicate-mission',r.id,'Duplikasi')} ${btn('archive-mission',r.id,'Arsip')}</div>`])));
 }else if(section==='reviews'){
  await loadReviews();
  renderReviews();
 }else if(section==='payments'){
 const rows=await query('payment_orders','id,order_code,user_id,amount,status,user_confirmed_at,paid_at,created_at',100);
 page('Pembayaran',`<p class="admin-note">Konfirmasi pengguna bukan bukti lunas. Verifikasi harus melalui webhook gateway tepercaya. Tidak ada tombol paksa paid.</p>`+table(['Order','Pengguna','Nominal','Status','Konfirmasi pengguna','Lunas'],rows.map(r=>[esc(r.order_code),short(r.user_id),rup(r.amount),esc(r.status),date(r.user_confirmed_at),date(r.paid_at)])));
 }else if(section==='memberships'){
 const rows=await query('memberships','user_id,tier,status,activated_at',100);
 page('Keanggotaan',`<p class="admin-note">Entitlement hanya aktif melalui proses pembayaran terverifikasi.</p>`+table(['Pengguna','Tier','Status','Aktivasi'],rows.map(r=>[short(r.user_id),esc(r.tier),esc(r.status),date(r.activated_at)])));
 }else if(section==='withdrawals'){
 const rows=await query('withdrawal_requests','id,user_id,amount,status,admin_note,created_at,account_id',100);
 page('Withdraw',`<p class="admin-note">Tandai Paid hanya setelah transfer aktual selesai dan diverifikasi di luar aplikasi. Sistem belum mentransfer uang otomatis.</p>`+table(['Pengguna','Jumlah','Status','Catatan','Aksi'],rows.map(r=>[short(r.user_id),rup(r.amount),esc(r.status),esc(r.admin_note),`<div class="admin-actions">${r.status==='pending'?btn('processing',r.id,'Proses'):''}${r.status==='processing'?btn('paid',r.id,'Sudah ditransfer'):''}${['pending','processing'].includes(r.status)?btn('reject-withdraw',r.id,'Tolak'):''}</div>`])));
 }else if(section==='announcements'){
 const rows=await query('announcements','id,title,status,publish_at,created_at',100);
 page('Pengumuman',`<div class="admin-toolbar">${btn('new-announcement','','+ Buat pengumuman')}</div>`+table(['Judul','Status','Terbit','Aksi'],rows.map(r=>[esc(r.title),esc(r.status),date(r.publish_at),btn('edit-announcement',r.id,'Edit')])));
 }else if(section==='audit'){
 const rows=await query('audit_logs','id,actor_id,action,entity_id,details,created_at',100);
 page('Audit Log',table(['Waktu','Aktor','Aksi','Entitas','Detail'],rows.map(r=>[date(r.created_at),short(r.actor_id),esc(r.action),short(r.entity_id),esc(JSON.stringify(r.details).slice(0,150))])));
 }
 info('Data diperbarui.');}catch(e){info(e.message,true);root.innerHTML=`<p class="admin-error">${esc(e.message)}</p>`;}}
async function loadReviews(){
 const [claims,missions,profiles,history]=await Promise.all([
  queryAll('mission_claims','id,mission_id,user_id,status,claimed_at,updated_at'),
  queryAll('missions','id,title,reward'),
  queryAll('profiles','id,display_name,username'),
  queryAll('mission_reviews','id,claim_id,submission_id,reviewer_id,decision,reason,created_at')
 ]);
 const claimIds=claims.map(r=>r.id);
 const subs=claimIds.length?await queryInChunks('mission_submissions','id,claim_id,user_id,answer,result_url,file_path,is_draft,submitted_at,updated_at','claim_id',claimIds):[];
 const byClaim=new Map(subs.map(s=>[s.claim_id,s]));
 const missionById=new Map(missions.map(m=>[m.id,m]));
 const profileById=new Map(profiles.map(p=>[p.id,p]));
 const claimById=new Map(claims.map(c=>[c.id,c]));
 const submissionById=new Map(subs.map(sub=>[sub.id,sub]));
 const pending=claims.filter(r=>['submitted','in_review'].includes(r.status)).filter(r=>{const sub=byClaim.get(r.id);return sub&&!sub.is_draft;})
  .sort((a,b)=>new Date(byClaim.get(b.id)?.submitted_at||b.updated_at||0)-new Date(byClaim.get(a.id)?.submitted_at||a.updated_at||0));
 history.sort((a,b)=>new Date(b.created_at||0)-new Date(a.created_at||0));
 reviewState={...reviewState,pending,history,selected:new Set([...reviewState.selected].filter(id=>pending.some(r=>r.id===id))),missionById,profileById,claimById,submissionById,byClaim};
}
function renderReviews(){
 const {pending,history,page:pageNo,pageSize,selected,missionById,profileById,claimById,submissionById,byClaim}=reviewState;
 const totalPages=Math.max(1,Math.ceil(pending.length/pageSize));
 reviewState.page=Math.min(Math.max(0,pageNo),totalPages-1);
 const current= pending.slice(reviewState.page*pageSize,(reviewState.page+1)*pageSize);
 const currentIds=current.map(r=>r.id);
 const allCurrentSelected=currentIds.length>0&&currentIds.every(id=>selected.has(id));
 const reviewRows=current.map(r=>{
  const sub=byClaim.get(r.id),profile=profileById.get(r.user_id),mission=missionById.get(r.mission_id);
  const proof=`<div>${esc((sub?.answer||'').slice(0,500))}</div>${sub?.result_url?`<div><a href="${esc(sub.result_url)}" target="_blank" rel="noopener noreferrer">Buka tautan hasil</a></div>`:''}${sub?.file_path?`<div><small>File: ${esc(sub.file_path)}</small></div>`:''}<small>Dikirim: ${date(sub?.submitted_at)}</small>`;
  const identity=`<strong>${esc(profile?.display_name||'Nama belum tersedia')}</strong><br><small>@${esc(profile?.username||'tanpa-username')} · ${short(r.user_id)}</small>`;
  const mission=`<strong>${esc(mission?.title||'Misi tidak ditemukan')}</strong><br><small>Reward: ${rup(mission?.reward)}</small>`;
  return [`<input type="checkbox" aria-label="Pilih submission ${short(r.id)}" data-review-select="${esc(r.id)}" ${selected.has(r.id)?'checked':''}>`,identity,mission,proof,esc(r.status),`<div class="admin-actions">${btn('approve',r.id,'Setujui')}${btn('revision_requested',r.id,'Revisi')}${btn('rejected',r.id,'Tolak')}</div>`];
 });
 const historyRows=history.slice(0,20).map(event=>{
  const claim=claimById.get(event.claim_id),sub=submissionById.get(event.submission_id),profile=profileById.get(claim?.user_id),mission=missionById.get(claim?.mission_id);
  return [`<strong>${esc(profile?.display_name||'Nama belum tersedia')}</strong><br><small>@${esc(profile?.username||'tanpa-username')} · ${short(claim?.user_id)}</small>`,`<strong>${esc(mission?.title||'Misi tidak ditemukan')}</strong><br><small>Reward: ${rup(mission?.reward)}</small>`,`${esc((sub?.answer||'').slice(0,250))}${sub?.result_url?`<br><a href="${esc(sub.result_url)}" target="_blank" rel="noopener noreferrer">Buka tautan</a>`:''}${event.reason?`<br><small>Alasan: ${esc(event.reason)}</small>`:''}`,esc(event.decision),date(event.created_at)];
 });
 const selectedCount=selected.size;
 const pagination=`<div class="review-pagination"><span>Halaman ${reviewState.page+1} dari ${totalPages} · ${pending.length} submission</span><div class="admin-actions"><button type="button" data-review-page="prev" ${reviewState.page===0?'disabled':''}>Sebelumnya</button><button type="button" data-review-page="next" ${reviewState.page>=totalPages-1?'disabled':''}>Berikutnya</button></div></div>`;
 const bulk=`<div class="review-bulk"><label class="review-select-all"><input type="checkbox" data-review-select-all ${allCurrentSelected?'checked':''}> Pilih semua di halaman ini</label><strong>${selectedCount} dipilih</strong><div class="admin-actions"><button type="button" data-action="bulk-approve" ${selectedCount?'':'disabled'}>Setujui semua</button><button type="button" data-action="bulk-revision" ${selectedCount?'':'disabled'}>Revisi semua</button><button type="button" data-action="bulk-reject" ${selectedCount?'':'disabled'}>Tolak semua</button><button type="button" data-action="clear-selection" ${selectedCount?'':'disabled'}>Batalkan pilihan</button></div></div>`;
 const pendingTable=`<div class="admin-table-wrap"><table class="admin-table"><thead><tr>${['Pilih','Pengerja','Misi','Bukti pengerjaan','Status','Aksi'].map(h=>`<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${reviewRows.length?reviewRows.map(row=>`<tr>${row.map((cell,i)=>`<td data-label="${esc(['Pilih','Pengerja','Misi','Bukti pengerjaan','Status','Aksi'][i])}">${cell}</td>`).join('')}</tr>`).join(''):`<tr><td colspan="6" class="admin-empty">Tidak ada submission yang menunggu review.</td></tr>`}</tbody></table></div>`;
 page('Review Misi',`<div class="admin-toolbar review-summary"><strong>Antrean: ${pending.length} · Riwayat: ${history.length}</strong><label>Data per halaman <select class="admin-filter" data-review-size><option value="20" ${pageSize===20?'selected':''}>20</option><option value="50" ${pageSize===50?'selected':''}>50</option><option value="100" ${pageSize===100?'selected':''}>100</option></select></label></div><h2>Menunggu review</h2>${bulk}${pendingTable}${pagination}<h2>Riwayat keputusan</h2>${table(['Pengerja','Misi','Bukti pengerjaan','Status akhir','Waktu'],historyRows)}<p class="admin-note">Riwayat menampilkan 20 keputusan terbaru dari tabel mission_reviews. Draft tidak masuk antrean. Submission lama yang masih tersimpan tetap dapat direview sesuai statusnya.</p>`);
}
async function bulkReview(action){
 const ids=[...reviewState.selected];if(!ids.length)return;
 const decision=action==='bulk-approve'?'approved':action==='bulk-revision'?'revision_requested':'rejected';
 let reason=null;
 if(decision!=='approved'){reason=prompt(decision==='revision_requested'?'Alasan revisi untuk semua submission terpilih (minimal 5 karakter):':'Alasan penolakan untuk semua submission terpilih (minimal 5 karakter):');if(reason===null)return;if(reason.trim().length<5){alert('Alasan minimal 5 karakter.');return;}}
 const label=decision==='approved'?'menyetujui':decision==='revision_requested'?'meminta revisi':'menolak';
 if(!confirm(`Kamu akan ${label} ${ids.length} submission. Tindakan ini diproses satu per satu. Lanjutkan?`))return;
 info(`Memproses ${ids.length} submission...`);
 const failed=[];let success=0;
 for(const id of ids){try{await rpc('admin_review_submission',{p_claim:id,p_decision:decision,p_reason:reason});success++;}catch(error){failed.push({id,message:error.message});}}
 await loadReviews();reviewState.page=Math.min(reviewState.page,Math.max(0,Math.ceil(reviewState.pending.length/reviewState.pageSize)-1));renderReviews();
 if(failed.length){const details=failed.slice(0,5).map(x=>`${x.id.slice(0,8)}: ${x.message}`).join('\n');info(`${success} berhasil, ${failed.length} gagal. ${details}`,true);alert(`Review massal selesai.\nBerhasil: ${success}\nGagal: ${failed.length}\n\n${details}${failed.length>5?'\nDan kegagalan lainnya.':''}`);}
 else info(`${success} submission berhasil diproses.`);
}
function field(name,value='',type='text'){return `<label>${esc(name)}<input name="${esc(name)}" type="${type}" value="${esc(value)}" required></label>`;}
async function missionForm(id,duplicate=false){let m={};if(id){let {data,error}=await db.from('missions').select('*').eq('id',id).single();if(error)throw error;m=data;}let form=document.createElement('form');form.className='admin-card admin-form';form.innerHTML=`<h2>${id&&!duplicate?'Edit':'Tambah'} misi</h2>${['slug','title','category','difficulty','description','objective','issuer','example_result','submission_type'].map(k=>field(k,m[k]||'')).join('')}${['reward','duration_minutes','quota','revision_limit'].map(k=>field(k,m[k]??(k==='revision_limit'?1:1),'number')).join('')}${field('deadline',m.deadline?.slice(0,16)||'', 'datetime-local')}<p class="form-hint">Kosongkan deadline untuk misi permanen. Isi jika ada batas waktu khusus.</p><label>Status<select name="status">${['draft','published','archived'].map(x=>`<option ${m.status===x?'selected':''}>${x}</option>`).join('')}</select></label><label><input name="plus_only" type="checkbox" ${m.plus_only!==false?'checked':''}> Khusus Plus</label>${['requirements','instructions','materials','review_criteria'].map(k=>`<label>${k} (JSON array)<textarea name="${k}">${esc(JSON.stringify(m[k]||[]))}</textarea></label>`).join('')}<button class="button" type="submit">Simpan misi</button><button type="button" id="cancel-form" class="button secondary">Batal</button>`;root.replaceChildren(form);form.querySelector('#cancel-form').onclick=render;form.onsubmit=async e=>{e.preventDefault();try{let o=Object.fromEntries(new FormData(form));for(const k of ['reward','duration_minutes','quota','revision_limit'])o[k]=Number(o[k]);for(const k of ['requirements','instructions','materials','review_criteria']){o[k]=JSON.parse(o[k]);if(!Array.isArray(o[k]))throw Error(k+' harus JSON array');}o.plus_only=form.elements.plus_only.checked;o.deadline=o.deadline?new Date(o.deadline).toISOString():null;if(duplicate)o.slug+='-copy-'+Date.now().toString(36);const q=id&&!duplicate?db.from('missions').update(o).eq('id',id):db.from('missions').insert(o);const {error}=await q;if(error)throw error;await render();}catch(err){alert(err.message);}};}
async function announcementForm(id){let a={};if(id){const {data,error}=await db.from('announcements').select('*').eq('id',id).single();if(error)throw error;a=data;}let f=document.createElement('form');f.className='admin-card admin-form';f.innerHTML=`<h2>Pengumuman</h2>${field('title',a.title||'')}<label>Isi<textarea name="body" required>${esc(a.body||'')}</textarea></label><label>Status<select name="status">${['draft','published','archived'].map(x=>`<option ${a.status===x?'selected':''}>${x}</option>`).join('')}</select></label><label>Jadwal publikasi<input type="datetime-local" name="publish_at" value="${esc(a.publish_at?.slice(0,16)||'')}"></label><button class="button">Simpan</button>`;root.replaceChildren(f);f.onsubmit=async e=>{e.preventDefault();let v=Object.fromEntries(new FormData(f));try{await rpc('admin_upsert_announcement',{p_id:id||null,p_title:v.title,p_body:v.body,p_status:v.status,p_publish_at:v.publish_at?new Date(v.publish_at).toISOString():null});await render();}catch(err){alert(err.message);}};}
async function act(action,id){try{
 if(action==='new-mission'||action==='edit-mission'||action==='duplicate-mission')return missionForm(id,action==='duplicate-mission');
 if(action==='archive-mission'){if(!confirm('Arsipkan misi?'))return;const {error}=await db.from('missions').update({status:'archived'}).eq('id',id);if(error)throw error;}
 else if(['approve','rejected','revision_requested'].includes(action)){let decision=action==='approve'?'approved':action;let reason=decision==='approved'?null:prompt('Alasan review (minimal 5 karakter):');if(decision!=='approved'&&reason===null)return;if(!confirm('Simpan keputusan '+decision+'?'))return;await rpc('admin_review_submission',{p_claim:id,p_decision:decision,p_reason:reason});}
 else if(['processing','paid','reject-withdraw'].includes(action)){let target=action==='reject-withdraw'?'rejected':action;let note=prompt(target==='paid'?'Masukkan referensi transfer aktual:':'Catatan pemeriksaan:', '');if(note===null)return;if(target==='paid'&&!note.trim())throw Error('Referensi transfer wajib diisi');if(!confirm('Ubah status withdraw menjadi '+target+'?'))return;await rpc('admin_withdrawal_decision',{p_request:id,p_status:target,p_note:note});}
 else if(action==='restrict'){let reason=prompt('Alasan / catatan pembatasan. Isi PULIHKAN untuk membuka kembali:','');if(reason===null)return;await rpc('admin_set_user_restriction',{p_user:id,p_suspended:reason!=='PULIHKAN',p_reason:reason});}
 else if(action==='new-announcement'||action==='edit-announcement')return announcementForm(id);
 await render();}catch(e){alert(e.message);}}
async function init(){try{db=await getSupabase();const {data:{user:u},error}=await db.auth.getUser();if(error||!u){location.replace('/login.html');return;}user=u;const {data:role,error:re}=await db.from('roles').select('role').eq('user_id',u.id).eq('role','super_admin').maybeSingle();if(re)throw re;if(!role){location.replace('/app.html');return;}
 $('#admin-nav').innerHTML=Object.entries(sections).map(([k,v])=>`<button data-section="${k}">${esc(v)}</button>`).join('');$('#admin-nav').onclick=e=>{let b=e.target.closest('[data-section]');if(!b)return;section=b.dataset.section;history.replaceState(null,'','#'+section);$('#admin-side').classList.remove('open');$('#menu-toggle').setAttribute('aria-expanded','false');$('#admin-nav').querySelectorAll('button').forEach(x=>x.setAttribute('aria-current',x===b?'page':'false'));render();};
 root.addEventListener('click',e=>{
  const pageButton=e.target.closest('[data-review-page]');if(pageButton){reviewState.page+=pageButton.dataset.reviewPage==='next'?1:-1;reviewState.selected.clear();renderReviews();return;}
  const b=e.target.closest('[data-action]');if(b){if(b.dataset.action.startsWith('bulk-')){bulkReview(b.dataset.action);return;}if(b.dataset.action==='clear-selection'){reviewState.selected.clear();renderReviews();return;}act(b.dataset.action,b.dataset.id);}
 });
 root.addEventListener('change',e=>{
  if(e.target.matches('[data-review-size]')){reviewState.pageSize=Number(e.target.value)||20;reviewState.page=0;reviewState.selected.clear();renderReviews();return;}
  if(e.target.matches('[data-review-select]')){const id=e.target.dataset.reviewSelect;e.target.checked?reviewState.selected.add(id):reviewState.selected.delete(id);renderReviews();return;}
  if(e.target.matches('[data-review-select-all]')){const start=reviewState.page*reviewState.pageSize;const ids=reviewState.pending.slice(start,start+reviewState.pageSize).map(r=>r.id);if(e.target.checked)ids.forEach(id=>reviewState.selected.add(id));else ids.forEach(id=>reviewState.selected.delete(id));renderReviews();}
 });const closeAdminDrawer=()=>{$('#admin-side').classList.remove('open');$('#admin-backdrop').hidden=true;$('#menu-toggle').setAttribute('aria-expanded','false');};$('#menu-toggle').onclick=()=>{let open=$('#admin-side').classList.toggle('open');$('#admin-backdrop').hidden=!open;$('#menu-toggle').setAttribute('aria-expanded',String(open));};$('#admin-backdrop').onclick=closeAdminDrawer;document.addEventListener('keydown',e=>{if(e.key==='Escape')closeAdminDrawer();});window.matchMedia('(min-width: 1025px)').addEventListener('change',e=>{if(e.matches)closeAdminDrawer();});section=sections[location.hash.slice(1)]?location.hash.slice(1):'overview';$('#admin-nav').querySelector(`[data-section="${section}"]`)?.setAttribute('aria-current','page');await render();}catch(e){info(e.message,true);}}
init();
