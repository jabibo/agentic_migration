# Der "stirbt nach erster Ablehnung"-Befund war falsch charakterisiert

Über diese ganze Session wurde wiederholt beobachtet und dokumentiert
(`docs/session9-multifile-loading.md`, `docs/session10-batch-run.md`,
`docs/session10-blocked-reporting.md`, `docs/session10-continuity-test.md`):
Qwens Sessions „sterben" fast immer kurz nach einer abgelehnten
`bash`-Aktion, statt einen alternativen Weg zu versuchen. Das wurde
bisher als **Modellverhalten** interpretiert („kommt nach einer
Ablehnung selten selbstständig auf eine Alternative"). Auf Nutzeranfrage
systematisch nachgeprüft — **die Interpretation war falsch, der
Befund selbst ist stärker als gedacht.**

## Methodik

Alle 34 in dieser Session noch lokal vorhandenen `opencode run`-
Transkripte (`/tmp/qwen_run_*.jsonl`) maschinell ausgewertet: Position
jeder Tool-Fehler-Meldung, Anzahl Ereignisse danach, und ob nach der
letzten Ablehnung überhaupt noch ein neuer `step_start` (= ein
weiterer Modell-Turn) folgt.

## Befund 1: Zwei völlig unterschiedliche Fehlerklassen

| Fehlertyp | Beispiel-Text | Vorkommen | Ereignisse danach |
|---|---|---|---|
| `Tool execution aborted` (das `"unknown"`-Tool-Artefakt, s. Session 9) | — | mehrfach pro Session möglich | Session läuft normal weiter, teils über 60 Ereignisse |
| Explizite `deny`-Regel getroffen | „The user **has specified a rule** which prevents…" | 1x beobachtet | **64** Ereignisse danach — Session lief lange normal weiter |
| `ask` im Headless-Modus automatisch abgelehnt | „The user **rejected permission**…" | 32x beobachtet | **1–3, ausnahmslos jedes einzelne Mal** |

Der entscheidende Unterschied ist nicht "Ablehnung ja/nein", sondern
**welche Art von Ablehnung**. `Tool execution aborted` und explizite
`deny`-Treffer sind für die Session überlebbar. `ask`-Ablehnungen im
nicht-interaktiven Modus sind es praktisch nie.

## Befund 2: Es ist kein Modellverhalten — der Run-Loop selbst endet

Bei **30 von 30** Transkripten mit einer `ask`-Ablehnung folgt danach
**kein einziger weiterer `step_start`** — also kein neuer Modell-Turn
überhaupt. Konkretes Beispiel (`qwen_run_knz701.jsonl`, letztes
Ereignis vor Sessionende):

```
tool_use  bash  error  "The user rejected permission..." (Befehl: "git status")
step_finish  reason=tool-calls, output_tokens=28, reasoning_tokens=11
[ENDE -- kein weiterer step_start]
```

Das Modell hat in diesem letzten Turn nur gerade genug generiert, um den
Tool-Aufruf selbst abzusetzen (28 Output-Tokens) — es bekommt **nie
die Gelegenheit**, das Ablehnungs-Ergebnis zu sehen und darauf zu
reagieren. Der `opencode run`-Prozess selbst beendet den Agenten-Loop,
sobald eine `ask`-Regel im Headless-Modus nicht beantwortbar ist —
nicht das Modell "gibt auf".

## Konsequenz: Frühere Interpretationen in dieser Session waren teilweise unzutreffend

- **„Kommt nach Ablehnung selten selbstständig auf eine Alternative aus"**
  (mehrfach in Session-9/10-Docs so formuliert) — unpräzise. Qwen bekommt
  in diesen Fällen **nie die Chance**, eine Alternative zu versuchen.
  Nicht Unwilligkeit oder fehlende Fähigkeit, sondern ein technischer
  Loop-Abbruch vor dem nächsten Modell-Turn.
- **`docs/session10-blocked-reporting.md`**s Befund („Qwen erkennt die
  Abbruchschwelle nicht, weil ihm die Versuchsnummer fehlt") bleibt
  richtig, aber unvollständig: selbst mit Versuchsnummer im Prompt
  (Runde 12) endete die Session an einer `ask`-Ablehnung, **bevor**
  Qwen den `ledger.jsonl`-Eintrag hätte schreiben können — der
  Mechanismus aus diesem Dokument ist die eigentliche Ursache, die
  fehlende Versuchsnummer nur ein zusätzliches, nachgeordnetes Problem.
- **`docs/session10-continuity-test.md`**s „Fixierung auf einen falschen
  Ansatz" (Runden 10-11: wiederholt `python3 tools/compare_data.py`
  direkt versucht) bleibt als Befund gültig (die *Wahl* des Ansatzes ist
  Modellverhalten) — aber warum das *tödlich* war, ist derselbe
  Mechanismus: `python3 ...` fällt auf `ask`, `ask` beendet den Loop
  sofort, bevor eine Korrektur überhaupt möglich wäre.

## Naheliegender, risikoarmer Test (nicht ausgeführt, zur Entscheidung)

Da `ask` im Headless-Betrieb ohnehin **faktisch immer** zu Ablehnung
führt (nichts kann es beantworten), ändert ein Wechsel von
`"*": "ask"` zu `"*": "deny"` in `opencode.jsonc`s `bash`-Regel das
**Ergebnis** einzelner Tool-Aufrufe nicht — abgelehnt wird so oder so.
Der einzige Unterschied, den die Daten hier nahelegen: eine explizite
`deny`-Ablehnung scheint die Session überleben zu lassen (n=1, aber mit
64 überlebten Ereignissen ein deutliches Signal), während `ask` sie
zuverlässig beendet. Das wäre ein **sehr kleiner, risikoarmer Eingriff**
(eine Zeile in `opencode.jsonc`) mit potenziell großer Wirkung auf
genau die Fragen aus `docs/session10-blocked-reporting.md` und
`docs/session10-continuity-test.md` — aber noch nicht getestet, bewusst
zur Entscheidung vorgelegt statt selbst umgesetzt.

## Related
`docs/session9-multifile-loading.md` · `docs/session10-batch-run.md` ·
`docs/session10-blocked-reporting.md` · `docs/session10-continuity-test.md`
