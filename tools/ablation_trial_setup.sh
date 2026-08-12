#!/usr/bin/env bash
# Bereitet einen isolierten git-worktree fuer einen Setup-A/B-Ablationsversuch
# vor (docs/setup-a-b-vergleich.md). Bewusst generisch: kein Objektname im
# Code, Zielmodell(e) werden als Argumente uebergeben.
#
# Usage:
#   tools/ablation_trial_setup.sh <trial-name> <a|b> <model-file> [<model-file> ...]
#
# Beispiel:
#   tools/ablation_trial_setup.sh knz703-a a dbt/models/fact/tf_pd_knz_703.sql
#   tools/ablation_trial_setup.sh knz709-b b dbt/models/fact/tf_pd_knz_709.sql \
#       dbt/models/calc/tt_pd_knz_709.sql
#
# Was passiert:
#   1. git worktree add in ../ablation-trials/<trial-name>, Basis main
#      (main ist bereits vollstaendig gate-verifiziert -- geteilte Infra
#      wie Makros/andere Objekte bleibt konstant, nur das Zielmodell wird
#      isoliert).
#   2. Zielmodell(e) im Trial-Worktree geloescht -- Qwen muss sie aus dem
#      Quell-DDL neu herleiten, nicht nur die bestehende main-Loesung lesen.
#   3. Bei Setup a/b: memory/rules/*.md im Trial-Worktree lokal geleert
#      (nicht committet, nur Arbeitskopie) -- verhindert, dass das
#      unrestriktierte read-Tool (nur "edit"-Permission wird von opencode
#      gegated) trotzdem akkumuliertes Regelgedaechtnis liest. Setup c
#      braucht das nicht (main-Zustand ist bereits Setup c).
#   4. Trial-Worktree bleibt uncommitted/unmerged -- nach Auswertung mit
#      `git worktree remove --force ../ablation-trials/<trial-name>`
#      wegwerfen, NIE nach main mergen (Vergleichsdaten, keine Migration).
#
# Nicht Teil dieses Skripts (bewusst manuell, gleiche Disziplin wie jeder
# reale Objektversuch): der eigentliche `opencode run --agent migrator_a|
# migrator_b`-Aufruf und die unabhaengige Bauherr-Verifikation danach.
set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <trial-name> <a|b> <model-file> [<model-file> ...]" >&2
    exit 1
fi

TRIAL_NAME="$1"; shift
SETUP="$1"; shift
MODEL_FILES=("$@")

if [ "$SETUP" != "a" ] && [ "$SETUP" != "b" ]; then
    echo "Zweites Argument muss 'a' oder 'b' sein, nicht '$SETUP'." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
TRIAL_DIR="$REPO_ROOT/../ablation-trials/$TRIAL_NAME"

if [ -e "$TRIAL_DIR" ]; then
    echo "Existiert bereits: $TRIAL_DIR -- vorher aufraeumen (git worktree remove --force)." >&2
    exit 1
fi

cd "$REPO_ROOT"
# --detach: main ist im Hauptworktree bereits ausgecheckt, ein zweiter
# Worktree kann denselben Branch nicht erneut auschecken. Detached HEAD auf
# mains aktuellem Commit ist fuer einen Wegwerf-Trial ausreichend -- es wird
# ohnehin nie zurueckgemergt (s. Docstring oben).
git worktree add --detach "$TRIAL_DIR" main
cd "$TRIAL_DIR"

for f in "${MODEL_FILES[@]}"; do
    if [ ! -e "$f" ]; then
        echo "WARNUNG: $f existiert nicht in main, ueberspringe." >&2
        continue
    fi
    rm -f "$f"
    echo "entfernt: $f"
done

if [ "$SETUP" = "a" ] || [ "$SETUP" = "b" ]; then
    if [ -d "memory/rules" ]; then
        find memory/rules -maxdepth 1 -name '*.md' -delete
        echo "memory/rules/*.md lokal geleert (nur Arbeitskopie dieses Worktrees)"
    fi
fi

echo ""
echo "Trial-Worktree bereit: $TRIAL_DIR"
echo "Naechster Schritt (manuell, gleiche Disziplin wie jeder reale Objektversuch):"
echo "  cd $TRIAL_DIR"
echo "  opencode run --agent migrator_$SETUP \"<Aufgabentext, s. docs/setup-a-b-vergleich.md>\""
echo ""
echo "Aufraeumen nach Auswertung:"
echo "  git worktree remove --force $TRIAL_DIR"
