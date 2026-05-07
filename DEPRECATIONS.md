# Pi package deprecation warnings

Current `pi install npm:...` warnings are from third-party package dependency trees, not this dotfiles repo.

## Warnings observed

- `node-domexception@1.0.0`
  - Pulled through `@google/genai -> google-auth-library -> gaxios -> node-fetch -> fetch-blob` in Pi core package dependencies.
  - Also observed while installing `pi-lens`.
- `@mariozechner/pi-agent-core@0.73.1`, `@mariozechner/pi-ai@0.73.1`, `@mariozechner/pi-coding-agent@0.73.1`, `@mariozechner/pi-tui@0.73.1`
  - Pulled as peer dependencies by `pi-docparser` and `@kaiserlich-dev/pi-session-search`.
  - npm warning recommends the renamed `@earendil-works/*` packages, but the published Pi packages still declare/import the old package names.
- `@mariozechner/pi-tui@0.72.1`
  - Direct dependency of `pi-lens@3.8.41`.
- `prebuild-install@7.1.3`
  - Pulled by `better-sqlite3`, used by `@kaiserlich-dev/pi-session-search@1.1.3`.

## Installed versions checked

- `pi-lens@3.8.41`
- `pi-docparser@1.1.1`
- `@kaiserlich-dev/pi-session-search@1.1.3`
- `pi-mermaid@0.3.0` latest metadata checked, but install failed due npm cache permissions.

## Resolution status

These warnings require upstream package releases to fully resolve without suppressing npm output or forking packages:

- `pi-lens` would need to stop depending on deprecated `@mariozechner/pi-tui`.
- `pi-docparser` and `@kaiserlich-dev/pi-session-search` would need updated peer dependency declarations compatible with current Pi package names.
- `better-sqlite3` would need to stop depending on deprecated `prebuild-install`, or `@kaiserlich-dev/pi-session-search` would need a replacement storage dependency.
- Pi core dependency chains would need to remove `node-domexception` via upstream dependency updates.

## npm cache permission issue

`pi install npm:pi-mermaid` failed because `~/.npm` contains root-owned cache files. The recommended repair is:

```bash
sudo chown -R 501:20 "$HOME/.npm"
```

This must be run from an interactive terminal because sudo needs a password.
