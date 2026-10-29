# The Shelf: working memory for task contexts

*Designed 2026-10-28. Prompted by Scott Jenson's Akademy 2026 talk ("Are we
really going to use the same Desktop UX forever?"), which calls the missing
working memory "the curse of direct manipulation": the clipboard forgets, and
the material you gather while working has nowhere to live. His prototype is an
Obsidian-Canvas-style collection that persists across sessions and that a
local model can organise. This is the ClaudeOS version of that idea.*

It extends existing doctrine instead of adding new doctrine:

- **Task contexts** (Phase 3 of the AI-native HMI plan) remember your *tools
  and places*. The Shelf remembers your *material*. `resume refinance` brings
  back the windows **and** the PDFs, the rate screenshot and the pasted email.
- **"The workspace is a repo."** A shelf is text plus blobs in the
  context store's own git repo, so every change, Claude's tidy included, is a
  commit that can be reverted.
- **Autonomy is earned.** v1 tidying runs only when you ask, and its output is
  one revertible commit. It never runs overnight.

---

## Decisions (made 2026-10-28)

| Question | Decision |
|---|---|
| Surface | **An Island popup**, a sibling of `CalendarPopup` / `MediaPopup`. Not an edge drawer and not a separate canvas window. |
| Scope | **One shelf per context, plus a "loose" shelf.** Outside any context, items go to `_loose`; they can be moved into a context later. |
| Capture | **Drag and drop** onto the Island, **a hotkey to shelve the clipboard**, and **a hotkey to shelve a screen region** (image plus OCR text). There is no `shelve …` intent-line route in v1. |
| AI role | **Tidy on request.** One Sonnet call groups and annotates the shelf, producing one commit and a receipt card. |

## What a shelf is

Storage sits beside the context manifests in
`$XDG_STATE_HOME/claudeos/contexts/`, the auto-committing git repo that
already exists:

```
contexts/
  refinance.json                     # existing context manifest (unchanged)
  shelf/refinance/shelf.json         # NEW: shelf manifest
  shelf/refinance/blobs/<id>.png     # NEW: blobs captured by value
  shelf/_loose/shelf.json
  shelf/_loose/blobs/…
```

Shelves live in a `shelf/` subdirectory, not beside the manifests as
`<slug>.shelf.json`. Both `claudeos-context list` and the `Contexts.qml` probe
glob `contexts/*.json`, so a sibling shelf file would show up as a context.
The subdirectory keeps shelves in the same git repo but outside that glob.

This repo is local state and is never pushed. That matters because the
ClaudeOS repo is public: shelf contents never leave the machine through git.

### Item schema (`modules/apps/shelf/shelf.schema.json`)

```jsonc
{
  "name": "refinance",
  "items": [
    {
      "id": "k3f9a2",                 // short random id, stable for the item's life
      "kind": "file|image|text|link",
      "added": 1793234567,
      "payload": {                    // exactly one, matching kind
        "path": "/home/tom/Downloads/payoff.pdf",   // file: BY REFERENCE
        "blob": "blobs/k3f9a2.png",                 // image: BY VALUE, relative to the shelf dir
        "text": "…",                                // text: inline, size-capped
        "url": "https://…"                          // link
      },
      "ocr": "…",                     // image: text from the grab-text pipeline
      "source": {                     // provenance, best-effort, structured only
        "class": "google-chrome", "title": "Rates — Bank", "url": "https://…"
      },
      "group": "Lenders",             // optional; written by tidy or by hand
      "note": "lowest APR so far"     // optional
    }
  ],
  "groups": ["Lenders", "Documents"]  // ordered; items without a group come first
}
```

**Files are kept by reference, everything else by value.** Copying a 40 MB PDF
into git just to shelve it would bloat the repo. Images and text clips have no
other home, so they get copied in. If a referenced file disappears, its tile
shows "moved or deleted" instead of failing silently. For downloads, the
`user.xdg.origin.url` xattr is read into `source.url` when present.

## Pieces

### 1. `claudeos-shelf` CLI (`modules/apps/shelf/default.nix`)

