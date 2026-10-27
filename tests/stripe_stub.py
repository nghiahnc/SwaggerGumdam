"""A tiny stand-in for the parts of the Stripe API the shop calls (used by tests/stripe_e2e.py).

POST /v1/checkout/sessions            create a session (400 amount_too_small below 10 000 VND,
                                      amount_too_large above 99 999 999 VND; test values only: Stripe's
                                      real limits depend on the payment method and on the account's
                                      settlement currency; 400 when expires_at is not 30 minutes to 24
                                      hours ahead). Like Stripe, a repeated Idempotency-Key gets the
                                      first answer back (a page or a 500, not a 400), 400 when the
                                      parameters differ, and 409 idempotency_key_in_use while the
                                      first request with that key is still running.
POST /v1/checkout/sessions/{id}/expire  expire an open session (400 when it is not open)
GET  /v1/checkout/sessions/{id}         read a session
POST /_test/pay/{id}                   mark a session paid, as if the customer paid
POST /_test/forget/{id}                drop a session, as if it belonged to another Stripe account
POST /_test/slow/{seconds}             make the next session creation take that long
POST /_test/fail                       make the next session creation fail with a 500
GET  /_test/state                      every session and every request seen
"""
import json
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 12111
LOCK = threading.Lock()
SESSIONS = {}
REQUESTS = []
IDEMPOTENT = {}
INFLIGHT = set()
SLOW = [0.0]
FAIL = [False]


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body):
        data = json.dumps(body).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _record(self, form=None):
        REQUESTS.append({
            'method': self.command,
            'path': urlparse(self.path).path,
            'auth': self.headers.get('Authorization', ''),
            'idempotency': self.headers.get('Idempotency-Key'),
            'form': form,
        })

    def log_message(self, *args):
        pass

    def _create(self, form):
        key = self.headers.get('Idempotency-Key')
        with LOCK:
            self._record(form)
            if not self.headers.get('Authorization', '').startswith('Bearer sk_test_'):
                return self._send(401, {'error': {'message': 'bad key'}})
            if key in INFLIGHT:
                return self._send(409, {'error': {'type': 'idempotency_error', 'code': 'idempotency_key_in_use',
                                                  'message': 'There is currently another in-progress request using this Idempotent Key.'}})
            if key in IDEMPOTENT:
                first_form, status, body = IDEMPOTENT[key]
                if first_form != form:
                    return self._send(400, {'error': {'type': 'idempotency_error',
                                                      'message': 'Keys for idempotent requests can only be used with the same parameters they were first used with.'}})
                return self._send(status, body)
            if key:
                INFLIGHT.add(key)
            delay, SLOW[0] = SLOW[0], 0.0
            fail, FAIL[0] = FAIL[0], False
        time.sleep(delay)
        with LOCK:
            INFLIGHT.discard(key)
            status, body = self._new_session(form, fail)
            # Stripe keeps the answer once the request ran (a page or a 500), not a refused request.
            if key and status in (200, 500):
                IDEMPOTENT[key] = (form, status, body)
            return self._send(status, body)

    @staticmethod
    def _new_session(form, fail):
        if fail:
            return 500, {'error': {'type': 'api_error', 'message': 'An unknown error occurred'}}
        amount = int(form.get('line_items[0][price_data][unit_amount]', '0'))
        if amount < 10000:
            return 400, {'error': {'code': 'amount_too_small', 'message': 'Amount too small'}}
        if amount > 99999999:
            return 400, {'error': {'code': 'amount_too_large', 'message': 'Amount too large'}}
        expires_at = int(form.get('expires_at', '0'))
        if not time.time() + 1800 <= expires_at <= time.time() + 86400:
            return 400, {'error': {'type': 'invalid_request_error', 'param': 'expires_at',
                                   'message': 'The expires_at must be between 30 minutes and 24 hours from now.'}}
        # Unique across restarts, as the database keeps every session id it was given.
        sid = f'cs_test_stub{uuid.uuid4().hex}'
        SESSIONS[sid] = {
            'id': sid, 'object': 'checkout.session',
            'url': f'https://checkout.stripe.com/c/pay/{sid}',
            'status': 'open', 'payment_status': 'unpaid',
            'expires_at': expires_at,
            'success_url': form.get('success_url'),
            'cancel_url': form.get('cancel_url'),
            'amount_total': amount,
            'metadata': {'orderId': form.get('metadata[orderId]')},
        }
        return 200, dict(SESSIONS[sid])

    def do_GET(self):
        path = urlparse(self.path).path
        with LOCK:
            if path == '/_test/state':
                return self._send(200, {'sessions': SESSIONS, 'requests': REQUESTS})
            self._record()
            if not self.headers.get('Authorization', '').startswith('Bearer sk_test_'):
                return self._send(401, {'error': {'message': 'bad key'}})
            if path.startswith('/v1/checkout/sessions/'):
                sid = path.rsplit('/', 1)[1]
                s = SESSIONS.get(sid)
                if not s:
                    return self._send(404, {'error': {'code': 'resource_missing'}})
                return self._send(200, s)
        self._send(404, {'error': {'message': 'unknown path'}})

    def do_POST(self):
        path = urlparse(self.path).path
        length = int(self.headers.get('Content-Length') or 0)
        raw = self.rfile.read(length).decode('utf-8') if length else ''
        form = {k: v[0] for k, v in parse_qs(raw).items()}
        if path == '/v1/checkout/sessions':
            return self._create(form)
        with LOCK:
            if path == '/_test/fail':
                FAIL[0] = True
                return self._send(200, {'fail': True})
            if path.startswith('/_test/slow/'):
                SLOW[0] = float(path.rsplit('/', 1)[1])
                return self._send(200, {'slow': SLOW[0]})
            if path.startswith('/_test/forget/'):
                return self._send(200, SESSIONS.pop(path.rsplit('/', 1)[1]))
            if path.startswith('/_test/pay/'):
                sid = path.rsplit('/', 1)[1]
                SESSIONS[sid].update(status='complete', payment_status='paid')
                return self._send(200, SESSIONS[sid])
            self._record(form)
            if not self.headers.get('Authorization', '').startswith('Bearer sk_test_'):
                return self._send(401, {'error': {'message': 'bad key'}})
            if path.startswith('/v1/checkout/sessions/') and path.endswith('/expire'):
                sid = path.split('/')[4]
                s = SESSIONS.get(sid)
                if not s:
                    return self._send(404, {'error': {'code': 'resource_missing'}})
                if s['status'] != 'open':
                    return self._send(400, {'error': {'message': 'Only Checkout Sessions with a status in ["open"] can be expired.'}})
                s['status'] = 'expired'
                return self._send(200, s)
        self._send(404, {'error': {'message': 'unknown path'}})


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
