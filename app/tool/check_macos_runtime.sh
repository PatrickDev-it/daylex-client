#!/usr/bin/env bash
# Universal Mach-O output contains one unindented header per architecture.
set -euo pipefail
runtime="${1:?runtime required}"
dependencies="$(otool -L "$runtime")" # Fail closed if inspection itself fails.
count=0
while IFS= read -r dependency; do
  case "$dependency" in
    /usr/lib/*|/System/Library/*) ;;
    *) echo "Node non portabile: dipendenza $dependency. Usa un runtime Node autonomo."; exit 1 ;;
  esac
  count=$((count + 1))
done < <(printf '%s\n' "$dependencies" | awk '/^[[:space:]]/ {print $1}')
if [[ "$count" == 0 ]]; then
  echo "Nessuna dipendenza Mach-O verificabile: $runtime"
  exit 1
fi
