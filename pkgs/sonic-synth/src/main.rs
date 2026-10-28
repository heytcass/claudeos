//! sonic-synth — renders the ClaudeOS sonic palette to WAVs.
//!
//! All musical decisions live in lib/sonic.nix: it derives pitches from the
//! base16 palette and timings + easing curves from the motion tokens, and hands
//! this program the result as JSON. This side only turns that spec into sound,
//! so the synth never needs to know what a palette is.
//!
//!   sonic-synth <spec.json> <out-dir>   →   <out-dir>/<name>.wav per sound
//!
//! Voice ("soft glass"): a sine plus an octave harmonic. Pitch runs through
//! fundsp oscillators driven by a control envelope, so a glide follows a motion
//! curve (CSS cubic-bezier, the same four numbers Hyprland and the bar use) with
//! a continuous phase. Amplitude is applied per sample afterwards — the control
//! envelope samples every ~2 ms, too coarse for a 3 ms detent attack.

use fundsp::prelude64::*;
use serde::Deserialize;
use std::collections::BTreeMap;
use std::path::Path;

/// A cubic-bezier easing curve: [x1, y1, x2, y2], endpoints (0,0) and (1,1).
#[derive(Deserialize, Clone, Copy)]
struct Curve([f64; 4]);

impl Curve {
    /// Progress (y) at time fraction `u` (x). y may leave 0..1 — that is the
    /// overshoot of `emphasized` or the wind-up of `anticipate`, kept on purpose.
    fn ease(self, u: f64) -> f64 {
        let [x1, y1, x2, y2] = self.0;
        let bez = |a: f64, b: f64, s: f64| {
            let r = 1.0 - s;
            3.0 * r * r * s * a + 3.0 * r * s * s * b + s * s * s
        };
        let u = u.clamp(0.0, 1.0);
        // x(s) is monotonic for 0 ≤ x1, x2 ≤ 1, so bisection always converges.
        let (mut lo, mut hi) = (0.0, 1.0);
        for _ in 0..40 {
            let mid = 0.5 * (lo + hi);
            if bez(x1, x2, mid) < u {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        bez(y1, y2, 0.5 * (lo + hi))
    }
}

#[derive(Deserialize)]
struct Spec {
    sample_rate: f64,
    root_hz: f64,
    /// dB below the note's peak at which the decay ends.
    decay_db: f64,
    tail: f64,
    curves: BTreeMap<String, Curve>,
    sounds: BTreeMap<String, Sound>,
}

#[derive(Deserialize)]
struct Sound {
    /// Peak level in dBFS; the mix is normalised to it.
    level: f64,
    notes: Vec<Note>,
}

#[derive(Deserialize, Clone)]
struct Note {
    semis: f64,
    start: f64,
    dur: f64,
    harm: f64,
    attack: f64,
    attack_curve: String,
    /// Optional glide: from `semis` to `to` over `glide` seconds along `curve`.
    to: Option<f64>,
    glide: Option<f64>,
    curve: Option<String>,
}

fn curve(spec: &Spec, name: &str) -> Curve {
    *spec
        .curves
        .get(name)
        .unwrap_or_else(|| panic!("unknown motion curve `{name}`"))
}

/// One note, rendered mono at the spec's sample rate.
fn render_note(spec: &Spec, n: &Note) -> Vec<f32> {
    let root = spec.root_hz;
    let from = n.semis;
    let to = n.to.unwrap_or(from);
    let glide = n.glide.unwrap_or(0.0);
    let glide_curve = n.curve.as_deref().map(|c| curve(spec, c));
    let semis_at = move |t: f64| match glide_curve {
        Some(c) if glide > 0.0 => from + (to - from) * c.ease(t / glide),
        _ => from,
    };
    let hz = move |t: f64| root * (semis_at(t) / 12.0).exp2();

    let mut tone =
        (envelope(hz) >> sine()) + (envelope(move |t| 2.0 * hz(t)) >> sine()) * n.harm as f32;
    let wave = Wave::render(spec.sample_rate, n.dur, &mut tone);

    // Amplitude: eased attack, then an exponential decay reaching `decay_db`
    // at the note's end, with a 5 ms linear taper so it lands on zero.
    let attack_curve = curve(spec, &n.attack_curve);
    let k = spec.decay_db / 20.0 * std::f64::consts::LN_10;
    let taper = 0.005_f64.min(n.dur / 4.0);
    wave.channel(0)
        .iter()
        .enumerate()
        .map(|(i, &s)| {
            let t = i as f64 / spec.sample_rate;
            let rise = if t < n.attack {
                attack_curve.ease(t / n.attack).clamp(0.0, 1.0)
            } else {
                1.0
            };
            let fall = if t < n.attack {
                1.0
            } else {
                (k * (t - n.attack) / (n.dur - n.attack).max(1e-6)).exp()
            };
            let end = ((n.dur - t) / taper).clamp(0.0, 1.0);
            (s as f64 * rise * fall * end) as f32
        })
        .collect()
}

fn render_sound(spec: &Spec, sound: &Sound) -> Vec<f32> {
    let sr = spec.sample_rate;
    let len = sound
        .notes
        .iter()
        .map(|n| n.start + n.dur)
        .fold(0.0, f64::max)
        + spec.tail;
    let mut mix = vec![0.0f32; (len * sr).ceil() as usize];
    for n in &sound.notes {
        let offset = (n.start * sr).round() as usize;
        for (i, s) in render_note(spec, n).into_iter().enumerate() {
            if let Some(m) = mix.get_mut(offset + i) {
                *m += s;
            }
        }
    }
    // Loudness is the spec's, not an accident of how many notes overlap.
    let peak = mix.iter().fold(0.0f32, |p, s| p.max(s.abs()));
    if peak > 0.0 {
        let gain = (10f64.powf(sound.level / 20.0) / peak as f64) as f32;
        mix.iter_mut().for_each(|s| *s *= gain);
    }
    mix
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let [_, spec_path, out_dir] = args.as_slice() else {
        eprintln!("usage: sonic-synth <spec.json> <out-dir>");
        std::process::exit(2);
    };
    let spec: Spec = serde_json::from_str(&std::fs::read_to_string(spec_path).expect("read spec"))
        .expect("parse spec");
    let out = Path::new(out_dir);
    std::fs::create_dir_all(out).expect("create out dir");
    for (name, sound) in &spec.sounds {
        let samples = render_sound(&spec, sound);
        Wave::from_samples(spec.sample_rate, &samples)
            .save_wav16(out.join(format!("{name}.wav")))
            .expect("write wav");
    }
}
