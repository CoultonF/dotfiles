#!/usr/bin/env python3
"""Set Codex permission defaults without replacing unrelated user configuration."""

import os
from pathlib import Path
import stat
import tempfile
import tomllib


SETTINGS = {
    "approval_policy": "never",
    "sandbox_mode": "danger-full-access",
}


def configure(source: str) -> str:
    tomllib.loads(source)
    lines = source.splitlines(keepends=True)
    retained = []
    index = 0
    while index < len(lines):
        line = lines[index]
        stripped = line.lstrip()
        key, separator, _ = line.partition("=")
        try:
            assignment = tomllib.loads(key + '= ""') if separator else {}
        except tomllib.TOMLDecodeError:
            assignment = {}
        managed = any(assignment.get(name) == "" for name in SETTINGS)
        if stripped.startswith("[") or managed:
            # A matching line inside a multiline string or array is not a new
            # statement: its preceding TOML is incomplete. Leave it untouched.
            try:
                tomllib.loads("".join(lines[:index]))
            except tomllib.TOMLDecodeError:
                retained.append(line)
                index += 1
                continue
            if stripped.startswith("["):
                # All subsequent assignments belong to tables, not the root.
                retained.extend(lines[index:])
                break
            end = index + 1
            while True:
                try:
                    tomllib.loads("".join(lines[index:end]))
                    break
                except tomllib.TOMLDecodeError:
                    if end == len(lines):
                        raise
                    end += 1
            index = end
        else:
            retained.append(line)
            index += 1

    updated = "".join(f'{key} = "{value}"\n' for key, value in SETTINGS.items())
    updated += "".join(retained)
    tomllib.loads(updated)
    return updated


def main() -> None:
    codex_home = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")
    path = (codex_home / "config.toml").resolve()
    source = path.read_bytes().decode("utf-8") if path.exists() else ""
    updated = configure(source)
    if updated == source:
        return

    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as output:
            temporary = Path(output.name)
            os.fchmod(output.fileno(), mode)
            output.write(updated.encode("utf-8"))
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
