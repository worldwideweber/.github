#!/usr/bin/env bash
# Richtet das Monitoring für ein Projekt ein:
#   1. Dependabot + wöchentlicher composer audit (.github/dependabot.yml, .github/workflows/audit.yml)
#   2. optional: Eintrag der Live-Domain in die Uptime-Überwachung (Repo worldwideweber/uptime)
#
# Aufruf:
#   monitoring-einrichten.sh <projektordner> [--uptime "<Name>" <https://domain>] [--php 8.4]
#
# Beispiele:
#   monitoring-einrichten.sh ~/projects/kunde/kunde
#   monitoring-einrichten.sh ~/projects/kunde/kunde --uptime "Kunde GmbH" https://www.kunde.de
#
# Das Skript ändert nur Dateien. Commit und Push fragt es jeweils nach – ohne "j" passiert nichts.

set -euo pipefail

SKRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VORLAGEN="$SKRIPT_DIR/../vorlagen"
UPTIME_REPO_URL="https://github.com/worldwideweber/uptime.git"
UPTIME_PUSH_URL="git@github.com:worldwideweber/uptime.git"
UPTIME_DIR="${UPTIME_DIR:-$HOME/.cache/worldwideweber-uptime}"

fehler() { echo "Fehler: $*" >&2; exit 1; }
frage() { local a; read -r -p "$1 [j/N] " a; [[ "$a" == "j" || "$a" == "J" ]]; }

[[ $# -ge 1 ]] || { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

PROJEKT="$(cd "$1" && pwd)" || fehler "Ordner $1 gibt es nicht"
shift
PHP=""
UPTIME_NAME=""
UPTIME_URL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --php) PHP="${2:?--php braucht eine Version}"; shift 2 ;;
        --uptime) UPTIME_NAME="${2:?--uptime braucht Name und URL}"; UPTIME_URL="${3:?--uptime braucht Name und URL}"; shift 3 ;;
        *) fehler "unbekannte Option $1" ;;
    esac
done

git -C "$PROJEKT" rev-parse --show-toplevel >/dev/null 2>&1 || fehler "$PROJEKT ist kein Git-Repo"
[[ -f "$PROJEKT/composer.lock" ]] || fehler "$PROJEKT hat keine composer.lock"

# PHP-Version aus composer.json (config.platform.php, sonst require.php), sonst 8.4
if [[ -z "$PHP" ]]; then
    PHP="$(python3 -I -c '
import json, re, sys
c = json.load(open(sys.argv[1]))
v = c.get("config", {}).get("platform", {}).get("php") or c.get("require", {}).get("php", "")
m = re.search(r"(\d+)\.(\d+)", v)
print(f"{m.group(1)}.{m.group(2)}" if m else "8.4")
' "$PROJEKT/composer.json")"
fi

echo "== 1. Dependabot + Audit in $PROJEKT (PHP $PHP)"
mkdir -p "$PROJEKT/.github/workflows"
GEAENDERT=()
if [[ -e "$PROJEKT/.github/dependabot.yml" ]]; then
    echo "   .github/dependabot.yml gibt es schon – bleibt unverändert"
else
    cp "$VORLAGEN/dependabot.yml" "$PROJEKT/.github/dependabot.yml"
    GEAENDERT+=(.github/dependabot.yml)
    echo "   .github/dependabot.yml angelegt"
fi
if [[ -e "$PROJEKT/.github/workflows/audit.yml" ]]; then
    echo "   .github/workflows/audit.yml gibt es schon – bleibt unverändert"
else
    sed "s/__PHP__/$PHP/" "$VORLAGEN/workflows/audit.yml" > "$PROJEKT/.github/workflows/audit.yml"
    GEAENDERT+=(.github/workflows/audit.yml)
    echo "   .github/workflows/audit.yml angelegt"
fi

if [[ ${#GEAENDERT[@]} -gt 0 ]]; then
    BRANCH="$(git -C "$PROJEKT" branch --show-current)"
    echo "   Aktueller Branch im Projekt: $BRANCH"
    if frage "   Diese Dateien im Projekt committen?"; then
        git -C "$PROJEKT" add "${GEAENDERT[@]}"
        git -C "$PROJEKT" commit -m "Add Dependabot and weekly security audit"
        echo "   Committet. Pushen musst du selbst: git -C \"$PROJEKT\" push"
    else
        echo "   Nicht committet."
    fi
fi

if [[ -n "$UPTIME_URL" ]]; then
    echo "== 2. Uptime-Eintrag: $UPTIME_NAME – $UPTIME_URL"
    [[ "$UPTIME_URL" =~ ^https?:// ]] || fehler "URL muss mit https:// beginnen"
    if [[ -d "$UPTIME_DIR/.git" ]]; then
        git -C "$UPTIME_DIR" pull -q --ff-only
    else
        git clone -q "$UPTIME_REPO_URL" "$UPTIME_DIR"
        git -C "$UPTIME_DIR" remote set-url --push origin "$UPTIME_PUSH_URL"
    fi
    python3 -I - "$UPTIME_DIR/.upptimerc.yml" "$UPTIME_NAME" "$UPTIME_URL" <<'PY'
import sys
pfad, name, url = sys.argv[1:4]
zeilen = open(pfad, encoding="utf-8").read().split("\n")
norm = lambda u: u.rstrip("/").lower()
if any(z.strip().startswith("url:") and norm(z.split("url:", 1)[1].strip()) == norm(url) for z in zeilen):
    print("   Diese URL wird schon überwacht – nichts geändert")
    sys.exit(0)
start = next(i for i, z in enumerate(zeilen) if z.startswith("sites:"))
ende = next(i for i in range(start + 1, len(zeilen)) if zeilen[i] and not zeilen[i].startswith((" ", "#")))
# vor Leerzeilen/Kommentaren einfügen, die schon zum nächsten Block gehören
while zeilen[ende - 1].strip() == "" or zeilen[ende - 1].startswith("#"):
    ende -= 1
zeilen[ende:ende] = [f"  - name: {name}", f"    url: {url}", "    maxResponseTime: 5000"]
open(pfad, "w", encoding="utf-8").write("\n".join(zeilen))
print("   Eintrag ergänzt")
PY
    if ! git -C "$UPTIME_DIR" diff --quiet; then
        git -C "$UPTIME_DIR" --no-pager diff
        if frage "   Im Uptime-Repo committen und pushen?"; then
            git -C "$UPTIME_DIR" commit -qam "Monitor $UPTIME_NAME"
            git -C "$UPTIME_DIR" push -q
            echo "   Gepusht. Status-Seite: https://worldwideweber.github.io/uptime/"
        else
            git -C "$UPTIME_DIR" checkout -q .upptimerc.yml
            echo "   Verworfen."
        fi
    fi
fi

cat <<EOF

== Noch von Hand (einmal pro Repo, auf GitHub):
   - Settings → Code security → "Dependabot alerts" und "Dependabot security updates" einschalten
   - Watch → Custom → Issues, Pull requests, Security alerts (damit Funde per Mail kommen)
   - Actions → "Security audit" → Run workflow (einmal testen)
EOF
