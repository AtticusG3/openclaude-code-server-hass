# OpenClaude Code Server (Home Assistant add-on)

Custom [Home Assistant](https://www.home-assistant.io/) add-on derived from the [Studio Code Server](https://github.com/hassio-addons/addon-vscode) layout ([code-server](https://github.com/coder/code-server) in the browser). Tooling and [OpenClaude](https://github.com/Gitlawb/openclaude) are installed **at image build time** so the container does not run `apt`, `npm install`, or `pip install` on every start.

**Repository:** [github.com/AtticusG3/openclaude-code-server-hass](https://github.com/AtticusG3/openclaude-code-server-hass)  
**In-app docs:** [openclaude_code_server/DOCS.md](openclaude_code_server/DOCS.md) (also linked from the add-on page when the store points at this repo)

## Repository layout

```text
repository.yaml                 # Add-on store manifest (Git URL shown in HA)
.github/workflows/ci.yml        # Validates repository.yaml, config.yaml, build.yaml (PyYAML)
openclaude_code_server/
  config.yaml                   # Add-on metadata, Supervisor maps, options schema
  build.yaml                    # hassio-addons/debian-base image per arch (pinned)
  Dockerfile                    # Multi-stage: py-builder + assets + hassio-base runtime
  CHANGELOG.md                  # Release history (HA app layout; shown in add-on UI when present)
  requirements.txt              # Python wheels baked in (esphome, yamllint, huggingface_hub CLI)
  vscode.extensions             # VSIX extensions installed at build
  rootfs/                       # s6-overlay init + code-server service
  DOCS.md                       # Long-form usage (shown in HA UI when linked)
README.md
```

**Install:** Add this repository under **Settings > Add-ons > Add-on store > Repositories** using the URL from `repository.yaml`, then install **OpenClaude Code Server**. The add-on version in the UI comes from `openclaude_code_server/config.yaml` (`version:`).

## Supervisor integration (from `config.yaml`)

The add-on declares **ingress** on port **1337** with **ingress_stream** enabled, **Home Assistant API** and **Supervisor API** access (`hassio_role: manager`), **UART** for serial workflows, and volume **maps** into the container (container paths follow [Home Assistant add-on `map` conventions](https://developers.home-assistant.io/docs/add-ons/configuration)):

| Map type | Container path | Typical use |
|----------|----------------|-------------|
| `addons` | `/addons` | Other add-on data |
| `all_addon_configs` | `/addon_configs` | Config folders for all add-ons (see HA docs for layout) |
| `backup` | `/backup` | Backups |
| `homeassistant_config` | `/config` | Live Home Assistant Core configuration |
| `media` | `/media` | Media library |
| `share` | `/share` | Host **Share** (default git/workspace lives under here) |
| `ssl` | `/ssl` | TLS material |

Add-on data (`/data`) is always available separately; host-side paths are defined by your Supervisor installation.

## What is baked into the image (build time)

- **code-server** (pinned `CODE_SERVER_VERSION` in `Dockerfile`)
- **Node.js** LTS tarball (pinned `NODE_VERSION`, currently 22.x; OpenClaude requires Node `>=20`)
- **OpenClaude** global npm package: `@gitlawb/openclaude` (pinned `OPENCLAUDE_NPM_VERSION`)
- **Pi** coding agent CLI: `@mariozechner/pi-coding-agent` from [badlogic/pi-mono](https://github.com/badlogic/pi-mono) (pinned `PI_CODING_AGENT_NPM_VERSION`; command **`pi`**, Node `>=20.6`)
- **Fallow** JS/TS codebase analyzer CLI: npm package [`fallow`](https://www.npmjs.com/package/fallow) from [fallow-rs/fallow](https://github.com/fallow-rs/fallow) (pinned `FALLOW_NPM_VERSION`; Rust native binary via npm optional deps)
- **Fallow agent skills (reference):** shallow clone of [fallow-rs/fallow-skills](https://github.com/fallow-rs/fallow-skills) at tag `FALLOW_SKILLS_REF` into **`/usr/local/share/fallow-skills`**. This add-on runs **code-server** (VS Code in the browser), not Cursor; the skills tree is bundled for reading, copying, or use with any tool that understands the [Agent Skills](https://github.com/fallow-rs/fallow-skills) layout. code-server does not auto-load that directory.
- **JS:** `pnpm` (global npm); **`yarn`** via Debian **`yarnpkg`** with `/usr/local/bin/yarn` symlink (npm global `yarn` removed to avoid duplicates); **Bun** (pinned `BUN_VERSION`, official release zip)
- **.NET:** **SDK 8.0** installed with Microsoft's official [**dotnet-install.sh**](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script) (channel `DOTNET_CHANNEL`, default `8.0`) into **`/usr/share/dotnet`**. This avoids the **packages.microsoft.com** apt repository, which fails OpenPGP verification on Debian Trixie (strict **sqv** / SHA1 policy).
- **C / native toolchain:** **`build-essential`** (gcc, libc dev, **make**, **g++**) is **kept after build** (not purged) so you can compile in the container; also **`cmake`**, **`clang`**, **`pkg-config`**
- **Python:** `python3`, `python3-venv` (system); **`pipx`** (apt) for extra tools under `/data/openclaude/pipx`; **`esphome` / `yamllint` / `huggingface_hub[cli]`** in **`/opt/addon-venv`** (prepended to `PATH`); no `python3-pip` or `get-pip.py` on the runtime image
- **`uv` / `uvx`:** pinned standalone binaries from [astral-sh/uv releases](https://github.com/astral-sh/uv/releases) (`UV_VERSION` in `Dockerfile`); not installed via `pipx` anymore
- **System / dev packages** (Debian `apt`, where not listed above): **ripgrep**, `git`, **git-lfs** (`git lfs install` at build), **gh**, **tig**, `curl`, `ca-certificates`, `jq`, **fd-find**, `unzip`, `zip`, **xz-utils**, **rsync**, **direnv**, **just**, **fzf**, **bat**, **mariadb-client**, **mosquitto-clients**, **nmap**, plus VS Code-style baseline (`ack`, `openssh-client`, `locales`, `net-tools`, etc.). **VSIX extraction** uses `libarchive-tools` only in the **`assets`** build stage, not in the final image.

This add-on does **not** use Supervisor **`packages:`** at runtime; the list above is the single source of truth in the **`Dockerfile`** (build-time only).

| Your manifest intent | How it is covered |
|---------------------|-------------------|
| nodejs / npm | Official **Node tarball** + bundled **npm** (pinned Node LTS, not Debian `nodejs`) |
| ripgrep, git, curl, ca-certificates | `apt` **`ripgrep`**, **`git`**, **`curl`**, **`ca-certificates`** |
| jq, fd-find, fzf, unzip, zip, xz-utils, rsync | `apt` (same names; `fd` via `fdfind` symlink) |
| yarn | `apt` **`yarnpkg`** + **`yarn`** symlink |
| pnpm | `npm install -g pnpm` at build |
| python3, python3-venv, pipx | `apt` + `pipx` (project CLIs live in `/opt/addon-venv`) |
| dotnet SDK 8.0 | **`dotnet-install.sh`** into `/usr/share/dotnet` + `dotnet` symlink |
| build-essential, make, g++ | **`build-essential`** kept; not purged after npm native builds |
| pkg-config, cmake, clang | `apt` **`pkg-config`**, **`cmake`**, **`clang`** |
| direnv, just | `apt` |
| bat | `apt` **`bat`** (`bat` -> `batcat` symlink) |
- **VS Code extensions** in `vscode.extensions` (Home Assistant YAML, **ESPHome**, Prettier, Error Lens, etc.)
- **Home Assistant CLI** (`ha`, pinned `HA_CLI_VERSION`)
- **Oh My Zsh** + autosuggestions + syntax highlighting (cloned at build)

**Not** baked: API keys, provider secrets, or machine-specific URLs (those come from add-on options at runtime).

**Runtime base image:** `ghcr.io/hassio-addons/debian-base:9.1.0` per arch (`build.yaml`).

## What persists across restarts

| Path | Purpose |
|------|---------|
| `/data/vscode` | code-server user data, UI state, user-installed VSIX |
| `/data/openclaude/claude` | Symlinked from `/root/.claude` (OpenClaude config, profiles, etc.) |
| `/data/openclaude/npm-cache` | npm cache (`NPM_CONFIG_CACHE`) |
| `/data/openclaude/pipx` | Extra `pipx` installs and binaries |
| `/data/openclaude/uv-cache` | uv cache (`UV_CACHE_DIR`) |
| `/data/workspace` | Optional workspace when `workspace_mode: addon_data` |
| `/data/git`, `/data/.ssh`, `/data/.zsh_history` | Git identity file, SSH keys, shell history |
| `/share/openclaude_workspace` | Default git/project workspace on **Share** (survives add-on reinstall if you keep `/share`) |

**Why `/share/openclaude_workspace` as default:** it is visible on the HA host backup/share workflows and is a natural place for repositories, while keeping `/config` (Home Assistant core config) untouched unless you explicitly choose `homeassistant_config`.

## First boot (runtime)

1. `init-user` creates symlinks (`/config`, `/share`, etc.) and persistent SSH/git/history files. **No `apt` or package installs.**
2. `init-openclaude` creates `/data/openclaude/*`, links `/root/.claude`, seeds optional git name/email once, and writes `/etc/profile.d/99-openclaude-hass.sh` from add-on options (`chmod 600`).
3. `init-code-server` prepares `/data/vscode` and copies default `settings.json` only if missing.
4. `code-server` starts on port **1337** (ingress).

## Configuration (options)

| Option | Meaning |
|--------|---------|
| `log_level` | Supervisor add-on log level: `trace`, `debug`, `info`, `notice`, `warning`, `error`, or `fatal` (default `info`) |
| `workspace_mode` | `share_openclaude` (default), `homeassistant_config`, or `addon_data` |
| `config_path` | Optional absolute path override (takes precedence over `workspace_mode`) |
| `default_provider` | `ollama` or `openrouter` |
| `ollama_base_url` | OpenAI-compatible base URL (default `http://127.0.0.1:11434/v1`) |
| `openrouter_base_url` | Default `https://openrouter.ai/api/v1` |
| `openai_model` | Model id passed as `OPENAI_MODEL` (default in schema: `qwen2.5-coder:7b`; set to a model your provider accepts) |
| `openrouter_api_key` | Stored in Supervisor options; written to root-only profile snippet (see security note) |
| `ollama_api_key` | Optional; some proxies require a placeholder key |
| `git_user_name` / `git_user_email` | Seeded into `/data/git/.gitconfig` **only if `user.name` is empty** |

OpenClaude reads `CLAUDE_CODE_USE_OPENAI=1` plus `OPENAI_BASE_URL`, `OPENAI_API_KEY` (when applicable), and `OPENAI_MODEL` as documented upstream.

## Security trade-offs

- Smaller runtime footprint vs the prior single-stage image: no `python3-dev`, no `get-pip.py` bootstrap, no `libarchive-tools` / `uuid-runtime` in the running container; downloads and VSIX unpacking happen only in the non-runtime `assets` build stage.
- The container runs as **root** (same pattern as the upstream VS Code add-on; non-root would conflict with s6/binds without a broader redesign).
- API keys from options are rendered into `/etc/profile.d/99-openclaude-hass.sh` with mode **600**. Anyone with root in the container can read them; there is no multi-user isolation. Prefer **short-lived keys** and **network restrictions** on your Ollama/OpenRouter endpoints.
- Do not commit real keys into git; configure via the HA add-on UI.

## Updating OpenClaude or code-server

Bump `OPENCLAUDE_NPM_VERSION`, `FALLOW_NPM_VERSION`, `PI_CODING_AGENT_NPM_VERSION`, `FALLOW_SKILLS_REF`, `CODE_SERVER_VERSION`, `NODE_VERSION`, `BUN_VERSION`, `UV_VERSION`, or `DOTNET_CHANNEL` in `Dockerfile`, then rebuild the add-on image (Supervisor **Rebuild** or CI). Bump `requirements.txt` for ESPHome, Hugging Face Hub CLI, or yamllint. No runtime installer is involved.

**Docs (not cloned into the image):** [fallow-rs/docs](https://github.com/fallow-rs/docs) / [docs.fallow.tools](https://docs.fallow.tools).

## Version pins (high level)

Values below match the `Dockerfile` / `requirements.txt` / `build.yaml` in this tree; rebuild after edits.

| Component | Default pin | Where |
|-----------|-------------|--------|
| code-server | `v4.107.0` | `Dockerfile` `CODE_SERVER_VERSION` |
| Node.js | `22.14.0` | `Dockerfile` `NODE_VERSION` |
| OpenClaude (npm) | `0.1.7` | `Dockerfile` `OPENCLAUDE_NPM_VERSION` |
| Home Assistant CLI (`ha`) | `4.45.0` | `Dockerfile` `HA_CLI_VERSION` |
| Debian base (runtime) | `9.1.0` | `build.yaml` `ghcr.io/hassio-addons/debian-base` |
| Bun | `1.2.6` | `Dockerfile` `BUN_VERSION` |
| Fallow (npm CLI) | `2.13.0` | `Dockerfile` `FALLOW_NPM_VERSION` |
| Pi coding agent | `0.65.0` | `Dockerfile` `PI_CODING_AGENT_NPM_VERSION` |
| fallow-skills (git tag) | `v1.0.0` | `Dockerfile` `FALLOW_SKILLS_REF` |
| uv (standalone) | `0.6.14` | `Dockerfile` `UV_VERSION` |
| .NET SDK | `8.0` (install script channel) | `Dockerfile` `DOTNET_CHANNEL`; **`dotnet-install.sh`** |
| ESPHome (pip) | `2025.12.3` | `requirements.txt` |
| huggingface_hub (CLI) | `0.28.1` | `requirements.txt` |
| yamllint | `1.37.1` | `requirements.txt` |

**Reproducibility notes:** Oh My Zsh and its plugins clone `master` with `--depth 1` (floating tip). Marketplace VSIX URLs are version-pinned in `vscode.extensions`. The `assets` stage uses `debian:trixie-slim` (rolling tag); pin by digest in `Dockerfile` if you need a fully frozen base for that stage.

## Local checks (test plan)

1. **CI:** On push/PR to `main`, GitHub Actions parses `repository.yaml`, `openclaude_code_server/config.yaml`, and `openclaude_code_server/build.yaml` with PyYAML (see `.github/workflows/ci.yml`).
2. **Build (BuildKit recommended for apt/npm cache mounts):** from repo root, `DOCKER_BUILDKIT=1 docker build --build-arg BUILD_ARCH=amd64 -t occs:test openclaude_code_server`. Compare image size: `docker image ls occs:test` (or `docker inspect occs:test --format '{{.Size}}'`). Compare build time: use `Measure-Command { ... }` (PowerShell) or `/usr/bin/time` on Unix with warm vs cold cache.
3. **Install:** Add custom repo, install add-on, confirm ingress opens code-server.
4. **Tools:** In integrated terminal: `node -v`, `npm -v`, `pnpm -v`, `yarn --version`, `bun --version`, `dotnet --version`, `gcc --version`, `cmake --version`, `clang --version`, `pkg-config --version`, `rg --version`, `git --version`, `git lfs version`, `gh --version`, `tig --version`, `uv --version`, `which python3`, `which pip` (expect `/opt/addon-venv/bin/pip` when the venv is first on `PATH`), `fd --version`, `just --version`, `fzf --version`, `bat --version`, `hf --version` (or `huggingface-cli --version`), `command -v openclaude`, `fallow --version`, `pi --version`, `test -d /usr/local/share/fallow-skills`, `mysql --version`, `nmap --version`, `mosquitto_pub -h` (prints help).
5. **OpenClaude:** Run `openclaude` (or follow OpenClaude docs for non-interactive checks).
6. **Pi / Fallow:** From a JS/TS repo workspace, run `fallow` or `fallow dead-code`; run `pi` per [pi-mono](https://github.com/badlogic/pi-mono) coding-agent docs (needs your LLM keys in the environment).
7. **Persistence:** Create a file under `/share/openclaude_workspace`, restart add-on, confirm file remains.
8. **Ollama:** Set `default_provider: ollama`, set `ollama_base_url` to reachable host IP, run OpenClaude against a remote Ollama.
9. **OpenRouter:** Set `default_provider: openrouter`, fill `openrouter_api_key`, confirm requests succeed.

## Line endings and executable bits

Scripts under `rootfs/etc/s6-overlay/.../run` must be executable in git:

```bash
git add --chmod=+x openclaude_code_server/rootfs/etc/s6-overlay/s6-rc.d/*/run
```

On Linux/macOS builds this matters for the container entrypoint.

## References

- [AtticusG3/openclaude-code-server-hass](https://github.com/AtticusG3/openclaude-code-server-hass) (this add-on)
- [hassio-addons/addon-vscode](https://github.com/hassio-addons/addon-vscode)
- [hassio-addons/debian-base](https://github.com/hassio-addons/addon-debian-base) (via `ghcr.io/hassio-addons/debian-base`)
- [Gitlawb/openclaude](https://github.com/Gitlawb/openclaude)
- [badlogic/pi-mono](https://github.com/badlogic/pi-mono) (Pi coding agent and related packages)
- [fallow-rs/fallow](https://github.com/fallow-rs/fallow) (Fallow analyzer; [npm `fallow`](https://www.npmjs.com/package/fallow))
- [fallow-rs/fallow-skills](https://github.com/fallow-rs/fallow-skills) (Agent skills for Fallow; bundled under `/usr/local/share/fallow-skills` in the image)
- [fallow-rs/docs](https://github.com/fallow-rs/docs) ([docs.fallow.tools](https://docs.fallow.tools))
