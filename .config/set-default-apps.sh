#!/bin/sh
# Make swayimg / mpv / zathura the default apps for every type they declare.
# Safe to re-run. Writes ~/.config/mimeapps.list via xdg-mime.
set -eu

# find a .desktop file in the standard XDG locations
desktop_file() {
  for d in "${XDG_DATA_HOME:-$HOME/.local/share}" $(echo "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' '); do
    [ -f "$d/applications/$1" ] && { echo "$d/applications/$1"; return; }
  done
  return 1
}

# assoc <desktop-id> [grep -E filter for mime types]
assoc() {
  f=$(desktop_file "$1") || { echo "skip: $1 not installed" >&2; return 0; }
  mimes=$(sed -n 's/^MimeType=//p' "$f" | tr ';' '\n' | grep -E "${2:-.}" || true)
  [ -n "$mimes" ] || { echo "skip: $1 declares no matching types" >&2; return 0; }
  # shellcheck disable=SC2086
  xdg-mime default "$1" $mimes
  echo "$1: $(echo "$mimes" | wc -l) types"
}

# Text files -> nvim inside kitty. GUI sessions lack the shell PATH (mise, kitty.app),
# so resolve absolute paths now and write the launcher.
kitty=$(command -v kitty || echo "$HOME/.local/kitty.app/bin/kitty")
nvim=$(command -v nvim || true)
[ -x "$HOME/.local/share/mise/shims/nvim" ] && nvim="$HOME/.local/share/mise/shims/nvim"   # survives mise upgrades
if [ -x "$kitty" ] && [ -n "$nvim" ]; then
  mkdir -p "$HOME/.local/share/applications"
  cat > "$HOME/.local/share/applications/nvim-kitty.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Neovim (kitty)
Icon=nvim
Exec=$kitty -e $nvim %F
Terminal=false
NoDisplay=true
MimeType=text/plain;text/markdown;text/x-log;text/csv;text/x-python;text/x-shellscript;application/x-shellscript;text/x-csrc;text/x-chdr;text/x-c++src;text/x-c++hdr;text/x-rust;text/x-go;text/x-lua;text/x-java;text/x-makefile;text/x-cmake;text/x-patch;text/x-diff;text/x-tex;text/css;text/javascript;application/javascript;application/json;application/toml;application/x-yaml;application/yaml;application/xml;text/xml;application/x-desktop;
EOF
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  assoc nvim-kitty.desktop
else
  echo "skip: kitty or nvim not found" >&2
fi

assoc swayimg.desktop '^image/'
assoc mpv.desktop '^(video|audio|application)/'   # skip image/* so swayimg keeps those
for z in /usr/share/applications/org.pwmt.zathura-*.desktop; do   # one per installed plugin (pdf, djvu, cb, ...)
  [ -f "$z" ] && assoc "$(basename "$z")"
done

for m in image/png video/mp4 audio/flac application/pdf text/plain application/json; do
  echo "check $m -> $(xdg-mime query default "$m")"
done
