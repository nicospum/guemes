#!/usr/bin/env python3
"""«Agente» de guion para probar el protocolo por archivos de tools/hx_agent_play.gd. Dueño: compuertas y documentos. No es el agente-jugador.

El arnés (hx_agent_play.gd) es el lado del juego: escribe turno_NN.png, espera accion_NN.json, aplica la entrada, avanza el tiempo y cierra con respuestas.json,
con el máximo de turnos o con «abandono». El --selftest del arnés contesta solo y NO recorre la espera de archivos; este programa sí: hace de agente, con un guion
fijo que no depende de la disposición de la interfaz (solo teclas, esperas y entradas inválidas a propósito), y comprueba lo que el arnés escribe.

Uso: python -I hx_agent_guion.py --turns-dir <carpeta> --arnes <arnes.json> [--guion protocolo|repetir:<arnes.json>|<guion.json>] [--timeout 120] [--log <log.json>]
  --guion protocolo   el guion de la compuerta (8 turnos: espera, JSON roto, clic fuera de la ventana, tipo desconocido, tres teclas y una espera) y después respuestas.json
  --guion repetir:<arnes.json>   repite, una por turno y por el protocolo de archivos, las acciones de un arnes.json de referencia (el del --selftest) y compara la partida con la de
                      referencia turno a turno: acción, si se aplicó, si fue una orden aceptada, modo, diálogo, fase, tiempo de juego antes y después, primera orden y desenlace de cada
                      intento (TR-217: el protocolo por archivos no cambia la partida). Si la referencia cerró con respuestas.json (llegó al parte de victoria), en su último turno escribe
                      las respuestas en lugar de una acción y la corrida tiene que cerrar con `respuestas`; si cerró con --max-turns, la repetición cierra igual
  --guion <archivo>   una lista JSON de entradas: {"tipo": "clic"|"tecla"|"esperar", ...}, {"crudo": "<texto sin tocar>"} u {"omitir": true} (no contesta: el arnés abandona)
Sale con 0 si cada comprobación del guion «protocolo» o «repetir» pasa (o, con otro guion, si no hubo errores de entrega) y con 1 si falla alguna. Imprime «HX_AGENT_GUION {json}».
"""
import argparse
import json
import os
import struct
import sys
import time
import unicodedata
from pathlib import Path

# Guion de la compuerta: (entrada, ¿el arnés la aplica?). La entrada «crudo» es un JSON que nunca se completa: el arnés reintenta 3 s y la da por inválida.
# «nota» es lo que el «agente» anota en bitacora.md antes de ese turno (no viaja en la acción). Con el briefing de hoy (Enter lo cierra y empieza la apertura, otra tecla la salta)
# el turno 5 nombra los tres frentes ANTES de ver el mapa (no cuenta), el 6 es el primer cuadro con mapa y nombra solo la batería, el 7 nombra el cuartel y la posta (los tres quedan
# nombrados 2 turnos después de ver el mapa: 7 - 6 + 1) y el 8 los repite por si un briefing más largo retrasara el primer cuadro con mapa. Lo esperado no está escrito a mano:
# `esperado_identificacion` lo recalcula con los modos que informó el arnés, así que un briefing que cambie de largo no rompe la prueba (la rompe solo si ya ningún turno con mapa
# recibe una nota que complete los tres nombres, o si tres teclas ya no alcanzan para salir del briefing).
PROTOCOLO = [
    ({"tipo": "esperar", "s": 1}, True),
    ({"crudo": '{"tipo": "clic", "x": 64'}, False),
    ({"tipo": "clic", "x": -5, "y": 10, "boton": "izq"}, False),
    ({"tipo": "baila"}, False),
    ({"tipo": "tecla", "tecla": "Enter", "nota": "Leí el briefing: hay que tomar la batería, el cuartel y la posta. Todavía no veo el mapa."}, True),
    ({"tipo": "tecla", "tecla": "Enter", "nota": "Veo la apertura: una cámara que pasa por la batería."}, True),
    ({"tipo": "tecla", "tecla": "Space", "nota": "Ahora veo el cuartel en el centro y la posta a la derecha."}, True),
    ({"tipo": "esperar", "s": 2, "nota": "Se ven la batería, el cuartel y la posta, cada una con su luz."}, True),
]
# Las mismas palabras (sin tildes) que usa el arnés para decir que la bitácora nombra un frente: este programa las repite aparte para no depender del código que prueba.
FRENTES = {"bateria": ["bater", "santa barbara"], "cuartel": ["cuartel", "casa del cura"], "posta": ["posta", "polvor"]}
RESPUESTAS = {
    "objetivo": "Tomar los tres frentes (la batería, el cuartel y la posta) y llevarse la carga antes del alba.",
    "entendiste": "Es una prueba del protocolo con un guion: no entendí nada porque no soy un jugador.",
    "aburrimiento": "No aplica: es un guion de la compuerta, no un agente que juega.",
    "aprendido": "No aplica: el guion no juega ni reintenta; solo prueba que el arnés lee, aplica y cierra.",
}


