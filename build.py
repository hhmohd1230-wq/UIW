"""Join the parts listed in manifest.txt into dist/UIW.lua (same as build.ps1)."""
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent
engine = (root / 'src/inventory/engine.lua').read_text(encoding='utf-8-sig')
assert ']========]' not in engine
(root / 'src/inventory/bundle.lua').write_bytes(
    ('-- Generated from src/inventory/engine.lua; isolated Luau chunk.\n'
     'local UIWInventorySource = [========[\n' + engine + '\n]========]\n').encode('utf-8'))
parts = []
for line in (root / "manifest.txt").read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    path = root / line
    if not path.is_file():
        sys.exit(f"Missing part: {line}")
    parts.append(path.read_text(encoding="utf-8-sig").replace("\r\n", "\n"))

out = root / "dist" / "UIW.lua"
out.parent.mkdir(exist_ok=True)
out.write_bytes("".join(parts).encode("utf-8"))
print(f"Built dist/UIW.lua ({out.stat().st_size} bytes, {len(parts)} parts)")
