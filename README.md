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

Dazu im Projekt `.github/dependabot.yml` (Vorlage: `www-typo3-fzn`) für automatische Update-PRs.

## Benachrichtigungen

Issues, Dependabot-Alerts und Dependabot-PRs erscheinen in den GitHub-Benachrichtigungen. Damit sie auch per Mail
kommen: Repo „Watch“ → mindestens *Issues*, *Pull requests* und *Security alerts*.
