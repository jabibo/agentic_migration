---
description: Fachlicher Systemkontext für die LLM-gestützte Migration nach Exasol – beschreibt das Gesamtsystem (generisch) und BPS/PD als konkrete Ausprägung. Wird von skills/greenfield/greenfield-migration.md und anderen Migrations-Prompts referenziert.
status: lebendes Dokument
---

# Systemkontext: Migration heterogener ETL-/SQL-Landschaft nach Exasol

Dieses Dokument liefert den **fachlichen Rahmen**, den ein Migrations-Prompt als
gegeben voraussetzt (Operations-Prompt: `skills/greenfield/greenfield-migration.md`).
Es ist zweigeteilt:

- **Teil A – Das System als Ganzes** beschreibt das *generische*
  Verarbeitungsmuster, das für mehrere Systeme/Verarbeitungen ähnlich gilt.
- **Teil B – BPS (PD)** beschreibt die *konkrete* Ausprägung, die als
  Referenz-/Pilotumsetzung migriert wird.

Begriffe aus Teil A (Schichten/Rollen) werden in Teil B auf die realen
Datenbanken und Skripte abgebildet.

---

## Teil A — Das System als Ganzes (generisch)

### A.1 Ziel und Ansatz

Eine heterogene Landschaft aus SQL-Skripten, ODI-Strecken und ähnlichen
ETL-Artefakten wird nach **Exasol** migriert. Die Migration erfolgt
**überwiegend LLM-gestützt**, das Ergebnis ist eine **1:1-Migration**:
semantisch äquivalent – gleiche Ergebnismenge, gleiche Typen, gleiche
NULL-, Sortier- und Rundungssemantik. Es wird nichts neu modelliert und
keine fachliche Logik erfunden.

### A.2 Generisches Verarbeitungsmuster (monatlicher Lauf)

Die Verarbeitungen folgen einem wiederkehrenden Schichtenmodell. Jede Schicht
hat eine feste Rolle; die konkreten Datenbanknamen unterscheiden sich je System.

| Schicht | Rolle | Speisung |
|---|---|---|
| **DATA** | geladene Daten des **aktuellen Monats** | externer Load (z. B. CSV) |
| **DWH** | **Gesamtbestand** der geladenen Daten | aus DATA |
| **CALC** | **Temp-/Zwischenschritte** der Kennzahlenberechnung | DWH und **iterativ aus sich selbst** |
| **FACT** | **finale Kennzahlen / Fakten** | DWH und CALC |
| **KNZ** | **nur Views** auf FACT und Dimensionen (Auslieferungsschicht) | FACT, DIM |
| **DIM** | **Dimensionstabellen** | als gegeben angesehen |
| **STRG** | **Logging und Ablaufsteuerung** | – |

### A.3 Generischer Ablauf (INKA MONAT 1)

1. **Load aktuell:** Die aktuellen Monatsdaten werden nach DATA geladen.
2. **Aufbau Gesamtbestand:** Die Daten werden in DWH zum Gesamtbestand
   zusammengeführt.
3. **Kennzahlen:** Berechnungsskripte erzeugen Zwischenergebnisse in CALC und
   finale Fakten in FACT.
4. **Auslieferung:** In KNZ werden Views auf FACT und DIM erzeugt.

Querverweise zwischen Schichten/Datenbanken (Kreuz-DB-Referenzen) behalten
ihren ursprünglichen Schema-Namen.

---

## Teil B — BPS (PD) als konkrete Ausprägung

BPS (intern auch **PD**) ist die Referenz-/Pilotumsetzung. Die hier migrierten
Artefakte sind **Microsoft-SQL-Server-Skripte (T-SQL)**; Zielplattform ist
**Exasol**.

### B.1 Datenbanken (Abbildung auf die generischen Schichten)

