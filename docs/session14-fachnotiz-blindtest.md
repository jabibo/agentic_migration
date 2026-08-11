# Session 14 — Blindtest: Erkennt Qwen Fachlogik, wenn es sie nicht umsetzen muss?

Fortsetzung der Session-14-Arbeit an der Bestand-Serie
(`docs/session13-bestand-711-fixes.md` Nachtrag) und den 15
Fachnotizen (`source_references/pd/pd_skripte/*.md`). Ausgangsfrage
des Nutzers, nachdem alle 15 Notizen geschrieben waren: *"wäre Qwen in
der Lage, diese fachliche Logik so zu erkennen und zu formulieren?
Wahrscheinlich nicht, da es sonst ja in der Lage sein sollte, es in
Code umzusetzen."*

## Methodik

Blindtest gegen die reichhaltigste der 15 Fachnotizen:
`PD KNZ INIT.unplausibler Fallabschluss.sql` (Zieltabelle `tf_pd_fc`,
Basis für praktisch alle Kennzahlen). Vor jedem Lauf wurde die
existierende Bauherr-Fachnotiz zur selben Datei aus dem Verzeichnis
entfernt (nach Lauf zurückgelegt) — sonst hätte Qwen sie über sein
eigenes Read-Tool einfach lesen können, `AGENTS.md` untersagt das nur
verhaltensseitig ("nichts sonst anfordern"), keine technische Sperre.

Prompt (identisch in allen drei Läufen): Datei lesen, **keinen** Code
erzeugen, **keine** Datei ändern, **kein** `make gate`/`compare`
aufrufen, stattdessen eine Fachnotiz im Entwickler-Nachfolger-Ton
schreiben — ausdrücklich ohne Migrations-/dbt-/Klassen-/Gate-Sprache.
Alle drei Läufe über `opencode run --agent migrator`, Modell per
`--model`-Override gewechselt, `opencode.jsonc`s Konfiguration
(`qwen/qwen3.6-35b-a3b`) dabei nie verändert.

## Ergebnis 1: `qwen3.6-35b-a3b` (konfiguriertes Modell, 3B aktive Parameter)

4 von 5 Typ-2-Fachlogik-Stellen korrekt erkannt und sachlich
zutreffend beschrieben (MySkills-Wertsubstitution, Alt-ID-
Konsolidierung, Zeitabhängigkeit der Geschlechts-Regel — fast wörtlich
als "das subtilste Konstrukt im Skript" wie in der Bauherr-Notiz —,
`pd_abschl_art`-Override), plus ein eigenständiger Fund, der in der
Bauherr-Notiz fehlte: das Skript filtert trotz seines Namens
"unplausibler Fallabschluss" gar nichts vor.

Bei der einen wirklich subtilen Stelle — Ganzzahl-Subtraktion `-1` auf
einem YYYYMM-Wert (`(LEFT(CONVERT(VARCHAR(8), bi_load_date, 112), 6))
- 1 < 201604`) statt echter Monatsarithmetik — lag Qwen falsch, und
zwar **konfident falsch**: *"das -1 ändert nichts am Ergebnis"*, ohne
jede Unsicherheits-Markierung, obwohl dieselbe Stelle korrekt als die
schwierigste identifiziert wurde. Trotz expliziter Gegenanweisung
endete die Antwort außerdem mit migrationsspezifischer Sprache
("Zusammenfassung für die Migration") — die `AGENTS.md`-Grundprägung
("Du migrierst...") ließ sich nicht vollständig weg-briefen.

**Bezug zu echten Migrationsfehlern derselben Session**: exakt dasselbe
Muster — überzeugend formulierte, aber falsche Schlussfolgerung ohne
Unsicherheits-Markierung, gerade an der technisch härtesten Stelle —
zeigte sich unabhängig davon bei KNZ-711/fa: die "Data-Versioning-
Mismatch"-Fehldiagnose wurde committet, ohne `make compare` danach
erneut laufen zu lassen (s. `docs/session13-bestand-711-fixes.md`
Nachtrag, `ledger.jsonl`-Eintrag). Erkennen/Formulieren von Fachlogik
trennt sich bei diesem Modell also nicht sauber von Umsetzungsfähigkeit
— beide scheitern an derselben Art Stelle, aus demselben Grund.

## Zwischenfrage: liegt es an der Quantisierung?

Nutzerhypothese: das konfigurierte Modell laufe vermutlich als
Q4-Quantisierung, ein Q8-Modell könnte die Lücke schließen. Live bei
OpenRouter geprüft (`GET /api/v1/models/qwen/qwen3.6-35b-a3b/endpoints`):

| Provider | Quantisierung |
|---|---|
| Venice, DeepInfra, AkashML, Parasail, AtlasCloud, SiliconFlow, CoreWeave, Io Net | fp8 |
| Phala | unknown |

**Kein einziger Anbieter läuft mit Q4** — durchgängig fp8, das ist
bereits ungefähr die Präzisionsklasse, die "Q8" gemeint hätte. Die
Quantisierungs-Hypothese ist damit widerlegt.

## Ergebnis 2: `qwen3-235b-a22b` (22B aktive Parameter statt 3B, gleiche Qwen3-Generation)

