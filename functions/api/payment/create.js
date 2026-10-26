import {config,currentUser,supa,json,fail} from './_shared.js';
export async function onRequestPost({request,env}){try{const cfg=config(env),user=await currentUser(request,cfg);const order=await supa(cfg,'rpc/plus_create_order',cfg.service,{p_user:user.id});return json({order});}catch(e){return fail(e)}}
