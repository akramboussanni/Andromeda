# Andromeda

## Host a server on Windows

Players and server operators do not need to clone these repositories. Download the Windows server bundle from Releases, extract it, and run `core\Setup-Andromeda-Server.bat`. The standard deployment runs a single API, `Andromeda.Core`, which starts game sessions locally.

For a bootstrap-only install, download and run `server/Setup-Andromeda-Server.ps1`; it fetches the latest published server bundle. Maintainers build the deterministic release zip with:

```bash
python server/build_server_bundle.py --version 0.11.6 --mod-version 0.11.6
```

`Andromeda.Orchestrator` is retained for advanced multi-host deployments only.

Andromeda is a game mod distribution setup with two coordinated repositories: `Andromeda.Mod` and `Andromeda.Installer`.

`Andromeda.Mod` contains the gameplay and runtime patching logic.

`Andromeda.Installer` installs MelonLoader, downloads and installs the mod from the latest `Andromeda.Mod` GitHub release, and applies the required configuration so the mod is ready to run with minimal manual setup.

The top-level Andromeda repository links both components as submodules so they can be versioned and released together while still being maintained independently.

Discord: https://discord.gg/fMbrCUKHP8
