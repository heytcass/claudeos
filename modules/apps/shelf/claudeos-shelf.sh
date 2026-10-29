# claudeos-shelf — the only writer of working-memory shelves. Sourced into the
# mkClaudeScriptBin preamble (lib/claude-script.nix), which provides
# CLAUDEOS_CONTEXTS_DIR, _claudeos_context_slug, _claudeos_context_commit and
# claudeos_notify; default.nix prepends SHELF_SCHEMA.
#
# Layout: $CLAUDEOS_CONTEXTS_DIR/shelf/<slug>/shelf.json + blobs/. A subdir,
# not <slug>.shelf.json beside the manifests, because `claudeos-context list`
# and the Contexts.qml probe glob contexts/*.json.
shopt -s nullglob

SHELF_ROOT="$CLAUDEOS_CONTEXTS_DIR/shelf"
LOOSE="_loose"
MAX_ITEMS=200
MAX_TEXT=65536
MAX_IMAGE=$((5 * 1024 * 1024))

die() { echo "claudeos-shelf: $*" >&2; exit 1; }

# A refusal the user should SEE: capture paths (hotkeys, the bar) have no
# terminal, so caps and bad input go to a notification as well as stderr.
refuse() { claudeos_notify "Shelf" "$*"; die "$*"; }

usage() {
  cat >&2 <<'EOF'
usage: claudeos-shelf add {file <path>|image <file>|text {-|<text>}|link <url>}
                         [--context <name>] [--source-json <json>] [--ocr <text>]
       claudeos-shelf list [<context>]     # JSON for the bar
       claudeos-shelf rm <id>
       claudeos-shelf move <id> <context>  # "loose" moves it back out
       claudeos-shelf open <id>            # open file/link, copy text/image
EOF
  exit 2
}

# Serialise writers: a drop and a hotkey can land within milliseconds, and
# every write is read-modify-write of one JSON file. The lock lives OUTSIDE
# the context repo so `git add -A` never commits it.
_lock() {
  mkdir -p "$STATE_DIR"
  exec 9>"$STATE_DIR/shelf.lock"
  flock -w 10 9 || die "shelf is locked by another writer"
}

_dir() { printf '%s/%s\n' "$SHELF_ROOT" "$1"; }

# The shelf a bare `add` targets: the focused workspace's name when it is a
# saved context (the same rule Contexts.qml uses for activeName), else _loose.
_active_slug() {
  local ws=""
  command -v hyprctl >/dev/null 2>&1 && ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // empty')
  if [[ -n "$ws" && -f "$CLAUDEOS_CONTEXTS_DIR/$ws.json" ]]; then
    printf '%s\n' "$ws"
  else
    printf '%s\n' "$LOOSE"
  fi
}

