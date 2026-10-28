"""Audio original sintetizado para el proyecto (fase 2). Sin muestras de terceros.

Todo se genera con numpy/scipy: capas, ruido filtrado, envolventes y una
reverberacion simple por convolucion con una respuesta sintetica. Los ambientes
se construyen en el dominio de la frecuencia con fase aleatoria y moduladores de
ciclos enteros, de modo que son periodicos: la ultima muestra enlaza con la
primera sin clic (se verifica con tools/analyze_audio.py).

Uso:  python tools/generate_audio.py
"""
from pathlib import Path
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100          # un disparo
SR_AMB = 32000      # ambientes con detalle (agua, grillos)
SR_WIND = 22050     # vientos (contenido grave/medio)
TAU = 2 * np.pi


def rngf(seed):
    return np.random.default_rng(seed)


def tarr(seconds, sr=SR):
    return np.arange(int(round(seconds * sr))) / sr


def filt(y, kind, cut, sr=SR, order=3):
    return sosfilt(butter(order, cut, btype=kind, fs=sr, output="sos"), y)


def white(rng, n):
    return rng.normal(0, 1, n)


def fade_edges(y, ms_in=3.0, ms_out=8.0, sr=SR):
    y = np.array(y, dtype=float)
    a = max(1, int(sr * ms_in / 1000))
    b = max(1, int(sr * ms_out / 1000))
    y[:a] *= np.linspace(0, 1, a)
    y[-b:] *= np.linspace(1, 0, b)
    return y


def reverb(y, rt60=1.2, wet=0.25, sr=SR, seed=7, predelay=0.012, tail=None, damp=5500):
    """Reverb sencilla: convolucion con ruido de decaimiento exponencial y filtro de agudos."""
    r = rngf(seed)
    n = int(sr * rt60 * 1.1)
    t = np.arange(n) / sr
    ir = r.normal(0, 1, n) * np.exp(-t * 6.9078 / rt60)
    ir = filt(ir, "low", damp, sr, 2)
    ir[: int(sr * predelay)] = 0
    for dt, g in ((0.017, 0.5), (0.029, 0.35), (0.041, 0.25)):   # reflexiones tempranas
        ir[int(sr * (predelay + dt))] += g * 3
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    extra = n if tail is None else int(sr * tail)
    padded = np.concatenate([y, np.zeros(extra)])
    w = fftconvolve(padded, ir)[: len(padded)]
    dry_rms = np.sqrt(np.mean(padded ** 2)) + 1e-9
    w *= dry_rms / (np.sqrt(np.mean(w ** 2)) + 1e-9) * 0.9
    return padded * (1 - wet * 0.5) + w * wet


def add_at(buf, sig, start, wrap=False):
    start = int(start)
    if wrap:
        idx = (start + np.arange(len(sig))) % len(buf)
        np.add.at(buf, idx, sig)
    else:
        end = min(len(buf), start + len(sig))
        if start < len(buf):
            buf[start:end] += sig[: end - start]
    return buf


def db(x):
    return 20 * np.log10(max(x, 1e-9))


def write_wav(name, y, sr):
    y = np.asarray(y)
    ch = 1 if y.ndim == 1 else y.shape[1]
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setnchannels(ch)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes((np.clip(y, -1, 1) * 32767).round().astype("<i2").tobytes())


def save_oneshot(name, y, peak_db=-3.0, sr=SR):
    y = fade_edges(y, sr=sr)
    y = y - np.mean(y)
    y *= 10 ** (peak_db / 20) / (np.max(np.abs(y)) + 1e-9)
    write_wav(name, y, sr)


def save_loop(name, y, rms_db, sr):
    """Los ambientes no llevan fundido: son periodicos."""
    y = y - np.mean(y, axis=0)
    rms = np.sqrt(np.mean(y ** 2))
    y = y * (10 ** (rms_db / 20) / (rms + 1e-9))
    peak = np.max(np.abs(y))
    if peak > 0.89:                        # limite suave, sin alterar la periodicidad
        y = np.tanh(y / 0.89 * 1.2) / np.tanh(1.2) * 0.89
    write_wav(name, y, sr)


