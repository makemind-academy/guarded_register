# guarded-register

One screen file for both roles; the till refuses what the role may not do and writes it to the audit log.

Article: [who-may-press-this](https://makemind.dev/en/build/who-may-press-this)

## What is here

- `register_server/` — Dart MCP server (`mcp_server` from pub.dev). It holds the data and the tools and serves the app's pages as `ui://` resources.
- `register.mbd/` — the app as a folder of JSON: `manifest.json` and the pages under `ui/`. No build step.
- `captures/` — screenshots taken from AppPlayer by `verify.py`.
- `verify.py`, `verify.sh` — the check.

## Open it in AppPlayer

Add a server app with command `dart`, arguments `run bin/server.dart`, working directory `register_server/`. The server serves its pages; the player draws them.

## Verify

```bash
bash verify.sh
```

Needs AppPlayer with the debug MCP on (see `tools/README.md`). The script builds what needs building, drives the player through the screens above, asserts the claim at the top of this file, and writes `captures/`.
