# modules/apps/cards.nix — the `claudeos-card` CLI: the write side of generated
# surfaces (Phase 4). Rendering lives in the bar (home/quickshell/Card*.qml);
# this is what a human (or a test) uses to install/inspect a card, and the
# dismiss backend the card's own dismiss action taps (CardRenderer calls
# `claudeos-card rm <id>`). All the real work — schema + registry validation,
# atomic install, index maintenance — is the shared claudeos_card /
# _claudeos_cards_reindex helpers in lib/claude-script.nix.
{ lib, pkgs, ... }:
let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-card";
      # check-jsonschema is the validator claudeos_card shells out to.
      runtimeInputs = [ pkgs.check-jsonschema ];
      text = ''
        cmd="''${1:-list}"
        [[ $# -gt 0 ]] && shift
        case "$cmd" in
          add)
            [[ -n "''${1:-}" ]] || { echo "usage: claudeos-card add <file.json> [id]" >&2; exit 2; }
            claudeos_card "$1" "''${2:-}"
            ;;
          rm)
            [[ -n "''${1:-}" ]] || { echo "usage: claudeos-card rm <id>" >&2; exit 2; }
            safe=$(printf '%s' "$1" | tr -c 'a-zA-Z0-9._-' '-' | tr -s '-')
            rm -f "$CLAUDEOS_CARDS_DIR/$safe.json"
            ;;
          clear)
            rm -f "$CLAUDEOS_CARDS_DIR"/*.json 2>/dev/null || true
            ;;
          list)
            for f in "$CLAUDEOS_CARDS_DIR"/*.json; do
              [ -e "$f" ] || continue
              base="''${f##*/}"; base="''${base%.json}"
              printf '%s\t%s\n' "$base" "$(jq -r '.title // "?"' "$f" 2>/dev/null)"
            done
            ;;
          *)
            echo "usage: claudeos-card {add <file> [id]|rm <id>|clear|list}" >&2
            exit 2
            ;;
        esac
      '';
    })
  ];
}
