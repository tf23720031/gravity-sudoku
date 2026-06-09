const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 44100;
const CHANNELS = 1;
const BITS = 16;

function writeWav(filename, samples) {
  const dataLength = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataLength);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataLength, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(CHANNELS, 22);
  buffer.writeUInt32LE(SAMPLE_RATE, 24);
  buffer.writeUInt32LE(SAMPLE_RATE * CHANNELS * BITS / 8, 28);
  buffer.writeUInt16LE(CHANNELS * BITS / 8, 32);
  buffer.writeUInt16LE(BITS, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataLength, 40);
  for (let i = 0; i < samples.length; i++) {
    buffer.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2);
  }
  fs.writeFileSync(filename, buffer);
  console.log(`Written: ${path.basename(filename)} (${(samples.length / SAMPLE_RATE).toFixed(2)}s)`);
}

function makeClick() {
  const n = Math.round(0.12 * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    return 0.4 * Math.exp(-30 * t) * Math.sin(2 * Math.PI * 880 * t);
  });
}

function makeThud() {
  const n = Math.round(0.30 * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    return 0.6 * Math.exp(-12 * t) * Math.sin(2 * Math.PI * 80 * t);
  });
}

function makeError() {
  const n = Math.round(0.25 * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    return 0.3 * Math.exp(-8 * t) * Math.sign(Math.sin(2 * Math.PI * 200 * t));
  });
}

function makeComplete() {
  const notes = [523.25, 659.25, 783.99, 1046.50];
  const noteDur = 0.18;
  const total = notes.length * noteDur + 0.3;
  const n = Math.round(total * SAMPLE_RATE);
  const samples = new Array(n).fill(0);
  notes.forEach((freq, idx) => {
    const start = Math.round(idx * noteDur * SAMPLE_RATE);
    const end = Math.round((idx * noteDur + 0.4) * SAMPLE_RATE);
    for (let i = start; i < Math.min(end, n); i++) {
      const t = (i - start) / SAMPLE_RATE;
      samples[i] += 0.35 * Math.exp(-5 * t) * Math.sin(2 * Math.PI * freq * t);
    }
  });
  return samples;
}

function makeBgMusic() {
  const duration = 4.0;
  const n = Math.round(duration * SAMPLE_RATE);
  const samples = new Array(n).fill(0);
  const freqs = [261.63, 293.66, 329.63, 392.00, 440.00];
  const noteDur = duration / freqs.length;
  freqs.forEach((freq, idx) => {
    const start = Math.round(idx * noteDur * SAMPLE_RATE);
    const end = Math.round((idx + 1) * noteDur * SAMPLE_RATE);
    for (let i = start; i < end; i++) {
      const t = (i - start) / SAMPLE_RATE;
      const env = Math.sin(Math.PI * (i - start) / (end - start));
      samples[i] += 0.15 * env * Math.sin(2 * Math.PI * freq * t);
      samples[i] += 0.08 * env * Math.sin(2 * Math.PI * freq * 2 * t);
    }
  });
  return samples;
}

const outDir = path.join(__dirname, '..', 'assets', 'audio');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

writeWav(path.join(outDir, 'click.wav'), makeClick());
writeWav(path.join(outDir, 'thud.wav'), makeThud());
writeWav(path.join(outDir, 'error.wav'), makeError());
writeWav(path.join(outDir, 'complete.wav'), makeComplete());
writeWav(path.join(outDir, 'bg_music.wav'), makeBgMusic());