# ----------------------------------------------------------------- tonos
def brass(f, t, open_rate=6.0, cutoff0=700.0, cutoff1=3200.0, vib=0.0):
    """Tono de metal: armonicos 1/k con corte que se abre durante el ataque."""
    cut = cutoff1 - (cutoff1 - cutoff0) * np.exp(-t * open_rate)
    ph = TAU * f * t + (vib * np.sin(TAU * 5.2 * t) if vib else 0)
    y = np.zeros_like(t)
    k = 1
    while f * k < SR / 2 - 500 and k <= 14:
        y += np.sin(k * ph) / k * np.exp(-((f * k) / cut) ** 2)
        k += 1
    return y


def bell(f0, dur, seed):
    """Campana: parciales inarmonicos (hum, prima, tercera menor, quinta, nominal...)."""
    r = rngf(seed)
    t = tarr(dur)
    parts = [(0.5, 0.7, 5.5), (1.0, 1.0, 4.0), (1.19, 0.75, 3.4), (1.5, 0.45, 2.6),
             (2.0, 0.6, 2.2), (2.5, 0.28, 1.6), (3.0, 0.22, 1.3), (4.1, 0.14, 1.0)]
    y = np.zeros_like(t)
    for ratio, amp, decay in parts:
        for det, w in ((0.0, 1.0), (1.4 + r.uniform(0, 1.2), 0.6)):   # pares con batido
            y += amp * w * np.sin(TAU * (f0 * ratio + det * ratio * 0.5) * t + r.uniform(0, TAU)) * np.exp(-t / decay * 1.0)
    strike = filt(white(r, len(t)), "band", [1500, 6000], SR, 2) * np.exp(-t * 90) * 0.5
    return y + strike


# --------------------------------------------------------------- efectos
def fx_order():
    t = tarr(0.32)
    r = rngf(11)
    tone1 = np.sin(TAU * 659.3 * t) * np.exp(-t * 28)
    t2 = np.maximum(0, t - 0.07)
    tone2 = np.sin(TAU * 880.0 * t2) * np.exp(-t2 * 22) * (t >= 0.07) * 0.8
    wood = filt(white(r, len(t)), "band", [900, 3200], SR, 2) * np.exp(-t * 150) * 0.5
    y = (tone1 + tone2 + 0.25 * np.sin(TAU * 1318.5 * t) * np.exp(-t * 40)) * (1 - np.exp(-t * 900)) + wood
    return reverb(y, 0.35, 0.18, tail=0.1, seed=3)


def fx_error():
    r = rngf(12)
    t = tarr(0.42)
    y = np.zeros_like(t)
    for start, f in ((0.0, 196.0), (0.13, 147.0)):
        tt = np.maximum(0, t - start)
        g = (t >= start) * np.exp(-tt * 13) * (1 - np.exp(-tt * 600))
        saw = sum(np.sin(TAU * f * k * tt) / k for k in range(1, 7))
        y += g * saw * 0.5
    y += filt(white(r, len(t)), "low", 500, SR, 2) * np.exp(-t * 40) * 0.4
    y = filt(y, "low", 1600, SR, 2)
    return reverb(y, 0.3, 0.12, tail=0.05, seed=4)


def fx_alert():
    """Toque de aviso: dos notas de metal seco (quinta ascendente) y repeticion."""
    t_total = 1.15
    y = np.zeros(int(SR * t_total))
    for start, f, d in ((0.0, 392.0, 0.17), (0.2, 587.3, 0.17), (0.5, 392.0, 0.17), (0.7, 587.3, 0.38)):
        n = int(SR * d)
        t = np.arange(n) / SR
        env = np.minimum(1, t / 0.012) * np.minimum(1, (d - t) / 0.05)
        add_at(y, brass(f, t, open_rate=18, cutoff0=900, cutoff1=3600, vib=0.0) * env, SR * start)
    return reverb(y, 0.9, 0.22, tail=0.5, seed=5)


def fx_bell():
    """Campana de aviso de ronda: un golpe grave con cola larga."""
    y = bell(311.0, 3.4, 21)
    y = np.concatenate([y, np.zeros(int(SR * 0.6))])
    return reverb(y, 1.6, 0.25, tail=0.3, seed=6)


