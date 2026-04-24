# Andromeda

![Andromeda banner](Andromeda.Mod/Assets/banner.png)

Andromeda is a community-run platform that keeps **Enemy On Board** playable through modern hosting, runtime patches, and player-first tooling.

[![Join Discord](https://img.shields.io/badge/Discord-Join%20the%20Community-5865F2?logo=discord&logoColor=white)](https://discord.gg/fMbrCUKHP8)
[![Releases](https://img.shields.io/badge/Downloads-GitHub%20Releases-2ea44f?logo=github&logoColor=white)](https://github.com/akramboussanni/Andromeda/releases)

## Community First

Discord is the center of the Andromeda community for support, announcements, testing coordination, and finding people to play with.

- Discord invite: **https://discord.gg/fMbrCUKHP8**
- Join first if you want help setting up or troubleshooting quickly.

## Downloads

Grab builds from the GitHub Releases page:

- Andromeda aggregated releases: https://github.com/akramboussanni/Andromeda/releases
- Installer upstream releases: https://github.com/akramboussanni/Andromeda.Installer/releases

Current installer filenames:

- Windows: `Andromeda.Installer.exe`
- Linux: `Andromeda.Installer.Linux`

If you are unsure which one to use, start with `Andromeda.Installer.exe` on Windows.

## What Is Andromeda?

Andromeda is a community replacement stack for Enemy On Board's online systems.
It combines a client mod, installer, backend API, and game-session host runtime so players can still launch, matchmake, and play together on maintained infrastructure.

## How It Works (Quick)

1. You install Andromeda with the installer release.
2. The mod patches the game at runtime and points it to Andromeda services.
3. Andromeda Core handles party flow, matchmaking, and account/progression logic.
4. The Orchestrator starts and manages dedicated sessions when matches are created.
5. Discord is the main community hub for support, announcements, and coordination.

## Platform Components

- [`Andromeda.Mod`](./Andromeda.Mod): gameplay/runtime patches and server-routing logic.
- [`Andromeda.Installer`](./Andromeda.Installer): guided install/update flow for players.
- [`Andromeda.Core`](./Andromeda.Core): central API for party flow, auth, progression, and session orchestration.
- [`Andromeda.Orchestrator`](./Andromeda.Orchestrator): host runtime for creating and stopping dedicated sessions.
- `bot` (private): the production Discord bot is closed-source and not distributed for public use.

## Community

Join the Andromeda Discord for support, announcements, matchmaking, and development updates:

**https://discord.gg/fMbrCUKHP8**
