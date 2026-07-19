# modules/apps/contexts/default.nix — `claudeos-context`: named, durable,
# git-tracked working contexts (Phase 3). A context is a text MANIFEST of a
# workspace's tools and places (schema: ./context.schema.json); this CLI is the
# save/restore/list/rm surface, and the intent line's `save as <name>` /
# `resume <name>` routes shell out to it. The shared validate-write-commit
# helpers (claudeos_context_install / _emit / _commit) live in
# lib/claude-script.nix, so a lane that PREPARES a context and a human who saves
# one go through exactly the same validation.
#
# The honest v1 contract (docs/plans/2026-07-17-ai-native-hmi-implementation.md):
# a context restores your TOOLS and PLACES, not pixel-perfect app state. `save`
# snapshots the ACTIVE workspace — window classes + a durable relaunch argv for
# apps, and the working directories of shells running in terminals. `restore`
# switches to a named workspace and launches each item into it, skipping what is
# already there (idempotent: re-restoring an open context just focuses it).
#
# Risk note: this is the plan's only live-window-manipulation surface. Restore is
# additive (it never CLOSES a window) and idempotent, and a malformed manifest is
# rejected BEFORE any window is touched — no half-restored workspace.
{ lib, pkgs, ... }:
let
  claudeLib = import ../../../lib/claude-script.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-context";
      # check-jsonschema validates manifests; xdg-utils opens `file` items on
      # restore. hyprctl + ghostty are resolved from the live session PATH (and
      # guarded), so this script doesn't drag the compositor into its closure.
      runtimeInputs = [
        pkgs.check-jsonschema
        pkgs.xdg-utils
      ];
      text = ''
        shopt -s nullglob

        # Window classes treated as "a terminal" for shell-cwd capture, and
        # classes skipped entirely on save (transient overlays / self). The
        # empty alternative in SKIP matches a window with no class.
        TERM_CLASS_RE='ghostty'
        SKIP_CLASS_RE='^(claude-quick|fuzzel|)$|Desk_today'

        # Resolve a name (or unambiguous prefix) to an existing context slug.
        _resolve_slug() {
          local q base matches=()
          q=$(_claudeos_context_slug "''${1:-}")
          [[ -z "$q" ]] && return 1
          if [[ -f "$CLAUDEOS_CONTEXTS_DIR/$q.json" ]]; then printf '%s\n' "$q"; return 0; fi
          for f in "$CLAUDEOS_CONTEXTS_DIR"/*.json; do
            base="''${f##*/}"; base="''${base%.json}"
            [[ "$base" == "$q"* ]] && matches+=("$base")
          done
          [[ ''${#matches[@]} -eq 1 ]] && { printf '%s\n' "''${matches[0]}"; return 0; }
          return 1
        }

        # cwds of every shell descendant of a pid (bounded recursive tree walk).
        # A terminal (ghostty) can serve several windows from one process, so the
        # caller unions + dedups these across the workspace.
        _shell_cwds_of() {
          local pid=$1 kid comm cwd
          for kid in $(pgrep -P "$pid" 2>/dev/null); do
            comm=$(cat "/proc/$kid/comm" 2>/dev/null || true)
            case "$comm" in
              fish|bash|zsh|sh|nu|dash)
                cwd=$(readlink "/proc/$kid/cwd" 2>/dev/null || true)
                [[ -n "$cwd" ]] && printf '%s\n' "$cwd"
                ;;
            esac
            _shell_cwds_of "$kid"
          done
        }

        # Durable relaunch argv for a window pid, as a JSON array. cmdline is
        # normally NUL-separated, but some wrappers (e.g. Electron apps like
        # claude-desktop) pack the whole command into a SINGLE space-joined arg —
        # so we treat NUL *and* space both as separators (tr NUL→space, split on
        # whitespace), which tokenises either shape and always yields a bare
        # argv0. The v1 contract is tools-and-places, not pixel-perfect state, so
        # losing a rare space-containing arg is an acceptable price for argv0
        # always being a resolvable command. Then: basename argv0 off any
        # /nix/store path so it survives a rebuild, drop /nix/store path args, and
        # collapse a chromium/electron renderer (`--type=…`) to the bare command.
        # Prints nothing when cmdline is empty/unreadable.
        _durable_argv() {
          tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | jq -Rs '
            (split(" ") | map(select(length>0)))
            | if length==0 then empty
              else (.[0] |= (split("/")|last))
                   | ( if any(.[]; startswith("--type=")) then [ .[0] ]
                       else [ .[0] ] + (.[1:] | map(select(startswith("/nix/store/")|not))) end )
              end'
        }

        cmd="''${1:-list}"
        [[ $# -gt 0 ]] && shift

        case "$cmd" in
          save)
            name="$*"
            [[ -z "$name" ]] && { echo "usage: claudeos-context save <name>" >&2; exit 2; }
            command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl unavailable — not in a Hyprland session" >&2; exit 1; }

            ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')
            [[ -z "$ws" ]] && { echo "could not read the active workspace" >&2; exit 1; }
            clients=$(hyprctl clients -j 2>/dev/null); [[ -z "$clients" ]] && clients='[]'

            tmp=$(mktemp); items="$tmp.items"; : > "$items"
            trap 'rm -f "$tmp" "$items"' EXIT

            # term items: union of shell cwds under every terminal on the ws.
            declare -A seen_cwd=()
            while IFS= read -r tp; do
              [[ -z "$tp" ]] && continue
              while IFS= read -r cwd; do
                [[ -z "$cwd" || -n "''${seen_cwd[$cwd]:-}" ]] && continue
                seen_cwd[$cwd]=1
                jq -nc --arg cwd "$cwd" '{kind:"term",cwd:$cwd}' >> "$items"
              done < <(_shell_cwds_of "$tp")
            done < <(jq -r --argjson ws "$ws" --arg re "$TERM_CLASS_RE" \
                       '.[] | select(.workspace.id==$ws) | select((.class//"")|test($re;"i")) | .pid' <<<"$clients" | sort -u)

            # app items for every other window, deduped by class+argv.
            declare -A seen_app=()
            while IFS= read -r row; do
              [[ -z "$row" ]] && continue
              class=$(jq -r '.class // ""' <<<"$row")
              pid=$(jq -r '.pid' <<<"$row")
              title=$(jq -r '.title // ""' <<<"$row")
              argv=$(_durable_argv "$pid")
              [[ -z "$argv" ]] && argv=$(jq -nc --arg c "$class" '[$c]')
              key="$class|$argv"
              [[ -n "''${seen_app[$key]:-}" ]] && continue
              seen_app[$key]=1
              jq -nc --arg class "$class" --arg title "$title" --argjson argv "$argv" \
                '{kind:"app",class:$class,argv:$argv,title:$title}' >> "$items"
            done < <(jq -c --argjson ws "$ws" --arg tre "$TERM_CLASS_RE" --arg sre "$SKIP_CLASS_RE" \
                       '.[] | select(.workspace.id==$ws)
                        | select(((.class//"")|test($tre;"i"))|not)
                        | select(((.class//"")|test($sre))|not)' <<<"$clients")

            arr=$(jq -s '.' "$items" 2>/dev/null); [[ -z "$arr" ]] && arr='[]'
            jq -n --arg name "$name" --argjson items "$arr" '{name:$name,items:$items}' > "$tmp"
            if slug=$(claudeos_context_install "$tmp" "$name"); then
              n=$(jq 'length' <<<"$arr")
              echo "saved context '$name' ($slug): $n item(s)"
              claudeos_notify "Context saved" "$name — $n item(s)"
            else
              echo "save failed" >&2; exit 1
            fi
            ;;

          restore|resume)
            [[ -n "''${1:-}" ]] || { echo "usage: claudeos-context restore <name>" >&2; exit 2; }
            slug=$(_resolve_slug "$1") || { echo "no unique context matching '$1'" >&2; exit 1; }
            file="$CLAUDEOS_CONTEXTS_DIR/$slug.json"
            command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl unavailable — not in a Hyprland session" >&2; exit 1; }

            # Validate BEFORE touching any window — a malformed manifest must
            # never leave a half-assembled workspace behind.
            if command -v check-jsonschema >/dev/null 2>&1; then
              if ! err=$(check-jsonschema --schemafile "$CLAUDEOS_CONTEXT_SCHEMA" "$file" 2>&1); then
                echo "context '$slug' is malformed — not restoring: $(printf '%s' "$err" | tr '\n' ' ' | tail -c 200)" >&2
                exit 1
              fi
            fi

            hyprctl dispatch workspace "name:$slug" >/dev/null 2>&1

            clients=$(hyprctl clients -j 2>/dev/null); [[ -z "$clients" ]] && clients='[]'
            present_classes=$(jq -r --arg ws "$slug" '.[] | select(.workspace.name==$ws) | .class // ""' <<<"$clients")
            declare -A present_cwd=()
            while IFS= read -r tp; do
              [[ -z "$tp" ]] && continue
              while IFS= read -r cwd; do [[ -n "$cwd" ]] && present_cwd[$cwd]=1; done < <(_shell_cwds_of "$tp")
            done < <(jq -r --arg ws "$slug" --arg re "$TERM_CLASS_RE" \
                       '.[] | select(.workspace.name==$ws) | select((.class//"")|test($re;"i")) | .pid' <<<"$clients")

            launched=0; skipped=0; missing=""
            while IFS= read -r item; do
              [[ -z "$item" ]] && continue
              kind=$(jq -r '.kind' <<<"$item")
              case "$kind" in
                app)
                  class=$(jq -r '.class // ""' <<<"$item")
                  if [[ -n "$class" ]] && grep -qxF "$class" <<<"$present_classes"; then skipped=$((skipped+1)); continue; fi
                  mapfile -t argv < <(jq -r '.argv[]' <<<"$item")
                  [[ ''${#argv[@]} -eq 0 ]] && continue
                  if ! command -v "''${argv[0]}" >/dev/null 2>&1; then missing+=" ''${argv[0]}"; continue; fi
                  hyprctl dispatch exec "[workspace name:$slug silent] $(printf '%q ' "''${argv[@]}")" >/dev/null 2>&1 && launched=$((launched+1))
                  ;;
                term)
                  cwd=$(jq -r '.cwd' <<<"$item")
                  [[ -n "''${present_cwd[$cwd]:-}" ]] && { skipped=$((skipped+1)); continue; }
                  command -v ghostty >/dev/null 2>&1 || continue
                  termcmd=$(jq -r '.cmd // empty' <<<"$item")
                  if [[ -n "$termcmd" ]]; then
                    hyprctl dispatch exec "[workspace name:$slug silent] ghostty --working-directory=$(printf '%q' "$cwd") -e $termcmd" >/dev/null 2>&1 && launched=$((launched+1))
                  else
                    hyprctl dispatch exec "[workspace name:$slug silent] ghostty --working-directory=$(printf '%q' "$cwd")" >/dev/null 2>&1 && launched=$((launched+1))
                  fi
                  ;;
                file)
                  path=$(jq -r '.path' <<<"$item"); path="''${path/#\~/$HOME}"
                  command -v xdg-open >/dev/null 2>&1 && \
                    hyprctl dispatch exec "[workspace name:$slug silent] xdg-open $(printf '%q' "$path")" >/dev/null 2>&1 && launched=$((launched+1))
                  ;;
              esac
            done < <(jq -c '.items[]' "$file")

            hyprctl dispatch workspace "name:$slug" >/dev/null 2>&1
            msg="restored '$slug': $launched launched, $skipped already present"
            [[ -n "$missing" ]] && msg="$msg; couldn't resolve:$missing"
            echo "$msg"
            claudeos_notify "Context resumed" "$msg"
            ;;

          list)
            found=0
            for f in "$CLAUDEOS_CONTEXTS_DIR"/*.json; do
              found=1
              base="''${f##*/}"; base="''${base%.json}"
              name=$(jq -r '.name // "?"' "$f" 2>/dev/null)
              n=$(jq -r '.items|length' "$f" 2>/dev/null)
              upd=$(jq -r '.updated // 0' "$f" 2>/dev/null)
              when=$(date -d "@$upd" '+%Y-%m-%d %H:%M' 2>/dev/null || echo '?')
              printf '%-20s %2s item(s)  %s  [%s]\n' "$name" "$n" "$when" "$base"
            done
            [[ $found -eq 0 ]] && echo "no saved contexts"
            ;;

          show)
            slug=$(_resolve_slug "''${1:-}") || { echo "no unique context matching '$1'" >&2; exit 1; }
            jq . "$CLAUDEOS_CONTEXTS_DIR/$slug.json"
            ;;

          rm)
            slug=$(_resolve_slug "''${1:-}") || { echo "no unique context matching '$1'" >&2; exit 1; }
            rm -f "$CLAUDEOS_CONTEXTS_DIR/$slug.json"
            _claudeos_context_commit "rm $slug"
            echo "removed context '$slug'"
            ;;

          *)
            echo "usage: claudeos-context {save <name>|restore <name>|list|show <name>|rm <name>}" >&2
            exit 2
            ;;
        esac
      '';
    })
  ];
}
