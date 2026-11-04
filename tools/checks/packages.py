#!/usr/bin/env python3
"""Check the Homebrew section of packages.yaml, read as JSON on stdin.

    packages.py <path for messages> <file holding the Role list template>

Offline on purpose: this checks the shape of each entry, not whether Homebrew
still carries it (`mise run packages:audit` does that).
"""
import json
import re
import sys

# Key in packages.yaml -> Brewfile keyword.
SECTIONS = {
    "taps": "tap",
    "brews": "brew",
    "casks": "cask",
    "mas": "mas",
    "winget": "winget",
    "vscode": "vscode",
    "go": "go",
    "cargo": "cargo",
    "uv": "uv",
    "npm": "npm",
    "krew": "krew",
    "flatpak": "flatpak",
}


def is_true(value):
    return value is True


def is_bool(value):
    return isinstance(value, bool)


def is_string(value):
    return isinstance(value, str) and value != ""


def is_string_list(value):
    return isinstance(value, list) and all(is_string(item) for item in value)


def is_string_map(value):
    return isinstance(value, dict) and bool(value)


def is_id(value):
    return isinstance(value, int) and not isinstance(value, bool)


def is_trust_map(value):
    keys = {"formula", "formulae", "cask", "casks", "command", "commands"}
    return (
        isinstance(value, dict)
        and bool(value)
        and set(value) <= keys
        and all(is_string(v) or is_string_list(v) for v in value.values())
    )


def one_of(*allowed):
    def check(value):
        return any(value is a if isinstance(a, bool) else value == a for a in allowed)

    check.__doc__ = " or ".join(json.dumps(a) for a in allowed)
    return check


is_true.__doc__ = "true"
is_bool.__doc__ = "true or false"
is_string.__doc__ = "a string"
is_string_list.__doc__ = "a list of strings"
is_string_map.__doc__ = "a map"
is_id.__doc__ = "an integer"
is_trust_map.__doc__ = "a map of formula, cask or command names"

# Brewfile keyword -> option -> validator. From
# https://docs.brew.sh/Brew-Bundle-and-Brewfile, plus uv's `with`, which
# Homebrew's source accepts.
OPTIONS = {
    "tap": {"url": is_string, "trusted": is_trust_map},
    "brew": {
        "args": is_string_list,
        "conflicts_with": is_string_list,
        "link": one_of(True, False, ":overwrite"),
        "postinstall": is_string,
        "restart_service": one_of(True, ":always", ":changed"),
        "trusted": is_true,
        "version_file": is_string,
    },
    "cask": {
        "args": is_string_map,
        "greedy": is_bool,
        "postinstall": is_string,
        "trusted": is_true,
    },
    "mas": {"id": is_id},
    "winget": {"id": is_string, "source": is_string},
    "vscode": {},
    "go": {},
    "cargo": {"source": is_string},
    "uv": {"source": is_string, "with": is_string_list},
    "npm": {},
    "krew": {},
    "flatpak": {"remote": is_string, "url": is_string},
}
REQUIRED_OPTIONS = {"mas": {"id"}, "winget": {"id"}}
ENTRY_KEYS = {"name", "options", "platforms", "when", "excludeEphemeral"}
PLATFORMS = {"macos", "linux", "wsl"}
TOP_LEVEL = set(SECTIONS) | {"env", "caskArgs"}


def known_buckets(config_template):
    with open(config_template, encoding="utf-8") as handle:
        match = re.search(r"\$roleNames := list ([^-}]*)", handle.read())
    if not match:
        sys.exit(f"check:packages: error: no $roleNames in {config_template}")
    return {"base"} | set(re.findall(r'"([^"]+)"', match.group(1)))


