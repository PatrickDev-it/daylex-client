import ast
from pathlib import Path
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
import live_http


class LiveCheckTests(unittest.TestCase):
    def test_checks_do_not_send_urllibs_default_user_agent(self):
        # Cloudflare answers Python-urllib/* with 403: a passing publication would read as failed and be redone.
        self.assertNotIn('urllib', live_http.USER_AGENT.lower())
        for script in sorted(SCRIPTS.glob('verify-*.py')):
            calls = [node.func.attr for node in ast.walk(ast.parse(script.read_text(encoding='utf-8')))
                     if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)]
            self.assertNotIn('urlopen', calls, f'{script.name} must read the live site through live_http')


if __name__ == '__main__':
    unittest.main()
