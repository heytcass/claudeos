# ClaudeOS Health Check — pure bash, zero cost
# Exits non-zero if issues found, writing context to alert file
# Triggered every 15 min by systemd timer; OnFailure starts the Claude notifier

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-monitor"
CONTEXT_FILE="$CACHE_DIR/alert-context.txt"

mkdir -p "$CACHE_DIR"
> "$CONTEXT_FILE"
issues=0

# --- Failed systemd services (system) ---
failed=$(systemctl --failed --no-legend --no-pager 2>/dev/null | grep -v "^$" || true)
if [[ -n "$failed" ]]; then
  printf '=== Failed System Services ===\n%s\n\n' "$failed" >> "$CONTEXT_FILE"
  issues=1
fi

# --- Failed systemd services (user, excluding our own) ---
failed_user=$(systemctl --user --failed --no-legend --no-pager 2>/dev/null \
  | grep -v -e claudeos-health-check -e claudeos-notify -e "^$" || true)
if [[ -n "$failed_user" ]]; then
  printf '=== Failed User Services ===\n%s\n\n' "$failed_user" >> "$CONTEXT_FILE"
  issues=1
fi

# --- Disk usage > 85% ---
while IFS= read -r line; do
  pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
  mount=$(echo "$line" | awk '{print $6}')
  [[ -z "$pct" || ! "$pct" =~ ^[0-9]+$ ]] && continue
  if (( pct > 85 )); then
    printf '=== Disk Usage Warning ===\n' >> "$CONTEXT_FILE"
    printf '%s is %s%% full\n' "$mount" "$pct" >> "$CONTEXT_FILE"
    if [[ "$mount" == "/" ]]; then
      store_size=$(du -sh /nix/store 2>/dev/null | awk '{print $1}')
      gen_count=$(ls -1d /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l)
      printf 'Nix store: %s, system generations: %s\n' "${store_size:-unknown}" "$gen_count" >> "$CONTEXT_FILE"
    fi
    printf '\n' >> "$CONTEXT_FILE"
    issues=1
  fi
done < <(df -h --output=pcent,target -x tmpfs -x devtmpfs -x efivarfs 2>/dev/null | tail -n +2)

# --- Low memory (< 500MB available) ---
mem_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "999999")
if (( mem_kb < 512000 )); then
  mem_mb=$((mem_kb / 1024))
  printf '=== Low Memory ===\nAvailable: %sMB\nTop memory consumers:\n' "$mem_mb" >> "$CONTEXT_FILE"
  ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5 >> "$CONTEXT_FILE"
  printf '\n' >> "$CONTEXT_FILE"
  issues=1
fi

# --- OOM kills in last 15 min ---
oom=$(journalctl --since "15 min ago" -k --no-pager -q 2>/dev/null | grep -i "killed process\|out of memory:" || true)
if [[ -n "$oom" ]]; then
  printf '=== OOM Kills ===\n%s\n\n' "$oom" >> "$CONTEXT_FILE"
  issues=1
fi

# --- Critical journal entries in last 15 min ---
# Exclude systemd-coredump: transient boot crashes are handled by Restart=on-failure
# and real service failures are caught by the "failed services" check above.
crit=$(journalctl --since "15 min ago" -p crit --no-pager -q 2>/dev/null \
  | grep -v "systemd-coredump" | head -20 || true)
if [[ -n "$crit" ]]; then
  printf '=== Critical Log Entries ===\n%s\n\n' "$crit" >> "$CONTEXT_FILE"
  issues=1
fi

# --- Append system context if any issues found ---
if (( issues )); then
  printf '=== System Context ===\n' >> "$CONTEXT_FILE"
  printf 'Host: %s\n' "$(hostname 2>/dev/null || echo unknown)" >> "$CONTEXT_FILE"
  printf 'Uptime: %s\n' "$(uptime -p 2>/dev/null || echo unknown)" >> "$CONTEXT_FILE"
  printf 'Time: %s\n' "$(date)" >> "$CONTEXT_FILE"
  exit 1
fi

exit 0
