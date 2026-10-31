"""Parse JSON, JSONC and TOML files. Arguments are `<kind>:<path>`.

JSONC allows // and /* */ comments and trailing commas, as editors do.
Exit status 1 if any file fails to parse.
"""

import json
import re
import sys
import tomllib


def strip_jsonc(text: str) -> str:
    """Remove comments outside strings, then trailing commas."""
    out = []
    i, n = 0, len(text)
    in_string = False
    while i < n:
        c = text[i]
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
        elif c == '"':
            in_string = True
            out.append(c)
            i += 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end == -1:
                raise ValueError("unterminated /* comment")
            # keep newlines so line numbers in errors stay right
            out.append("\n" * text.count("\n", i, end))
            i = end + 2
        else:
            out.append(c)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def check(kind: str, path: str) -> str | None:
    try:
        with open(path, "rb") as fh:
            data = fh.read()
        if kind == "toml":
            tomllib.loads(data.decode("utf-8"))
        elif kind == "json":
            json.loads(data)
        elif kind == "jsonc":
            json.loads(strip_jsonc(data.decode("utf-8")))
        else:
            return f"unknown kind {kind!r}"
    except (ValueError, UnicodeDecodeError) as exc:
        return f"invalid {kind.upper()}: {exc}"
    return None


def main(argv: list[str]) -> int:
    failed = False
    for arg in argv:
        kind, _, path = arg.partition(":")
        err = check(kind, path)
        if err:
            print(f"{path}: {err}", file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
