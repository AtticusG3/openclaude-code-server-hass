# AGENTS.md — DOX Framework

## Purpose

Home Assistant add-on packaging OpenClaude (browser-based code server) as a HA add-on container. Derived from Studio Code Server add-on layout. Tooling installed at image build time.

## Ownership

HA add-on repository. Build config in `openclaude_code_server/`, add-on metadata in `repository.yaml`.

## Local Contracts

- Add-on store manifest: `repository.yaml`
- CI: `.github/workflows/ci.yml` validates `repository.yaml`, `config.yaml`, `build.yaml`
- Docker build context: `openclaude_code_server/`
- GitHub remote: `AtticusG3/openclaude-code-server-hass`
- DOCS.md in `openclaude_code_server/` for in-app documentation

## Work Guidance

- Build: HA add-on builder, not Docker Hub
- Config changes: update `openclaude_code_server/config.yaml`
- Docs: update `openclaude_code_server/DOCS.md` for user-facing changes

## Verification

CI workflow validates YAML. Test by loading the add-on in HA.

## Child DOX Index

`openclaude_code_server/` is the main subtree

---
*DOX framework: re-read this file before editing any path in this subtree. Closer docs override parents but never weaken DOX.*
