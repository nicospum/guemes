"""Audio original del nivel II «Humahuaca» (pista visual, CONTRATO 1.2). Sin material externo.

Todo se sintetiza con numpy y scipy sobre las primitivas de tools/generate_audio.py (ruido filtrado por bandas, envolventes
exponenciales, tonos de metal por armonicos, campana de parciales inarmonicos, reverberacion por convolucion con una respuesta
sintetica). Salida: WAV de 44,1 kHz, mono, 16 bits, cada uno <= 300 KB (3,3 s como mucho), en assets/audio/humahuaca/.
Los cuatro lazos ambientales son periodicos exactos (ruido por FFT con fase al azar, moduladores de ciclos enteros y granos
envueltos circularmente): la ultima muestra enlaza con la primera sin clic (lo mide tools/analyze_audio.py).

Uso:   python tools/generate_audio.py --humahuaca          (equivale a: python tools/generate_audio_humahuaca.py)
       python tools/analyze_audio.py --dir assets/audio/humahuaca --loops lluvia_noche,viento_quebrada,grillos,alba_pajaros
Escribe tambien assets/audio/humahuaca/MANIFIESTO.md: la receta de cada archivo y sus cifras medidas.
Determinista: cada sonido lleva su semilla; volver a correr el script produce los mismos bytes con las mismas versiones de numpy/scipy.
"""
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_audio as G  # primitivas compartidas con la Justina; no se llama a G.build()

SR = 44100
TAU = 2 * np.pi
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "humahuaca"
MAX_BYTES = 300 * 1024
MAX_S = (MAX_BYTES - 44) / (SR * 2)  # 3,48 s de PCM 16 bits mono
LOOP_S = 3.30
LOOPS = ["lluvia_noche", "viento_quebrada", "grillos", "alba_pajaros"]

# Receta en una linea de cada archivo (va al MANIFIESTO.md). Clave = nombre del archivo sin .wav.
RECIPES = {}
STATS = {}


def recipe(name, group, text, tag):
    RECIPES[name] = (group, text, tag)


def write(name, y):
    y = np.asarray(y, dtype=float)
    if len(y) > int(MAX_S * SR):
        raise ValueError("%s dura %.2f s y el tope es %.2f s" % (name, len(y) / SR, MAX_S))
    pcm = (np.clip(y, -1, 1) * 32767).round().astype("<i2")
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    yy = pcm.astype(float) / 32768.0
    STATS[name] = {"s": len(yy) / SR, "bytes": path.stat().st_size, "peak_db": G.db(float(np.max(np.abs(yy)))),
                   "rms_db": G.db(float(np.sqrt(np.mean(yy ** 2)))), "clip": int(np.sum(np.abs(yy) >= 0.9995))}


def oneshot(name, y, peak_db):
    y = G.fade_edges(y, 3.0, 10.0, SR)
    y = y - np.mean(y)
    y *= 10 ** (peak_db / 20) / (np.max(np.abs(y)) + 1e-9)
    write(name, y)


def loop(name, y, rms_db, peak_cap_db=-3.0):
    """Los lazos no llevan fundido: son periodicos. Se fija el RMS y, si el pico pasa del tope, se baja todo (sin recortar)."""
    y = y - np.mean(y)
    y = y * (10 ** (rms_db / 20) / (np.sqrt(np.mean(y ** 2)) + 1e-9))
    peak = np.max(np.abs(y))
    cap = 10 ** (peak_cap_db / 20)
    if peak > cap:
        y *= cap / peak
    write(name, y)


def seg(dur):
    n = int(round(dur * SR))
    return n, np.arange(n) / SR


def env_ad(t, attack, release, dur):
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.clip((dur - t) / max(release, 1e-4), 0.0, 1.0)


def harmonics(f, t, k_max, decay_k=1.0):
    y = np.zeros_like(t)
    for k in range(1, k_max + 1):
        if f * k >= SR / 2 - 200:
            break
        y += np.sin(TAU * f * k * t) / (k ** decay_k)
    return y


# ------------------------------------------------------------------------------------------------------------ disparos
def musket(r, crack=1.0, body=1.0, thump=1.0, dur=0.9):
    """Un fusil de chispa: chasquido agudo, cuerpo medio y golpe grave con barrido descendente."""
    n, t = seg(dur)
    c = G.filt(G.white(r, n), "high", 2200, SR, 2) * np.exp(-t * 260) * 1.3 * crack
    b = G.filt(G.white(r, n), "band", [180, 1400], SR, 2) * np.exp(-t * 24) * (1 - np.exp(-t * 900)) * 1.1 * body
    f = 95 + 60 * np.exp(-t * 30)
    th = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 11) * (1 - np.exp(-t * 500)) * 0.9 * thump
    low = G.filt(G.white(r, n), "low", 320, SR, 3) * np.exp(-t * 9) * 0.8 * thump
    return c + b + th + low


def fx_disparo(seed):
    r = G.rngf(seed)
    y = musket(r, crack=r.uniform(0.9, 1.2), body=r.uniform(0.9, 1.1), thump=r.uniform(0.8, 1.1))
    return G.reverb(y, 0.8, 0.22, SR, seed + 1, tail=0.3, damp=4500)


