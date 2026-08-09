# Warum meldet Qwen nie `blocked`? — Ursache gefunden

Über den gesamten Session-10-Batch (701, 702, 708, 709 — ~20 Runden
insgesamt, mehrere davon 2+ Runden ohne Fortschritt auf demselben
Gate-Fehler) hat kein einziges Objekt jemals einen `ledger.jsonl`-
Eintrag mit `status: blocked` bekommen, obwohl `AGENTS.md`s eigenes
Abbruchkriterium („3 Iterationen auf demselben Gate ohne Fortschritt
→ blocked") mehrfach faktisch erreicht war.

## Befund

Geprüft: alle ~30 Prompts dieser Session (`/tmp/qwen_prompt_*.txt`) auf
irgendeine explizite Nennung der Versuchsnummer („Versuch 3", „dritte
Runde", o.ä.) — **null Treffer**.

Jede `opencode run`-Runde ist eine **komplett neue, zustandslose
Session** (kein `--continue`). Qwen bekommt in jeder Runde nur: den
rohen Gate-Fehlertext + den aktuellen Dateiinhalt. Es hat **keine
Erinnerung an vorherige Runden** — aus seiner Sicht könnte jede Runde
der allererste Versuch sein. `AGENTS.md`s Abbruchkriterium verlangt
aber explizit Selbstwissen über die eigene Iterationszahl
(„3 Iterationen ohne Fortschritt"), das unter diesem Aufrufmuster
**strukturell nicht existiert** — nicht, weil Qwen es nicht anwenden
würde, sondern weil ihm die dafür nötige Information nie mitgegeben
wurde.

Das ist kein Modell-Versagen, sondern eine Protokoll-Lücke auf meiner
(Bauherr-)Seite: ich habe in keinem einzigen Follow-up-Prompt jemals
„das ist jetzt Versuch N" geschrieben.

## Konsequenz für die bisherigen Session-10-Daten

Die in `docs/ablation-metrics.md` dokumentierte Beobachtung „Ø 4,25
Runden/Objekt, kein Objekt tatsächlich abgebrochen" ist damit nicht
(nur) ein Qwen-Autonomie-Befund — sie ist teilweise ein Artefakt dieser
Protokoll-Lücke. Ich selbst habe wiederholt (mit Nutzerzustimmung)
über die 3er-Schwelle hinaus weiterversuchen lassen, aber selbst wenn
ich das nicht getan hätte, hätte Qwen die Schwelle aus eigener Kraft
nie erkennen können.

## Zwei unabhängige, nicht-invasive Fixes (keine Content-Änderung)

1. **Iterationszähler explizit im Prompt nennen** — bei jeder
   Folgerunde `„Dies ist Versuch N von 3 auf diesem Gate. Bei
   fehlendem Fortschritt jetzt: Zeile an ledger.jsonl anhängen
   (status: blocked), nicht weiterversuchen."` mitgeben. Einfach,
   sofort umsetzbar, ändert nichts an Qwens Modellinhalt.
2. **Session-Kontinuität (`opencode run --continue`/`-s`)** — würde
   Qwen die eigene Historie automatisch zugänglich machen, ohne dass
   ich sie manuell mitgeben muss. Testet gleichzeitig eine andere
   Hypothese (Kontextverlust als Konvergenz-Bremse, s.
   `docs/session10-batch-run.md` Fazit) — beide Fragen hängen zusammen:
   wenn Kontinuität hilft, löst sie vermutlich auch dieses Problem
   nebenbei.

Nächster Schritt: (2) empirisch testen (s. u.), da es beide Fragen auf
einmal beantwortet.

## Related
`docs/ablation-metrics.md` · `docs/session10-batch-run.md` · `AGENTS.md`
„Abbruchkriterium"