| Datenbank | Schicht (Teil A) | Inhalt |
|---|---|---|
| `con_pd_data` | DATA | geladene Monatsdaten des aktuellen Monats (CSV-Load) |
| `con_pd_dwh_vm` | *(BPS-spezifisch: Vormonats-Sicherung)* | alle Monatsdaten bis einschließlich Vormonat |
| `con_pd_dwh` | DWH | Gesamtbestand = `con_pd_data` + `con_pd_dwh_vm` |
| `con_pd_calc` | CALC | Temp-Datenbank für Zwischenschritte der Kennzahlen |
| `con_pd_fact` | FACT | finale Kennzahlenberechnung |
| `con_pd_knz` | KNZ | nur Views auf `con_pd_fact` und `con_bio_dim` |
| `con_bio_dim` | DIM | Dimensionstabellen (für BPS als gegeben angesehen) |
| `con_strg` | STRG | Logging und Ablaufsteuerung |

### B.2 Verarbeitung Verfahrensspezifisch

1. Der vor Beginn vorhandene Bestand wird nach `con_pd_dwh_vm` gesichert und
   gilt als Vormonatsdaten.
2. Die aktuellen Monatsdaten werden als **CSV** nach `con_pd_data` geladen.
3. `con_pd_data` + `con_pd_dwh_vm` werden in `con_pd_dwh` zum Gesamtbestand
   zusammengeführt (am Monatsanfang voll neu aufgebaut).
4. Die Kennzahlen-Skripte laufen und erzeugen Daten **sowohl in
   `con_pd_calc`** (Zwischenschritte, teils iterativ) **als auch in
   `con_pd_fact`** (finale Fakten).
5. In `con_pd_knz` werden abschließend Views auf Kennzahlen (`con_pd_fact`)
   und Dimensionen (`con_bio_dim`) erzeugt.

Gesteuert und protokolliert wird der Lauf über `con_strg`.

### B.3 Besonderheiten / verbindliche Annahmen

- **Voll-Merge:** `con_pd_dwh` wird am Monatsanfang vollständig neu aus
  `con_pd_data` + `con_pd_dwh_vm` aufgebaut, nicht inkrementell fortgeschrieben.
- **Iterative Zwischenschritte:** `con_pd_calc` speist sich teilweise selbst (azyklisch auf Tabellenebene)

- **Dimensionen gegeben:** `con_bio_dim` wird nicht migriert, sondern als
  vorhanden vorausgesetzt.
- **Kreuz-DB-Referenzen** (z. B. aus `con_pd_knz` auf `con_pd_fact` /
  `con_bio_dim`) behalten ihren Schema-/Datenbanknamen.

### B.4 Festlegung: Quelldatenbanken → Monats-Schemata [Chat-Entscheidung]

Jede ursprünglich getrennte SQL-Server-Datenbank wird auf ein eigenes,
**monats-suffigiertes** Exasol-Schema abgebildet (Schema-je-Verarbeitungsmonat-
Modell, siehe `skills/schema/monatsschema-konvention.md`):

```
sqlserver__bps__dbo__<db-name>_<verarbeitungsmonat>
z. B.  sqlserver__bps__dbo__con_pd_fact_202607
```

Physische Objekte tragen darin ihre **echten Original-Namen** (kein
Tabellenpräfix) — die Unterscheidung übernimmt das Schema selbst.
Kreuz-DB-Referenzen (`db.dbo.tabelle`) werden dadurch zu
`<schema-name>_<verarbeitungsmonat>.tabelle`.

Die DB-Namen sind in den Quellskripten als **Platzhalter** eingebettet und lassen
sich automatisch extrahieren (kein manuelles Pflegen je Verfahren nötig):

```
/*<DBNAME_PD_FACT>*/con_pd_fact/*<DBNAME_PD_FACT>*/
```

Extraktion aller Platzhalter → DB-Namen aus einem Verfahren:
```bash
rg --no-filename --only-matching --pcre2 \
  '/\*<(DBNAME_[^>]+)>\*/([^/]+)/\*<\1>\*/' \
  source_references/pd/pd_skripte/ -r '$1 → $2' | sort -u
```

