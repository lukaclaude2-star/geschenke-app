---
name: app-ausliefern
description: Use when a change to the Geschenke iPhone app (ios/**) is finished on a work branch and should reach Luka's iPhone - compile check on the branch, merge to main, release app-<N>, SideStore update.
---

# App ausliefern (Geschenke-App)

Es gibt kein lokales Swift und keinen Mac. Die CI ist der Compiler. Auf dem Handy landet
nur, was auf `main` gebaut wurde: Jeder Build auf main legt das Release `app-<run_number>`
an. Die SideStore-Quelle (`/dl/<geheimnis>/source.json`) liest immer das neueste Release.

## Ablauf

1. **Arbeitszweig, nie direkt main.** Erst committen, dann `git push -u origin <zweig>`.
2. **Kern-Tests:** Bei Änderungen unter `ios/GeschenkeCore/**` läuft „iOS-Kern testen“ von
   selbst. Abwarten mit `gh run watch <id> --exit-status`.
3. **App auf dem Zweig bauen.** Auf Arbeitszweigen startet der Build nur per Hand, weil
   Mac-Minuten Geld kosten:
   ```bash
   gh workflow run ios-build.yml --ref <zweig> -f runner=macos-15
   gh run list --branch <zweig> --workflow ios-build.yml --limit 1   # Run-ID
   gh run watch <id> --exit-status
   gh run view <id> --log | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
   ```
   Fertig ist es erst bei „BUILD SUCCEEDED“ und ohne `error:`. Der Schritt-Status reicht
   nicht, weil der Build-Schritt die Ausgabe filtert.
4. **Review** des ganzen Zweigs (superpowers:requesting-code-review). Critical und
   Important vor dem Merge beheben.
5. **Mergen und pushen:**
   ```bash
   git checkout main && git pull
   git merge --no-ff <zweig> -m "Merge <zweig>: <was>"
   git push
   ```
   Der Push auf main startet „iOS-App bauen“ mit Release.
6. **Release prüfen:**
   ```bash
   gh run list --branch main --workflow ios-build.yml --limit 1
   gh run watch <id> --exit-status
   gh release list --limit 3          # neuestes: app-<N>, Titel „App 1.0.<N>“
   gh release view app-<N>            # Asset Geschenke.ipa vorhanden?
   ```
   `source.json` braucht das Download-Geheimnis (nur auf Render). Ohne Geheimnis reicht
   die Prüfung des Releases, weil der Server immer das neueste nimmt.
7. **Luka Bescheid geben:** Version 1.0.<N>, was er auf dem iPhone testen soll. In
   SideStore aktualisieren (Quelle neu laden, dann „Update“).

## Stolpersteine

- Swift-Dateien mit `\n` in String-Literalen nicht per Bash-Heredoc schreiben, denn er
  macht daraus einen echten Zeilenumbruch („unterminated string literal“). Lieber Edit
  oder ein Python-Skript als Datei.
- Neue Felder in `AppDaten` immer mit `decodeIfPresent` lesen, sonst landen alte Daten in
  `appdaten.kaputt-*.json`.
- Nach dem Merge den Zweig nur löschen, wenn `git branch --merged main` ihn zeigt.
