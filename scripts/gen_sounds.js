// Generates the flag sound cues as 16-bit mono WAV files.
// Usage: node scripts/gen_sounds.js   (writes apps/lua/LMCC_Flags/sounds/*.wav)
const fs = require('fs');
const path = require('path');

const RATE = 44100;
const AMPLITUDE = 0.5;
const FADE = 0.008; // seconds of fade in/out per tone, avoids clicks

// A cue is a list of tones: { from, to (Hz, sweeps linearly), length, gap (seconds of silence after) }.
const CUES = {
  caution: [{ from: 880, length: 0.15, gap: 0.08 }, { from: 880, length: 0.15 }],
  blue: [{ from: 600, to: 1200, length: 0.25 }],
  severe: [{ from: 440, length: 0.2, gap: 0.1 }, { from: 440, length: 0.2, gap: 0.1 }, { from: 440, length: 0.2 }],
  info: [{ from: 660, length: 0.2 }],
};

function renderTone({ from, to = from, length }) {
  const n = Math.round(length * RATE);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const freq = from + ((to - from) * i) / n;
    phase += (2 * Math.PI * freq) / RATE;
    const envelope = Math.min(1, t / FADE, (length - t) / FADE);
    out[i] = Math.sin(phase) * AMPLITUDE * envelope;
  }
  return out;
}

function renderCue(tones) {
  const parts = [];
  for (const tone of tones) {
    parts.push(renderTone(tone));
    if (tone.gap) parts.push(new Float32Array(Math.round(tone.gap * RATE)));
  }
  const total = parts.reduce((s, p) => s + p.length, 0);
  const samples = new Float32Array(total);
  let offset = 0;
  for (const p of parts) {
    samples.set(p, offset);
    offset += p.length;
  }
  return samples;
}

function toWav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, s)) * 32767), i * 2));
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16); // fmt chunk size
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28); // byte rate
  header.writeUInt16LE(2, 32); // block align
  header.writeUInt16LE(16, 34); // bits per sample
  header.write('data', 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

const outDir = path.join(__dirname, '..', 'apps', 'lua', 'LMCC_Flags', 'sounds');
fs.mkdirSync(outDir, { recursive: true });
for (const [name, tones] of Object.entries(CUES)) {
  const file = path.join(outDir, name + '.wav');
  fs.writeFileSync(file, toWav(renderCue(tones)));
  console.log('wrote ' + path.relative(process.cwd(), file));
}