The only writer. The bar, the hotkeys and the tidy agent all go through it,
the same way every context write goes through `claudeos_context_install`.

```
claudeos-shelf add {file <path>|image <png>|text -|link <url>} [--source-json …]
claudeos-shelf list [<context>]            # JSON for the bar
claudeos-shelf rm <id>
claudeos-shelf move <id> <context>         # file a loose item into a context
claudeos-shelf open <id>                   # xdg-open / wl-copy, by kind
claudeos-shelf tidy [<context>]
```

- **Target shelf:** the active context, derived exactly as `Contexts.qml` does
  it (focused workspace name = context slug). Otherwise `_loose`.
- **Every write** validates against the schema and then commits. That reuses
  `_claudeos_context_commit` from `lib/claude-script.nix`, so one repo has
  one commit path.
- **Caps:** text payloads ≤ 64 KB; image blobs ≤ 5 MB; 200 items per shelf.
  Over the cap, `add` refuses with a notification instead of truncating
  silently.

### 2. Capture hotkeys (`lib/keybindings.nix`)

| Key (tentative) | Action |
|---|---|
| `Super+S` | **Shelve clipboard.** `wl-paste --list-types` picks the kind (image/png → image, text/uri-list → file or link, text → text). `source` comes from the active window (`hyprctl activewindow -j`). A sonic tick confirms. |
| `Super+Shift+S` | **Shelve region.** slurp → grim → the OCR step `claude-grab-text` already uses → `add image` with the OCR text attached. |

The keys are tentative. Before binding them, check that they're free in the
generated Hyprland config (`hypr_config_check`), since `home/hyprland.nix` also
binds keys that aren't listed in `lib/keybindings.nix`.

### 3. The Island: drop target and popup

- **`Shelf.qml` singleton** works like `Contexts.qml`: it polls
  `claudeos-shelf list` slowly and re-polls right away after any write the bar
  itself triggers. It exposes `items`, `count` and `activeShelf`. No model calls.
- **Drop face.** The Island gains a QtQuick `DropArea`. When a drag enters the
  Island, it switches to a new `drop` state (highest precedence, like OSD) and
  widens into a target labelled "Shelve to *refinance*". Dropping hands URLs
  and paths to `claudeos-shelf add file|link` and plain text to `add text`.
  The widening animates with the existing motion tokens, so the small target
  gets bigger exactly when it's needed.
- **`ShelfPopup.qml`** works like `CalendarPopup`: a grid of tiles (thumbnail,
  or file icon plus middle-elided name, or a text snippet), grouped under
  `groups` headers, with the shelf name and a **Tidy** button in the header.
  Clicking a tile opens it (file/link) or copies it (text/image).
  Right-clicking gives: move to context…, note…, remove.
- **Opening it:** a modifier-click on the Island (exact gesture decided in the
  dial-in pass), plus a hotkey. When the shelf has items, a count chip appears
  on the clock face at the same low emphasis as the active-context name.

### 4. Tidy (`claudeos-shelf tidy`)

One `claude -p` Sonnet call. It receives the shelf JSON (text, OCR, source
titles and URLs; never blob bytes) and returns a new `groups` array plus a
`group`/`note` for each item.

