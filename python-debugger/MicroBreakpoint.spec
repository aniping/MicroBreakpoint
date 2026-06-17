# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path


block_cipher = None

BASE_DIR = Path(SPECPATH).resolve()

datas = [
    (str(BASE_DIR / "desktop" / "qml"), "desktop/qml"),
    (str(BASE_DIR / "app" / "models" / "schema.sql"), "app/models"),
]

optional_dirs = [
    ("backend", "backend"),
    ("desktop/assets", "desktop/assets"),
    ("assets", "assets"),
    ("config", "config"),
]

for src, dst in optional_dirs:
    src_path = BASE_DIR / src
    if src_path.exists():
        datas.append((str(src_path), dst))

java_jar = BASE_DIR.parent / "java-debugger" / "target" / "micro-breakpoint-debugger-0.1.0.jar"
if java_jar.is_file() and not (BASE_DIR / "backend").exists():
    datas.append((str(java_jar), "backend"))

a = Analysis(
    ["run_desktop.py"],
    pathex=[str(BASE_DIR)],
    binaries=[],
    datas=datas,
    hiddenimports=[
        "PySide6.QtCore",
        "PySide6.QtGui",
        "PySide6.QtQml",
        "PySide6.QtQuick",
        "PySide6.QtQuickControls2",
        "PySide6.QtWidgets",
        "flask",
        "flask_cors",
        "werkzeug",
        "werkzeug.serving",
        "requests",
        "sqlite3",
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
    optimize=0,
)

pyz = PYZ(
    a.pure,
    a.zipped_data,
    cipher=block_cipher,
)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="MicroBreakpoint",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    contents_directory=".",
    uac_admin=True,
    uac_uiaccess=False,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name="MicroBreakpoint",
)
