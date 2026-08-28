#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

if rg -n --hidden -g '!.git/**' -g '!.build/**' \
  '(BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,})' .; then
  printf '%s\n' 'Potential committed secret detected.' >&2
  exit 1
fi

if rg -n -g '*.swift' '(sand-secrets\.json|Application Support/Grok Bot).*(Data\(contentsOf|String\(contentsOf)' Sources; then
  printf '%s\n' 'Forbidden Grok Bot private-data read detected.' >&2
  exit 1
fi

printf '%s\n' 'Security checks passed.'
