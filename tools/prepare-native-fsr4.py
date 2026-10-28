#!/usr/bin/env python3
"""Stage native FSR resources inside a game's sandbox, without changing entitlements."""
from pathlib import Path
import os
import plistlib
import re
import shutil
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
APPS = {'cyberpunk': Path('/Applications/Cyberpunk2077.app'), 'crimson': Path('/Applications/CrimsonDesert.app')}
if len(sys.argv) != 2 or sys.argv[1] not in APPS:
    raise SystemExit('Usage: prepare-native-fsr4.py cyberpunk|crimson')
info = plistlib.loads((APPS[sys.argv[1]]/'Contents/Info.plist').read_bytes())
binary = APPS[sys.argv[1]]/'Contents/MacOS'/info['CFBundleExecutable']
if subprocess.run(['pgrep', '-f', '^'+re.escape(str(binary))], stdout=subprocess.DEVNULL).returncode == 0:
    raise SystemExit('Quit the target game before preparing its runtime')
stage = Path.home()/'Library/Containers'/info['CFBundleIdentifier']/'Data/Library/Application Support/NativeFSR4'
source = ROOT/'vendor/fsr4-native-macos'
model = source/'build/fsr412_model'
if not model.exists():
    raise SystemExit('Run python3 tools/setup-fsr4-model.py first')
stage.mkdir(parents=True, exist_ok=True)
(stage/"logs").mkdir(exist_ok=True)
shutil.copytree(source, stage, dirs_exist_ok=True,
    ignore=shutil.ignore_patterns('.git', 'build', 'dist', 'tests', '__pycache__', '.DS_Store'))
shutil.copytree(model, stage/'build/fsr412_model', dirs_exist_ok=True)
for name in ['libbg3fsr4.dylib', 'libnativefsr4.dylib']:
    # Fresh inode preserves arm64 code-signature cache correctness.
    dest = stage/name
    temporary = stage/('.'+name+'.new')
    shutil.copy2(ROOT/'build'/name, temporary)
    temporary.replace(dest)
env = dict(os.environ, FSR4_ROOT=str(stage), FSR4_BUILD_DIR=str(stage/'build'),
    FSR4_SETTINGS='none', FSR4_VERSION='4.1.2', FSR4_PROFILE='int8-lite',
    FSR4_MODEL='auto', FSR4_RCAS='0', FSR4_COMPILE='1',
    DYLD_INSERT_LIBRARIES=str(stage/'libnativefsr4.dylib'))
# Warm the shaders for the observed native game's linear HDR, reversed-depth,
# render-resolution un-jittered motion path, then prove compilation is optional.
for compile_flag in ['1', '0']:
    env['FSR4_COMPILE'] = compile_flag
    subprocess.run([str(ROOT/'build/native-fsr4-smoke'), str(stage/'libbg3fsr4.dylib'), 'large'], env=env, check=True)
(stage/'prepared.txt').write_text('FSR 4.1.2 Lite; tier 2160; reversed depth; linear HDR; low-res unjittered MV; auto exposure off\n')
print(f'Prepared sandbox runtime: {stage}')
