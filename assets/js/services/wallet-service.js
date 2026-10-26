import {getSupabase} from './supabase-client.js';
const check=(r)=>{if(r.error)throw r.error;return r.data};
export async function walletOverview(userId){const db=await getSupabase();const [bal,ledger,accounts,requests,settings]=await Promise.all([
 db.from('wallet_balances').select('balance').eq('user_id',userId).maybeSingle(),
 db.from('wallet_ledger').select('id,kind,amount,reference,note,created_at').eq('user_id',userId).order('created_at',{ascending:false}).limit(100),
 db.from('withdrawal_accounts').select('id,provider,account_number,account_name').eq('user_id',userId).order('created_at',{ascending:false}),
 db.from('withdrawal_requests').select('id,amount,status,created_at,account_id').eq('user_id',userId).order('created_at',{ascending:false}).limit(50),
 db.from('app_settings').select('key,value').in('key',['minimum_withdrawal','registration_bonus','profile_bonus'])
 ]);return {balance:Number(check(bal)?.balance||0),ledger:check(ledger),accounts:check(accounts),requests:check(requests),settings:Object.fromEntries(check(settings).map(x=>[x.key,Number(x.value)]))};}
export async function claimProfileBonus(){const db=await getSupabase();return check(await db.rpc('claim_profile_completion_bonus'));}
export async function saveWithdrawalAccount(userId,provider,accountNumber,accountName){const db=await getSupabase();return check(await db.from('withdrawal_accounts').insert({user_id:userId,provider,account_number:accountNumber,account_name:accountName}).select('id').single());}
export async function requestWithdrawal(accountId,amount,requestKey){const db=await getSupabase();return check(await db.rpc('request_withdrawal',{p_account:accountId,p_amount:amount,p_request_key:requestKey}));}