def volley(seed, shots, ranks, boom_gain, echo, dur_body, tail, damp):
    """Descarga de fusileria: `shots` fusiles en `ranks` filas con desorden de milisegundos, retumbo grave y eco de la quebrada."""
    r = G.rngf(seed)
    n, t = seg(dur_body)
    y = np.zeros(n)
    for k in range(shots):
        rank = k % ranks
        at = rank * 0.085 + r.uniform(0.0, 0.07)
        G.add_at(y, musket(r, crack=r.uniform(0.8, 1.2), body=r.uniform(0.8, 1.1), thump=r.uniform(0.7, 1.0)) * r.uniform(0.6, 1.0), SR * at)
    boom = G.filt(G.white(r, n), "low", 300, SR, 4) * np.exp(-t * 5.0) * (1 - np.exp(-t * 300)) * 2.6 * boom_gain
    f_sub = 32 + 40 * np.exp(-t * 10)
    sub = np.sin(TAU * np.cumsum(f_sub) / SR) * np.exp(-t * 3.5) * (1 - np.exp(-t * 300)) * 1.1 * boom_gain
    y = y + boom + sub
    ec = np.zeros_like(y)
    for dt, g in echo:
        G.add_at(ec, G.filt(y, "low", 800, SR, 2) * g, SR * dt)
    return G.reverb(y + ec, 1.9, 0.33, SR, seed + 3, tail=tail, damp=damp)


def fx_descarga_torre():
    return volley(601, shots=10, ranks=1, boom_gain=1.0, echo=((0.36, 0.30), (0.72, 0.15)), dur_body=2.4, tail=0.6, damp=2800)


def fx_descarga_senal():
    return volley(611, shots=14, ranks=2, boom_gain=1.3, echo=((0.42, 0.38), (0.86, 0.20)), dur_body=2.55, tail=0.7, damp=2600)


# ---------------------------------------------------------------------------------------------------- choque e impactos
def clash(r, dur, parts, gain=1.0):
    n, t = seg(dur)
    y = np.zeros(n)
    for i, f in enumerate(parts):
        det = f * (1 + r.uniform(-0.01, 0.01))
        w = 0.9 / (1 + i * 0.6)
        y += np.sin(TAU * det * t + r.uniform(0, TAU)) * np.exp(-t * (16 + 7 * i)) * w
        y += np.sin(TAU * det * 1.004 * t) * np.exp(-t * (20 + 7 * i)) * w * 0.5  # par con batido
    strike = G.filt(G.white(r, n), "band", [1800, 9000], SR, 2) * np.exp(-t * 130) * 0.9
    return (y * 0.35 + strike) * (1 - np.exp(-t * 2500)) * gain


def fx_choque_armas(seed):
    r = G.rngf(seed)
    n, t = seg(1.1)
    y = np.zeros(n)
    G.add_at(y, clash(r, 0.9, (2350, 3720, 5160, 6980, 8800)), 0)
    G.add_at(y, clash(r, 0.8, (2630, 4170, 5780, 7820), 0.7), SR * 0.13)
    G.add_at(y, clash(r, 0.6, (2100, 3300, 4600), 0.4), SR * 0.31)
    return G.reverb(y, 0.6, 0.18, SR, seed + 1, tail=0.2)


def fx_impacto():
    r = G.rngf(631)
    n, t = seg(0.5)
    thud = G.filt(G.white(r, n), "low", 350, SR, 2) * np.exp(-t * 30) + np.sin(TAU * 95 * t) * np.exp(-t * 25) * 0.8
    tt = np.maximum(0.0, t - 0.015)
    dirt = G.filt(G.white(r, n), "high", 3000, SR, 2) * np.exp(-tt * 60) * (t >= 0.015) * 0.3
    return G.reverb((thud + dirt) * (1 - np.exp(-t * 1500)), 0.5, 0.15, SR, 632, tail=0.15)


def fx_explosion_polvora():
    r = G.rngf(641)
    n, t = seg(2.5)
    crack = G.filt(G.white(r, n), "high", 1500, SR, 2) * np.exp(-t * 150) * 1.0
    boom = G.filt(G.white(r, n), "low", 240, SR, 4) * np.exp(-t * 4.5) * (1 - np.exp(-t * 250)) * 3.5
    f_sub = 26 + 44 * np.exp(-t * 9)
    sub = np.sin(TAU * np.cumsum(f_sub) / SR) * np.exp(-t * 3.0) * (1 - np.exp(-t * 300)) * 1.4
    mid = G.filt(G.white(r, n), "band", [100, 900], SR, 2) * np.exp(-t * 10) * 1.2
    y = crack + boom + sub + mid
    for k in range(45):  # chisporroteo que se va apagando
        at = 0.15 + 1.55 * (k / 45.0) ** 1.6 + r.uniform(0, 0.03)
        m, tm = seg(0.006)
        G.add_at(y, G.filt(G.white(r, m), "high", 2500, SR, 2) * np.exp(-tm * 600) * r.uniform(0.12, 0.45) * (1 - k / 60.0), SR * at)
    for at in (0.55, 0.9, 1.3):  # escombros que caen
        m, tm = seg(0.1)
        G.add_at(y, G.filt(G.white(r, m), "low", 400, SR, 2) * np.exp(-tm * 40) * 0.3, SR * at)
    ec = np.zeros_like(y)
    G.add_at(ec, G.filt(y, "low", 700, SR, 2) * 0.3, SR * 0.5)
    return G.reverb(y + ec, 2.0, 0.3, SR, 642, tail=0.75, damp=2400)


def fx_brasas_humo():
    r = G.rngf(651)
    n, t = seg(1.4)
    whoosh = G.filt(G.white(r, n), "band", [250, 2200], SR, 2) * np.sin(np.pi * np.clip(t / 1.2, 0, 1)) ** 1.5 * 0.6
    y = whoosh.copy()
    for _ in range(22):
        m, tm = seg(0.004)
        G.add_at(y, G.filt(G.white(r, m), "low", 5000, SR, 2) * np.exp(-tm * 900) * r.uniform(0.1, 0.35), r.integers(0, n - m))
    return G.reverb(y, 0.6, 0.15, SR, 652, tail=0.2)


