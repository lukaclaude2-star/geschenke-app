"""Zerlegt den Linienpfad eines Coco-SVGs in Teilpfade mit absolutem Startpunkt.

Die Löcher in den Linien (Gesicht, Paket, Blatt …) sind eigene Teilpfade.
Jeder Teilpfad bekommt Umriss-Box, Fläche und Umlaufsinn, damit man Löcher
von Außenkonturen unterscheiden kann.
"""
import re

ZAHL = r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"
TOKEN = re.compile(rf"[MmLlHhVvCcSsQqTtAaZz]|{ZAHL}")
ANZAHL = {"m": 2, "l": 2, "h": 1, "v": 1, "c": 6, "s": 4, "q": 4, "t": 2, "a": 7, "z": 0}


def teilpfade(d: str) -> list[dict]:
    tokens = TOKEN.findall(d)
    i, cmd = 0, None
    x = y = 0.0
    start = (0.0, 0.0)
    teile: list[dict] = []
    aktuell = None

    def zahl():
        nonlocal i
        wert = float(tokens[i]); i += 1
        return wert

    while i < len(tokens):
        t = tokens[i]
        if re.fullmatch(r"[A-Za-z]", t):
            cmd = t; i += 1
            if cmd in "Zz":
                x, y = start
                if aktuell:
                    aktuell["d"].append("Z")
                continue
        elif cmd is None:
            raise ValueError("Pfad beginnt ohne Befehl")
        rel = cmd.islower()
        c = cmd.lower()
        werte = [zahl() for _ in range(ANZAHL[c])]
        if c == "m":
            nx, ny = (x + werte[0], y + werte[1]) if rel else (werte[0], werte[1])
            aktuell = {"d": [f"M{nx:.3f},{ny:.3f}"], "punkte": [(nx, ny)]}
            teile.append(aktuell)
            x, y = nx, ny
            start = (x, y)
            cmd = "l" if rel else "L"  # weitere Zahlenpaare nach m sind Linien
            continue
        # alle anderen Befehle absolut umschreiben
        if c == "h":
            nx = x + werte[0] if rel else werte[0]
            aktuell["d"].append(f"L{nx:.3f},{y:.3f}"); x = nx
        elif c == "v":
            ny = y + werte[0] if rel else werte[0]
            aktuell["d"].append(f"L{x:.3f},{ny:.3f}"); y = ny
        elif c == "a":
            ex, ey = (x + werte[5], y + werte[6]) if rel else (werte[5], werte[6])
            w = werte
            aktuell["d"].append(f"A{w[0]},{w[1]},{w[2]},{int(w[3])},{int(w[4])},{ex:.3f},{ey:.3f}")
            x, y = ex, ey
        else:
            paare = [(werte[k] + (x if rel else 0), werte[k + 1] + (y if rel else 0))
                     for k in range(0, len(werte), 2)]
            aktuell["d"].append(c.upper() + " ".join(f"{px:.3f},{py:.3f}" for px, py in paare))
            aktuell["punkte"].extend(paare)
            x, y = paare[-1]
        aktuell["punkte"].append((x, y))

    for teil in teile:
        p = teil["punkte"]
        xs, ys = [a for a, _ in p], [b for _, b in p]
        teil["box"] = (min(xs), min(ys), max(xs), max(ys))
        flaeche = sum(p[k][0] * p[(k + 1) % len(p)][1] - p[(k + 1) % len(p)][0] * p[k][1]
                      for k in range(len(p))) / 2
        teil["flaeche"] = flaeche
        teil["d"] = " ".join(teil["d"])
    return teile


def innen(a: tuple, b: tuple) -> bool:
    return a[0] >= b[0] and a[1] >= b[1] and a[2] <= b[2] and a[3] <= b[3] and a != b


def loecher(teile: list[dict], min_anteil: float = 0.002) -> list[int]:
    """Indizes der Teilpfade, die innerhalb eines anderen liegen und groß genug sind."""
    gesamt = max(abs(t["flaeche"]) for t in teile)
    ergebnis = []
    for i, t in enumerate(teile):
        if abs(t["flaeche"]) < gesamt * min_anteil:
            continue
        if any(innen(t["box"], u["box"]) for j, u in enumerate(teile) if j != i):
            ergebnis.append(i)
    return ergebnis
