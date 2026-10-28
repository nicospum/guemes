"""Analisis numerico de los WAV (no sustituye la escucha humana).

Mide pico, RMS, recortes, desplazamiento DC, duracion y, para los lazos, la
continuidad en la costura (salto entre la ultima y la primera muestra frente al
salto tipico entre muestras vecinas).
Uso: python tools/analyze_audio.py [salida.txt]
"""
import sys
import wave
from pathlib import Path
import numpy as np

D = Path(__file__).resolve().parents[1] / "assets" / "audio"
LOOPS = {"river", "ribera", "wind", "wind_north"}


def load(p):
    with wave.open(str(p)) as f:
        ch, sr, n = f.getnchannels(), f.getframerate(), f.getnframes()
        y = np.frombuffer(f.readframes(n), "<i2").astype(float) / 32768
    return y.reshape(-1, ch), sr


def db(x):
    return 20 * np.log10(max(x, 1e-9))


rows, fails = [], []
for p in sorted(D.glob("*.wav")):
    y, sr = load(p)
    name = p.stem
    peak = np.max(np.abs(y))
    rms = np.sqrt(np.mean(y ** 2))
    clip = int(np.sum(np.abs(y) >= 0.9995))
    dc = float(np.max(np.abs(np.mean(y, 0))))
    line = (f"{name:11s} {sr:5d} Hz {y.shape[1]}ch {len(y)/sr:5.2f}s  pico {db(peak):6.1f} dBFS  "
            f"RMS {db(rms):6.1f} dBFS  recortes {clip}  DC {dc:.5f}")
    if name in LOOPS:
        seam = np.max(np.abs(y[0] - y[-1]))
        typ = np.percentile(np.abs(np.diff(y, axis=0)), 99.9)
        ratio = seam / (typ + 1e-9)
        line += f"  costura {seam:.4f} (p99.9 vecinas {typ:.4f}, razon {ratio:.2f})"
        if ratio > 1.0:
            fails.append(name + ": costura")
    else:
        e = np.max(np.abs(y[-int(sr * 0.005):]))
        line += f"  extremo final {e:.5f}"
        if e > 0.01 or abs(y[0, 0]) > 0.01:
            fails.append(name + ": extremos")
    if clip:
        fails.append(name + ": recorte")
    rows.append(line)
rows.append("RESULTADO: " + ("OK" if not fails else "FALLAS " + "; ".join(fails)))
txt = "\n".join(rows)
print(txt)
if len(sys.argv) > 1:
    Path(sys.argv[1]).write_text(txt + "\n", encoding="utf-8")
