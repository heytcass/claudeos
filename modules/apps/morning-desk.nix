# modules/apps/morning-desk.nix — the day starts already prepared.
#
# Overnight (05:30), an agent reads the morning: calendar (gcalcli, if
# connected), weather, the journal diary's overnight findings, repo and
# system state — and writes ~/Desk/today/index.html: a self-contained,
# Stylix-themed dashboard ordered by what deserves attention first
# (Jasper doctrine: ONE most important thing on top, never a feed).
# It opens once a day in Chrome app mode, the first time the session is
# unlocked after the build — armed by a timer, not by login. A laptop that
# suspends rather than reboots enters graphical-session.target once and then
# never again, so a login-only trigger shows the page exactly once, ever.
#
# Presentation is NOT the model's job. The <style> and <script> below are
# built here, from the Stylix palette and the brand faces in lib/theme.nix,
# and concatenated around the model's output. Claude emits only body markup,
# so a bad generation can degrade the prose but never the design. The chart
# is rendered by the script from a data-hours JSON blob — the model supplies
# numbers, never geometry.
#
# DE-agnostic by design: the artifact is a file; the opener is a URL.
# Calendar bootstrap (one-time, interactive): run `gcalcli init` with the
# Google OAuth client from sops (jasper_google_client_id/secret).
#
# Cost: one sonnet call per day, riding the Claude subscription.
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude-os.morningDesk;

  claudeLib = import ../../lib/claude-script.nix { inherit pkgs lib; };
  themeLib = import ../../lib/theme.nix;

  # Every color in the page resolves from Stylix — no hardcoded hex.
  colors = config.lib.stylix.colors.withHashtag;

  # Poppins is installed for artifacts only; Lora is the system serif.
  displayFont = themeLib.brand.display.name;
  textFont = themeLib.fonts.serif.name;
  uiFont = themeLib.fonts.sansSerif.name;

  # ---- Head: doctype, meta, and the entire visual system ----
  headHtml = pkgs.writeText "morning-desk-head.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Today</title>
    <style>
      :root {
        --base00: ${colors.base00};
        --base01: ${colors.base01};
        --base02: ${colors.base02};
        --base03: ${colors.base03};
        --base04: ${colors.base04};
        --base05: ${colors.base05};
        --base08: ${colors.base08};
        --base09: ${colors.base09};
        --base0B: ${colors.base0B};
        --base0C: ${colors.base0C};
        --base0D: ${colors.base0D};

        --ink: var(--base05);
        --ink-2: var(--base04);
        --ink-3: var(--base03);
        --line: var(--base02);
        --accent: var(--base0D);
        --rain: var(--base0C);
        --ok: var(--base0B);
        --warn: var(--base08);

        --font-display: "${displayFont}", "${uiFont}", system-ui, sans-serif;
        --font-text: "${textFont}", Georgia, serif;
        --font-ui: "${uiFont}", system-ui, sans-serif;
        --ease: cubic-bezier(.22,.61,.36,1);
      }

      * { box-sizing: border-box; margin: 0; padding: 0; }

      body {
        background: var(--base00);
        color: var(--ink);
        font-family: var(--font-text);
        min-height: 100vh;
        padding: 4vw 5vw 3rem;
        display: flex;
        justify-content: center;
      }

      .dashboard {
        width: 100%;
        max-width: 820px;
        display: flex;
        flex-direction: column;
        gap: 2.5rem;
      }

      /* ---- Motion: staggered rise, hover lift ---- */
      @keyframes rise {
        from { opacity: 0; transform: translateY(14px); }
        to   { opacity: 1; transform: none; }
      }
      @keyframes grow {
        from { transform: scaleY(0); }
        to   { transform: scaleY(1); }
      }

      .card {
        animation: rise .6s var(--ease) both;
        animation-delay: calc(var(--i, 0) * 70ms);
        transition: transform .25s var(--ease), box-shadow .25s var(--ease),
                    border-color .25s var(--ease);
      }
      .card:hover {
        transform: translateY(-2px);
        box-shadow: 0 12px 32px -14px rgb(0 0 0 / .65);
        border-color: var(--base03);
      }

      @media (prefers-reduced-motion: reduce) {
        *, *::before, *::after {
          animation: none !important;
          transition: none !important;
        }
        .temp-line { stroke-dasharray: none !important; stroke-dashoffset: 0 !important; }
        .card:hover { transform: none; }
      }

      .date-line {
        font-family: var(--font-ui);
        color: var(--ink-3);
        font-size: .95rem;
        letter-spacing: .04em;
        text-transform: uppercase;
      }

      /* ---- Hero: the one thing that matters ---- */
      .hero {
        position: relative;
        overflow: hidden;
        isolation: isolate;
        background: linear-gradient(160deg, var(--base01), var(--base00));
        border: 1px solid var(--line);
        border-left: 5px solid var(--accent);
        border-radius: 18px;
        padding: 2.4rem 2.1rem;
      }
      .hero::after {
        content: "";
        position: absolute;
        inset: -45% -12% auto auto;
        width: 58%;
        aspect-ratio: 1;
        background: radial-gradient(circle,
          color-mix(in oklab, var(--accent) 34%, transparent), transparent 70%);
        filter: blur(34px);
        z-index: -1;
        pointer-events: none;
      }
      .hero-eyebrow {
        font-family: var(--font-ui);
        color: var(--base09);
        font-size: .8rem;
        font-weight: 600;
        letter-spacing: .1em;
        text-transform: uppercase;
        margin-bottom: .7rem;
      }
      .hero-headline {
        font-family: var(--font-display);
        font-size: clamp(1.9rem, 4.6vw, 2.75rem);
        font-weight: 600;
        line-height: 1.12;
        letter-spacing: -.02em;
        margin-bottom: .85rem;
        text-wrap: balance;
      }
      .hero-sub {
        font-size: 1.05rem;
        color: var(--ink-2);
        line-height: 1.6;
        max-width: 58ch;
      }

      .setup-hint {
        background: var(--base01);
        border: 1px dashed var(--line);
        border-radius: 12px;
        padding: 1rem 1.25rem;
        display: flex;
        align-items: center;
        gap: .9rem;
        font-size: .9rem;
        color: var(--ink-3);
      }
      .setup-hint .dot {
        width: 8px; height: 8px; border-radius: 50%;
        background: var(--accent); flex-shrink: 0;
      }
      .setup-hint code {
        font-family: ui-monospace, monospace;
        background: var(--base02);
        color: var(--ink-2);
        padding: .15rem .4rem;
        border-radius: 5px;
        font-size: .85em;
      }

      .section-title {
        font-family: var(--font-ui);
        font-size: .8rem;
        font-weight: 600;
        letter-spacing: .1em;
        text-transform: uppercase;
        color: var(--ink-3);
        margin-bottom: 1rem;
      }

      /* ---- Chart: two panels, one shared x-axis. Never a dual axis. ---- */
      .chart {
        background: var(--base01);
        border: 1px solid var(--line);
        border-radius: 14px;
        padding: 1.4rem 1.5rem 1rem;
      }
      .panel + .panel { margin-top: 1.5rem; }
      .panel-title {
        font-family: var(--font-ui);
        font-size: .75rem;
        font-weight: 600;
        letter-spacing: .08em;
        text-transform: uppercase;
        color: var(--ink-3);
        margin-bottom: .75rem;
      }

      .plot { position: relative; height: 150px; }
      .plot svg { display: block; width: 100%; height: 100%; overflow: visible; }
      .grid-line { stroke: var(--line); stroke-width: 1; }
      .temp-area { fill: color-mix(in oklab, var(--accent) 12%, transparent); stroke: none; }
      .temp-line {
        fill: none;
        stroke: var(--accent);
        stroke-width: 2;
        stroke-linecap: round;
        stroke-linejoin: round;
        transition: stroke-dashoffset 1.2s ease-out .2s;
      }
      .now-rule { stroke: var(--base03); stroke-width: 1; }

      .overlay { position: absolute; inset: 0; pointer-events: none; }
      .point { position: absolute; transform: translate(-50%, -50%); }
      .point-dot {
        display: block; width: 9px; height: 9px; border-radius: 50%;
        background: var(--accent);
        box-shadow: 0 0 0 2px var(--base01); /* surface ring, not a border */
      }
      .point-label {
        position: absolute; left: 50%; transform: translateX(-50%);
        font-family: var(--font-ui);
        font-size: .72rem; font-weight: 600;
        color: var(--ink-2);
        white-space: nowrap;
      }
      .point-hot .point-label { bottom: 14px; }
      .point-cold .point-label { top: 14px; }

      /* padding-top reserves label headroom on the GRID, so every column's
         track is the same height — a labelled bar and a quiet one share one
         scale. Never let a label eat plot height. */
      .bars { display: grid; height: 112px; padding-top: 20px; align-items: end; }
      .bar-col {
        position: relative;
        display: flex; flex-direction: column; align-items: center;
        justify-content: flex-end; height: 100%;
        padding-inline: 1px; /* the 2px surface gap between neighbours */
      }
      .bar-track { width: 100%; max-width: 24px; height: 100%; display: flex; align-items: flex-end; }
      .bar-fill {
        width: 100%;
        background: var(--base02);
        border-radius: 4px 4px 0 0; /* rounded data-end, square at baseline */
        transform-origin: bottom;
        animation: grow .7s var(--ease) both;
        animation-delay: var(--d, 0ms);
      }
      .bar-col.is-wet .bar-fill { background: var(--rain); }
      .bar-label {
        position: absolute;
        left: 50%;
        bottom: calc(var(--h, 0) * 1% + 6px); /* rides its own bar's tip */
        transform: translateX(-50%);
        font-family: var(--font-ui);
        font-size: .68rem; font-weight: 600;
        color: var(--ink-2);
        white-space: nowrap;
      }

      .axis {
        display: grid;
        margin-top: .55rem;
        padding-top: .55rem;
        border-top: 1px solid var(--line);
      }
      .tick {
        font-family: var(--font-ui);
        font-variant-numeric: tabular-nums;
        font-size: .7rem;
        color: var(--ink-3);
        text-align: center;
      }
      .tick.is-now { color: var(--ink); font-weight: 600; }

      .table-view { margin-top: 1rem; }
      .table-view summary {
        font-family: var(--font-ui);
        font-size: .72rem;
        color: var(--ink-3);
        cursor: pointer;
        letter-spacing: .04em;
      }
      .table-view table {
        margin-top: .75rem;
        width: 100%;
        border-collapse: collapse;
        font-family: var(--font-ui);
        font-variant-numeric: tabular-nums;
        font-size: .78rem;
      }
      .table-view th, .table-view td {
        text-align: right;
        padding: .3rem .5rem;
        border-bottom: 1px solid var(--line);
        color: var(--ink-2);
      }
      .table-view th { color: var(--ink-3); font-weight: 600; }
      .table-view th:first-child, .table-view td:first-child { text-align: left; }

      .weather-caption {
        margin-top: .9rem;
        font-size: .88rem;
        color: var(--ink-3);
      }

      .journal-card {
        background: var(--base01);
        border: 1px solid var(--line);
        border-radius: 12px;
        padding: 1.1rem 1.25rem;
        font-size: .95rem;
        color: var(--ink-2);
        display: flex;
        align-items: center;
        gap: .75rem;
      }
      .journal-card .check { color: var(--ok); font-size: 1.1rem; }

      footer {
        margin-top: 1rem;
        padding-top: 1.25rem;
        border-top: 1px solid var(--line);
        display: flex;
        flex-wrap: wrap;
        gap: .5rem 1.5rem;
        font-family: var(--font-ui);
        font-size: .78rem;
        color: var(--ink-3);
      }
      footer .item { display: flex; align-items: center; gap: .4rem; }
      footer .warn { color: var(--warn); }
      footer .dot { width: 6px; height: 6px; border-radius: 50%; background: var(--warn); }
      footer .dot.ok { background: var(--ok); }

      @media (max-width: 560px) {
        .hero { padding: 1.75rem 1.4rem; }
        .point-label { display: none; }
      }
    </style>
    </head>
    <body>
  '';

  # ---- Tail: the renderer. Model supplies numbers; this owns geometry. ----
  tailHtml = pkgs.writeText "morning-desk-tail.html" ''
    <script>
    (function () {
      var NS = "http://www.w3.org/2000/svg";
      var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

      function el(tag, cls, txt) {
        var n = document.createElement(tag);
        if (cls) { n.className = cls; }
        if (txt !== undefined) { n.textContent = txt; }
        return n;
      }
      function svgEl(tag, attrs) {
        var n = document.createElementNS(NS, tag);
        for (var k in attrs) { n.setAttribute(k, attrs[k]); }
        return n;
      }

      // Which hours read as a rain window: they get the accent hue and a
      // direct label. Everything else stays neutral gray. Emphasis is by
      // value, never by re-hueing the series.
      function rainWindow(hours) {
        return hours.map(function (h) { return h.rain >= 50; });
      }

      function build(root) {
        var hours;
        try { hours = JSON.parse(root.getAttribute("data-hours")); }
        catch (e) { return; }
        if (!Array.isArray(hours) || hours.length < 2) { return; }

        var n = hours.length;
        var temps = hours.map(function (h) { return h.temp; });
        var tmin = Math.min.apply(null, temps);
        var tmax = Math.max.apply(null, temps);
        var span = (tmax - tmin) || 1;
        var hot = temps.indexOf(tmax);
        var cold = temps.indexOf(tmin);
        var wet = rainWindow(hours);
        var nowIdx = hours.findIndex(function (h) { return h.now === true; });

        var W = 720, H = 150, PAD = 24;
        function cx(i) { return ((i + 0.5) / n) * W; }
        function cy(t) { return H - PAD - ((t - tmin) / span) * (H - 2 * PAD); }

        // --- Panel 1: temperature line ---
        var p1 = el("div", "panel");
        p1.appendChild(el("div", "panel-title", "Temperature °F"));
        var plot = el("div", "plot");
        var svg = svgEl("svg", {
          viewBox: "0 0 " + W + " " + H,
          preserveAspectRatio: "none",
          "aria-hidden": "true"
        });

        [PAD, H / 2, H - PAD].forEach(function (y) {
          svg.appendChild(svgEl("line", {
            x1: 0, y1: y, x2: W, y2: y,
            "class": "grid-line", "vector-effect": "non-scaling-stroke"
          }));
        });

        var pts = hours.map(function (h, i) {
          return cx(i).toFixed(1) + "," + cy(h.temp).toFixed(1);
        });
        svg.appendChild(svgEl("path", {
          "class": "temp-area",
          d: "M" + cx(0).toFixed(1) + "," + H + " L" + pts.join(" L") +
             " L" + cx(n - 1).toFixed(1) + "," + H + " Z"
        }));
        if (nowIdx >= 0) {
          svg.appendChild(svgEl("line", {
            x1: cx(nowIdx), y1: 0, x2: cx(nowIdx), y2: H,
            "class": "now-rule", "vector-effect": "non-scaling-stroke"
          }));
        }
        var line = svgEl("path", {
          "class": "temp-line",
          d: "M" + pts.join(" L"),
          "vector-effect": "non-scaling-stroke"
        });
        svg.appendChild(line);
        plot.appendChild(svg);

        var overlay = el("div", "overlay");
        [[hot, "point-hot"], [cold, "point-cold"]].forEach(function (pair) {
          var i = pair[0];
          var p = el("div", "point " + pair[1]);
          p.style.left = ((i + 0.5) / n * 100) + "%";
          p.style.top = (cy(hours[i].temp) / H * 100) + "%";
          p.appendChild(el("span", "point-dot"));
          p.appendChild(el("span", "point-label", hours[i].temp + "°"));
          overlay.appendChild(p);
        });
        plot.appendChild(overlay);
        p1.appendChild(plot);

        // --- Panel 2: rain probability columns, same x positions ---
        var p2 = el("div", "panel");
        p2.appendChild(el("div", "panel-title", "Chance of rain %"));
        var bars = el("div", "bars");
        bars.style.gridTemplateColumns = "repeat(" + n + ", 1fr)";
        hours.forEach(function (h, i) {
          var col = el("div", "bar-col" + (wet[i] ? " is-wet" : ""));
          col.title = h.t + " — " + h.rain + "% chance of rain";
          // The label positions itself off --h, so it tracks the bar's tip
          // without occupying any of the column's plot height.
          col.style.setProperty("--h", h.rain);
          var track = el("div", "bar-track");
          var fill = el("div", "bar-fill");
          fill.style.height = Math.max(h.rain, 1.5) + "%";
          fill.style.setProperty("--d", (i * 45) + "ms");
          track.appendChild(fill);
          col.appendChild(track);
          if (wet[i]) { col.appendChild(el("div", "bar-label", h.rain + "%")); }
          bars.appendChild(col);
        });
        p2.appendChild(bars);

        // --- Shared axis ---
        var axis = el("div", "axis");
        axis.style.gridTemplateColumns = "repeat(" + n + ", 1fr)";
        hours.forEach(function (h, i) {
          axis.appendChild(el("div", "tick" + (i === nowIdx ? " is-now" : ""), h.t));
        });

        // --- Table view: every value reachable without hovering ---
        var det = el("details", "table-view");
        det.appendChild(el("summary", null, "Table view"));
        var tbl = el("table");
        var thead = el("thead");
        var hr = el("tr");
        ["Time", "Temp °F", "Rain %"].forEach(function (t) {
          hr.appendChild(el("th", null, t));
        });
        thead.appendChild(hr);
        tbl.appendChild(thead);
        var tb = el("tbody");
        hours.forEach(function (h) {
          var tr = el("tr");
          tr.appendChild(el("td", null, h.t));
          tr.appendChild(el("td", null, String(h.temp)));
          tr.appendChild(el("td", null, String(h.rain)));
          tb.appendChild(tr);
        });
        tbl.appendChild(tb);
        det.appendChild(tbl);

        root.appendChild(p1);
        root.appendChild(p2);
        root.appendChild(axis);
        root.appendChild(det);

        if (!reduce) {
          var len = line.getTotalLength();
          line.style.strokeDasharray = len;
          line.style.strokeDashoffset = len;
          requestAnimationFrame(function () {
            requestAnimationFrame(function () { line.style.strokeDashoffset = 0; });
          });
        }
      }

      var charts = document.querySelectorAll(".chart");
      for (var i = 0; i < charts.length; i++) { build(charts[i]); }
    })();
    </script>
    </body>
    </html>
  '';

  buildScript = claudeLib.mkClaudeScript {
    name = "claudeos-morning-desk";
    runtimeInputs = [
      pkgs.curl
      pkgs.gcalcli
    ];
    text = ''
      DESK_DIR="$HOME/Desk/today"
      ARCHIVE_DIR="$HOME/Desk/archive"
      mkdir -p "$DESK_DIR" "$ARCHIVE_DIR"

      # Archive a previous day's dashboard before overwriting
      if [[ -f "$DESK_DIR/index.html" ]]; then
        prev_day=$(date -r "$DESK_DIR/index.html" +%F 2>/dev/null)
        [[ "$prev_day" != "$(date +%F)" && -n "$prev_day" ]] \
          && cp "$DESK_DIR/index.html" "$ARCHIVE_DIR/$prev_day.html" 2>/dev/null
      fi

      # ---- Collectors (each degrades gracefully) ----
      today=$(date "+%A, %B %-d, %Y")
      now_hour=$(date +%-H)

      weather=$(timeout 15 curl -fsSL "wttr.in/?format=j1" 2>/dev/null \
        | jq -c '{now: .current_condition[0] | {tempF: .temp_F, feelsF: .FeelsLikeF, desc: .weatherDesc[0].value}, today: .weather[0] | {maxF: .maxtempF, minF: .mintempF, hourly: [.hourly[] | {time, tempF, chanceofrain, desc: .weatherDesc[0].value}]}}' 2>/dev/null)
      [[ -z "$weather" ]] && weather="unavailable"

      calendar="not connected — run: gcalcli init (OAuth client in sops as jasper_google_client_id/secret)"
      if command -v gcalcli >/dev/null && [[ -d "$HOME/.local/share/gcalcli" || -f "$HOME/.gcalcli_oauth" ]]; then
        calendar=$(timeout 60 gcalcli --nocolor agenda "$(date +%F)" "$(date -d tomorrow +%F)" 2>/dev/null || echo "fetch failed")
      fi

      diary=""
      [[ -s "$DIARY_ACTIONABLE_FILE" ]] && diary=$(cat "$DIARY_ACTIONABLE_FILE")

      failed_units=$(claudeos_failed_units)
      disk_pct=$(claudeos_disk_pct)
      repo=$(claudeos_repo_summary)
      update_age=$(claudeos_update_age_days)

      snapshot="DATE: $today on $(hostname) (current hour, 24h: $now_hour)
      WEATHER (json or unavailable): $weather
      CALENDAR (today + tomorrow): $calendar
      OVERNIGHT JOURNAL TRIAGE: ''${diary:-nothing actionable}
      SYSTEM: failed units: ''${failed_units:-none}; root disk ''${disk_pct:-?}% used; last successful flake update ''${update_age:-unknown} days ago
      CONFIG REPO: ''${repo:-unknown}"

      # ---- The brain: content only. The design is not up for negotiation. ----
      fragment=""
      if [[ -x "$CLAUDE_BIN" ]]; then
        prompt="You are ClaudeOS. Write the BODY MARKUP of today's morning dashboard.

      Output ONLY the markup that goes inside <body>. Do NOT emit <!DOCTYPE>, <html>,
      <head>, <body>, <style>, or <script> — a themed stylesheet and a chart renderer
      are wrapped around your output automatically. Never write a hex color, a style
      attribute, or a font name; use only the classes below. No markdown fences.

      Content doctrine:
      - Information hierarchy is the product: the single most important thing about
        today goes in the hero, large and unmissable (a conflict, a deadline, the
        first meeting, a deliberate 'clear morning — protect it'). Never a feed.
      - Then the weather chart; then anything actionable from the overnight journal
        triage; then, smallest, system state in the footer (only if something is wrong).
      - Don't restate raw data; synthesize. Don't invent events. If the calendar isn't
        connected, emit the setup-hint card, not an error.

      Required skeleton — copy this structure, fill in the prose:

      <div class=\"dashboard\">
        <div class=\"date-line\">$today &middot; $(hostname)</div>

        <section class=\"hero card\" style=\"--i:0\">
          <div class=\"hero-eyebrow\">SHORT KICKER</div>
          <div class=\"hero-headline\">The one thing that matters today</div>
          <div class=\"hero-sub\">Two or three sentences of synthesis.</div>
        </section>

        <!-- Only if the calendar is not connected: -->
        <div class=\"setup-hint card\" style=\"--i:1\">
          <div class=\"dot\"></div>
          <div>Calendar isn't connected... Run <code>gcalcli init</code>.</div>
        </div>

        <section class=\"card\" style=\"--i:2\">
          <div class=\"section-title\">Today's weather</div>
          <div class=\"chart\" data-hours='[{\"t\":\"12AM\",\"temp\":73,\"rain\":7}]'></div>
          <div class=\"weather-caption\">One line naming the rain windows.</div>
        </section>

        <section class=\"card\" style=\"--i:3\">
          <div class=\"section-title\">Overnight triage</div>
          <div class=\"journal-card\"><span class=\"check\">&#10003;</span><span>...</span></div>
        </section>

        <footer class=\"card\" style=\"--i:4\">
          <div class=\"item warn\"><span class=\"dot\"></span>...</div>
          <div class=\"item\"><span class=\"dot ok\"></span>...</div>
        </footer>
      </div>

      The chart: data-hours is a JSON array (single-quoted attribute, so use double
      quotes inside) of 6-8 evenly spaced hours covering the day. Each entry is
      {\"t\": \"3PM\", \"temp\": <integer F>, \"rain\": <integer 0-100>}. Add \"now\": true
      to the ONE entry nearest the current hour. Supply numbers only — the renderer
      draws the temperature curve, the rain columns, the axis and the table.
      Increment --i on each top-level card so they rise in order.

      CONTEXT SNAPSHOT:
      $snapshot"

        fragment=$(claude_headless sonnet "$prompt" \
          | sed -e 's/^```html$//' -e 's/^```$//' \
                -e '/<!DOCTYPE/Id' -e '/<\/\?html/Id' -e '/<\/\?body/Id')
      fi

      # A fragment must at minimum carry the hero; otherwise fall back.
      if [[ "$fragment" != *"hero-headline"* ]]; then
        fragment="<div class=\"dashboard\">
          <div class=\"date-line\">$today &middot; $(hostname)</div>
          <section class=\"hero card\" style=\"--i:0\">
            <div class=\"hero-eyebrow\">Raw snapshot</div>
            <div class=\"hero-headline\">$today</div>
            <div class=\"hero-sub\">Claude was unavailable — the morning's data, unsynthesized.</div>
          </section>
          <div class=\"journal-card card\" style=\"--i:1\"><span>$(printf '%s' "$snapshot" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g')</span></div>
        </div>"
      fi

      {
        cat ${headHtml}
        printf '%s\n' "$fragment"
        cat ${tailHtml}
      } > "$DESK_DIR/index.html"
    '';
  };

  showScript = pkgs.writeShellScript "claudeos-morning-desk-show" ''
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.google-chrome
        pkgs.systemd # loginctl
      ]
    }:$PATH"
    STAMP_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/claudeos-desk"
    mkdir -p "$STAMP_DIR"
    STAMP="$STAMP_DIR/shown-$(date +%F)"
    [[ -e "$STAMP" ]] && exit 0
    DESK="$HOME/Desk/today/index.html"
    # Wait (up to 10 min) for TODAY'S dashboard: at first login the
    # Persistent=true catch-up build may still be running — opening
    # yesterday's file now would show a stale page and stamp the day done.
    for _ in $(seq 120); do
      [[ -f "$DESK" && "$(date -r "$DESK" +%F)" == "$(date +%F)" ]] && break
      sleep 5
    done
    [[ -f "$DESK" ]] || exit 0
    [[ "$(date -r "$DESK" +%F)" == "$(date +%F)" ]] || exit 0

    # Wait until someone is actually at the machine. The daily timer fires at
    # dawn; opening Chrome behind a lock screen just parks a window nobody
    # asked for. Give up after 4h — tomorrow gets a fresh page anyway.
    session=$(loginctl show-user "$(id -un)" --value -p Display 2>/dev/null || true)
    if [[ -n "$session" ]]; then
      for _ in $(seq 2880); do
        [[ "$(loginctl show-session "$session" --value -p LockedHint 2>/dev/null || echo no)" == "no" ]] && break
        sleep 5
      done
    fi

    sleep 8 # let the session settle before claiming the screen
    # Atomic claim: the login trigger and the daily timer can both reach here.
    # noclobber makes exactly one of them win; the loser exits quietly.
    (set -o noclobber; : > "$STAMP") 2>/dev/null || exit 0
    exec google-chrome-stable --app="file://$DESK"
  '';