Zweite Hypothese: nicht Präzision, sondern aktive Rechenkapazität pro
Token. Ergebnis widerspricht der Hypothese eher, als sie zu
bestätigen: das größere Modell übersprang eine ganze Kategorie
(`pd_veranl_stl`/`pd_rks_id`-Wertkonsolidierung, sowohl vom kleineren
Modell als auch vom Bauherrn gefunden), machte keinen Bonus-Fund, und
löste die `-1`-Stelle nicht falsch, sondern ließ sie beim Abschreiben
der Bedingung still weg (`LEFT(bi_load_date,6) < 201604` statt der
tatsächlichen `(LEFT(...))-1 < 201604`) — kein Zeichen besserer
Kalibrierung, eher Vermeidung statt Auseinandersetzung. Einzige
Verbesserung: hielt die Anweisung ohne Migrationssprache sauber ein.

Insgesamt kürzer, generischer, mit einer vagen Abschlussfloskel statt
konkreter Punkte.

## Ergebnis 3: `qwen3.8-max` (neuere Generation, Flaggschiff-Stufe)

Deutlich besseres Ergebnis, gerade an der Stelle, die beide
vorherigen Modelle verfehlt hatten. Löste die `-1`-Arithmetik korrekt
und präzise: *"Das '−1' führt dazu, dass auch April-2016-Laden noch
umgehoben werden."* Nachgerechnet und bestätigt: `201604 - 1 = 201603
< 201604` → wahr, der P61-Umstellungsmonat selbst fällt noch unter die
alte Behandlung. Das ist präziser als die eigene Bauherr-Notiz, die an
dieser Stelle fälschlich einen Jahresübergang/Januar-Fall betont hatte
statt der tatsächlichen Verschiebung der Schwelle um einen Monat.

Zwei weitere eigenständige Funde, die in keiner der drei anderen
Notizen (auch der Bauherr-Notiz nicht) stehen:
- Die `pd_abschl_art`-Prüfung (Zeilen 78-81) greift auf das *rohe*
  `pd_tae_durch` zu, nicht auf den weiter oben in derselben
  SELECT-Liste transformierten Alias — eine echte SQL-Scoping-
  Feinheit (Spalten-Aliase derselben SELECT-Liste sind für andere
  Ausdrücke derselben Liste nicht sichtbar), die bei einem
  Refactoring-Versuch leicht übersehen würde.
- Aus der Änderungshistorie im Dateikopf abgeleitet, dass `kdt_id`
  (entfernt mit P91) und `pd_geb_dat`/Alter (entfernt Februar 2024)
  bewusst entfernte, nicht vergessene Spalten sind — fehlende Spalten
  als Historie erkannt, nicht nur vorhandene Sonderfälle.

Dazu die Rahmung *"Der Dateiname lügt"* (ursprünglich ging es 2012 nur
um unplausible Fallabschlüsse, über die Jahre kamen unabhängige
Regelkomplexe dazu) — treffender formuliert als in allen drei anderen
Notizen. Hielt sich zudem sauber an die Anweisung, keine
Migrationssprache zu verwenden.

## Vergleichstabelle

| Modell | Aktive Parameter | Generation | `-1`-Stelle | Migrationssprache trotz Verbot | Kosten (in/out pro Mio. Token) |
|---|---|---|---|---|---|
| `qwen3.6-35b-a3b` (konfiguriert) | 3B | Qwen3.6 | konfident falsch | ja | $0,098 / $0,95 |
| `qwen3-235b-a22b` | 22B | Qwen3 (älter) | ausgelassen | nein | ~$0,20 / $0,80 |
| `qwen3.8-max` | unbekannt, Flaggschiff | Qwen3.8 (neuer) | korrekt, präzise | nein | $2 / $6 |

## Einordnung

Der Qualitätssprung kam nicht von reiner Größe (`a22b` war größer als
`a3b`, aber schlechter) — sondern vom Wechsel in eine neuere
Modellgeneration/-klasse. Die sauberste Lesart: Modellklasse/
Trainingsstand insgesamt zählt hier, nicht eine einzelne Achse wie
aktive Parameterzahl oder Quantisierung.

Für das spätere Gesamt-Fazit der Ablationsstudie:

1. **Nicht verkürzen zu "Qwen kann keine Fachlogik erkennen"** — das
   widerlegt bereits der erste Test (4/5 Stellen korrekt, ein
   eigenständiger Fund). Präziser: Fachlogik-*Mustererkennung*
   funktioniert über alle drei Modelle hinweg überraschend gut; was
   sich unterscheidet, ist die Fähigkeit, an der technisch härtesten
   Einzelstelle entweder korrekt zu bleiben oder wenigstens
   Unsicherheit zu signalisieren, statt konfident falschzuliegen.
2. **Echter Kosten-Qualitäts-Zielkonflikt, kein reines Kostenargument.**
   Das aktuell konfigurierte Modell ist mit Abstand am günstigsten,
   aber auch das mit der schwächsten Kalibrierung an der härtesten
   Stelle — und genau dieses Muster (konfident falsch statt unsicher)
   deckt sich mit einem echten, teuren Migrationsfehler derselben
   Session (KNZ-711/fa).
3. **n=1 pro Modell** — kein belastbarer Beweis, aber ein Datenpunkt,
   der der ursprünglichen Nutzer-Intuition ("Qwen kann das
   wahrscheinlich nicht") in der Mustererkennung widerspricht, sie bei
   der Kalibrierung an harten Einzelstellen aber teilweise bestätigt.

## Related

`docs/session13-bestand-711-fixes.md` (Nachtrag Session 14, KNZ-711/fa-
Fehldiagnose) · `docs/ablation-metrics.md` · `AGENTS.md` (Fachnotiz-
Konvention) · `source_references/pd/pd_skripte/PD KNZ INIT.
unplausibler Fallabschluss.md` (Bauherr-Fachnotiz, Vergleichsgrundlage)
