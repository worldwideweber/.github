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
die neue `composer.lock` direkt auf `main` und startet danach den Deploy-Workflow. Die Summary des Laufs zeigt, welche
Pakete von welcher auf welche Version aktualisiert wurden.

Dependabot ist dafür nicht geeignet: Es aktualisiert die TYPO3-Core-Pakete einzeln, Composer lehnt das ab, weil alle
`typo3/cms-*` dieselbe Version brauchen – und der Dependabot-Lauf ist trotzdem grün („No PRs affected“).

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
    permissions:
      contents: write
      actions: write
```

Voraussetzungen: Der Deploy-Workflow (Standard `deploy.yml`, Input `deploy-workflow`) muss `workflow_dispatch`
haben, und `main` darf nicht gegen direkte Pushes geschützt sein. Mit `deploy-workflow: ''` wird nur committet.

Dependabot (`vorlagen/dependabot.yml`) bleibt nur für die GitHub Actions zuständig.

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
- Bei schon eingerichteten Projekten bleibt eine vorhandene `dependabot.yml` unverändert – den Composer-Eintrag dort
  von Hand entfernen (Vorlage übernehmen).

## Benachrichtigungen

Issues, Dependabot-Alerts, Dependabot-PRs und fehlgeschlagene Läufe erscheinen in den GitHub-Benachrichtigungen. Damit sie auch per Mail
kommen: Repo „Watch“ → mindestens *Issues*, *Pull requests* und *Security alerts*.
