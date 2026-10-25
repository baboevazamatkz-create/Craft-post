"""Собирает assets/icons/tabler.json из npm-пакета @tabler/icons.

    npm pack @tabler/icons@3.49.0 && tar -xzf tabler-icons-3.49.0.tgz
    python3 tool/icons/build_tabler.py package

Берём только контурные значки из тематик, подходящих для инфографики
электромонтажа (без логотипов брендов, букв, цифр, валют и т. п.):
так список имён, который уходит в AI, короче и дешевле.
"""
import json
import pathlib
import shutil
import sys

KEEP = {
    'System', 'Devices', 'Design', 'Map', 'Document', 'Media', 'E-commerce',
    'Communication', 'Buildings', 'Vehicles', 'Health', 'Weather',
    'Photography', 'Nature', 'Computers', 'Database', 'Charts', 'Symbols',
    'Electrical', 'Gestures',
}

pkg = pathlib.Path(sys.argv[1])
root = pathlib.Path(__file__).resolve().parents[2]
meta = json.loads((pkg / 'icons.json').read_text())
nodes = json.loads((pkg / 'tabler-nodes-outline.json').read_text())
version = json.loads((pkg / 'package.json').read_text())['version']

icons = {}
for name in sorted(nodes):
    if meta.get(name, {}).get('category') not in KEEP:
        continue
    paths = [a['d'] for tag, a in nodes[name] if tag == 'path' and a.get('d')]
    if paths:
        icons[name] = paths

out = root / 'assets' / 'icons'
out.mkdir(parents=True, exist_ok=True)
(out / 'tabler.json').write_text(
    json.dumps({'version': version, 'icons': icons}, separators=(',', ':')))
shutil.copy(pkg / 'LICENSE', out / 'TABLER_LICENSE.txt')
print(f'{len(icons)} icons, version {version}')