def fx_cannon():
    r = rngf(13)
    t = tarr(3.0)
    crack = filt(white(r, len(t)), "high", 1800, SR, 2) * np.exp(-t * 220) * 1.2
    boom = filt(white(r, len(t)), "low", 420, SR, 4) * np.exp(-t * 7.5) * (1 - np.exp(-t * 400)) * 3.0
    mid = filt(white(r, len(t)), "band", [120, 1200], SR, 2) * np.exp(-t * 16) * 1.3
    f_sub = 34 + 70 * np.exp(-t * 14)
    ph = TAU * np.cumsum(f_sub) / SR
    sub = np.sin(ph) * np.exp(-t * 4.0) * (1 - np.exp(-t * 300)) * 1.2
    y = crack + boom + mid + sub
    # reflexion/eco lejano de las lomas y retumbo
    echo = np.zeros_like(y)
    add_at(echo, filt(y, "low", 900, SR, 2) * 0.28, SR * 0.42)
    add_at(echo, filt(y, "low", 500, SR, 2) * 0.16, SR * 0.85)
    y = y + echo
    return reverb(y, 2.2, 0.35, tail=0.9, seed=8, damp=2600)


def hoof_variant(seed):
    r = rngf(seed)
    t = tarr(0.62)
    y = np.zeros_like(t)
    hits = [0.0, 0.115 + r.uniform(-0.01, 0.01), 0.235 + r.uniform(-0.012, 0.012)]
    for i, h in enumerate(hits):
        n = int(SR * 0.22)
        tt = np.arange(n) / SR
        amp = (0.8 + 0.2 * r.random()) * (1.0 if i != 1 else 0.85)
        body = filt(white(r, n), "band", [260 + 80 * r.random(), 1500], SR, 2) * np.exp(-tt * 55)
        thud = np.sin(TAU * (105 + 25 * r.random()) * tt) * np.exp(-tt * 40) * 0.8
        click = filt(white(r, n), "high", 2500, SR, 2) * np.exp(-tt * 380) * 0.35
        add_at(y, (body + thud + click) * amp * (1 - np.exp(-tt * 1500)), SR * h)
    return reverb(y, 0.45, 0.16, tail=0.08, seed=seed + 1)


def fx_dismount():
    r = rngf(14)
    t = tarr(1.5)
    y = np.zeros_like(t)
    for st, a in ((0.00, 1.0), (0.21, 0.8), (0.37, 0.65)):   # botas contra la tierra
        n = int(SR * 0.18)
        tt = np.arange(n) / SR
        step = filt(white(r, n), "low", 520, SR, 2) * np.exp(-tt * 38) + np.sin(TAU * 88 * tt) * np.exp(-tt * 30) * 0.8
        add_at(y, step * a, SR * st)
    for st in (0.05, 0.24, 0.40, 0.55):                     # espuelas y correaje
        n = int(SR * 0.35)
        tt = np.arange(n) / SR
        jing = sum(np.sin(TAU * f * tt + r.uniform(0, TAU)) * np.exp(-tt * (18 + 6 * i))
                   for i, f in enumerate([3150, 4020, 5310, 6770])) * 0.07
        add_at(y, jing * (0.6 + 0.4 * r.random()), SR * st)
    n = int(SR * 0.6)                                       # resoplido del caballo
    tt = np.arange(n) / SR
    huff = filt(white(r, n), "band", [350, 900], SR, 2) + 0.6 * filt(white(r, n), "band", [1200, 2200], SR, 2)
    huff *= np.sin(np.pi * np.clip(tt / 0.5, 0, 1)) ** 2 * np.exp(-tt * 3.5)
    add_at(y, huff * 0.55, SR * 0.62)
    return reverb(y, 0.8, 0.2, tail=0.3, seed=9)


