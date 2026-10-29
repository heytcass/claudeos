# claudeos-shelve-region (Super+Shift+S) — drag a region and shelve it as an
# image, with the text in it attached as `ocr` so tidy (and search, later) can
# read it. The OCR is the same haiku transcription claude-grab-text uses; the
# image goes to the model as data and only the transcription comes back. If
# the model is unavailable or finds no text, the image is shelved without it.

region=$(slurp 2>/dev/null) || exit 0
[[ -z "$region" ]] && exit 0

# Provenance: the topmost visible window under the region's top-left corner
# (slurp doesn't change focus, so the focus order still says which is on top).
# Only windows on a workspace some monitor is showing, special ones included.
source_json='{}'
if command -v hyprctl >/dev/null 2>&1; then
  read -r x y _ <<<"${region//,/ }"
  shown=$(hyprctl monitors -j 2>/dev/null | jq -c '[.[] | .activeWorkspace.id, .specialWorkspace.id] | map(select(. != 0))') || shown='[]'
  source_json=$(hyprctl clients -j 2>/dev/null | jq -c --argjson x "$x" --argjson y "$y" --argjson shown "${shown:-[]}" '
    [.[] | select(.mapped and (.hidden | not) and (.workspace.id | IN($shown[])))
         | select(.at[0] <= $x and $x < .at[0] + .size[0] and .at[1] <= $y and $y < .at[1] + .size[1])]
    | sort_by(.focusHistoryID) | (first // {}) | {class, title}
    | with_entries(select((.value // "") != ""))' 2>/dev/null) || source_json='{}'
  [[ -z "$source_json" ]] && source_json='{}'
fi

TMP=$(mktemp -d)
SHOT="$TMP/region.png"
grim -g "$region" "$SHOT" || { rm -rf "$TMP"; exit 0; }

# agent_begin installs its own EXIT trap; extend it rather than lose either.
claudeos_agent_begin "reading the region for the shelf"
trap 'rm -rf "$TMP"; claudeos_agent_end' EXIT
ocr=$(claude_text haiku "Read the image at $SHOT and transcribe ALL text in it, exactly as written, preserving line breaks. Output ONLY the transcribed text — no commentary, no code fences. If there is no legible text, output exactly NO-TEXT." --allowedTools "Read")
[[ "$ocr" == "NO-TEXT" ]] && ocr=""
ocr=$(printf '%s' "$ocr" | head -c 65536)

args=(add image "$SHOT" --source-json "$source_json")
[[ -n "$ocr" ]] && args+=(--ocr "$ocr")
claudeos-shelf "${args[@]}" >/dev/null || exit 1
claudeos_notify --urgency=low "Shelved" "$(claudeos-shelf list | jq -r .name): region${ocr:+ — $(head -c 80 <<<"$ocr" | tr '\n' ' ')}"