# ------------------------------------------------------------------------------------------------- cascos, mulas, carga
def hoof_hit(r, amp, thud_hz, squelch, click):
    n, tt = seg(0.2)
    body = G.filt(G.white(r, n), "band", [240 + 90 * r.random(), 1500], SR, 2) * np.exp(-tt * 55)
    thud = np.sin(TAU * thud_hz * tt) * np.exp(-tt * 38) * 0.85
    sq = np.zeros(n)
    m = n - int(SR * 0.008)
    sq[int(SR * 0.008):] = G.filt(G.white(r, m), "low", 900, SR, 2) * np.exp(-tt[:m] * 30) * squelch
    ck = G.filt(G.white(r, n), "high", 2500, SR, 2) * np.exp(-tt * 350) * click
    return (body + thud + sq + ck) * amp * (1 - np.exp(-tt * 1500))


def fx_cascos_mulas(seed):
    r = G.rngf(seed)
    n, t = seg(1.5)
    y = np.zeros(n)
    for i, at in enumerate((0.0, 0.22, 0.43, 0.63, 0.87, 1.07, 1.28)):
        G.add_at(y, hoof_hit(r, r.uniform(0.7, 1.0), 100 + 30 * r.random(), 0.45, 0.2), SR * max(0.0, at + r.uniform(-0.02, 0.02)))
    return G.reverb(y, 0.5, 0.15, SR, seed + 1, tail=0.12)


def fx_galope():
    r = G.rngf(671)
    n, t = seg(1.76)
    y = np.zeros(n)
    for stride in range(4):
        base = stride * 0.44
        for off, amp in ((0.0, 0.8), (0.085, 0.9), (0.17, 1.0), (0.30, 0.7)):
            G.add_at(y, hoof_hit(r, amp * r.uniform(0.9, 1.05), 118 + 20 * r.random(), 0.15, 0.3), SR * max(0.0, base + off + r.uniform(-0.008, 0.008)))
    return G.reverb(y, 0.7, 0.2, SR, 672, tail=0.2)


def formants(src, fs, gains, bw=0.09):
    out = np.zeros_like(src)
    for f, g in zip(fs, gains):
        out += G.filt(src, "band", [f * (1 - bw), f * (1 + bw)], SR, 2) * g
    return out


def fx_relincho_mula():
    r = G.rngf(681)
    n, t = seg(1.55)
    y = np.zeros(n)
    # «hi»: la inspiracion, aguda y ronca, con la altura subiendo y vibrato
    m, tt = seg(0.58)
    ease = np.sin(np.pi / 2 * np.clip(tt / 0.58, 0, 1))
    f = (540 + 260 * ease) * (1 + 0.03 * np.sin(TAU * 7 * tt))
    ph = TAU * np.cumsum(f) / SR
    src = sum(np.sin(k * ph) / k for k in range(1, 13))
    breath = G.filt(G.white(r, m), "band", [1500, 4000], SR, 2) * 0.5
    hi = formants(src + breath, (1000, 1900, 3000), (1.0, 0.6, 0.3)) * env_ad(tt, 0.06, 0.08, 0.58) * 0.9
    G.add_at(y, hi, 0)
    # «ha»: la espiracion, grave, con el tremolo que parte el rebuzno en golpes
    m2, t2 = seg(0.93)
    f2 = 400 - 170 * np.clip(t2 / 0.93, 0, 1) ** 0.8
    ph2 = TAU * np.cumsum(f2) / SR
    src2 = sum(np.sin(k * ph2) / k for k in range(1, 19))
    trem = 0.6 + 0.4 * np.sin(TAU * 5.5 * t2 - np.pi / 2)
    ha = formants(src2, (650, 1150, 2400), (1.0, 0.7, 0.25)) * env_ad(t2, 0.04, 0.25, 0.93) * trem * 1.1
    G.add_at(y, ha, SR * 0.62)
    return G.reverb(y, 1.0, 0.2, SR, 682, tail=0.25)


def fx_carga_bultos():
    r = G.rngf(691)
    n, t = seg(1.4)
    y = np.zeros(n)
    m, tm = seg(0.25)  # crujido de la cincha y del cuero
    f = 430 - 70 * tm / 0.25
    creak = np.sin(TAU * np.cumsum(f * (1 + 0.02 * np.sin(TAU * 60 * tm))) / SR) * np.sin(np.pi * tm / 0.25) * 0.35
    creak += G.filt(G.white(r, m), "band", [300, 700], SR, 2) * np.sin(np.pi * tm / 0.25) * 0.3
    G.add_at(y, creak, 0)
    for at, amp in ((0.32, 1.0), (0.92, 0.55)):  # el bulto que cae sobre el lomo
        k, tk = seg(0.35)
        thud = G.filt(G.white(r, k), "low", 170, SR, 2) * np.exp(-tk * 16) + np.sin(TAU * 62 * tk) * np.exp(-tk * 12) * 0.9
        thud += G.filt(G.white(r, k), "band", [400, 2000], SR, 2) * np.exp(-tk * 80) * 0.4
        G.add_at(y, thud * amp * (1 - np.exp(-tk * 1200)), SR * at)
    k, tk = seg(0.8)  # soga y lona
    rustle = G.filt(G.white(r, k), "band", [1100, 5000], SR, 2) * (0.55 + 0.45 * np.sin(TAU * 12 * tk)) * np.sin(np.pi * tk / 0.8) * 0.22
    G.add_at(y, rustle, SR * 0.3)
    return G.reverb(y, 0.7, 0.18, SR, 692, tail=0.2)


