#!/usr/bin/env bash
# Misst den Ressourcenverbrauch des laufenden Pegli: durchschnittliche CPU (aus der verbrauchten
# CPU-Zeit, nicht aus Momentwerten), Speicher-Footprint (wie in der Aktivitätsanzeige) und Energie.
# Aufruf: scripts/measure.sh [sekunden]   (Standard 300; Panel währenddessen geschlossen lassen)
set -euo pipefail

DURATION="${1:-300}"
PID="$(pgrep -x Pegli)" || { echo "Pegli läuft nicht." >&2; exit 1; }

cpu_seconds() { ps -o time= -p "$PID" | awk -F'[:.]' '{ print $1 * 60 + $2 + $3 / 100 }'; }

echo "Messe Pegli (PID $PID) für $DURATION s …"
start_cpu="$(cpu_seconds)"
start_time="$(date +%s)"
samples=$((DURATION / 5 + 1))
# top liefert den Energiewert (POWER, wie „Energiebedarf“ in der Aktivitätsanzeige) je 5-s-Fenster; erste Zeile ist ohne Basis
energy="$(top -l "$samples" -s 5 -pid "$PID" -stats pid,power 2>/dev/null \
  | awk -v pid="$PID" '$1 == pid { if (seen++) { power += $2; n++ } }
      END { if (n) printf "%.2f", power / n }')"
end_cpu="$(cpu_seconds)"
elapsed=$(($(date +%s) - start_time))

awk -v a="$start_cpu" -v b="$end_cpu" -v t="$elapsed" \
  'BEGIN { printf "CPU (Durchschnitt):    %.2f %% eines Kerns\n", (b - a) / t * 100 }'
echo "Speicher (Footprint):  $(footprint -p "$PID" | awk '{ for (i = 1; i < NF; i++) if ($i == "Footprint:") print $(i + 1), $(i + 2) }')"
echo "Energiebedarf:         $energy"