def fx_victory():
    r = rngf(15)
    total = 5.2
    y = np.zeros(int(SR * total))
    # timbal de apertura
    n = int(SR * 1.2)
    tt = np.arange(n) / SR
    tim = (np.sin(TAU * (92 + 28 * np.exp(-tt * 18)) * tt) * np.exp(-tt * 5) + filt(white(r, n), "low", 300, SR, 2) * np.exp(-tt * 20) * 0.5)
    add_at(y, tim * 0.9, 0)
    notes = [(0.15, 196.0, 0.5), (0.45, 261.6, 0.5), (0.75, 329.6, 0.5), (1.05, 392.0, 0.6), (1.5, 523.3, 2.8)]
    for st, f, d in notes:
        n = int(SR * d)
        t = np.arange(n) / SR
        env = np.minimum(1, t / 0.03) * np.exp(-np.maximum(0, t - 0.35) * (1.4 if d > 1 else 4.0))
        tone = brass(f, t, open_rate=5, cutoff0=700, cutoff1=2800, vib=0.0) + 0.6 * brass(f * 1.003, t, open_rate=5, cutoff0=700, cutoff1=2800)
        add_at(y, tone * env * 0.22, SR * st)
    chord = np.zeros_like(y)
    for f in (261.6, 329.6, 392.0, 523.3):                  # acorde sostenido
        t = np.arange(int(SR * 2.9)) / SR
        env = np.minimum(1, t / 0.15) * np.exp(-t * 1.0)
        add_at(chord, brass(f, t, open_rate=2, cutoff0=500, cutoff1=1600) * env * 0.07, SR * 1.5)
    y += chord
    return reverb(y, 2.0, 0.32, tail=0.6, seed=10)


# ------------------------------------------------------------- ambientes
def pnoise(n, sr, shape, rng):
    """Ruido periodico exacto (fase aleatoria, espectro dado)."""
    f = np.fft.rfftfreq(n, 1 / sr)
    mag = shape(f)
    ph = rng.uniform(0, TAU, len(f))
    spec = mag * np.exp(1j * ph)
    spec[0] = 0
    y = np.fft.irfft(spec, n)
    return y / (np.std(y) + 1e-9)


def slow_mod(t, dur, rng, cycles, depth):
    """Modulador periodico: suma de senos con ciclos enteros en la duracion."""
    m = np.zeros_like(t)
    for c in cycles:
        m += rng.uniform(0.5, 1.0) * np.sin(TAU * c * t / dur + rng.uniform(0, TAU))
    m /= max(1e-9, np.max(np.abs(m)))
    return 1 + depth * m


def bp_shape(lo, hi, slope=2.0):
    def s(f):
        f = np.maximum(f, 1.0)
        return 1.0 / (1 + (lo / f) ** (slope * 2)) / (1 + (f / hi) ** (slope * 2))
    return s


def amb_river(dur=10.0):
    sr = SR_AMB
    n = int(sr * dur)
    t = np.arange(n) / sr
    ch = []
    for side, seed in enumerate((101, 102)):
        r = rngf(seed)
        base = pnoise(n, sr, bp_shape(180, 3200, 1.0), r) * slow_mod(t, dur, r, [1, 2, 3, 5], 0.22)
        rush = pnoise(n, sr, bp_shape(900, 7000, 1.5), r) * 0.35 * slow_mod(t, dur, r, [4, 7, 9], 0.4)
        low = pnoise(n, sr, bp_shape(50, 260, 2.0), r) * 0.7 * slow_mod(t, dur, r, [1, 2], 0.3)
        bub = np.zeros(n)
        for _ in range(55):                                 # burbujas, con envoltura circular
            p = r.integers(0, n)
            f0 = r.uniform(380, 1700)
            d = int(sr * r.uniform(0.02, 0.05))
            tt = np.arange(d) / sr
            sweep = TAU * (f0 * tt + 0.5 * f0 * 7 * tt ** 2)
            add_at(bub, np.sin(sweep) * np.exp(-tt * 90) * r.uniform(0.05, 0.28), p, wrap=True)
        ch.append(base + rush + low + bub)
    return np.stack(ch, axis=1), sr


def amb_ribera(dur=12.0):
    """Ribera nocturna: oleaje bajo, grillos y brisa suave."""
    sr = SR_AMB
    n = int(sr * dur)
    t = np.arange(n) / sr
    ch = [np.zeros(n), np.zeros(n)]
    r = rngf(201)
    for side in (0, 1):
        rr = rngf(210 + side)
        lap = pnoise(n, sr, bp_shape(90, 700, 2.0), rr) * (0.55 + 0.45 * np.sin(TAU * 4 * t / dur + rr.uniform(0, TAU))) ** 2
        breeze = pnoise(n, sr, bp_shape(200, 1800, 1.0), rr) * 0.5 * slow_mod(t, dur, rr, [1, 2, 3], 0.5)
        ch[side] += lap * 0.9 + breeze
    for _ in range(5):                                      # cinco grillos, cada uno con su lugar
        f = r.uniform(4300, 5300)
        pan = r.uniform(0.15, 0.85)
        voice = np.zeros(n)
        groups = r.integers(10, 16)
        for _g in range(groups):
            gstart = r.integers(0, n)
            for p in range(int(r.integers(3, 6))):
                m = int(sr * 0.010)
                tt = np.arange(m) / sr
                pulse = np.sin(TAU * f * tt) * np.hanning(m) * 0.9
                add_at(voice, pulse, gstart + int(sr * 0.022 * p), wrap=True)
        voice *= 0.16
        ch[0] += voice * (1 - pan)
        ch[1] += voice * pan
    return np.stack(ch, axis=1), sr


