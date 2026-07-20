#!/bin/bash
# Rebuild + reinstall + restart instalirane aplikacije — ali samo ako je izvorni kod
# noviji od instalirane verzije. Poziva se iz Claude Code Stop hook-a (.claude/settings.json),
# pa se izvršava jednom po završenom turnu, a ne posle svake pojedinačne izmene fajla.
#
# Namerno bez `set -e`: nijedan neuspeh ne sme da obori hook: uvek izlazimo sa 0 i
# prijavljujemo problem kroz systemMessage, jer bi blokiranje turna vrtelo petlju.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 0

INSTALLED=/Applications/WorkHronos.app
BIN="$INSTALLED/Contents/MacOS/WorkHronos"
BUILD_LOG_FILE=/tmp/workhronos-build-error.log

# Emituje validan JSON za Claude Code hook. jq radi escaping; bez njega ide poruka bez detalja.
emit() {
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg m "$1" '{systemMessage: $m}'
    else
        echo '{"systemMessage": "WorkHronos auto-deploy: vidi '"$BUILD_LOG_FILE"'"}'
    fi
}

# Ništa izmenjeno od poslednjeg deploy-a → tiho izlaz (konverzacioni turnovi, izmene docs-a…).
if [ -f "$BIN" ]; then
    CHANGED=$(find Sources Package.swift Package.resolved scripts assets -newer "$BIN" 2>/dev/null | head -1)
    [ -z "$CHANGED" ] && exit 0
fi

if ! BUILD_LOG=$(scripts/make_app.sh 2>&1); then
    printf '%s\n' "$BUILD_LOG" > "$BUILD_LOG_FILE"
    emit "⚠️  Auto-deploy PREKINUT: build pao, instalirana app je i dalje stara verzija.

$(printf '%s' "$BUILD_LOG" | tail -5)

Pun log: $BUILD_LOG_FILE"
    exit 0
fi

if ! ditto dist/WorkHronos.app "$INSTALLED" 2>/tmp/workhronos-ditto-error.log; then
    # Bez restarta — ubiti app i dići staru verziju je gore nego ne dirati je.
    emit "⚠️  Auto-deploy PREKINUT: build prošao ali instalacija u /Applications nije.

$(cat /tmp/workhronos-ditto-error.log)"
    exit 0
fi

pkill -x WorkHronos 2>/dev/null
# Sačekati stvarni izlazak (SQLite flush) umesto fiksnog sleep-a — inače `open` može
# samo reaktivirati proces koji se gasi, umesto da digne novu verziju.
for _ in $(seq 20); do
    pgrep -x WorkHronos >/dev/null 2>&1 || break
    sleep 0.25
done
open "$INSTALLED"   # po putanji, ne `-a WorkHronos` (to može da digne dist/ build)

emit "✅ WorkHronos rebuild-ovan, reinstaliran u /Applications i restartovan."