def fx_pisadas():
    r = G.rngf(701)
    n, t = seg(1.1)
    y = np.zeros(n)
    for at in (0.0, 0.29, 0.57, 0.86):
        m, tm = seg(0.22)
        step = G.filt(G.white(r, m), "low", 600, SR, 2) * np.exp(-tm * 42) * 0.8
        step += G.filt(G.white(r, m), "band", [400, 2500], SR, 2) * np.exp(-tm * 70) * 0.3
        step += np.sin(TAU * 80 * tm) * np.exp(-tm * 35) * 0.3
        G.add_at(y, step * r.uniform(0.75, 1.0) * (1 - np.exp(-tm * 1500)), SR * max(0.0, at + r.uniform(-0.015, 0.015)))
    return G.reverb(y, 0.5, 0.12, SR, 702, tail=0.1)


def fx_vado_agua():
    r = G.rngf(711)
    n, t = seg(2.3)
    env = np.minimum(1.0, t / 0.3) * np.clip((2.3 - t) / 0.5, 0, 1)
    y = G.filt(G.white(r, n), "band", [200, 3000], SR, 2) * env * 0.22
    for k in range(9):
        at = 0.1 + k * 0.24 + r.uniform(-0.04, 0.04)
        m, tm = seg(0.16)
        splash = G.filt(G.white(r, m), "band", [600, 5000], SR, 2) * np.exp(-tm * 22) * r.uniform(0.5, 1.0) * (1 - np.exp(-tm * 900))
        G.add_at(y, splash, SR * at)
        for _ in range(3):
            d, td = seg(0.025)
            f0 = r.uniform(500, 1500)
            G.add_at(y, np.sin(TAU * (f0 * td + 0.5 * f0 * 8 * td ** 2)) * np.exp(-td * 120) * 0.2, SR * (at + r.uniform(0.0, 0.1)))
    return G.reverb(y, 0.6, 0.15, SR, 712, tail=0.3)


# ----------------------------------------------------------------------------------------- señales, campanas y tambores
def bugle(notes, vib_last=0.004, cutoff1=3400):
    total = max(st + d for st, _f, d in notes)
    n, t = seg(total)
    y = np.zeros(n)
    last = len(notes) - 1
    for i, (st, f, d) in enumerate(notes):
        m, tm = seg(d)
        tone = G.brass(f, tm, open_rate=16, cutoff0=800, cutoff1=cutoff1, vib=vib_last if i == last else 0.0)
        G.add_at(y, tone * env_ad(tm, 0.01, 0.04, d), SR * st)
    return y


def fx_corneta():
    y = bugle(((0.0, 392.0, 0.17), (0.2, 523.3, 0.17), (0.4, 659.3, 0.2), (0.62, 784.0, 0.75)))
    return G.reverb(y, 1.4, 0.26, SR, 721, tail=0.5)


def drum_hit(r, amp, tone_hz=190.0, rattle=0.25, dur=0.3):
    n, tt = seg(dur)
    y = G.filt(G.white(r, n), "band", [170, 900], SR, 2) * np.exp(-tt * 38) + np.sin(TAU * tone_hz * tt) * np.exp(-tt * 30) * 0.6
    y += G.filt(G.white(r, n), "high", 3000, SR, 2) * np.exp(-tt * 60) * rattle
    return y * amp * (1 - np.exp(-tt * 1500))


def fx_captura():
    r = G.rngf(731)
    n, t = seg(0.85)
    y = np.zeros(n)
    G.add_at(y, drum_hit(r, 1.0, 160.0, 0.2), 0)
    G.add_at(y, bugle(((0.0, 523.3, 0.15), (0.18, 784.0, 0.5))) * 0.9, SR * 0.08)
    return G.reverb(y, 1.2, 0.25, SR, 732, tail=0.4)