Für BPS/PD ergibt sich folgendes Mapping (Platzhalter → generischer DB-Name → Monats-Schema):

| Platzhalter | DB-Name | Schicht | Monats-Schema |
|---|---|---|---|
| `DBNAME_PD_DATA` | `con_pd_data` * | DATA | `sqlserver__bps__dbo__con_pd_data_<monat>` |
| `DBNAME_PD_DWH_Vormonat` | `con_pd_dwh_vm` | DWH-Vormonat | löst auf das bereits bestehende `con_pd_dwh`-Schema des Vormonats auf — kein eigenes `dwh_vm`-Schema |
| `DBNAME_PD_DWH` | `con_pd_dwh` | DWH | `sqlserver__bps__dbo__con_pd_dwh_<monat>` |
| `DBNAME_PD_CALC` | `con_pd_calc` | CALC | `sqlserver__bps__dbo__con_pd_calc_<monat>` |
| `DBNAME_PD_FACT` | `con_pd_fact` | FACT | `sqlserver__bps__dbo__con_pd_fact_<monat>` |
| `DBNAME_PD_KNZ` | `con_pd_knz` | KNZ | `sqlserver__bps__dbo__con_pd_knz_<monat>` |
| `DBNAME_CON_DIM` | `con_bio_dim` | DIM | `sqlserver__bps__dbo__con_bio_dim_<monat>` |
| `DBNAME_CON_STRG` | `con_strg` | STRG | `sqlserver__bps__dbo__con_strg_<monat>` |

\* In den Skripten teils als Monats-Snapshot ausgeprägt (z. B. `con_data_201108`);
für die Migration gilt der generische Name `con_pd_data`. In einigen
Skripten sind Platzhalter mit dem Dummy-Wert `x` befüllt — maßgeblich ist der hier
festgelegte Name, nicht der Dummy.

Details/Umsetzungsstand: `skills/schema/monatsschema-konvention.md` (Prinzip
und BPS/PD-Instanz, in einem Dokument).

### B.5 Kennzahlen: Umsetzungsstand

Von den Kennzahl-Skripten in `source_references/pd/pd_skripte/` sind **8 von 9**
als dbt-Facts umgesetzt: **701, 702, 703, 705, 706, 708, 709, 711**.

- **KNZ 721 ist bewusst ausgeschlossen**: `PD KNZ 721.KNZ 721.sql` enthält
  keine aktive Logik (vollständig auskommentiert). Das ist kein
  Migrations-Rückstand, sondern eine fachliche Feststellung — das Skript war
  im Referenzsystem bereits stillgelegt.
- **KNZ 711** ist nur für den Zweig **„nach P51"** umgesetzt (aktueller
  Regelfall); der historische Zweig „vor P51" wird nicht migriert.

### B.6 Bekannte Lücken / POC-Ersatzlösungen

- **`con_pd_knz.vd_pd_dienststelle`** (Brücke `ba_schl → org_id`) liegt nicht
  in einem für die Migration verwertbaren Format vor. POC-Ersatz: externe
  Ladetabelle `vd_as_pd_dienststelle`
  (`source_references/pd/dimensions/dbo__vd_as_pd_dienststelle.csv`, per
  `scripts/load_dimensions_monatsschema.sh` geladen wie jede andere
  Dimension) mit derselben Abbildung.
- **`uf_pd_Behinderung_Key()`** (Behinderungscode → Bitmaske) wird durch das
  dbt-Makro `behinderung_bit()` (`dbt/macros/pd_helpers.sql`) 1:1 nachgebildet.
- **Kalendertabelle** (`td_ueb_kalender_Tag` o. Ä.) liegt nicht vor;
  Kalenderarithmetik (Monatsverschiebung) erfolgt stattdessen per
  Datumsfunktion (`month_add()`-Makro) statt per Tabellen-Join.
