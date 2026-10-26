import {json} from './_shared.js';
// Fail closed: a shared HMAC over a caller-supplied payload is NOT proof that a
// payment provider settled a transaction. Implement a provider-specific adapter
// that validates the provider's signature and independently retrieves payment
// status, merchant account, currency, amount and transaction ID before invoking
// plus_verify_payment with a backend-only credential.
export async function onRequestPost(){
 return json({error:'Verifikasi gateway pembayaran belum dikonfigurasi'},503);
}
