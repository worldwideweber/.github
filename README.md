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

Dazu im Projekt `.github/dependabot.yml` (Vorlage: `vorlagen/dependabot.yml`) für automatische Update-PRs.

## Monitoring für ein neues Projekt einrichten

`bin/monitoring-einrichten.sh` legt im Projekt `.github/dependabot.yml` und `.github/workflows/audit.yml` an
(Vorlagen in `vorlagen/`, PHP-Version aus der `composer.json`) und trägt auf Wunsch die Live-Domain in die
Uptime-Überwachung ([worldwideweber/uptime](https://github.com/worldwideweber/uptime)) ein:

```bash
bin/monitoring-einrichten.sh ~/projects/kunde/kunde --uptime "Kunde GmbH" https://www.kunde.de
```

- Vorhandene Dateien bleiben unverändert, eine schon überwachte URL wird nicht doppelt eingetragen.
- Vor jedem Commit fragt das Skript nach. Das Projekt pushst du selbst, das Uptime-Repo pusht es nach dem „j“.
- Danach von Hand auf GitHub: Dependabot alerts/security updates einschalten, Watch einstellen, Audit einmal starten.

## Benachrichtigungen

Issues, Dependabot-Alerts und Dependabot-PRs erscheinen in den GitHub-Benachrichtigungen. Damit sie auch per Mail
kommen: Repo „Watch“ → mindestens *Issues*, *Pull requests* und *Security alerts*.
