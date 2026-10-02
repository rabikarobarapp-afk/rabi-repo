"""Generates an original, royalty-free calm lo-fi track (30 s, 80 BPM) -> build/music.wav"""
import numpy as np, wave, os

SR = 44100
BPM = 80
BEAT = 60 / BPM            # 0.75 s
BAR = 4 * BEAT             # 3 s  (scene cuts land on bar lines)
DUR = 30.0
N = int(SR * DUR)
rng = np.random.default_rng(42)
mix = np.zeros((N, 2))

def midi(n): return 440 * 2 ** ((n - 69) / 12)

def add(sig, start, pan=0.5, gain=1.0):
    i = int(start * SR)
    if i >= N: return
    sig = sig[: N - i] * gain
    mix[i:i + len(sig), 0] += sig * np.sqrt(1 - pan)
    mix[i:i + len(sig), 1] += sig * np.sqrt(pan)

def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc; y[i] = acc
    return y

def epiano(note, length):
    t = np.arange(int(length * SR)) / SR
    f = midi(note)
    wob = 1 + 0.0025 * np.sin(2 * np.pi * 0.6 * t)          # tape wow
    s = (np.sin(2 * np.pi * f * wob * t)
         + 0.35 * np.sin(2 * np.pi * 2 * f * wob * t) * np.exp(-t * 3)
         + 0.12 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-t * 6))
    env = (1 - np.exp(-t * 60)) * np.exp(-t * 0.9)
    rel = np.clip((length - t) / 0.3, 0, 1)
    return s * env * rel

def kick():
    t = np.arange(int(0.45 * SR)) / SR
    f = 50 + 70 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)

def snare():
    t = np.arange(int(0.3 * SR)) / SR
    n = lowpass(rng.standard_normal(len(t)), 3500)
    return (0.8 * n + 0.3 * np.sin(2 * np.pi * 190 * t)) * np.exp(-t * 16)

def hat():
    t = np.arange(int(0.08 * SR)) / SR
    n = rng.standard_normal(len(t))
    n = n - lowpass(n, 6000)                                # crude highpass
    return n * np.exp(-t * 60)

def bass(note, length):
    t = np.arange(int(length * SR)) / SR
    f = midi(note)
    s = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 2 * f * t)
    return s * (1 - np.exp(-t * 80)) * np.exp(-t * 0.8) * np.clip((length - t) / 0.1, 0, 1)

# Fmaj9 - Em7 - Dm9 - Cmaj7 (soft, warm progression)
CHORDS = [
    (41, [57, 60, 64, 67]),   # F  : A C E G
    (40, [55, 59, 62, 67]),   # Em7: G B D G
    (38, [57, 60, 64, 65]),   # Dm9: A C E F
    (36, [55, 59, 64, 67]),   # Cmaj7: G B E G
]
n_bars = int(DUR / BAR)
for b in range(n_bars):
    root, notes = CHORDS[b % 4]
    t0 = b * BAR
    last = b == n_bars - 1
    for k, n in enumerate(notes):                           # slightly strummed chord
        add(epiano(n, BAR + 0.4), t0 + k * 0.025, pan=0.3 + 0.13 * k, gain=0.11)
    if not last:                                            # off-beat chord stab
        for k, n in enumerate(notes[1:]):
            add(epiano(n + 12, 0.6), t0 + 2.5 * BEAT + k * 0.02, pan=0.6, gain=0.035)
    add(bass(root, BEAT * 2.5), t0, gain=0.28)
    add(bass(root + 7 if b % 2 else root, BEAT * 1.4), t0 + 2.5 * BEAT, gain=0.22)

    if b == 0 or last:                                      # drums enter after bar 1, drop on last bar
        continue
    for beat in range(4):
        bt = t0 + beat * BEAT
        if beat in (0,) or (beat == 2 and b % 2 == 0):
            add(kick(), bt, gain=0.55)
        if beat == 2 and b % 2 == 1:
            add(kick(), bt + BEAT * 0.5 * 1.33, gain=0.4)
        if beat in (1, 3):
            add(snare(), bt + 0.012, pan=0.55, gain=0.22)
        for half in (0, 1):                                 # swung hats
            ht = bt + (0 if half == 0 else BEAT * 0.5 * 1.33)
            add(hat(), ht, pan=0.65, gain=0.05 if half == 0 else 0.03)

# simple melody sparkle over bars 4-8
MEL = [72, 76, 79, 77, 76, 74, 72, 71, 74, 72]
for i, n in enumerate(MEL):
    add(epiano(n, 0.9), 4 * BAR + i * 1.5 + 0.375, pan=0.45, gain=0.05)

# vinyl crackle + soft noise bed
crackle = np.zeros(N)
pos = rng.integers(0, N, 900)
crackle[pos] = rng.uniform(-1, 1, 900)
bed = lowpass(rng.standard_normal(N), 1200) * 0.01
add(lowpass(crackle, 4000) * 0.35 + bed, 0, gain=1.0)

# warm the whole mix, fade in/out, normalize
for ch in range(2):
    mix[:, ch] = lowpass(mix[:, ch], 5200)
t = np.arange(N) / SR
fade = np.clip(t / 1.0, 0, 1) * np.clip((DUR - t) / 2.5, 0, 1)
mix *= fade[:, None]
mix = np.tanh(mix * 1.4) / np.tanh(1.4)
mix *= 0.89 / np.max(np.abs(mix))

os.makedirs("build", exist_ok=True)
with wave.open("build/music.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
print("wrote build/music.wav")
