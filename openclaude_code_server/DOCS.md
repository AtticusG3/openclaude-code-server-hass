# OpenClaude Code Server

## Overview

Browser-based VS Code (`code-server`) with OpenClaude and common CLI tooling **pre-installed in the image**. Startup scripts only create directories, symlink persistent config, and render a small shell profile from your options.

## Ollama (remote)

Set:

- `default_provider` to `ollama`
- `ollama_base_url` to your OpenAI-compatible endpoint, e.g. `http://192.168.1.50:11434/v1` (use the host or machine where Ollama actually runs)

Ollama often does not require an API key; leave `ollama_api_key` empty unless your proxy requires a token.

## OpenRouter (fallback primary)

Set:

- `default_provider` to `openrouter`
- `openrouter_api_key` to your OpenRouter key
- `openai_model` to a model id OpenRouter accepts (see OpenRouter docs)

You can switch provider any time; restart the add-on to re-render `/etc/profile.d/99-openclaude-hass.sh`.

## Workspaces

- **`share_openclaude` (default):** opens `/share/openclaude_workspace` as the code-server folder. Good for git repos you want on the HA **Share** volume.
- **`homeassistant_config`:** opens `/config` (live HA configuration). Use with care; indexing large trees can be slow.
- **`addon_data`:** opens `/data/workspace` on the add-on data volume.
- **`config_path`:** advanced override; must exist inside the container.

## OpenClaude files

`/root/.claude` points to `/data/openclaude/claude`. Use `/provider` inside OpenClaude for interactive profile setup; files remain across upgrades.

## Troubleshooting

- **`pip` / ESPHome / `hf` not found:** project Python CLIs live in `/opt/addon-venv` on `PATH`. Use `which pip` and `pip --version` from a new terminal; install extra tools with `pipx` (see `PIPX_HOME` in the generated profile) or the venv's `pip` if you accept that they are not preserved across image-only upgrades unless you reinstall.
- **`openclaude` not found:** rebuild the image; the binary is installed globally at build time.
- **`rg` not found:** should not happen; `ripgrep` is installed in the image. Open a new terminal tab.
- **Cannot reach Ollama:** verify URL from inside the add-on terminal (`curl -sS .../v1/models` against your base URL).
- **Permission on `/share`:** ensure the Share mount is read/write in `config.yaml` (`map: share`).

## Pi and Fallow

- **`pi`:** coding agent CLI from `@mariozechner/pi-coding-agent` ([pi-mono](https://github.com/badlogic/pi-mono)). Configure LLM keys and usage per upstream; the add-on only supplies the binary on `PATH`.
- **`fallow`:** JS/TS analyzer CLI ([fallow-rs/fallow](https://github.com/fallow-rs/fallow)); docs live at [docs.fallow.tools](https://docs.fallow.tools) and the doc source repo [fallow-rs/docs](https://github.com/fallow-rs/docs).
- **Fallow agent skills** ([fallow-skills](https://github.com/fallow-rs/fallow-skills)) are cloned into **`/usr/local/share/fallow-skills`** for reference. code-server does not integrate with Cursor-style skill paths; open or copy files from there as needed, or point another agent client at that folder if it supports the same skill format.

## Further reading

See the repository `README.md` for architecture, persistence tables, and the full test plan.