def fx_campana_alarma():
    n, t = seg(3.0)
    y = np.zeros(n)
    for at, amp, s in ((0.0, 1.0, 741), (0.55, 0.9, 742), (1.1, 0.95, 743)):
        G.add_at(y, G.bell(480.0, 1.9, s) * amp, SR * at)
    y = G.reverb(y, 1.5, 0.22, SR, 744, tail=0.3)
    k = int(SR * 0.45)  # la cola de la campana se apaga con un fundido de 450 ms (el tope de 3,3 s no le deja agotarse sola)
    y[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return y


def fx_campana_decision():
    y = G.bell(660.0, 1.5, 751)
    return G.reverb(y, 1.2, 0.22, SR, 752, tail=0.3)


def fx_tambor_refuerzo():
    r = G.rngf(761)
    n, t = seg(2.4)
    y = np.zeros(n)
    pattern = ((0.0, 0.5), (0.12, 0.55), (0.24, 0.6), (0.36, 0.65), (0.6, 1.0), (0.9, 0.9))
    for rep in range(2):
        for at, amp in pattern:
            G.add_at(y, drum_hit(r, amp * r.uniform(0.92, 1.0)), SR * (rep * 1.2 + at))
    y = G.filt(y, "low", 1400, SR, 2)  # viene de lejos, por el camino del sur
    return G.reverb(y, 2.2, 0.42, SR, 762, tail=0.6, damp=1800)


# ---------------------------------------------------------------------------------------------------- avisos de interfaz
def ui_orden_ok():
    r = G.rngf(771)
    n, t = seg(0.37)
    y = G.filt(G.white(r, n), "band", [1500, 4500], SR, 2) * np.exp(-t * 170) * 0.6 + np.sin(TAU * 740.0 * t) * np.exp(-t * 30) * 0.5
    t2 = np.maximum(0.0, t - 0.09)
    y += (np.sin(TAU * 988.0 * t2) * np.exp(-t2 * 28) * 0.45 + G.filt(G.white(r, n), "band", [1200, 3500], SR, 2) * np.exp(-t2 * 150) * 0.3) * (t >= 0.09)
    return G.reverb(y * (1 - np.exp(-t * 1200)), 0.3, 0.12, SR, 772, tail=0.08)


def ui_orden_rechazada():
    r = G.rngf(781)
    n, t = seg(0.44)
    y = np.zeros(n)
    for st, f in ((0.0, 185.0), (0.14, 139.0)):
        tt = np.maximum(0.0, t - st)
        y += (t >= st) * np.exp(-tt * 14) * (1 - np.exp(-tt * 600)) * harmonics(f, tt, 5) * 0.5
    y += G.filt(G.white(r, n), "band", [600, 1200], SR, 2) * np.exp(-t * 90) * 0.4
    y = G.filt(y, "low", 1200, SR, 2)
    return G.reverb(y, 0.3, 0.1, SR, 782, tail=0.06)


def fife(f, tm, d):
    tone = sum(np.sin(TAU * f * k * tm) / k for k in (1, 3, 5))
    return G.filt(tone, "low", 6000, SR, 2) * env_ad(tm, 0.008, 0.03, d)


def ui_alerta():
    n, t = seg(0.65)
    y = np.zeros(n)
    for st, f, d in ((0.0, 880.0, 0.11), (0.16, 880.0, 0.11), (0.32, 1174.7, 0.28)):
        m, tm = seg(d)
        G.add_at(y, fife(f, tm, d), SR * st)
    return G.reverb(y, 0.9, 0.2, SR, 791, tail=0.35)


def ui_aviso():
    r = G.rngf(801)
    n, t = seg(0.26)
    y = np.sin(TAU * 1320.0 * t) * np.exp(-t * 45) * 0.5 + G.filt(G.white(r, n), "band", [2000, 5000], SR, 2) * np.exp(-t * 200) * 0.3
    return G.reverb(y * (1 - np.exp(-t * 2000)), 0.25, 0.1, SR, 802, tail=0.05)


def ui_victoria():
    r = G.rngf(811)
    n, t = seg(2.6)
    y = np.zeros(n)
    for at, amp in ((0.0, 0.9), (0.35, 0.7)):
        m, tm = seg(1.0)
        tim = np.sin(TAU * (98 + 26 * np.exp(-tm * 18)) * tm) * np.exp(-tm * 5) + G.filt(G.white(r, m), "low", 300, SR, 2) * np.exp(-tm * 20) * 0.5
        G.add_at(y, tim * amp, SR * at)
    for st, f, d in ((0.15, 293.7, 0.22), (0.4, 370.0, 0.22), (0.65, 440.0, 0.22), (0.9, 587.3, 1.6)):
        m, tm = seg(d)
        env = np.minimum(1, tm / 0.03) * np.exp(-np.maximum(0, tm - 0.3) * (1.5 if d > 1 else 4.0))
        tone = G.brass(f, tm, open_rate=5, cutoff0=700, cutoff1=2800) + 0.6 * G.brass(f * 1.003, tm, open_rate=5, cutoff0=700, cutoff1=2800)
        G.add_at(y, tone * env * 0.22, SR * st)
    for f in (293.7, 370.0, 440.0, 587.3):
        m, tm = seg(1.5)
        G.add_at(y, G.brass(f, tm, open_rate=2, cutoff0=500, cutoff1=1600) * np.minimum(1, tm / 0.15) * np.exp(-tm * 1.1) * 0.07, SR * 0.95)
    return G.reverb(y, 1.6, 0.3, SR, 812, tail=0.5)


def ui_derrota():
    r = G.rngf(821)
    n, t = seg(2.5)
    y = np.zeros(n)
    for st, f, d in ((0.0, 146.8, 0.9), (0.8, 116.5, 1.5)):
        m, tm = seg(d)
        env = np.minimum(1, tm / 0.08) * np.clip((d - tm) / 0.5, 0, 1)
        G.add_at(y, (G.brass(f, tm, open_rate=3, cutoff0=400, cutoff1=1400) + 0.5 * G.brass(f * 1.004, tm, open_rate=3, cutoff0=400, cutoff1=1400)) * env * 0.6, SR * st)
    roll = G.filt(G.white(r, n), "band", [120, 600], SR, 2) * (0.6 + 0.4 * np.sin(TAU * 14 * t)) * np.exp(-t * 1.6) * np.minimum(1, t / 0.1) * 0.3
    y = G.filt(y + roll, "low", 2500, SR, 2)
    return G.reverb(y, 1.8, 0.3, SR, 822, tail=0.4)


# ------------------------------------------------------------------------------------------------------------ ambientes
def amb_lluvia_noche(dur=LOOP_S):
    r = G.rngf(501)
    n = int(SR * dur)
    t = np.arange(n) / SR
    hiss = G.pnoise(n, SR, G.bp_shape(500, 9000, 1.0), r) * G.slow_mod(t, dur, r, [1, 2, 3], 0.18)
    body = G.pnoise(n, SR, G.bp_shape(120, 1100, 1.5), r) * 0.55 * G.slow_mod(t, dur, r, [1, 3], 0.25)
    drops = np.zeros(n)
    for _ in range(140):  # gotas sobre techos y paja: barridos cortos descendentes, envueltos circularmente
        p = r.integers(0, n)
        f0 = r.uniform(1400, 3800)
        d = int(SR * r.uniform(0.006, 0.02))
        tt = np.arange(d) / SR
        G.add_at(drops, np.sin(TAU * (f0 * tt - 0.5 * f0 * 12 * tt ** 2)) * np.exp(-tt * 180) * r.uniform(0.08, 0.3), p, wrap=True)
    for _ in range(18):  # gotas gordas sobre charcos
        p = r.integers(0, n)
        f0 = r.uniform(280, 700)
        d = int(SR * 0.035)
        tt = np.arange(d) / SR
        G.add_at(drops, np.sin(TAU * (f0 * tt + 0.5 * f0 * 6 * tt ** 2)) * np.exp(-tt * 70) * r.uniform(0.1, 0.25), p, wrap=True)
    return hiss + body + drops


def amb_viento_quebrada(dur=3.0):
    r = G.rngf(511)
    n = int(SR * dur)
    t = np.arange(n) / SR
    gust = np.maximum(G.slow_mod(t, dur, r, [1, 2], 0.7), 0.08) ** 1.4
    body = G.pnoise(n, SR, G.bp_shape(55, 480, 2.0), r) * gust
    air = G.pnoise(n, SR, G.bp_shape(300, 1900, 1.5), r) * 0.32 * gust
    # silbido entre las laderas: la portadora deriva con ciclos enteros y su fase neta es un numero entero de vueltas (sin costura)
    drift = 820 + 180 * np.sin(TAU * 2 * t / dur + r.uniform(0, TAU)) + 90 * np.sin(TAU * 5 * t / dur + r.uniform(0, TAU))
    cycles = np.round(np.sum(drift) / SR)
    drift *= cycles * SR / np.sum(drift)
    whistle = np.sin(TAU * np.cumsum(drift) / SR) * gust ** 2 * 0.14
    return body + air + whistle


def amb_grillos(dur=LOOP_S):
    r = G.rngf(521)
    n = int(SR * dur)
    y = np.zeros(n)
    for _v in range(4):  # cuatro grillos, cada uno con su altura y su lugar
        f = r.uniform(4200, 5400)
        amp = r.uniform(0.09, 0.16)
        for _g in range(int(r.integers(9, 14))):
            gstart = r.integers(0, n)
            for p in range(int(r.integers(3, 6))):
                m = int(SR * 0.011)
                tt = np.arange(m) / SR
                G.add_at(y, np.sin(TAU * f * tt) * np.hanning(m) * amp, gstart + int(SR * 0.021 * p), wrap=True)
    bed = G.pnoise(n, SR, G.bp_shape(2500, 7000, 1.0), r) * 0.025
    return y + bed


def amb_alba_pajaros(dur=LOOP_S):
    r = G.rngf(531)
    n = int(SR * dur)
    t = np.arange(n) / SR
    breeze = G.pnoise(n, SR, G.bp_shape(180, 1400, 1.2), r) * 0.35 * G.slow_mod(t, dur, r, [1, 2], 0.4)
    y = np.zeros(n)
    for _v in range(3):  # tres aves con su registro
        base = r.uniform(2100, 4300)
        for _s in range(int(r.integers(2, 4))):
            start = r.integers(0, n)
            for c in range(int(r.integers(2, 6))):
                d = int(SR * r.uniform(0.05, 0.14))
                tt = np.arange(d) / SR
                f0 = base * r.uniform(0.9, 1.1)
                f1 = f0 * r.uniform(0.75, 1.3)
                ph = TAU * (f0 * tt + (f1 - f0) * tt ** 2 / (2 * d / SR))
                trem = (1 + 0.5 * np.sin(TAU * r.uniform(25, 45) * tt)) if r.random() < 0.5 else 1.0
                chirp = np.sin(ph) * np.sin(np.pi * tt / (d / SR)) ** 1.2 * trem * r.uniform(0.12, 0.28)
                G.add_at(y, chirp, start + int(SR * (0.16 * c + r.uniform(0, 0.03))), wrap=True)
    return y + breeze


# ------------------------------------------------------------------------------------------------------------- manifiesto
def describe():
    amb = "ambiente (lazo periodico)"
    recipe("lluvia_noche", amb, "ruido periodico por FFT en dos bandas (500-9000 Hz y 120-1100 Hz) con moduladores de 1, 2 y 3 ciclos; 140 gotas (barridos descendentes de 1,4-3,8 kHz, 6-20 ms) y 18 gotas gordas sobre charcos (280-700 Hz), envueltas circularmente; semilla 501", "documentado (lluvia la noche del 1 de marzo de 1817, parte de Arias) / diseno (la textura)")
    recipe("viento_quebrada", amb, "cuerpo 55-480 Hz y aire 300-1900 Hz de ruido periodico por rafagas (moduladores de 1 y 2 ciclos, exponente 1,4) mas un silbido de 650-1100 Hz cuya fase neta es un numero entero de vueltas; semilla 511", "razonado (viento de quebrada) / diseno")
    recipe("grillos", amb, "cuatro voces de 4,2-5,4 kHz en pulsos de 11 ms con ventana de Hann, grupos de 3 a 5 pulsos cada 21 ms, envueltos circularmente, sobre un lecho tenue de 2,5-7 kHz; semilla 521", "diseno")
    recipe("alba_pajaros", amb, "tres aves (registro 2,1-4,3 kHz) con frases de 2 a 5 trinos: barridos de frecuencia de 50-140 ms, la mitad con tremolo de 25-45 Hz, envueltos circularmente, sobre una brisa de 180-1400 Hz; semilla 531", "diseno (el alba del 1 de marzo es documentada; las aves son ambientacion)")
    comb = "combate"
    recipe("descarga_torre", comb, "diez fusiles de chispa (chasquido > 2,2 kHz, cuerpo 180-1400 Hz, golpe grave con barrido 155 -> 95 Hz) disparados en una fila con desorden de 0-70 ms, retumbo grave (< 300 Hz) y subgrave 72 -> 32 Hz, dos ecos de la quebrada a 0,36 y 0,72 s, reverberacion de 1,9 s; semilla 601", "documentado (la torre con tiradores; el fuego «indecible») / diseno (la cantidad)")
    recipe("descarga_senal", comb, "catorce fusiles en dos filas (0-160 ms), retumbo x1,3 y ecos a 0,42 y 0,86 s: la descarga «que parecio canonazo» del parte; misma sintesis que descarga_torre; semilla 611", "documentado (la descarga que parecio canonazo) / diseno (la senal general)")
    recipe("disparo_1", comb, "un fusil de chispa: chasquido, cuerpo y golpe grave con barrido; reverberacion corta de 0,8 s; semilla 621", "razonado")
    recipe("disparo_2", comb, "idem, semilla 622 (otra variante al azar)", "razonado")
    recipe("disparo_3", comb, "idem, semilla 623", "razonado")
    recipe("choque_armas_1", comb, "tres golpes de metal a 0, 130 y 310 ms: parciales inarmonicos (2,3-8,8 kHz) con batido y decaimiento rapido mas un golpe de ruido de 1,8-9 kHz; semilla 641", "razonado (palos y sables: «sin mas armas que palos») / diseno")
    recipe("choque_armas_2", comb, "idem, semilla 645", "razonado / diseno")
    recipe("impacto", comb, "golpe sordo (< 350 Hz, 95 Hz) con tierra que salta (> 3 kHz, 15 ms despues); semilla 631", "diseno")
    recipe("explosion_polvora", comb, "chasquido, retumbo (< 240 Hz), subgrave 70 -> 26 Hz y medios, 45 chisporroteos que se apagan, tres escombros, eco a 0,5 s y reverberacion de 2 s; semilla 641", "documentado (la polvora quemada) / diseno")
    recipe("brasas_humo", comb, "soplido de 250-2200 Hz en arco de 1,2 s con 22 chasquidos de brasas; semilla 651", "diseno")
    anim = "animales, carga y agua"
    recipe("cascos_mulas_1", anim, "siete pisadas al paso de mula (0 a 1,28 s con desorden de 20 ms): cuerpo 240-1500 Hz, golpe de 100-130 Hz, chapoteo del barro (< 900 Hz, 8 ms despues) y chasquido del casco; semilla 661", "documentado (las mulas de la posta) / diseno")
    recipe("cascos_mulas_2", anim, "idem, semilla 664", "documentado / diseno")
    recipe("galope", anim, "galope de caballo: cuatro trancos de 0,44 s con cuatro cascos por tranco (0, 85, 170 y 300 ms), mas seco que el paso de mula; semilla 671", "razonado (el mensajero a caballo) / diseno")
    recipe("relincho_mula", anim, "rebuzno en dos tiempos: inspiracion aguda (540 -> 800 Hz con vibrato de 7 Hz, armonicos y aliento, formantes 1000/1900/3000 Hz) y espiracion grave (400 -> 230 Hz, tremolo de 5,5 Hz, formantes 650/1150/2400 Hz); semilla 681", "diseno")
    recipe("carga_bultos", anim, "crujido de cincha (430 -> 360 Hz), bulto que cae (< 170 Hz, 62 Hz, chasquido 400-2000 Hz) a 0,32 y 0,92 s y roce de soga y lona (1,1-5 kHz con aleteo de 12 Hz); semilla 691", "documentado (la carga del botin en mulas) / diseno")
    recipe("pisadas", anim, "cuatro pasos sobre barro (< 600 Hz con chapoteo de 400-2500 Hz) a 0, 0,29, 0,57 y 0,86 s; semilla 701", "diseno")
    recipe("vado_agua", anim, "nueve chapoteos de 600-5000 Hz con burbujas (barridos de 0,5-1,5 kHz) sobre un lecho de 200-3000 Hz: la columna cruza el vado; semilla 711", "documentado (el cruce del rio) / diseno")
    sen = "senales y avisos del campo"
    recipe("corneta", sen, "toque de corneta de cuatro notas (sol4, do5, mi5, sol5) con armonicos de metal cuyo corte se abre en el ataque y vibrato en la ultima; reverberacion de 1,4 s", "diseno (no hay toque documentado)")
    recipe("captura", sen, "golpe de tambor y dos notas de corneta (do5, sol5): el frente cae; semilla 731", "diseno")
    recipe("campana_alarma", sen, "tres golpes de campana (fundamental 480 Hz, parciales inarmonicos con batido) a 0, 0,55 y 1,1 s; reverberacion de 1,5 s; semillas 741-744", "diseno (la alarma de la guarnicion; que tocaran la campana no esta documentado)")
    recipe("campana_decision", sen, "un golpe de campana chica (660 Hz) con cola; semillas 751-752", "diseno (interfaz)")
    recipe("tambor_refuerzo", sen, "redoble militar (cuatro golpes rapidos y dos acentos, dos veces) filtrado a 1,4 kHz y con reverberacion larga: la columna realista por el camino del sur; semilla 761", "razonado (el refuerzo) / diseno")
    ui = "interfaz"
    recipe("orden_ok", ui, "dos toques de madera (1,5-4,5 kHz) con notas de 740 y 988 Hz; semilla 771", "diseno (interfaz)")
    recipe("orden_rechazada", ui, "dos notas graves (185 y 139 Hz, 5 armonicos) con un bloque de madera apagado; semilla 781", "diseno (interfaz)")
    recipe("alerta", ui, "tres notas de pifano (880, 880 y 1175 Hz; armonicos impares) en 0,65 s", "diseno (interfaz)")
    recipe("aviso", ui, "un toque breve y suave (1320 Hz con un chasquido de 2-5 kHz); semilla 801", "diseno (interfaz)")
    recipe("victoria", ui, "dos timbales, cuatro notas de metal ascendentes (re4, fa#4, la4, re5) y el acorde de re mayor sostenido; reverberacion de 1,6 s; semilla 811", "diseno (interfaz)")
    recipe("derrota", ui, "dos notas graves de metal descendentes (re2, sib1) con un redoble que se apaga; semilla 821", "diseno (interfaz)")


def build(verbose=True):
    OUT.mkdir(parents=True, exist_ok=True)
    describe()
    loop("lluvia_noche", amb_lluvia_noche(), -23.0)
    loop("viento_quebrada", amb_viento_quebrada(), -26.0)
    loop("grillos", amb_grillos(), -30.0)
    loop("alba_pajaros", amb_alba_pajaros(), -28.0)
    oneshot("descarga_torre", fx_descarga_torre(), -1.5)
    oneshot("descarga_senal", fx_descarga_senal(), -1.5)
    for i, seed in enumerate((621, 622, 623)):
        oneshot("disparo_%d" % (i + 1), fx_disparo(seed), -3.0)
    oneshot("choque_armas_1", fx_choque_armas(641), -4.0)
    oneshot("choque_armas_2", fx_choque_armas(645), -4.0)
    oneshot("impacto", fx_impacto(), -5.0)
    oneshot("explosion_polvora", fx_explosion_polvora(), -1.5)
    oneshot("brasas_humo", fx_brasas_humo(), -10.0)
    oneshot("cascos_mulas_1", fx_cascos_mulas(661), -6.0)
    oneshot("cascos_mulas_2", fx_cascos_mulas(664), -6.0)
    oneshot("galope", fx_galope(), -5.0)
    oneshot("relincho_mula", fx_relincho_mula(), -5.0)
    oneshot("carga_bultos", fx_carga_bultos(), -6.0)
    oneshot("pisadas", fx_pisadas(), -9.0)
    oneshot("vado_agua", fx_vado_agua(), -6.0)
    oneshot("corneta", fx_corneta(), -4.0)
    oneshot("captura", fx_captura(), -5.0)
    oneshot("campana_alarma", fx_campana_alarma(), -4.0)
    oneshot("campana_decision", fx_campana_decision(), -7.0)
    oneshot("tambor_refuerzo", fx_tambor_refuerzo(), -8.0)
    oneshot("orden_ok", ui_orden_ok(), -8.0)
    oneshot("orden_rechazada", ui_orden_rechazada(), -8.0)
    oneshot("alerta", ui_alerta(), -6.0)
    oneshot("aviso", ui_aviso(), -12.0)
    oneshot("victoria", ui_victoria(), -3.0)
    oneshot("derrota", ui_derrota(), -4.0)
    missing = sorted(set(STATS) ^ set(RECIPES))
    if missing:
        raise RuntimeError("archivos sin receta o recetas sin archivo: %s" % missing)
    write_manifest()
    if verbose:
        total = sum(s["bytes"] for s in STATS.values())
        print("Humahuaca: %d sonidos originales en %s (%.1f KB en total, el mayor %.1f KB)" % (len(STATS), OUT, total / 1024.0, max(s["bytes"] for s in STATS.values()) / 1024.0))


def write_manifest():
    lines = ["# Manifiesto del audio del nivel II «Humahuaca»", "",
             "Todos los archivos de esta carpeta son **originales y sintetizados por código**: los genera `tools/generate_audio_humahuaca.py`",
             "(`python tools/generate_audio.py --humahuaca`) con numpy y scipy sobre las primitivas de `tools/generate_audio.py`. **No hay ningún",
             "material externo**: ni muestras, ni bancos de sonido, ni grabaciones. Cada archivo es WAV de 44,1 kHz, mono, 16 bits y pesa menos de",
             "300 KB (tope de 3,3 s). Las semillas fijas hacen la generación determinista. Las cifras de abajo las mide el propio generador al escribir",
             "cada archivo (pico y RMS en dBFS sobre las muestras de 16 bits; «recortes» cuenta muestras en ±0,9995). El análisis independiente está en",
             "`docs/humahuaca/SONIDO.md` (`tools/analyze_audio.py --dir assets/audio/humahuaca --loops " + ",".join(LOOPS) + "`).", "",
             "La etiqueta de fuente sigue el vocabulario del nivel (`documentado`, `razonado`, `discutido`, `sin_datos`, `diseno`): dice qué parte del",
             "sonido se apoya en el parte de Arias (la lluvia, la descarga que pareció cañonazo, la pólvora, las mulas, el cruce del río) y qué parte es",
             "ambientación de diseño. Ningún sonido se presenta como grabación de época.", "",
             "| Archivo | Grupo | Receta (síntesis) | Duración | Tamaño | Pico | RMS | Recortes | Fuente |", "|---|---|---|---|---|---|---|---|---|"]
    for name in sorted(RECIPES, key=lambda k: (RECIPES[k][0], k)):
        group, text, tag = RECIPES[name]
        s = STATS[name]
        lines.append("| `%s.wav` | %s | %s | %.2f s | %.1f KB | %.1f dBFS | %.1f dBFS | %d | %s |" % (
            name, group, text, s["s"], s["bytes"] / 1024.0, s["peak_db"], s["rms_db"], s["clip"], tag))
    lines += ["", "Los lazos (`lluvia_noche`, `viento_quebrada`, `grillos`, `alba_pajaros`) se reproducen con `loop_mode = LOOP_FORWARD` sobre una copia del",
              "recurso (igual que hace `scripts/audio_manager.gd` con los ambientes de la Justina); el resto son disparos de una vez. El mapeo de eventos a",
              "sonidos vive en `data/humahuaca_audio.json` y el reproductor en `scripts/humahuaca/view/humahuaca_audio.gd`.", ""]
    (OUT / "MANIFIESTO.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    build()
