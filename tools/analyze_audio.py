"""Analisis numerico de los WAV (no sustituye la escucha humana).

Mide pico, RMS, recortes, desplazamiento DC, duracion y, para los lazos, la
continuidad en la costura (salto entre la ultima y la primera muestra frente al
salto tipico entre muestras vecinas).
Uso: python tools/analyze_audio.py [salida.txt] [--dir <carpeta>] [--loops a,b,c] [--max-kb N]
  Sin argumentos analiza assets/audio/ (la Justina y el Norte) con sus cuatro lazos.
  --dir   otra carpeta de WAV (por ejemplo assets/audio/humahuaca); --loops dice cuales son lazos;
  --max-kb falla si algun archivo pesa mas que ese tope (el nivel II exige 300).
"""
import sys
import wave
from pathlib import Path
import numpy as np

D = Path(__file__).resolve().parents[1] / "assets" / "audio"
LOOPS = {"river", "ribera", "wind", "wind_north"}


def parse_args(argv):
    out, args = None, {"dir": D, "loops": LOOPS, "max_kb": None}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--dir":
            args["dir"] = Path(argv[i + 1]).resolve()
            i += 2
        elif a == "--loops":
            args["loops"] = {s for s in argv[i + 1].split(",") if s}
            i += 2
        elif a == "--max-kb":
            args["max_kb"] = float(argv[i + 1])
            i += 2
        else:
            out = a
            i += 1
    return out, args


def load(p):
    with wave.open(str(p)) as f:
        ch, sr, n = f.getnchannels(), f.getframerate(), f.getnframes()
        y = np.frombuffer(f.readframes(n), "<i2").astype(float) / 32768
    return y.reshape(-1, ch), sr


def db(x):
    return 20 * np.log10(max(x, 1e-9))


def analyze(folder, loops, max_kb=None):
    rows, fails = [], []
    for p in sorted(folder.glob("*.wav")):
        y, sr = load(p)
        name = p.stem
        peak = np.max(np.abs(y))
        rms = np.sqrt(np.mean(y ** 2))
        clip = int(np.sum(np.abs(y) >= 0.9995))
        dc = float(np.max(np.abs(np.mean(y, 0))))
        kb = p.stat().st_size / 1024.0
        line = (f"{name:18s} {sr:5d} Hz {y.shape[1]}ch {len(y)/sr:5.2f}s {kb:6.1f} KB  pico {db(peak):6.1f} dBFS  "
                f"RMS {db(rms):6.1f} dBFS  recortes {clip}  DC {dc:.5f}")
        if name in loops:
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
        if max_kb is not None and kb > max_kb:
            fails.append(name + ": tamano")
        rows.append(line)
    rows.append("RESULTADO: " + ("OK" if not fails else "FALLAS " + "; ".join(fails)))
    return "\n".join(rows), fails


if __name__ == "__main__":
    out, args = parse_args(sys.argv[1:])
    txt, fails = analyze(args["dir"], args["loops"], args["max_kb"])
    print(txt)
    if out:
        Path(out).write_text(txt + "\n", encoding="utf-8")
    sys.exit(1 if fails else 0)
