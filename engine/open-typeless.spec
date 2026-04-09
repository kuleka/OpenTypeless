# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for OpenTypeless Engine

import os

block_cipher = None
engine_dir = os.path.dirname(os.path.abspath(SPEC))

a = Analysis(
    [os.path.join(engine_dir, 'open_typeless', 'cli.py')],
    pathex=[engine_dir],
    binaries=[],
    datas=[
        (os.path.join(engine_dir, 'open_typeless', 'prompts'), 'open_typeless/prompts'),
    ],
    hiddenimports=[
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'uvicorn.lifespan.off',
        'fastapi',
        'fastapi.routing',
        'fastapi.middleware',
        'fastapi.middleware.cors',
        'pydantic',
        'pydantic.deprecated.decorator',
        'httpx',
        'yaml',
        'multipart',
        'multipart.multipart',
        'open_typeless',
        'open_typeless.server',
        'open_typeless.cli',
        'open_typeless.config',
        'open_typeless.context',
        'open_typeless.llm',
        'open_typeless.models',
        'open_typeless.prompt_router',
        'open_typeless.stt',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'scipy',
        'pandas',
        'PIL',
        'cv2',
        'torch',
        'tensorflow',
    ],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='open-typeless',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    target_arch='arm64',
)
