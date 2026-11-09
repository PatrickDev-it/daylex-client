"""Render tracked website templates against an existing public release inventory.

Usage: python scripts/render-site.py [site directory]
The same small rendering functions are used by the root-owned deployment receiver.
"""
import ast
import html
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
site = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'site'
module = ast.parse((root / 'scripts/deploy-server.py').read_text(encoding='utf-8'))
selected = ast.Module(body=[node for node in module.body if isinstance(node, ast.FunctionDef)
                           and node.name in ('article', 'marketing_article', 'render_site')], type_ignores=[])
namespace = dict(html=html, json=json, re=re)
exec(compile(selected, 'deploy-server.py', 'exec'), namespace)
release = json.loads((site / 'release.json').read_text())
packages = []
for platform in ('windows', 'macos', 'linux'):
    item = release[platform]
    packages.append(dict(platform=platform, installer=Path(item['url']).name, installer_size=item['bytes'],
                         installer_sha256=item['sha256'], version=item['version'], build=item['build'],
                         authenticode=item.get('authenticode', False), notarized=item.get('notarized', False),
                         signing=item.get('signing'), linux_minimum=item.get('linux_minimum') or '26.04'))
namespace['render_site'](site, packages)
print(f'Website rendered from desktop build {release["build"]}')
