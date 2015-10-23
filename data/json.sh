#!/usr/bin/env bash
json_key() {
    python -c '
import json
import sys

data = json.load(sys.stdin)
for key in sys.argv[1:]:
    try:
        data = data[key]
    except TypeError:  # This is a list index
        data = data[int(key)]
    except KeyError:   # Key does not exist
        data = str('')
        break

print(data)' "$@"
}