def check_entry(where, keyword, entry):
    if not isinstance(entry, dict) or not is_string(entry.get("name")):
        yield f"{where}: an entry must be a map with a name"
        return
    where = f"{where}: {entry['name']}"
    for key in sorted(set(entry) - ENTRY_KEYS):
        yield f"{where}: unknown key '{key}' (known: {', '.join(sorted(ENTRY_KEYS))})"
    platforms = entry.get("platforms", [])
    if not is_string_list(platforms) or not platforms and "platforms" in entry:
        yield f"{where}: platforms must be a list of {', '.join(sorted(PLATFORMS))}"
    else:
        for platform in sorted(set(platforms) - PLATFORMS):
            yield f"{where}: unknown platform '{platform}' (known: {', '.join(sorted(PLATFORMS))})"
    when = entry.get("when")
    if when is not None and not (is_string(when) and re.match(r"(if|unless) \S", when)):
        yield f"{where}: when must start with 'if ' or 'unless '"
    if "excludeEphemeral" in entry and not is_bool(entry["excludeEphemeral"]):
        yield f"{where}: excludeEphemeral must be true or false"

    options = entry.get("options", {})
    if not isinstance(options, dict):
        yield f"{where}: options must be a map"
        return
    allowed = OPTIONS[keyword]
    for option in sorted(options):
        if option not in allowed:
            known = ", ".join(sorted(allowed)) or "none"
            yield f"{where}: unknown {keyword} option '{option}' (known: {known})"
        elif not allowed[option](options[option]):
            yield f"{where}: option '{option}' must be {allowed[option].__doc__}"
    for option in sorted(REQUIRED_OPTIONS.get(keyword, set()) - set(options)):
        yield f"{where}: a {keyword} entry needs the '{option}' option"


def third_party_tap(name):
    """The tap of a fully-qualified name (user/tap/item), unless it is Homebrew's own."""
    parts = name.split("/")
    if len(parts) == 3 and parts[0].lower() != "homebrew":
        return "/".join(parts[:2])
    return None


def trusted_items(tap_entry):
    trusted = (tap_entry.get("options") or {}).get("trusted")
    # Anything but a map is already reported by check_entry.
    for value in trusted.values() if isinstance(trusted, dict) else []:
        yield from [value] if isinstance(value, str) else value


def entries_of(homebrew, section):
    for bucket, entries in (homebrew.get(section) or {}).items():
        for entry in entries or []:
            if isinstance(entry, dict) and is_string(entry.get("name")):
                yield f"{section}.{bucket}", entry


def check_trust(homebrew):
    """Homebrew refuses untrusted third-party items, so a gap fails on a fresh Machine."""
    taps = {entry["name"]: entry for _, entry in entries_of(homebrew, "taps")}
    trusted_by_tap = {name: set(trusted_items(entry)) for name, entry in taps.items()}
    used = set()
    for section in ("brews", "casks"):
        for where, entry in entries_of(homebrew, section):
            name = entry["name"]
            tap = third_party_tap(name)
            is_trusted = (entry.get("options") or {}).get("trusted") is True
            if tap is None:
                if is_trusted:
                    yield f"{where}: {name}: trusted needs a fully-qualified name (user/tap/{name})"
                continue
            used.add(tap)
            if not is_trusted and name.split("/")[2] not in trusted_by_tap.get(tap, set()):
                yield f"{where}: {name}: a third-party entry needs `trusted: true` or its tap's `trusted` map"
    for where, entry in entries_of(homebrew, "taps"):
        name = entry["name"]
        if name.split("/")[0].lower() != "homebrew" and name not in used and not trusted_by_tap[name]:
            yield f"{where}: {name}: nothing from this tap is trusted, so nothing in it can load"


def uses_flatpak(homebrew):
    return any((homebrew.get("flatpak") or {}).values())


def native_lists(data):
    linux = (data.get("packages") or {}).get("linux") or {}
    for family, managers in linux.items():
        if isinstance(managers, dict):
            for bucket in (managers.get("packages") or {}).values():
                yield from bucket or []


def check(data, buckets):
    homebrew = (data.get("packages") or {}).get("homebrew")
    if not isinstance(homebrew, dict):
        yield "packages.homebrew is missing"
        return
    for key in sorted(set(homebrew) - TOP_LEVEL):
        yield f"packages.homebrew: unknown section '{key}' (known: {', '.join(sorted(TOP_LEVEL))})"
    for key in ("env", "caskArgs"):
        if key in homebrew and not is_string_map(homebrew[key]):
            yield f"packages.homebrew.{key} must be a map"
    for section, keyword in SECTIONS.items():
        for bucket, entries in (homebrew.get(section) or {}).items():
            where = f"{section}.{bucket}"
            if bucket not in buckets:
                yield f"{where}: unknown bucket (known: {', '.join(sorted(buckets))})"
            for entry in entries or []:
                yield from check_entry(where, keyword, entry)
    yield from check_trust(homebrew)
    if uses_flatpak(homebrew) and "flatpak" not in native_lists(data):
        yield "flatpak: entries need `flatpak` in a packages.linux native list, Homebrew has no formula for it"


def main():
    path, config_template = sys.argv[1:3]
    problems = list(check(json.load(sys.stdin), known_buckets(config_template)))
    for problem in problems:
        print(f"{path}: {problem}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