def plegar(texto: str) -> str:
    """Minúsculas y sin tildes."""
    return "".join(c for c in unicodedata.normalize("NFD", texto.lower()) if unicodedata.category(c) != "Mn")


def esperado_identificacion(notas: dict, modos: list):
    """Lo que el arnés tiene que informar: (turnos desde el primer cuadro con mapa hasta que lo anotado desde ese cuadro nombra los tres frentes, primer cuadro con mapa)."""
    primero = next((i + 1 for i, m in enumerate(modos) if m in ("opening", "play")), -1)
    if primero < 0:
        return -1, -1
    acumulado = ""
    for t in range(primero, len(modos) + 1):
        acumulado += " " + notas.get(t, "")
        texto = plegar(acumulado)
        if all(any(w in texto for w in palabras) for palabras in FRENTES.values()):
            return t - primero + 1, primero
    return -1, primero


CAMPOS_TURNO = ("accion", "aplicada", "orden_aceptada", "modo", "dialogo", "fase", "t_juego_s", "t_despues_s")


def comparar(ref: dict, nuevo: dict) -> list:
    """Diferencias entre la partida de referencia (el arnes.json del --selftest) y la repetida por archivos, en texto; vacía si es la misma partida turno a turno."""
    dif = []
    rt, nt = ref.get("turnos", []), nuevo.get("turnos", [])
    if len(nt) != len(rt):
        dif.append("la repetición tuvo %d turnos y la referencia %d" % (len(nt), len(rt)))
    for i in range(min(len(rt), len(nt))):
        for campo in CAMPOS_TURNO:
            if rt[i].get(campo) != nt[i].get(campo):
                dif.append("turno %d: %s es %r y la referencia %r" % (i + 1, campo, nt[i].get(campo), rt[i].get(campo)))
                break
    for campo in ("primera_orden_turno", "primera_orden_t_s", "cierre"):
        if ref.get(campo) != nuevo.get(campo):
            dif.append("%s es %r y la referencia %r" % (campo, nuevo.get(campo), ref.get(campo)))
    def intento(x):
        return (x.get("n"), x.get("resultado"), x.get("cause_id"), x.get("t_juego_s"), x.get("turnos"))
    if [intento(x) for x in ref.get("intentos", [])] != [intento(x) for x in nuevo.get("intentos", [])]:
        dif.append("los intentos difieren: %s y la referencia %s" % ([intento(x) for x in nuevo.get("intentos", [])], [intento(x) for x in ref.get("intentos", [])]))
    return dif


def png_size(path: Path):
    try:
        with open(path, "rb") as f:
            head = f.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h = struct.unpack(">II", head[16:24])
    return (w, h)


