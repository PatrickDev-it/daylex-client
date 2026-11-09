#!/usr/bin/env bash
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
target="${XDG_DATA_HOME:-$HOME/.local/share}/daylex/app"
command -v unzip >/dev/null || { echo 'Installare unzip prima di procedere.'; exit 1; }
if ldd "$source_dir/paper_agent" | grep -q 'not found'; then
  echo 'Dipendenze mancanti. Ubuntu: sudo apt install libgtk-3-0 libsecret-1-0 libstdc++6 unzip gnome-keyring'
  exit 1
fi
if pgrep -u "$(id -u)" -x paper_agent >/dev/null; then echo 'Chiudere Daylex prima di installare.'; exit 1; fi
mkdir -p "$target" "$HOME/.local/share/applications"
if [ "$source_dir" != "$target" ]; then cp -a "$source_dir/." "$target/"; fi
cat > "$HOME/.local/share/applications/daylex.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Daylex
Exec="$target/paper_agent"
Path=$target
Terminal=false
Categories=Office;
EOF
echo "Daylex installato: $target/paper_agent"
