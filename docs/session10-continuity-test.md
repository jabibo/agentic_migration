# Session-Kontinuität als Test-Variable (KNZ 709, Runden 9-11)

Auf Nutzeranfrage getestet: `opencode run -s <session-id>` statt eines
frischen Laufs, um zu prüfen, ob Kontextverlust zwischen Runden die
Konvergenz-Bremse ist (Hypothese aus `docs/session10-batch-run.md`s
Fazit) und ob es nebenbei das `blocked`-Melde-Problem löst
(`docs/session10-blocked-reporting.md`).

## Aufbau

Fortgesetzt wurde Runde 8 (`ses_018c56f8affeJ0P7eRspz0MRLX`, die
gründlichste, aber erfolglose frische Runde — mehrere gezielte
`exapump_select.sh`-Abfragen, Lektüre der eigenen Compare-Tools, kein
Fortschritt). Drei Folgeprompts an dieselbe Session, keine neuen
frischen Sessions.

## Ergebnis

**Runde 9** (derselbe rohe G2/G3-Fehlertext wie zuvor an frische Runden):
deutlich anderes Verhalten als jede vorherige frische Runde auf dieses
Objekt. Reasoning teils auf Englisch (Modellvarianz, nicht kontrollierbar).
Entfernte korrekt die überzählige `Anzahl`-Spalte (**G2 jetzt sauber** —
erster echter G2-Fortschritt in der gesamten Session-10-Serie), änderte
die `mon_id`-Berechnung (Triple-Cast → `EXTRACT`, Wirkung auf G3 unklar
geblieben) und war laut eigener Aussage mitten in der Analyse von
`pd_beh_key` („The `behinderung_bit` macro sums" — exakt der zuvor
bestätigte, nie an Qwen weitergegebene `+`-vs-`\|`-Fund), als die Session
abbrach. Kein Steckenbleiben — ein Abbruch mitten im Fortschritt,
vermutlich ein Turn-/Step-Limit des non-interaktiven Laufs, nicht
Ratlosigkeit des Modells. **Committet** (`2b7fc2a`).

**Runde 10** (minimaler Nudge „Mach weiter mit deiner Untersuchung von
pd_beh_key"): ein einziger Tool-Call — `python3 tools/compare_data.py
--hash-only` direkt aufgerufen, zu Recht abgelehnt (nicht in der
Allowlist) — Session endet sofort danach, kein Rückfall auf `make
compare` oder `exapump_select.sh`.

**Runde 11** (derselbe volle rohe G3-Fehlertext wie Runde 9, um zu
prüfen ob mehr Kontext im Prompt selbst hilft): identisches Muster —
ein einziger Tool-Call, wieder `python3 tools/compare_data.py` direkt
(diesmal ohne `--hash-only`), wieder abgelehnt, wieder sofortiger
Abbruch. Keine Änderung.

## Interpretation

Kontinuität ist **kein einfacher Hebel** — sie half einmal deutlich
(Runde 9: echter G2-Fix, sichtbare Annäherung an den `pd_beh_key`-Fund)
und schadete danach zweimal (Runden 10-11: die Session hatte sich
offenbar auf den Ansatz „`compare_data.py` direkt aufrufen" **fixiert**
— ein Ansatz, den frühere *frische* Runden (7, 8) gar nicht erst
versucht hatten, weil sie stattdessen erfolgreich `exapump_select.sh`
nutzten. Mit Gedächtnis an die eigene vorherige (in Runde 8 gelesene)
Lektüre von `tools/compare_data.py` scheint das Modell diesen einen,
nicht erlaubten Weg für „den richtigen" zu halten und wiederholt genau
ihn, statt auf die bekannte Alternative zurückzufallen — ein Muster,
das eine frische Session (ohne diese Fixierung) nicht zeigt.

Das ist ein eigenständiger, nicht-trivialer Befund: Kontinuität kann
sowohl **Fortschritt beschleunigen** (mehr Kontext, kein Neuaufbau des
Verständnisses) als auch **Sackgassen verstärken** (ein einmal probierter,
falscher Ansatz wird durch die eigene Historie "bestätigt" statt neu
bewertet). Für dieses Projekt bedeutet das: Kontinuität ist kein
pauschaler Fix, sondern eine echte, in beide Richtungen wirkende
Variable — passt zur allgemeinen Beobachtung dieser Session, dass
Qwen nach einer einzelnen Ablehnung selten selbstständig auf eine
Alternative ausweicht (`docs/session9-multifile-loading.md`,
`docs/session10-batch-run.md`).

Zur ursprünglichen `blocked`-Frage (`docs/session10-blocked-reporting.md`):
auch mit vollem Gedächtnis an die eigene Erfolglosigkeit über jetzt
3 fortgesetzte Runden hat Qwen **nicht** von sich aus einen
`ledger.jsonl`-Eintrag geschrieben — Kontinuität allein löst das
Melde-Problem also nicht, mindestens nicht ohne die Versuchsnummer
zusätzlich explizit zu benennen (der in jenem Dokument vorgeschlagene
erste Fix bleibt separat nötig).

## Endstand nach diesem Test

G0 14/14, G1 14/14, **G2 grün** (neu), G3 weiterhin offen (dieselben
8 Spalten, `pd_beh_key` inklusive). Auf `qwen/knz-709`, ungemerged.
Kein vierter Kontinuitäts-Versuch — zwei Runden ohne Fortschritt in
Folge, dieselbe Schwelle wie bei frischen Runden angewandt.

## Related
`docs/session10-batch-run.md` · `docs/session10-blocked-reporting.md` ·
`docs/ablation-metrics.md`
