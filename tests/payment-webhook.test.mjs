import test from 'node:test';
import assert from 'node:assert/strict';
import {onRequestPost} from '../functions/api/payment/webhook.js';
for (const payload of [
 {type:'payment.paid',amount:10000,order_code:'MSN-PLUS-20261026-123',event_id:'a',transaction_id:'x'},
 {type:'payment.failed'},
 {},
]) {
 test('webhook refuses unverified provider payload', async () => {
  const response=await onRequestPost({request:new Request('https://example.test/api/payment/webhook',{method:'POST',body:JSON.stringify(payload)}),env:{PAYMENT_PROVIDER_VERIFIED_ADAPTER:'enabled',PAYMENT_WEBHOOK_SECRET:'test'}});
  assert.equal(response.status,503);
  assert.match((await response.json()).error,/belum dikonfigurasi/);
 });
}
