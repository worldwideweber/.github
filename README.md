# worldwideweber/.github

Gemeinsame GitHub-Konfiguration der Organisation. **Öffentliches Repo** – enthält keine Zugangsdaten, nur
wiederverwendbare Workflows, die alle (auch private) Projekt-Repos aufrufen können.

## Workflows

### `composer-audit.yml` – Sicherheitsprüfung der Abhängigkeiten

Prüft die `composer.lock` des aufrufenden Repos mit `composer audit` (Packagist- und GitHub-Advisories, inkl.
TYPO3-Core und TER-Extensions).

- Funde → Issue **„Sicherheitslücken in Abhängigkeiten“** mit Label `security` im Projekt-Repo (bzw. Aktualisierung
  des offenen Issues), der Lauf schlägt fehl.
- Keine Funde → ein offenes Issue wird mit Kommentar geschlossen.
- Nicht mehr gepflegte Pakete werden im Issue mit aufgeführt, lösen allein aber kein Issue aus.

Einbinden in einem Projekt (`.github/workflows/audit.yml`):

```yaml
name: Security audit

on:
  schedule:
    - cron: '0 5 * * 1'   # montags 05:00 UTC
  workflow_dispatch:
  push:
    branches: [main]
    paths: [composer.lock]

jobs:
  audit:
    uses: worldwideweber/.github/.github/workflows/composer-audit.yml@main
    with:
      php-version: '8.4'
    permissions:
      contents: read
      issues: write
```

Jede Lauf-Zusammenfassung (Actions → „Security audit“ → Lauf → Summary) listet außerdem die verfügbaren Updates
der direkten Abhängigkeiten.

### `composer-update.yml` – Updates automatisch einspielen

Führt `composer update -W` im Rahmen der Versionsangaben der `composer.json` aus (bei `^14.3` also keine
Major-Updates), prüft das Ergebnis (`composer validate`, `composer audit`, Build ohne Entwicklungspakete), committet
die neue `composer.lock` und startet das Deployment. Die Summary des Laufs zeigt den Weg und welche Pakete von welcher
auf welche Version aktualisiert wurden.

**Für alle Projekte gleich** – der Weg ergibt sich aus `config/deploy/hosts.yaml`:

| Projekt | Weg |
|---|---|
| mit Testseite (`staging` hat `hostname`) | `dev` → `staging`, Testseite deployen → erst wenn das grün ist: Live-Branch, Live deployen |
| ohne Testseite | direkt Live-Branch (`main`), Live deployen |

- **Live** nur mit der Repo-Variable `AUTO_UPDATE_LIVE` = `true` (Settings → Secrets and variables → Actions →
  Variables) und wenn das Ziel `live` einen `hostname` hat. Beim Go-live setzen; bis dahin bleibt `main` unverändert.
- Gibt es keinen `dev`, wird mit Testseite direkt auf `staging` aktualisiert.
- Hat `staging` Commits, die `dev` nicht hat, bricht der Lauf ab (rot), statt etwas zu überschreiben.
- **Lokal:** Der Bot committet wie ein Kollege. Vor dem Weiterarbeiten `git pull` und `ddev composer install`.
  Vergessen ist nicht schlimm: GitHub lehnt den Push dann ab („non-fast-forward“), Pull nachholen.

Dependabot ist für Composer nicht geeignet: Es aktualisiert die TYPO3-Core-Pakete einzeln, Composer lehnt das ab, weil
alle `typo3/cms-*` dieselbe Version brauchen – und der Dependabot-Lauf ist trotzdem grün („No PRs affected“).
Dependabot (`vorlagen/dependabot.yml`) bleibt nur für die GitHub Actions zuständig.

Einbinden in einem Projekt (`.github/workflows/update.yml`, Vorlage: `vorlagen/workflows/update.yml`):

```yaml
name: Composer update

on:
  schedule:
    - cron: '30 3 * * *'   # täglich 03:30 UTC
  workflow_dispatch:

jobs:
  update:
    uses: worldwideweber/.github/.github/workflows/composer-update.yml@main
    with:
      php-version: '8.4'
      live: ${{ vars.AUTO_UPDATE_LIVE == 'true' }}
    permissions:
      contents: write
      actions: write
```

Voraussetzungen: Der Deploy-Workflow (Standard `deploy.yml`, Input `deploy-workflow`) muss `workflow_dispatch` haben,
`dev`, `staging` und `main` dürfen nicht gegen direkte Pushes geschützt sein. Standard-Branch des Repos = der Branch,
auf dem gearbeitet wird (mit Testseite `dev`), damit der Audit diesen Stand prüft.

## Monitoring für ein neues Projekt einrichten

`bin/monitoring-einrichten.sh` legt im Projekt `.github/dependabot.yml`, `.github/workflows/audit.yml` und
`.github/workflows/update.yml` an
(Vorlagen in `vorlagen/`, PHP-Version aus der `composer.json`) und trägt auf Wunsch die Live-Domain in die
Uptime-Überwachung ([worldwideweber/uptime](https://github.com/worldwideweber/uptime)) ein:

```bash
bin/monitoring-einrichten.sh ~/projects/kunde/kunde --uptime "Kunde GmbH" https://www.kunde.de
```

- Vorhandene Dateien bleiben unverändert, eine schon überwachte URL wird nicht doppelt eingetragen.
- Vor jedem Commit fragt das Skript nach. Das Projekt pushst du selbst, das Uptime-Repo pusht es nach dem „j“.
- Danach von Hand auf GitHub: Dependabot alerts einschalten, Watch einstellen, Audit und Update einmal starten.
- Eine vorhandene `dependabot.yml` mit Composer-Eintrag wird durch die Vorlage ersetzt (für TYPO3 funktioniert
  Composer dort nicht); andere bleiben unverändert.

## Benachrichtigungen

Issues, Dependabot-Alerts, Dependabot-PRs und fehlgeschlagene Läufe erscheinen in den GitHub-Benachrichtigungen. Damit sie auch per Mail
kommen: Repo „Watch“ → mindestens *Issues*, *Pull requests* und *Security alerts*.