# Resolve a user-typed context name to a shelf slug. "loose"/"_loose" → _loose;
# otherwise it must name a saved context (exact slug or unique prefix), so a
# typo can't silently create an orphan shelf.
_resolve() {
  local q base matches=()
  case "${1:-}" in loose | _loose) printf '%s\n' "$LOOSE"; return 0 ;; esac
  q=$(_claudeos_context_slug "${1:-}")
  [[ -z "$q" ]] && return 1
  [[ -f "$CLAUDEOS_CONTEXTS_DIR/$q.json" ]] && { printf '%s\n' "$q"; return 0; }
  for f in "$CLAUDEOS_CONTEXTS_DIR"/*.json; do
    base="${f##*/}"; base="${base%.json}"
    [[ "$base" == "$q"* ]] && matches+=("$base")
  done
  [[ ${#matches[@]} -eq 1 ]] && { printf '%s\n' "${matches[0]}"; return 0; }
  return 1
}

# Print a shelf's JSON, or an empty shelf named after its context.
_read() {
  local slug="$1" f name
  f="$(_dir "$slug")/shelf.json"
  if [[ -f "$f" ]]; then cat "$f"; return; fi
  name="$LOOSE"
  [[ "$slug" != "$LOOSE" ]] && name=$(jq -r '.name // empty' "$CLAUDEOS_CONTEXTS_DIR/$slug.json" 2>/dev/null)
  jq -n --arg name "${name:-$slug}" '{name: $name, groups: [], items: []}'
}

# Validate JSON (stdin) against the schema, then install it atomically. Does
# NOT commit: callers commit once, so a move (two shelves) is one commit.
# Returns non-zero WITHOUT writing on any validation failure.
_install() {
  local slug="$1" dir tmp err
  dir=$(_dir "$slug")
  mkdir -p "$dir"
  tmp="$dir/.shelf.json.tmp"
  cat >"$tmp"
  if ! err=$(check-jsonschema --schemafile "$SHELF_SCHEMA" "$tmp" 2>&1); then
    rm -f "$tmp"
    echo "shelf rejected: $(printf '%s' "$err" | tr '\n' ' ' | tail -c 300)" >&2
    return 1
  fi
  mv "$tmp" "$dir/shelf.json"
}

# The shelf slug holding item ID (ids are random and unique across shelves).
_find() {
  local f slug
  for f in "$SHELF_ROOT"/*/shelf.json; do
    if jq -e --arg id "$1" 'any(.items[]; .id == $id)' "$f" >/dev/null 2>&1; then
      slug="${f%/shelf.json}"; printf '%s\n' "${slug##*/}"; return 0
    fi
  done
  return 1
}

_new_id() { head -c 5 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

cmd="${1:-}"; shift || true
case "$cmd" in
  add)
    kind="${1:-}"; arg="${2:-}"
    [[ -n "$kind" && -n "$arg" ]] || usage
    shift 2
    target="" source_json='{}' ocr=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --context) target=$(_resolve "${2:-}") || die "no unique context matching '${2:-}'"; shift 2 ;;
        --source-json) source_json="${2:-}"; shift 2 ;;
        --ocr) ocr="${2:-}"; shift 2 ;;
        *) usage ;;
      esac
    done
    jq -e 'type == "object"' <<<"$source_json" >/dev/null 2>&1 || die "--source-json must be a JSON object"
    [[ -z "$target" ]] && target=$(_active_slug)

    _lock
    shelf=$(_read "$target")
    [[ $(jq '.items | length' <<<"$shelf") -ge $MAX_ITEMS ]] &&
      refuse "$(jq -r .name <<<"$shelf") shelf is full ($MAX_ITEMS items) — remove something first"

    id=$(_new_id)
    blob=""
    case "$kind" in
      file)
        path=$(realpath -e -- "$arg" 2>/dev/null) || refuse "no such file: $arg"
        [[ -f "$path" || -d "$path" ]] || refuse "not a file or folder: $arg"
        payload=$(jq -n --arg p "$path" '{path: $p}')
        # Browsers stamp downloads with their origin URL; keep it as provenance.
        origin=$(getfattr --only-values -n user.xdg.origin.url -- "$path" 2>/dev/null || true)
        [[ -n "$origin" ]] && source_json=$(jq -c --arg u "$origin" '.url //= $u' <<<"$source_json")
        label="${path##*/}"
        ;;
      image)
        [[ -f "$arg" ]] || refuse "no such image: $arg"
        [[ $(stat -c %s -- "$arg") -le $MAX_IMAGE ]] || refuse "image is over 5 MB"
        ext="${arg##*.}"; ext="${ext,,}"
        [[ "$ext" =~ ^(png|jpg|jpeg|webp|gif|avif)$ ]] || refuse "unsupported image type: .$ext"
        blob="blobs/$id.$ext"
        payload=$(jq -n --arg b "$blob" '{blob: $b}')
        label="image"
        ;;
      text)
        if [[ "$arg" == "-" ]]; then text=$(cat); else text="$arg"; fi
        [[ -n "$text" ]] || refuse "nothing to shelve: the text is empty"
        [[ $(printf '%s' "$text" | wc -c) -le $MAX_TEXT ]] || refuse "text is over 64 KB"
        payload=$(jq -n --arg t "$text" '{text: $t}')
        label="text"
        ;;
      link)
        [[ "$arg" =~ ^https?:// ]] || refuse "not an http(s) link: $arg"
        payload=$(jq -n --arg u "$arg" '{url: $u}')
        label="$arg"
        ;;
      *) usage ;;
    esac

    item=$(jq -n --arg id "$id" --arg kind "$kind" --argjson added "$(date +%s)" \
      --argjson payload "$payload" --argjson source "$source_json" --arg ocr "$ocr" \
      '{id: $id, kind: $kind, added: $added, payload: $payload}
       + (if $source == {} then {} else {source: $source} end)
       + (if $ocr == "" then {} else {ocr: $ocr} end)')

    dir=$(_dir "$target")
    if [[ -n "$blob" ]]; then mkdir -p "$dir/blobs" && cp -- "$arg" "$dir/$blob"; fi
    if ! jq --argjson item "$item" '.items += [$item]' <<<"$shelf" | _install "$target"; then
      [[ -n "$blob" ]] && rm -f "$dir/$blob"
      refuse "could not shelve $label (see stderr)"
    fi
    _claudeos_context_commit "shelf: add $kind $id to $target"
    printf '%s\n' "$id"
    ;;

  list)
    if [[ -n "${1:-}" ]]; then
      slug=$(_resolve "$1") || die "no unique context matching '$1'"
    else
      slug=$(_active_slug)
    fi
    # Annotate for the bar: the shelf's slug and absolute dir (so blob paths
    # resolve), and `missing` on file items whose referenced file is gone.
    shelf=$(_read "$slug")
    missing='[]'
    while IFS=$'\t' read -r id path; do
      [[ -e "$path" ]] || missing=$(jq -c --arg id "$id" '. + [$id]' <<<"$missing")
    done < <(jq -r '.items[] | select(.kind == "file") | [.id, .payload.path] | @tsv' <<<"$shelf")
    jq --arg slug "$slug" --arg dir "$(_dir "$slug")" --argjson missing "$missing" \
      '. + {slug: $slug, dir: $dir}
       | .items |= map(if (.id | IN($missing[])) then . + {missing: true} else . end)' <<<"$shelf"
    ;;

  rm)
    id="${1:-}"; [[ -n "$id" ]] || usage
    _lock
    slug=$(_find "$id") || die "no shelf item '$id'"
    dir=$(_dir "$slug")
    blob=$(jq -r --arg id "$id" '.items[] | select(.id == $id) | .payload.blob // empty' "$dir/shelf.json")
    jq --arg id "$id" '.items |= map(select(.id != $id))' "$dir/shelf.json" | _install "$slug" || die "rm failed"
    [[ -n "$blob" ]] && rm -f "$dir/$blob"
    _claudeos_context_commit "shelf: rm $id from $slug"
    echo "removed $id from $slug"
    ;;

  move)
    id="${1:-}"; [[ -n "$id" && -n "${2:-}" ]] || usage
    to=$(_resolve "$2") || die "no unique context matching '$2'"
    _lock
    from=$(_find "$id") || die "no shelf item '$id'"
    [[ "$from" == "$to" ]] && { echo "$id is already on $to"; exit 0; }
    src=$(_dir "$from"); dst=$(_dir "$to")
    dest=$(_read "$to")
    [[ $(jq '.items | length' <<<"$dest") -ge $MAX_ITEMS ]] && refuse "$to shelf is full ($MAX_ITEMS items)"
    # A group belongs to the shelf it was made on; the item arrives ungrouped.
    item=$(jq -c --arg id "$id" '.items[] | select(.id == $id) | del(.group)' "$src/shelf.json")
    blob=$(jq -r '.payload.blob // empty' <<<"$item")
    if [[ -n "$blob" ]]; then mkdir -p "$dst/blobs" && cp -- "$src/$blob" "$dst/$blob"; fi
    jq --argjson item "$item" '.items += [$item]' <<<"$dest" | _install "$to" || die "move failed"
    jq --arg id "$id" '.items |= map(select(.id != $id))' "$src/shelf.json" | _install "$from" || die "move failed"
    [[ -n "$blob" ]] && rm -f "$src/$blob"
    _claudeos_context_commit "shelf: move $id $from -> $to"
    echo "moved $id to $to"
    ;;

  open)
    id="${1:-}"; [[ -n "$id" ]] || usage
    slug=$(_find "$id") || die "no shelf item '$id'"
    dir=$(_dir "$slug")
    item=$(jq -c --arg id "$id" '.items[] | select(.id == $id)' "$dir/shelf.json")
    case "$(jq -r .kind <<<"$item")" in
      file)
        path=$(jq -r .payload.path <<<"$item")
        [[ -e "$path" ]] || refuse "${path##*/} was moved or deleted"
        xdg-open "$path" >/dev/null 2>&1 &
        ;;
      link) xdg-open "$(jq -r .payload.url <<<"$item")" >/dev/null 2>&1 & ;;
      text) jq -j .payload.text <<<"$item" | wl-copy ;;
      image)
        blob="$dir/$(jq -r .payload.blob <<<"$item")"
        wl-copy --type "image/${blob##*.}" <"$blob"
        ;;
    esac
    ;;

  *) usage ;;
esac
