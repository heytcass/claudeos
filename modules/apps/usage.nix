# modules/apps/usage.nix — `claudeos-usage`: a local counter of which Claude
# desktop actions actually get used, so the unused ones can be cut.
#
#   claudeos-usage log ID SOURCE      append one line (SOURCE = summon | key)
#   claudeos-usage report [--days N]  every action with its count, zeros included
#   claudeos-usage counts [--days N]  "ID<TAB>COUNT" lines (the summon reads this)
#
# Loggers: Summon.qml (action rows, its routes, app launches), the Super+C bind
# (home/hyprland.nix wraps every registry `command` bind), and RegionShot.qml's
# Super+Shift+C / Super+Shift+P handlers. Ids come from lib/action-id.nix; the
# report's action list is generated from lib/keybindings.nix at build time.
{ lib, pkgs, ... }:
let
  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
  actionId = import ../../lib/action-id.nix { inherit lib; };

  # Every action the summon can run (the summon entry itself is not an action).
  registry = lib.filter (b: b.summon or true) (import ../../lib/keybindings.nix);
  # The summon's own rows that are not registry actions (Summon.qml `routeRow`
  # kinds, plus app launches). Logged by kind only, never by what was typed.
  summonRows = [
    {
      id = "route:cmd";
      name = "Shell command ($cmd)";
    }
    {
      id = "route:ask";
      name = "Question? route";
    }
    {
      id = "route:task";
      name = "Hand it to Claude (router)";
    }
    {
      id = "route:save";
      name = "Save context";
    }
    {
      id = "route:resume";
      name = "Resume context";
    }
    {
      id = "app";
      name = "App launch (any app)";
    }
  ];
  known = map (b: {
    id = actionId b.name;
    inherit (b) name;
  }) registry;
  knownFile = pkgs.writeText "claudeos-usage-actions.tsv" (
    lib.concatMapStrings (e: "${e.id}\t${e.name}\n") (known ++ summonRows)
  );
in
{
  environment.systemPackages = [
    (claudeLib.mkClaudeScriptBin {
      name = "claudeos-usage";
      text = ''
        # PRIVACY: this repo is public, and this log never enters it. It lives
        # only in the user's state dir ($XDG_STATE_HOME/claudeos/usage.log), is
        # never synced or committed, and each line is exactly three fields:
        # UTC timestamp, action id, source (summon|key). No typed text, no app
        # names, no window titles: `log` refuses any id outside [a-z0-9:-] and
        # any other source, silently.
        log_file="$STATE_DIR/usage.log"

        # id<TAB>name, registry order first (generated from lib/keybindings.nix),
        # then the summon's own routes.
        known_file=${knownFile}

        usage() {
          cat >&2 <<'EOF'
        usage: claudeos-usage log ID summon|key
               claudeos-usage report [--days N]
               claudeos-usage counts [--days N]
        EOF
          exit 2
        }

        # --days N → the UTC cutoff timestamp (ISO strings compare as text).
        cutoff=""
        days=""
        parse_days() {
          while [[ $# -gt 0 ]]; do
            case "$1" in
              --days)
                [[ "''${2:-}" =~ ^[0-9]+$ ]] || usage
                days="$2"
                shift 2
                ;;
              *) usage ;;
            esac
          done
          if [[ -n "$days" ]]; then
            cutoff=$(date -u -d "-$days days" +%Y-%m-%dT%H:%M:%SZ)
          fi
        }

        case "''${1:-}" in
          log)
            # Fast and silent: called from binds and the bar, it must never
            # fail loudly or hold the action up.
            id="''${2:-}"
            src="''${3:-}"
            [[ "$id" =~ ^[a-z0-9][a-z0-9:-]{0,63}$ ]] || exit 0
            [[ "$src" == summon || "$src" == key ]] || exit 0
            {
              mkdir -p "$STATE_DIR" &&
                printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id" "$src" >>"$log_file"
            } 2>/dev/null
            exit 0
            ;;
          counts)
            shift
            parse_days "$@"
            [[ -r "$log_file" ]] || exit 0
            awk -F'\t' -v cut="$cutoff" 'NF == 3 && $1 >= cut { n[$2]++ }
              END { for (k in n) printf "%s\t%d\n", k, n[k] }' "$log_file"
            ;;
          report)
            shift
            parse_days "$@"
            if [[ -n "$days" ]]; then
              printf 'Claude action use, last %s days\n\n' "$days"
            else
              printf 'Claude action use, all time\n\n'
            fi
            printf '%-6s %-7s %-4s %-11s %-28s %s\n' COUNT SUMMON KEY "LAST USED" ACTION ID
            {
              awk -F'\t' 'NF >= 2 { printf "K\t%s\t%s\n", $1, $2 }' "$known_file"
              [[ -r "$log_file" ]] && awk -F'\t' 'NF == 3 { printf "L\t%s\t%s\t%s\n", $1, $2, $3 }' "$log_file"
            } | awk -F'\t' -v cut="$cutoff" '
              $1 == "K" { if (!($2 in ord)) { ord[$2] = ++k; name[$2] = $3 } next }
              $1 == "L" && $2 >= cut {
                id = $3; n[id]++; if ($4 == "key") kn[id]++; else sn[id]++
                if ($2 > last[id]) last[id] = $2
                if (!(id in ord)) { ord[id] = 1000 + (++u); name[id] = "(not in registry)" }
              }
              END {
                for (id in ord)
                  printf "%d\t%d\t%d\t%d\t%s\t%s\t%s\n", n[id], ord[id], sn[id], kn[id],
                    (id in last) ? last[id] : "never", substr(name[id], 1, 28), id
              }' | sort -t$'\t' -k1,1nr -k2,2n |
              # The log stores UTC; show the day it was in local time.
              while IFS=$'\t' read -r count _ summon key last name id; do
                [[ "$last" == never ]] || last=$(date -d "$last" +%Y-%m-%d 2>/dev/null || printf '%s' "''${last:0:10}")
                printf '%-6d %-7d %-4d %-11s %-28s %s\n' "$count" "$summon" "$key" "$last" "$name" "$id"
              done
            ;;
          *) usage ;;
        esac
      '';
    })
  ];
}
