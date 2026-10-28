#!/usr/bin/env python3
"""Fetch the pinned upstream release's model assets without executing its binaries."""
from pathlib import Path
import hashlib
import io
import urllib.request
import zipfile
ROOT = Path(__file__).resolve().parents[1]
URL = 'https://github.com/UzenUPoZiTiV4ik/fsr4-native-macos/releases/download/crossover-v2.2/fsr4-mac-v2.2-crossover.zip'
SHA256 = '2401f3232e04097ddfc10d0b37e745078c7c693ff98cc769acb33e355e47166e'
with urllib.request.urlopen(URL) as response:
    payload = response.read()
if hashlib.sha256(payload).hexdigest() != SHA256:
    raise SystemExit('Release checksum mismatch; no files extracted')
count = 0
with zipfile.ZipFile(io.BytesIO(payload)) as archive:
    for entry in archive.infolist():
        relative = Path(*Path(entry.filename).parts[1:])
        if '..' in relative.parts or relative.is_absolute():
            raise SystemExit('Unsafe archive path')
        if str(relative).startswith('build/fsr412_model/') and not entry.is_dir():
            dest = ROOT / 'vendor/fsr4-native-macos' / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(archive.read(entry))
            count += 1
print(f'Installed {count} model files from verified crossover-v2.2 release')