**Mechanical guards** (the constitution's style: machine checks, not trust):

1. Output must validate against the schema.
2. **The item-id set must be unchanged.** Tidy may group and annotate; it may
   never add, drop or rewrite a payload. This is checked with `jq` before
   install, and a violation is rejected and reported.
3. It lands as **one commit** (`shelf: tidy refinance`), so undoing it is a
   single `git revert` in the context repo, exposed as `claudeos-shelf untidy`.
4. A receipt card (`claudeos_lane_card`, id `shelf-tidy`) says what changed
   ("3 groups · 11 items · 4 notes"). A declined or failed tidy also gets a
   card, at `low` urgency, per the cards doctrine.

### 5. Context integration

- `claudeos-context restore` doesn't need to change: the Shelf follows the
  active context automatically because it's keyed on the same slug.
- `claudeos-context rm <name>` must also remove `shelf/<slug>/`, in the same
  commit.
- `wherewasi` adds one line, e.g. "refinance shelf: 11 items, last added
  payoff.pdf 2h ago".

## Phases

0. **Spikes. Done 2026-10-28; both pass. Findings below.**
1. Schema + `claudeos-shelf` CLI (add/list/rm/move/open) + context `rm` cleanup.
2. Capture hotkeys.
3. `Shelf.qml`, drop face, `ShelfPopup.qml` (dial in with the `qml-dial-in`
   skill; `quickshell_check` before every rebuild).
4. Tidy + the `untidy` revert + receipt card.
5. Docs: CAPABILITIES.md (desktop integration + cards table), the
   `claudeos` cheat sheet, `wherewasi`.

## Phase 0 spike findings (2026-10-28)

Tested with a throwaway Quickshell 0.3.2 config: an overlay `PanelWindow` pill
holding a `DropArea`, plus a tile that can be dragged out. Tom did the drags by
hand on Hyprland.

**Drag-in works on a layer-shell surface.** Here is what each source offered:

| Source | Formats offered | What the Shelf should do |
|---|---|---|
| Nautilus file | `text/uri-list` (`file://…`), `text/plain` (bare path), `application/vnd.portal.files`, `application/x-gtk-local-dnd` | `add file <path>` from the `file://` url |
| Chrome link | `text/uri-list` (url plus a second scheme-less copy), `text/plain` | `add link`, using the first url only |
| Chrome selected text | `text/plain`, `text/html`, `chromium/x-web-custom-data` | `add text` from `text/plain`; v1 drops the html |
| Chrome image (a linked thumbnail) | `text/uri-list` = **the link's target page, not the image**, `text/html` (`<img src=…>`), `application/octet-stream;name="hq720.avif"` | Look for an `application/octet-stream;name=<image ext>` format first and save its bytes as the blob (`drop.getDataAsArrayBuffer`). Otherwise fall back to the `<img src>` in the html. **Never trust `uri-list` for an image drag**: on a linked image it's the page, not the picture. |

Detection order follows from this table: image octet-stream → `file://` →
`http(s)` url → text.

**The drop target must not resize under the cursor.** When the `DropArea` sat
on the pill, widening the pill fired exit/enter on every drag. Fix (verified):
the `DropArea` covers a fixed-size region (the Island's window area), and only
the *visual* grows inside it.

**Drag-out works** into both Nautilus and a Chrome text field, with two caveats
that are now requirements:

- **Offer `Qt.CopyAction` only.** With copy, move and link all offered, the
  drop proposed *Move*, and Nautilus **moved the test file out of its original
  location**. Shelf file items are kept by reference, so a move would take the
  user's real file away from where it was. Copy-only is a hard rule, not a
  default.
- **The finish result is unreliable under QtWayland.** `Drag.onDragFinished`
  reported `Ignore` on every drop, including ones that landed. Don't build
  "it moved!" feedback on it; treat the drag as fire-and-forget.

**The drag needs a visible carry image** (Tom's feedback: with only the
closed-hand cursor it isn't clear the drag is working). `grabToImage` on the
tile → `Drag.imageSource` works on a layer surface. For the real tiles, grab a
small rendition (pass `targetSize` to `grabToImage`; `sourceSize` is ignored for
grabbed images).

## Out of scope for v1 (each needs its own design pass)

- **Overnight preparation** of shelves. This becomes possible once tidy has a
  track record, and would graduate by the usual rule: a narrow window plus a
  machine check.
- A freeform spatial canvas. The popup grid is the deliberate v1 shape.
- An intent-line `shelve …` route.
- Recording the active context on downloads (the "file provenance as memory"
  idea), which pairs naturally with this but is a separate feature.

## Blast radius

The failure lane is narrow and visible: a broken shelf affects only the
popup and the capture keys. Restore, windows and the rest of the bar don't
depend on it. One QML caveat stands, though: a broken `ShelfPopup.qml` blanks
**the whole bar** (Quickshell loads the config dir as one module), so phase 3
is gated on `quickshell_check`. Shelf data lives in the context repo, so a bad
write can be reverted with `git revert` there.
