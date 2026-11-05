"""Prüfskript vor dem Einreichen im App Store (Plan 2026-11-05, Task 4)."""

import json
import shutil
from pathlib import Path

from scripts.pruefe_store_bereit import probleme

WURZEL = Path(__file__).parent.parent


def test_echtes_repo_meldet_offene_angaben():
    gefunden = probleme(WURZEL)
    assert "Angabe offen in rechtliches/rechtliches.json: name" in gefunden


def kopie(tmp_path: Path, angaben: dict) -> Path:
    (tmp_path / "rechtliches").mkdir()
    texte = json.loads((WURZEL / "rechtliches" / "rechtliches.json").read_text(encoding="utf-8"))
    texte["angaben"] = angaben
    (tmp_path / "rechtliches" / "rechtliches.json").write_text(json.dumps(texte), encoding="utf-8")
    (tmp_path / "ios" / "Geschenke").mkdir(parents=True)
    return tmp_path


def test_fehlende_store_dateien(tmp_path):
    wurzel = kopie(tmp_path, {"name": "Max"})
    (wurzel / "ios" / "project.yml").write_text("name: Geschenke\n", encoding="utf-8")
    gefunden = probleme(wurzel)
    assert "Fehlt: ios/Geschenke/PrivacyInfo.xcprivacy" in gefunden
    assert "Fehlt in ios/project.yml: ITSAppUsesNonExemptEncryption" in gefunden


def test_alles_da(tmp_path):
    wurzel = kopie(tmp_path, {"name": "Max", "email": "max@example.org"})
    shutil.copy(WURZEL / "ios" / "project.yml", wurzel / "ios" / "project.yml")
    with open(wurzel / "ios" / "project.yml", "a", encoding="utf-8") as datei:
        datei.write("\n        ITSAppUsesNonExemptEncryption: false\n")
    (wurzel / "ios" / "Geschenke" / "PrivacyInfo.xcprivacy").write_text("<plist/>", encoding="utf-8")
    assert probleme(wurzel) == []
