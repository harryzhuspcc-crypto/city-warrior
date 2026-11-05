# Web release

```sh
python3 tools/run_smoke_tests.py
python3 tools/build_web.py
```

The Web preset produces a release build in `build/web/` (git-ignored), using
Godot's single-threaded Compatibility template. Set `GODOT_BIN` if Godot is
not on PATH or installed at `/Applications/Godot.app/Contents/MacOS/Godot`.
Install matching export templates first.
The builder also loads all three scenes from the exported PCK in a headless
harness and rejects script/resource diagnostics before reporting success.

All three stages and runtime GDScript classes are included. Raw source sheets,
reference assets, test tools, documentation and unused music are excluded.
Using all runtime resources is intentional: several `class_name` workers are
referenced only through GDScript types, not an explicit scene dependency.

Upload the full generated directory, not just `index.html`. Keep relative
filenames intact so the game can be hosted in a website subdirectory.
The single-threaded build does not require SharedArrayBuffer/COOP/COEP.

Cloudflare Workers static assets are limited to 25 MiB per file. The default
Godot WASM exceeds this, so that host requires the same split-WASM fetch
adapter used by the existing First Game embed, or a separate object-storage
host. Do not upload the unmodified large file to Workers assets.

The export script only builds locally; it never uploads, deploys another
project, changes Git remotes, or reads deployment credentials. Confirm the
target website/project before publishing the generated game.
