"""End-to-end check of the Stripe payment flow without a Stripe account.

Start tests/stripe_stub.py (port 12111), then the API in Development with
  --Payments:Provider=Stripe --Payments:Stripe:SecretKey=sk_test_local_stub
  --Payments:Stripe:WebhookSecret=whsec_local_test --Payments:Stripe:ApiBase=http://127.0.0.1:12111
and run: python tests/stripe_e2e.py [api] [stub] [database]
The script uses the Development seed admin and adds its own category, products, customer, vouchers
and orders to the API's database without removing them, so point the API at a test database. It needs
sqlcmd on the LocalDB instance MSSQLLocalDB for five updates (three order deadlines, two payment providers), and
fails if an update finds no row. The expiry checks wait for the background job, so a full run takes
a few minutes.
"""
import hashlib
import hmac
import json
import re
import subprocess
import threading
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone
from urllib import request as rq
from urllib.error import HTTPError

sys.stdout.reconfigure(encoding='utf-8')
API = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:5288'
STUB = sys.argv[2] if len(sys.argv) > 2 else 'http://127.0.0.1:12111'
DB = sys.argv[3] if len(sys.argv) > 3 else 'GundamShopDb'
SECRET = 'whsec_local_test'
RESULTS = []


def call(method, url, body=None, token=None, raw=False, headers=None):
    data = None if body is None else (body if isinstance(body, bytes) else json.dumps(body).encode())
    req = rq.Request(url, data=data, method=method)
    req.add_header('Content-Type', 'application/json')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with rq.urlopen(req, timeout=30) as r:
            text = r.read().decode('utf-8')
            return r.status, (text if raw else (json.loads(text) if text else None)), r.headers.get('Content-Type')
    except HTTPError as e:
        text = e.read().decode('utf-8')
        try:
            return e.code, json.loads(text), None
        except Exception:
            return e.code, text, None


def check(name, cond, detail=''):
    RESULTS.append((name, bool(cond), detail))
    print(('PASS ' if cond else 'FAIL ') + name + (f' | {detail}' if detail else ''))


