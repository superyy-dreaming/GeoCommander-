"""Local-only OpenAI-compatible protocol fixture. Never logs headers or request bodies."""
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import json, time
from pathlib import Path
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def reply(self, code, data):
        payload = json.dumps(data).encode()
        try:
            self.send_response(code); self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', str(len(payload))); self.end_headers(); self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError): pass
    def do_GET(self):
        if '/no-models/' in self.path: return self.reply(503, {'error': 'list unavailable'})
        self.reply(200, {'data': [{'id': 'good'}, {'id': 'manual-model'}]})
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        model = data.get('model')
        if model == 'slow': time.sleep(.25)
        if model == 'stalled': time.sleep(1.25)
        if model == 'auth': return self.reply(401, {'error': {'code': 'invalid_api_key'}})
        if model == 'missing': return self.reply(404, {'error': {'code': 'model_not_found'}})
        if model == 'redirect':
            self.send_response(307); self.send_header('Location', '/other'); self.end_headers(); return
        if model == 'invalid': return self.reply(200, {'wrong': True})
        if model == 'oversize': return self.reply(200, {'text': 'a' * (1024 * 1024 + 100)})
        content = 'OK'
        if len(data.get('messages', [])) > 1:
            content = json.dumps({'version':1,'unit_type':'triangle','base':{'movement':'flank_sides','priority':'ranged_or_commander','skill_cond':'backstab_or_grav','retreat_hp':.2,'lane_mode':'auto','stance':'balanced','behavior':'normal','skill_usage':'auto'},'rules':[{'id':'low_hp','when':{'fact':'self_hp','op':'lt','value':.3},'actions':{'behavior':'retreat'}}]})
        if model == 'bad-json': content = '```json\n{}\n```'
        if model in ('plan-v2', 'plan-v2-invalid'):
            plan = json.loads((Path(__file__).parent / 'fixtures/tactic-v2-triangle.json').read_text())
            if model == 'plan-v2-invalid': plan['plan']['steps'][0]['speed'] = 999
            content = json.dumps(plan, ensure_ascii=False)
        self.reply(200, {'choices': [{'message': {'content': content}}]})
ThreadingHTTPServer(('127.0.0.1', 18741), Handler).serve_forever()