in
{
  options.claude-os.morningDesk = {
    enable = lib.mkEnableOption "overnight-built HTML morning dashboard, auto-opened at first login";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 05:30:00";
      description = "When to build the dashboard (systemd calendar expression).";
    };

    showSchedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 05:35:00";
      description = ''
        When to arm the opener (systemd calendar expression). It then waits for
        the session to be unlocked, so this is when the day's page becomes
        eligible to appear — not when a window pops up.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.claudeos-morning-desk = {
      description = "ClaudeOS morning desk dashboard build";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString buildScript;
        TimeoutStartSec = "15min";
        SyslogIdentifier = "morning-desk";
      };
    };

    systemd.user.timers.claudeos-morning-desk = {
      description = "Build the morning desk dashboard";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };

    # Two triggers, because they cover different days. graphical-session
    # catches a fresh boot or login; the timer catches every other morning on
    # a laptop that suspends instead of rebooting — where the session target
    # fires once and then never again. The per-day stamp keeps them honest.
    systemd.user.services.claudeos-morning-desk-show = {
      description = "Open today's dashboard once the session is unlocked";
      wantedBy = [ "graphical-session.target" ];
      # Order after the build when both jobs are queued together (login-time
      # Persistent catch-up); the in-script wait covers the async case.
      after = [
        "graphical-session.target"
        "claudeos-morning-desk.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString showScript;
        # Must outlast the build wait (10min) plus the unlock wait (4h).
        TimeoutStartSec = "5h";
      };
    };

    systemd.user.timers.claudeos-morning-desk-show = {
      description = "Arm the morning desk opener for today";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.showSchedule;
        # Catch up after a suspend spanning the scheduled time; the script
        # then waits for unlock rather than opening into a locked screen.
        Persistent = true;
      };
    };
  };
}