def sql(query):
    # One row must change, or the API is not using this database.
    query += "; IF @@ROWCOUNT <> 1 THROW 50000, 'no row updated: is the API on this database?', 1;"
    out = subprocess.run(['sqlcmd', '-S', r'(localdb)\MSSQLLocalDB', '-d', DB, '-b', '-I', '-Q', query],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(out.stdout + out.stderr)


def stub_state():
    return call('GET', f'{STUB}/_test/state')[1]


def session_for(order_id):
    return next((s for s in stub_state()['sessions'].values() if s['metadata']['orderId'] == order_id), None)


def webhook(session_id, type_, paid=True, expires_at=None):
    page = {'id': session_id, 'payment_status': 'paid' if paid else 'unpaid'}
    if expires_at is not None:
        page['expires_at'] = expires_at
    payload = json.dumps({'id': f'evt_{uuid.uuid4().hex}', 'type': type_, 'data': {'object': page}})
    stamp = str(int(time.time()))
    sig = hmac.new(SECRET.encode(), f'{stamp}.{payload}'.encode(), hashlib.sha256).hexdigest()
    return call('POST', f'{API}/api/v1/payments/stripe/webhook', payload.encode(),
                headers={'Stripe-Signature': f't={stamp},v1={sig}'})


def utc_epoch(text):
    text = text if text.endswith('Z') or '+' in text[10:] else text + 'Z'
    text = re.sub(r'(\.\d{6})\d+', r'\1', text)  # SQL Server keeps 7 digits, Python before 3.11 reads 6
    return int(datetime.fromisoformat(text.replace('Z', '+00:00')).timestamp())


def wait_status(order_id, token, statuses, seconds=150):
    end = time.time() + seconds
    while time.time() < end:
        o = call('GET', f'{API}/api/v1/orders/{order_id}', token=token)[1]
        if o['status'] in statuses:
            return o
        time.sleep(3)
    return call('GET', f'{API}/api/v1/orders/{order_id}', token=token)[1]


# ---- set-up: admin product with stock, a customer with an address, vouchers
suffix = uuid.uuid4().hex[:8]
admin = call('POST', f'{API}/api/v1/auth/login', {'email': 'admin@gundam.local', 'password': 'Admin123!'})[1]['accessToken']
cat = call('POST', f'{API}/api/v1/categories', {'name': f'Stripe {suffix}', 'slug': f'stripe-{suffix}', 'description': 'e2e'}, admin)[1]
prod = call('POST', f'{API}/api/v1/products', {'categoryId': cat['id'], 'name': f'Stripe Kit {suffix}', 'slug': f'stripe-kit-{suffix}',
                                               'grade': 'HG', 'scale': '1/144', 'description': 'e2e', 'imageUrl': None}, admin)[1]
var = call('POST', f'{API}/api/v1/variants', {'productId': prod['id'], 'sku': f'STRIPE-{suffix}'.upper(), 'label': 'Std',
                                              'priceVnd': 300000, 'initialStock': 50}, admin)[1]
pw = uuid.uuid4().hex + 'Aa1!'
cust = call('POST', f'{API}/api/v1/auth/register', {'email': f'stripe-{suffix}@example.test', 'password': pw, 'fullName': 'Stripe E2E'})[1]['accessToken']
addr = call('POST', f'{API}/api/v1/addresses', {'recipient': 'E2E', 'phone': '0900000000', 'line1': '1 Test', 'ward': 'W',
                                                'district': 'D', 'province': 'HCMC', 'isDefault': True}, cust)[1]


def voucher(discount):
    code = f'ST{uuid.uuid4().hex[:8]}'.upper()
    now = datetime.now(timezone.utc)
    v = call('POST', f'{API}/api/v1/vouchers', {'code': code, 'discountVnd': discount, 'minSubtotalVnd': 0, 'maxUses': 10,
                                                'startsAtUtc': now.replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
                                                'endsAtUtc': (now + timedelta(days=365)).replace(microsecond=0).isoformat().replace('+00:00', 'Z')}, admin)[1]
    return v


def stock():
    return call('GET', f'{API}/api/v1/variants/{var["id"]}')[1]['stock']


def make_order(code=None):
    call('POST', f'{API}/api/v1/cart/items', {'variantId': var['id'], 'quantity': 1}, cust)
    status, o, _ = call('POST', f'{API}/api/v1/orders', {'addressId': addr['id'], 'voucherCode': code}, cust)
    assert status == 201, (status, o)
    return o


def session(order_id, token=None):
    return call('POST', f'{API}/api/v1/payments/orders/{order_id}/session', token=token or cust)


# S1 session: deadline in UTC, return pages at the API address, reuse
o1 = make_order()
started = time.time()
st, s1, _ = session(o1['id'])
ended = time.time()
check('S1 session opens with a Checkout URL', st == 200 and 'cs_test_' in (s1 or {}).get('checkoutUrl', ''), str(s1))
stub_s1 = session_for(o1['id'])
order1 = call('GET', f'{API}/api/v1/orders/{o1["id"]}', token=cust)[1]
# Stripe takes at most 24 hours ahead; the API ends the page 5 minutes inside 24 hours from when the
# order was placed (for clock differences), which is never later than the order deadline.
expected = min(utc_epoch(order1['expiresAtUtc']), utc_epoch(order1['createdAtUtc']) + 24 * 3600 - 300)
check("S1 expires_at is the order deadline in UTC, kept inside Stripe's 24 hours",
      stub_s1 and abs(stub_s1['expires_at'] - expected) <= 1 and stub_s1['expires_at'] < started + 24 * 3600,
      f"stub={stub_s1 and stub_s1['expires_at']} expected={expected} raw={order1['expiresAtUtc']}")
check('S1 success/cancel pages are the API pages', stub_s1 and stub_s1['success_url'] == f'{API}/payment/success?session_id={{CHECKOUT_SESSION_ID}}'
      and stub_s1['cancel_url'] == f'{API}/payment/cancel', f"{stub_s1 and stub_s1['success_url']} | {stub_s1 and stub_s1['cancel_url']}")
creates_before = len([r for r in stub_state()['requests'] if r['path'] == '/v1/checkout/sessions'])
st, s1b, _ = session(o1['id'])
creates_after = len([r for r in stub_state()['requests'] if r['path'] == '/v1/checkout/sessions'])
check('S1 a second call reuses the same page', st == 200 and s1b['checkoutUrl'] == s1['checkoutUrl'] and creates_after == creates_before)

# S2 return pages
for page in ['success', 'cancel']:
    st, body, ctype = call('GET', f'{API}/payment/{page}?session_id=cs_test_x', raw=True)
    check(f'S2 /payment/{page} is a page', st == 200 and 'text/html' in (ctype or '') and '<h1' in body, f'{st} {ctype}')

# S3 webhook paid, then the same event again
st, r, _ = webhook(stub_s1['id'], 'checkout.session.completed')
order1 = call('GET', f'{API}/api/v1/orders/{o1["id"]}', token=cust)[1]
check('S3 completed webhook marks the order paid', st == 200 and order1['status'] == 'Paid', f'{st} {r} {order1["status"]}')

# S4 cancel with an open page closes the page first
o2 = make_order(); session(o2['id']); before = stock()
st, r, _ = call('POST', f'{API}/api/v1/orders/{o2["id"]}/cancel', token=cust)
check('S4 cancel succeeds', st == 200 and r['status'] == 'Cancelled', f'{st} {r}')
check('S4 the Stripe page was expired', session_for(o2['id'])['status'] == 'expired')
check('S4 stock given back', stock() == before + 1, f'{before} -> {stock()}')

# S5 cancel after the customer already paid on Stripe
o3 = make_order(); session(o3['id']); call('POST', f'{STUB}/_test/pay/{session_for(o3["id"])["id"]}')
st, r, _ = call('POST', f'{API}/api/v1/orders/{o3["id"]}/cancel', token=cust)
o3now = call('GET', f'{API}/api/v1/orders/{o3["id"]}', token=cust)[1]
check('S5 cancel refused because the page was paid', st == 409 and 'thanh toán' in (r or {}).get('title', ''), f'{st} {r}')
check('S5 the order is now paid', o3now['status'] == 'Paid' and o3now['paymentStatus'] == 'Paid', str(o3now['status']))

# S6 Stripe ends the page at the deadline: Expired, stock and voucher given back
v6 = voucher(10000); o4 = make_order(v6['code']); session(o4['id']); before = stock()
# A page closed before its expires_at was closed by the API itself (cancel, expiry job), which closes
# the order on its own; Stripe still sends checkout.session.expired for it.
st, r, _ = webhook(session_for(o4['id'])['id'], 'checkout.session.expired', paid=False, expires_at=int(time.time()) + 3600)
o4now = call('GET', f'{API}/api/v1/orders/{o4["id"]}', token=cust)[1]
check('S6 a page closed early does not expire the order', st == 200 and o4now['status'] == 'PendingPayment', f"{st} {o4now['status']}")
st, r, _ = webhook(session_for(o4['id'])['id'], 'checkout.session.expired', paid=False, expires_at=int(time.time()) - 1)
o4now = call('GET', f'{API}/api/v1/orders/{o4["id"]}', token=cust)[1]
v6now = call('GET', f'{API}/api/v1/vouchers/{v6["id"]}', token=admin)[1]
check('S6 expired webhook gives Expired, not PaymentFailed', o4now['status'] == 'Expired' and o4now['paymentStatus'] == 'Expired', f"{o4now['status']}/{o4now['paymentStatus']}")
check('S6 stock and voucher use given back', stock() == before + 1 and v6now['usedCount'] == 0, f'stock {before}->{stock()} used {v6now["usedCount"]}')

# S7 total too small for Stripe
v7 = voucher(295000); o5 = make_order(v7['code'])
st, r, _ = session(o5['id'])
check('S7 too-small total gives a readable 409', st == 409 and 'quá nhỏ' in (r or {}).get('title', ''), f'{st} {r}')

# S8 expiry job closes the page and expires the order
o6 = make_order(); session(o6['id'])
sql(f"UPDATE Orders SET ExpiresAtUtc = DATEADD(minute, -1, SYSUTCDATETIME()) WHERE Id = '{o6['id']}'")
o6now = wait_status(o6['id'], cust, {'Expired', 'Paid', 'PaymentFailed'})
check('S8 expiry job expires the order', o6now['status'] == 'Expired', o6now['status'])
check('S8 and closes its Stripe page', session_for(o6['id'])['status'] == 'expired')

# S9 paid in the last seconds: the job marks it paid instead
o7 = make_order(); session(o7['id']); call('POST', f'{STUB}/_test/pay/{session_for(o7["id"])["id"]}')
sql(f"UPDATE Orders SET ExpiresAtUtc = DATEADD(minute, -1, SYSUTCDATETIME()) WHERE Id = '{o7['id']}'")
o7now = wait_status(o7['id'], cust, {'Expired', 'Paid', 'PaymentFailed'})
check('S9 a page paid before the deadline makes the order Paid', o7now['status'] == 'Paid', o7now['status'])

# S10 an order placed while the provider was Mock
o8 = make_order(); sql(f"UPDATE Payments SET Provider = 'Mock' WHERE OrderId = '{o8['id']}'")
st, r, _ = session(o8['id'])
check('S10 Mock-era order opens a Stripe page', st == 200 and 'cs_test_' in (r or {}).get('checkoutUrl', ''), f'{st} {r}')
st, r, _ = webhook(session_for(o8['id'])['id'], 'checkout.session.completed')
check('S10 and its webhook is accepted', st == 200 and call('GET', f'{API}/api/v1/orders/{o8["id"]}', token=cust)[1]['status'] == 'Paid', f'{st} {r}')
v10 = voucher(300000); o9 = make_order(v10['code']); sql(f"UPDATE Payments SET Provider = 'Mock' WHERE OrderId = '{o9['id']}'")
st, r, _ = session(o9['id'])
check('S10 Mock-era free order is paid at once', st == 200 and (r or {}).get('status') == 'Paid', f'{st} {r}')

# S11 cancel without a Stripe page, by the admin
o10 = make_order()
st, r, _ = call('POST', f'{API}/api/v1/orders/{o10["id"]}/cancel', token=admin)
check('S11 admin cancels an order that never opened a page', st == 200 and r['status'] == 'Cancelled', f'{st} {r}')

# S12 async payment failure is still PaymentFailed; bad signature still refused
o11 = make_order(); session(o11['id'])
webhook(session_for(o11['id'])['id'], 'checkout.session.async_payment_failed', paid=False)
check('S12 async failure gives PaymentFailed', call('GET', f'{API}/api/v1/orders/{o11["id"]}', token=cust)[1]['status'] == 'PaymentFailed')
st, r, _ = call('POST', f'{API}/api/v1/payments/stripe/webhook', b'{"id":"evt_x"}', headers={'Stripe-Signature': 't=1,v1=bad'})
check('S12 a bad signature is refused', st == 400, str(st))

# S13 events about other Stripe objects are acknowledged and ignored
st, r, _ = webhook('pi_test_other', 'payment_intent.succeeded')
check('S13 an unrelated event is answered 200, not processed', st == 200 and r == {'processed': False}, f'{st} {r}')
st, r, _ = webhook('cs_test_never_handed_out', 'checkout.session.expired', paid=False)
check('S13 an unknown page that expired is answered 200, not processed', st == 200 and r == {'processed': False}, f'{st} {r}')
st, r, _ = webhook('cs_test_never_handed_out', 'checkout.session.completed')
check('S13 an unknown page that was paid is still refused', st == 400, f'{st} {r}')

# S14 a page this Stripe account does not know (the key was changed) does not block a cancel
o12 = make_order(); session(o12['id']); call('POST', f'{STUB}/_test/forget/{session_for(o12["id"])["id"]}')
st, r, _ = call('POST', f'{API}/api/v1/orders/{o12["id"]}/cancel', token=cust)
check('S14 cancel succeeds when Stripe no longer has the page', st == 200 and r['status'] == 'Cancelled', f'{st} {r}')

# S15 total above what Stripe takes
big = call('POST', f'{API}/api/v1/variants', {'productId': prod['id'], 'sku': f'STRIPE-BIG-{suffix}'.upper(), 'label': 'Big',
                                              'priceVnd': 100000000, 'initialStock': 5}, admin)[1]
call('POST', f'{API}/api/v1/cart/items', {'variantId': big['id'], 'quantity': 1}, cust)
o13 = call('POST', f'{API}/api/v1/orders', {'addressId': addr['id'], 'voucherCode': None}, cust)[1]
st, r, _ = session(o13['id'])
check('S15 too-large total gives a readable 409', st == 409 and 'vượt mức' in (r or {}).get('title', ''), f'{st} {r}')

# S16 the order is cancelled while Stripe is still creating its page
o14 = make_order(); call('POST', f'{STUB}/_test/slow/3')
slow = {}
worker = threading.Thread(target=lambda: slow.update(r=session(o14['id'])))
worker.start(); time.sleep(1)
st, r, _ = call('POST', f'{API}/api/v1/orders/{o14["id"]}/cancel', token=cust)
worker.join()
check('S16 the cancel goes through', st == 200 and r['status'] == 'Cancelled', f'{st} {r}')
check('S16 the late page is not handed out', slow['r'][0] == 409, str(slow['r'][:2]))
check('S16 and Stripe closed it', (session_for(o14['id']) or {}).get('status') == 'expired', str(session_for(o14['id'])))

# S17 two session requests for one order at the same time, from two addresses (so two Stripe pages)
o15 = make_order(); call('POST', f'{STUB}/_test/slow/3')
both = {}
first = threading.Thread(target=lambda: both.update(a=session(o15['id'])))
first.start(); time.sleep(1)
both['b'] = call('POST', f'{API}/api/v1/payments/orders/{o15["id"]}/session', token=cust, headers={'Host': 'localhost:5288'})
first.join()
pages = [s for s in stub_state()['sessions'].values() if s['metadata']['orderId'] == o15['id']]
check('S17 both requests get the same page', both['a'][0] == 200 and both['b'][0] == 200
      and both['a'][1]['checkoutUrl'] == both['b'][1]['checkoutUrl'], f"{both['a'][:2]} | {both['b'][:2]}")
check('S17 the other page is closed, one stays open', len(pages) == 2 and sorted(p['status'] for p in pages) == ['expired', 'open']
      and next(p for p in pages if p['status'] == 'open')['url'] == both['b'][1]['checkoutUrl'], str([(p['id'][-6:], p['status']) for p in pages]))

def creates_for(order_id):
    return [r for r in stub_state()['requests']
            if r['path'] == '/v1/checkout/sessions' and (r['form'] or {}).get('metadata[orderId]') == order_id]


# S18 the app asks twice at once from the same address: same key, Stripe answers 409 in-use, API retries
o16 = make_order(); call('POST', f'{STUB}/_test/slow/2')
twice = {}
first = threading.Thread(target=lambda: twice.update(a=session(o16['id'])))
first.start(); time.sleep(0.5)
twice['b'] = session(o16['id'])
first.join()
pages = [s for s in stub_state()['sessions'].values() if s['metadata']['orderId'] == o16['id']]
check('S18 a double tap gets the same page twice', twice['a'][0] == 200 and twice['b'][0] == 200
      and twice['a'][1]['checkoutUrl'] == twice['b'][1]['checkoutUrl'], f"{twice['a'][:2]} | {twice['b'][:2]}")
check('S18 Stripe made one page, with one key', len(pages) == 1 and len({r['idempotency'] for r in creates_for(o16['id'])}) == 1
      and len(creates_for(o16['id'])) >= 2, f'{len(pages)} pages, {len(creates_for(o16["id"]))} creates')

# S19 Stripe fails with a 500 (which it would replay for that key): the API tries once with a new key
o17 = make_order(); call('POST', f'{STUB}/_test/fail')
st, r, _ = session(o17['id'])
keys = [c['idempotency'] for c in creates_for(o17['id'])]
check('S19 a Stripe 500 still opens a page', st == 200 and 'cs_test_' in (r or {}).get('checkoutUrl', ''), f'{st} {r}')
check('S19 the second try used a new key', len(keys) == 2 and keys[0] != keys[1] and keys[1].startswith(keys[0]), str(keys))
st, again, _ = session(o17['id'])
check('S19 later calls reuse that page', st == 200 and again['checkoutUrl'] == r['checkoutUrl'] and len(creates_for(o17['id'])) == 2)

# S20 an order too close to its deadline for Stripe (pages must last 30 minutes) gets no page
o18 = make_order()
sql(f"UPDATE Orders SET ExpiresAtUtc = DATEADD(minute, 20, SYSUTCDATETIME()) WHERE Id = '{o18['id']}'")
st, r, _ = session(o18['id'])
check('S20 an order with 20 minutes left gets a readable 409', st == 409 and 'sắp hết hạn' in (r or {}).get('title', ''), f'{st} {r}')
check('S20 and Stripe is not asked', not creates_for(o18['id']))

stripe_calls = [r for r in stub_state()['requests'] if r['path'].startswith('/v1/')]
check('every Stripe call carried the secret key',
      stripe_calls and all(r['auth'].startswith('Bearer sk_test_') for r in stripe_calls), f'{len(stripe_calls)} calls')
creates = [r for r in stripe_calls if r['path'] == '/v1/checkout/sessions']
check('every session creation carried an Idempotency-Key', all(r['idempotency'] for r in creates), f'{len(creates)} creations')
failed = [n for n, ok, _ in RESULTS if not ok]
print(f'\n{len(RESULTS) - len(failed)}/{len(RESULTS)} passed')
sys.exit(1 if failed else 0)
