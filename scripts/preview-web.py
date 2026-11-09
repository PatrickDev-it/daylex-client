"""Loopback-only preview; --fixture uses explicit synthetic API responses for UI tests."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import urllib.error
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--fixture', action='store_true')
parser.add_argument('--port', type=int, default=8765)
args = parser.parse_args()
directory = Path(__file__).resolve().parents[1] / 'app/build/web'

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.mjs': 'text/javascript', '.js': 'text/javascript', '.wasm': 'application/wasm'}
    def __init__(self, *params, **kwargs):
        super().__init__(*params, directory=str(directory), **kwargs)

    def do_GET(self):
        if self.path.startswith('/v1/'):
            return self.api()
        if self.path == '/':
            self.send_response(302)
            self.send_header('Location', '/app/')
            self.end_headers()
            return
        if not self.path.startswith('/app/'):
            return self.send_error(404)
        self.path = self.path.removeprefix('/app')
        super().do_GET()

    def do_POST(self):
        self.api()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; worker-src 'self' blob:; frame-src 'self' blob:; base-uri 'self'; frame-ancestors 'none'")
        super().end_headers()

    def api(self):
        if not self.path.startswith('/v1/'):
            return self.send_error(404)
        body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        if args.fixture:
            accepted = self.headers.get('Authorization') == 'Bearer dlx_' + 'A' * 43
            if self.path == '/v1/tools':
                code, data = (200, {'tools': []}) if accepted else (401, {'detail': 'Chiave di test non valida'})
            elif 'status' in self.path or 'presence' in self.path:
                code, data = 200, {'schema': 1, 'maintenance': False, 'message': ''}
            elif self.path == '/v1/documents/review' and accepted:
                code, data = 200, {'revision': 'synthetic-preview', 'complete': True, 'issues': [], 'pdf': {'complete': True, 'issues': []}}
            else:
                code, data = 503, {'detail': 'Anteprima locale: servizio AI non simulato'}
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
            return
        headers = {key: value for key, value in self.headers.items() if key.lower() not in ('host', 'connection', 'content-length')}
        request = urllib.request.Request('https://api.daylex.it' + self.path, data=body if self.command == 'POST' else None, headers=headers)
        try:
            response = urllib.request.urlopen(request, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        self.send_response(response.status)
        self.send_header('Content-Type', response.headers.get('Content-Type', 'application/json'))
        self.end_headers()
        self.wfile.write(response.read())

ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
