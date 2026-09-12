# Jasper insight quality — what "good" looks like

A regression benchmark for the Jasper lane (`modules/apps/jasper.nix`). The lane
is one prompt, so every change to it is a change to *all* future insights with no
build-time gate that can catch a regression — `nix build` proves the script
evaluates, not that the sentence is any good. This file is the substitute: a
record of what a good insight is made of, so a prompt edit can be judged against
something.

**Personal data stays out of this file.** Verbatim runs — real calendar contents,
names, addresses — go in `~/.config/jasper-companion/insight-log.md`, which is
local-only for the same reason `context.md` is. Add every entry to both: the
mechanism here, the evidence there.

## The anatomy of a good insight

Derived from the 2026-09-12 midday run, the first one rated as matching the
original intent. Six properties, in rough order of how hard they are to get:

1. **It names an inference, not an entry.** The load-bearing phrase was a
   *quiet solo stretch* — a fact present in none of the inputs, derived from an
   absence (partner's calendar occupied, child's event already past, user's own
   calendar empty). An insight whose every clause traces to one calendar row has
   failed rule 1 of the prompt even if it reads well.
2. **Ownership is correct and invisible.** Third-party events are framed as
   theirs (`<child> has X`), the user's as theirs. When a shared calendar's
   event *title* names the user, the title wins over the calendar.
3. **It triages hard and silently.** The winning run had 10 events and a weather
   payload in context and used 5 of them. The omissions were as load-bearing as
   the inclusions — notably a location field that would have been absurd to act
   on (a broadcast event whose "location" is the host city abroad), which no
   prompt rule explicitly guards against.
4. **It spans the seam between today and tomorrow.** "Use this gap now, because
   of that sequence later" is the shape. A single-day insight is usually just a
   calendar restatement.
5. **It is true at the moment it is written.** "This quiet stretch" only works
   if the stretch is actually open *now*. See the timing section below — this is
   the property most at the mercy of the gate.
6. **The emoji carries the mood alone.** The bar renders only the emoji until
   clicked. It must track the insight's *action* (a free window, a crunch, a
   departure), not its subject matter.

## Failure modes seen in practice

- **Emoji/subject mismatch.** The best run so far still scored a celebration
  emoji for a "you have a free hour, get ahead" sentence, because the input
  happened to contain two birthday signals. The subject is the wrong anchor.
- **Hedged durations.** The prompt feeds start times only, so the model guesses
  when things end and says so out loud ("wraps around 12:30ish"). The fix is
  input-side, not prompt-side: `gcalcli agenda --tsv` emits
  `start_date/start_time/end_date/end_time/title/location/calendar`, so end
  times cost nothing extra.
- **Unmapped calendars handled by inference.** The ownership rule generalizes
  surprisingly well from a display name alone, but that is luck, not
  configuration. Every calendar the model must attribute should be mapped in
  `context.md`; the prompt rule is then a check, not a guess.
- **Afternoon rendered as evening.** Cosmetic, but it is the kind of drift that
  makes the whole thing feel approximate.

## Timing: the gate decides whether the insight can be true

The significance gate hashes `date | phase | calendar | weather_stable` and calls
the model only on a change (or a stale heartbeat window). Of those four fields:

- `calendar` is a full-day agenda, so it is **stable from midnight to midnight**
  — it does not change when an event starts or ends.
- `phase` changes three times a day.
- `weather_stable` re-fetches on a 15-minute cache and is the only field that
  moves on the poll's own timescale.

So on a normal day, **weather noise is what decides when Jasper speaks**, and
whether it speaks at a moment when its observation is actually true is chance.
The 2026-09-12 run landed 29 seconds after the event it described began; that
was a coincidence of a forecast field settling, not a design.

The repair is to give the gate an **event-boundary signal**: a discrete value
derived from the same calendar fetch that changes exactly when the day's state
changes — an event starting, an event ending, a departure window opening. Because
it is discrete, it costs nothing on a quiet stretch (the hash simply does not
move), and it fires once, promptly, on each transition. See
`modules/apps/jasper.nix` (`jasper_boundary_signal`).

### The signal, as chosen (2026-09-12)

`started-ended-imminent` for today's timed events, with a **60-minute** horizon
for `imminent`. Three properties are worth preserving through any future edit:

- **Discreteness is the whole point.** A continuous field — "minutes until the
  next event" — differs at every poll and would fire the gate every 30 minutes,
  destroying the significance gate entirely. A *count* is constant across a quiet
  stretch and moves exactly once per boundary. This is the same trick
  `weather_stable` already uses (the day's hi/lo, never the live temperature).
- **The horizon is derived, not guessed.** Polls land on `:00`/`:30`, so with
  horizon *H* the first warning arrives between *H* and *H−30* minutes ahead.
  *H*=30 therefore has a worst case of **zero** notice; *H*=60 guarantees at
  least 30 minutes. Widening *H* does not add flips — consecutive polls that both
  see the same event ahead yield the same count — so it buys lead time for free.
- **Cost is bounded and rides the subscription.** Simulated against two real
  days, the boundary field contributes 11–12 flips across the 06:00–21:30 poll
  window, against a prior baseline of roughly 7 model calls per day. Flips
  overlap with weather and phase changes rather than stacking, so the practical
  total is 12–14 short sonnet calls per day on the Max lane — no API spend, and
  the poll itself is still dumb shell. "Nothing polls an LLM" holds *better* than
  before: the trigger is now an actual event rather than forecast noise.

## Adding an entry

When a run is notably good or notably bad:

1. Append the verbatim run to `~/.config/jasper-companion/insight-log.md` —
   output, all three inputs, the previous insight, and clause-by-clause
   attribution. Recover inputs by re-running the collectors and reading
   `~/.cache/claudeos-monitor/presence-done.jsonl` (last 20 lane results, which
   is where insight history survives after `jasper-insight.txt` is overwritten).
2. Fold anything generalizable into the lists above, redacted.
