# claudeos-shelve-clipboard (Super+S) — put whatever is on the clipboard on
# the active shelf. The clipboard's own MIME types pick the kind: an image is
# kept by value, a uri-list becomes a file (file://) or a link (http/https),
# and anything else is text, unless the text is a single bare URL.
# claudeos-shelf does the validation and the refusal notifications; this only
# decides what to hand it.

types=$(wl-paste --list-types 2>/dev/null) || true
if [[ -z "$types" ]]; then
  claudeos_notify "Shelf" "The clipboard is empty."
  exit 0
fi

# Provenance: the window you copied from is almost always still focused.
source_json='{}'
if command -v hyprctl >/dev/null 2>&1; then
  source_json=$(hyprctl activewindow -j 2>/dev/null |
    jq -c '{class, title} | with_entries(select((.value // "") != ""))' 2>/dev/null) || source_json='{}'
  [[ -z "$source_json" ]] && source_json='{}'
fi

shelve() {
  local id
  id=$(claudeos-shelf add "$@" --source-json "$source_json") || exit 1
  claudeos_notify --urgency=low "Shelved" "$(claudeos-shelf list | jq -r --arg id "$id" '
    "\(.name): " + (.items[] | select(.id == $id) |
      if .kind == "file" then .payload.path | split("/")[-1]
      elif .kind == "link" then .payload.url
      elif .kind == "text" then .payload.text[0:80]
      else "image" end)')"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

img=$(grep -m1 -E '^image/(png|jpeg|webp|gif)$' <<<"$types" || true)
if [[ -n "$img" ]]; then
  ext="${img#image/}"; [[ "$ext" == "jpeg" ]] && ext=jpg
  wl-paste --type "$img" >"$TMP/clip.$ext"
  shelve image "$TMP/clip.$ext"
  exit 0
fi

if grep -qx 'text/uri-list' <<<"$types"; then
  # First real entry only: Chrome adds a scheme-less duplicate of the url.
  uri=$(wl-paste --type text/uri-list | tr -d '\r' | grep -v '^#' | grep -m1 -E '^(file|https?)://' || true)
  case "$uri" in
    file://*)
      path="${uri#file://}"; path="${path#localhost}"
      shelve file "$(printf '%b' "${path//%/\\x}")"
      exit 0
      ;;
    http://* | https://*) shelve link "$uri"; exit 0 ;;
  esac
fi

text=$(wl-paste --no-newline 2>/dev/null || true)
if [[ "$text" =~ ^https?://[^[:space:]]+$ ]]; then
  shelve link "$text"
else
  printf '%s' "$text" | shelve text -
fi