def amb_wind(dur=12.0):
    sr = SR_WIND
    n = int(sr * dur)
    t = np.arange(n) / sr
    ch = []
    for seed in (301, 302):
        r = rngf(seed)
        body = pnoise(n, sr, bp_shape(70, 520, 2.0), r) * slow_mod(t, dur, r, [1, 2, 3], 0.45)
        air = pnoise(n, sr, bp_shape(400, 2200, 1.5), r) * 0.35 * slow_mod(t, dur, r, [2, 3, 5], 0.6)
        ch.append(body + air)
    return np.stack(ch, axis=1), sr


def amb_wind_north(dur=15.0):
    """Viento frio del norte: rafagas fuertes, silbido entre 800 y 1500 Hz, granos de polvo."""
    sr = SR_WIND
    n = int(sr * dur)
    t = np.arange(n) / sr
    ch = []
    for seed in (401, 402):
        r = rngf(seed)
        gust = slow_mod(t, dur, r, [1, 2, 3], 0.75)
        gust = np.maximum(gust, 0.05) ** 1.6
        body = pnoise(n, sr, bp_shape(100, 900, 2.0), r) * gust
        # silbido: portadora que deriva dentro de una banda, con ciclos enteros
        drift = 1100 + 260 * np.sin(TAU * 3 * t / dur + r.uniform(0, TAU)) + 120 * np.sin(TAU * 7 * t / dur + r.uniform(0, TAU))
        phase = TAU * np.cumsum(drift) / sr
        phase -= phase[-1] * np.arange(n) / n   # la fase neta del lazo queda en 0 (ciclos enteros)
        phase = phase - np.round(0)
        whistle = np.sin(phase) * gust ** 2 * 0.18
        dust = pnoise(n, sr, bp_shape(2500, 7500, 1.0), r) * 0.20 * gust
        ch.append(body + whistle + dust)
    y = np.stack(ch, axis=1)
    return y, sr


def make_periodic_whistle_fix(y, sr):
    """Ajusta la fase del silbido en la costura: mezcla cruzada circular de 40 ms."""
    n = len(y)
    x = int(sr * 0.04)
    ramp = np.linspace(0, 1, x)[:, None]
    head = y[:x].copy()
    tail = y[-x:].copy()
    # cruce: el final se desvanece hacia el inicio y viceversa para eliminar el salto
    y[-x:] = tail * (1 - ramp) + head * ramp
    return y


def build():
    save_oneshot("order", fx_order(), -6.0)
    save_oneshot("error", fx_error(), -6.0)
    save_oneshot("alert", fx_alert(), -4.0)
    save_oneshot("bell", fx_bell(), -4.0)
    save_oneshot("cannon", fx_cannon(), -1.5)
    for i, seed in enumerate((21, 22, 23)):
        save_oneshot("hoof" if i == 0 else "hoof%d" % (i + 1), hoof_variant(seed), -6.0)
    save_oneshot("dismount", fx_dismount(), -6.0)
    save_oneshot("victory", fx_victory(), -3.0)
    y, sr = amb_river()
    save_loop("river", y, -22.0, sr)
    y, sr = amb_ribera()
    save_loop("ribera", y, -26.0, sr)
    y, sr = amb_wind()
    save_loop("wind", y, -24.0, sr)
    y, sr = amb_wind_north()
    y = make_periodic_whistle_fix(y, sr)
    save_loop("wind_north", y, -24.0, sr)
    print("Generated", len(list(OUT.glob("*.wav"))), "original sounds")


if __name__ == "__main__":
    build()