def write_action(path: Path, entry: dict, partial: bool) -> None:
    text = str(entry["crudo"]) if "crudo" in entry else json.dumps({k: v for k, v in entry.items() if k != "nota"}, ensure_ascii=False)
    if partial and len(text) > 8:
        # a medias: el arnés puede encontrar el archivo incompleto y tiene que reintentar sin darlo por inválido
        half = len(text) // 2
        with open(path, "w", encoding="utf-8") as f:
            f.write(text[:half])
            f.flush()
            os.fsync(f.fileno())
            time.sleep(0.6)
            f.write(text[half:])
    else:
        tmp = path.with_suffix(".tmp")
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, path)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--turns-dir", required=True)
    ap.add_argument("--arnes", required=True, help="el arnes.json que escribe el arnés (--out de hx_agent_play)")
    ap.add_argument("--guion", default="protocolo")
    ap.add_argument("--timeout", type=float, default=120.0, help="segundos máximos esperando cada turno y el cierre del arnés")
    ap.add_argument("--log", default="")
    a = ap.parse_args()

    turns = Path(a.turns_dir)
    turns.mkdir(parents=True, exist_ok=True)
    protocolo = a.guion == "protocolo"
    referencia = None
    cierra_con_respuestas = False
    if protocolo:
        guion = [dict(e) for e, _ in PROTOCOLO]
        esperado = [ok for _, ok in PROTOCOLO]
    elif a.guion.startswith("repetir:"):
        referencia = json.loads(Path(a.guion.split(":", 1)[1]).read_text(encoding="utf-8"))
        guion = [dict(t["accion"]) for t in referencia.get("turnos", [])]  # la acción exacta que aplicó el arnés en cada turno de la referencia
        esperado = []
        # Una referencia que cerró con respuestas.json (el --selftest que llegó al parte de victoria) termina igual: su última acción es la espera de 0,25 s con que el arnés contesta solo
        # cuando ve respuestas.json, así que en ese último turno el agente de guion escribe las respuestas en lugar de una acción.
        cierra_con_respuestas = referencia.get("cierre") == "respuestas"
    else:
        guion = json.loads(Path(a.guion).read_text(encoding="utf-8"))
        esperado = []
    errores = []
    filas = []
    t0 = time.time()
    for i, entry in enumerate(guion, start=1):
        png = turns / ("turno_%02d.png" % i)
        w0 = time.time()
        while not png.exists() and time.time() - w0 < a.timeout:
            time.sleep(0.1)
        if not png.exists():
            errores.append("turno_%02d.png no apareció en %.0f s" % (i, a.timeout))
            break
        time.sleep(0.15)  # el arnés escribe el PNG con otro nombre y lo renombra: ya está completo, la espera es por cortesía con el disco
        size = png_size(png)
        if size != (1280, 720):
            errores.append("turno_%02d.png mide %s y no 1280x720" % (i, size))
        filas.append({"n": i, "png": list(size) if size else None, "entrada": entry})
        if entry.get("omitir"):
            break
        if entry.get("nota"):
            # como el agente real: anota qué ve antes de actuar (el arnés lee bitacora.md al leer la acción de este turno)
            with open(turns / "bitacora.md", "a", encoding="utf-8") as f:
                f.write("Turno %d: %s\n" % (i, entry["nota"]))
        if cierra_con_respuestas and i == len(guion):
            time.sleep(0.3)  # como la referencia: en el último turno no hay acción, hay respuestas
            (turns / "respuestas.json").write_text(json.dumps(RESPUESTAS, ensure_ascii=False, indent=1), encoding="utf-8")
            break
        # la mitad de los turnos se escribe a medias, para probar el reintento de lectura del arnés
        write_action(turns / ("accion_%02d.json" % i), entry, partial=(i % 2 == 0 and "crudo" not in entry))
    cerro_con_respuestas = cierra_con_respuestas and len(filas) == len(guion)
    if guion and referencia is None and not guion[-1].get("omitir") and len(filas) == len(guion):
        time.sleep(1.5)  # el arnés lee la acción del último turno antes de ver respuestas.json
        (turns / "respuestas.json").write_text(json.dumps(RESPUESTAS, ensure_ascii=False, indent=1), encoding="utf-8")
        cerro_con_respuestas = True
    # esperar el cierre del arnés: escribe arnes.json con «cierre» al terminar
    arnes_path = Path(a.arnes)
    arnes = {}
    c0 = time.time()
    while time.time() - c0 < a.timeout:
        try:
            arnes = json.loads(arnes_path.read_text(encoding="utf-8"))
            if arnes.get("cierre"):
                break
        except (OSError, ValueError):
            pass
        time.sleep(0.5)
    comprobaciones = []

    def chk(nombre, ok, detalle=""):
        comprobaciones.append({"check": nombre, "ok": bool(ok), "detalle": detalle})
        if not ok:
            errores.append("%s %s" % (nombre, detalle))

    if protocolo:
        todos = arnes.get("turnos", [])
        n = len(guion)
        # las respuestas llegan después de la última acción: el arnés puede alcanzar a abrir un turno más y lo cierra con una espera de 0,25 s
        extra = todos[n:]
        turnos = todos[:n]
        chk("el arnés escribió arnes.json con el esquema hx_agente_v1", arnes.get("schema") == "hx_agente_v1", str(arnes.get("schema")))
        chk("atendió los %d turnos del guion" % n, len(turnos) == n and all((t.get("accion") or {}) == {"tipo": "esperar", "s": 0.25} for t in extra) and len(extra) <= 1, "turnos=%d" % len(todos))
        aplicadas = [bool(t.get("aplicada")) for t in turnos]
        chk("aplicó solo lo válido (esperar, teclas) y rechazó el JSON roto, el clic fuera de la ventana y el tipo desconocido", aplicadas == esperado, "aplicadas=%s esperado=%s" % (aplicadas, esperado))
        tipos = [str((t.get("accion") or {}).get("tipo", "")) for t in turnos]
        chk("registró el tipo de cada acción", tipos == ["esperar", "invalida", "clic", "baila", "tecla", "tecla", "tecla", "esperar"], str(tipos))
        modos = [str(t.get("modo", "")) for t in turnos]
        chk("el primer turno es el briefing", bool(modos) and modos[0] == "briefing", str(modos[:2]))
        chk("las teclas Enter, Enter y Space hicieron salir del briefing", len(modos) == n and modos[-1] in ("opening", "play"), str(modos))
        chk("cerró con respuestas.json", arnes.get("cierre") == "respuestas" and cerro_con_respuestas, str(arnes.get("cierre")))
        notas = {i: str(e["nota"]) for i, e in enumerate(guion, start=1) if e.get("nota")}
        esperado_id, esperado_mapa = esperado_identificacion(notas, modos)
        chk("el guion nombra los tres frentes en su bitácora desde que se ve el mapa (si no, la prueba no mide nada)", esperado_id > 0, "esperado=%s mapa_desde_turno=%s modos=%s" % (esperado_id, esperado_mapa, modos))
        chk("la bitácora identifica los tres frentes en %s turno(s) contados desde el primer cuadro con mapa (turno %s); lo escrito antes de ver el mapa no cuenta" % (esperado_id, esperado_mapa),
            arnes.get("objetivos_identificados_en_turnos") == esperado_id and arnes.get("mapa_desde_turno") == esperado_mapa,
            "informado=%s mapa_desde_turno=%s" % (arnes.get("objetivos_identificados_en_turnos"), arnes.get("mapa_desde_turno")))
    if referencia is not None:
        chk("el arnés escribió arnes.json con el esquema hx_agente_v1", arnes.get("schema") == "hx_agente_v1", str(arnes.get("schema")))
        if cierra_con_respuestas:
            chk("atendió los %d turnos de la referencia y cerró con respuestas.json, como ella" % len(guion), len(arnes.get("turnos", [])) == len(guion) and (turns / "respuestas.json").exists() and arnes.get("cierre") == "respuestas",
                "turnos=%d cierre=%s" % (len(arnes.get("turnos", [])), arnes.get("cierre")))
        else:
            chk("atendió los %d turnos de la referencia y cerró sin respuestas.json" % len(guion), len(arnes.get("turnos", [])) == len(guion) and not (turns / "respuestas.json").exists(), "turnos=%d cierre=%s" % (len(arnes.get("turnos", [])), arnes.get("cierre")))
        difs = comparar(referencia, arnes)
        chk("la partida por archivos es la del --selftest, turno a turno (%d turnos, %d campos por turno, la primera orden y los intentos)" % (len(guion), len(CAMPOS_TURNO)), not difs, "; ".join(difs[:3]))
    log = {"turnos": filas, "errores": errores, "comprobaciones": comprobaciones, "cierre": arnes.get("cierre"), "duracion_s": round(time.time() - t0, 1)}
    if a.log:
        Path(a.log).write_text(json.dumps(log, ensure_ascii=False, indent=1), encoding="utf-8")
    print("HX_AGENT_GUION " + json.dumps({"turnos": len(filas), "cierre": arnes.get("cierre"), "comprobaciones": len(comprobaciones), "errores": errores, "duracion_s": log["duracion_s"]}, ensure_ascii=False))
    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
