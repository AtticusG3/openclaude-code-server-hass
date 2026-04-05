# Changelog

All notable changes to this add-on are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- (none)

## [1.0.3] - 2026-04-05

### Fixed

- Install [fallow-skills](https://github.com/fallow-rs/fallow-skills) under **`/usr/local/share/fallow-skills`** instead of a Cursor-only `~/.cursor/skills` path; this add-on targets **code-server** / VS Code, which does not use that layout.

## [1.0.2] - 2026-04-05

### Added

- Global npm CLIs: **`fallow`** ([fallow-rs/fallow](https://github.com/fallow-rs/fallow), pinned `FALLOW_NPM_VERSION`) and **`pi`** from **`@mariozechner/pi-coding-agent`** ([badlogic/pi-mono](https://github.com/badlogic/pi-mono), pinned `PI_CODING_AGENT_NPM_VERSION`), installed in the `assets` stage with OpenClaude/pnpm.
- [fallow-skills](https://github.com/fallow-rs/fallow-skills) repo cloned at tag `FALLOW_SKILLS_REF` to `/root/.cursor/skills/fallow-skills` (path revised in v1.0.3 for code-server).

## [1.0.1] - 2026-04-05

### Changed

- Container build: multi-stage Dockerfile (`py-builder`, `assets`, final) for better layer caching, smaller runtime context, and clearer build vs runtime split.
- Python CLI tools (ESPHome, yamllint, huggingface_hub) install into `/opt/addon-venv` with `PATH` prepended; `python3-dev` and `get-pip.py` removed from the final image.
- Downloads and VSIX extraction run on `debian:trixie-slim` (`assets` stage); final image drops `libarchive-tools` and `uuid-runtime` from runtime.
- `uv` and `uvx` ship as pinned standalone binaries (`UV_VERSION`); `pipx` remains for user-managed tools under `/data/openclaude/pipx`.
- `.dockerignore` expanded to trim build context (caches, editor dirs, logs, `.env*`).

## [1.0.0] - 2026-04-05

### Added

- Initial release as a Home Assistant app (add-on): `code-server` in the browser on port 1337 with ingress.
- OpenClaude CLI installed globally at image build (`@gitlawb/openclaude`); Node.js LTS from official tarball; Bun from official release archives.
- Build-time tooling: `pnpm` (npm global), `yarn` via Debian `yarnpkg` with `yarn` symlink, `uv` (pipx global), Hugging Face Hub CLI (`huggingface_hub[cli]`), ESPHome and yamllint (pip), ripgrep, git, git-lfs, GitHub CLI (`gh`), tig, jq, fd-find, fzf, bat, direnv, just, rsync, zip/unzip, xz-utils.
- Database and network clients: `mariadb-client`, `mosquitto-clients`, `nmap`.
- .NET SDK 8.0 via Microsoft Debian package feed (`DOTNET_DEBIAN_MS_MAJOR` default 12).
- Native/C toolchain retained at runtime: `build-essential`, `cmake`, `clang`, `pkg-config` (not purged after builds).
- VS Code extensions baked at build (Home Assistant, ESPHome, YAML, Prettier, Error Lens, etc.).
- s6-overlay services: `init-user` (no runtime `apt`), `init-openclaude` (persistent `~/.claude`, shell env from options), `init-code-server`, `code-server` longrun.
- Add-on options: workspace mode, Ollama/OpenRouter-style OpenAI-compatible env, optional API keys (root-only profile snippet), optional git identity seeding.
- Persistent layout: `/data/vscode`, `/data/openclaude/*`, default workspace `/share/openclaude_workspace`, HA maps for `/config`, `/share`, backups, SSL, media.

### Security

- API keys are not baked into the image; optional keys are written to `/etc/profile.d/99-openclaude-hass.sh` with mode 600 (single-user root container).

[Unreleased]: https://github.com/LOCAL/openclaude-code-server-hass/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/LOCAL/openclaude-code-server-hass/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/LOCAL/openclaude-code-server-hass/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/LOCAL/openclaude-code-server-hass/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/LOCAL/openclaude-code-server-hass/releases/tag/v1.0.0
