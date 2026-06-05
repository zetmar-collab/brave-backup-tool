# Brave Backup Tool v2.1.1

Narzędzie na **Windows** do kopii zapasowej i przywracania profilu przeglądarki **Brave** — zakładki, hasła, historia, rozszerzenia, sesje kart.

![Windows](https://img.shields.io/badge/platform-Windows-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Pobieranie

**[Pobierz BraveBackup.exe z Releases](https://github.com/zetmar-collab/brave-backup-tool/releases/latest)** — jeden plik, bez instalacji.

Alternatywnie: sklonuj repozytorium i uruchom `Uruchom.bat`.

## Szybki start

1. Pobierz i uruchom `BraveBackup.exe`.
2. Przy pierwszym uruchomieniu przejdź krótki onboarding (folder kopii, zamknięcie Brave).
3. Kliknij **Ustaw folder kopii** i wybierz dysk (np. `E:\Brave_kopia`).
4. Użyj **Utwórz kopię zapasową** (kluczowe dane) lub **Pełna kopia**.
5. Po zakończeniu kopia pojawi się na liście.

**Język:** przycisk **EN** / **PL** w prawym górnym rogu lub **Ustawienia → Język**. Możesz też uruchomić z parametrem: `BraveBackup.exe -Lang en`.

## Pomoc / Help

| Język | Plik |
|-------|------|
| Polski | [docs/POMOC-pl.md](docs/POMOC-pl.md) |
| English | [docs/HELP-en.md](docs/HELP-en.md) |

## Funkcje

| Funkcja | Opis |
|--------|------|
| Pełna kopia | Profil bez cache (mniejszy rozmiar) |
| Kluczowe dane | Zakładki, loginy, cookies, historia, rozszerzenia, sesje |
| Przywracanie | Nadpisanie lub pełne przywrócenie profilu |
| Folder kopii | Dowolna ścieżka, zapisywana w ustawieniach |
| Rotacja | Maks. kopii w ustawieniach (domyślnie 10) |
| Onboarding | Pierwsze uruchomienie — 3 kroki |
| Bezpieczeństwo | Okno z informacją o lokalnych kopiach |
| Przywracanie | Checkbox potwierdzenia + opcjonalna kopia przed restore |
| Języki | Polski i angielski (PL / EN) |
| Wiele profili | Wybór profilu Brave przy kopii i przywracaniu |

## Tryb konsoli

```text
BraveBackup.exe -end -Console
```

lub `Uruchom-Konsola.bat`.

## Budowanie EXE ze źródeł

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Build-Exe.ps1
```

Wynik: `BraveBackup.exe` w katalogu głównym projektu.

## Automatyczny release (GitHub Actions)

Po wypchnięciu tagu `v*` workflow buduje EXE i publikuje go w **Releases**:

```bash
git tag v2.1.1
git push origin v2.1.1
```

Możesz też uruchomić workflow ręcznie: **Actions → Release EXE → Run workflow**.

## Struktura projektu

```text
brave-backup-tool/
  BraveBackup.exe      # build / release
  assets/              # ikona aplikacji
  scripts/
    BraveBackupTool.ps1
    BraveBackup.I18n.ps1
    BraveBackup.Gui.ps1
    Build-Exe.ps1
  docs/
    POMOC-pl.md        # pomoc (PL)
    HELP-en.md         # help (EN)
    NAFFY-OPIS.md      # opis pod listing naffy.io
```

## Bezpieczeństwo

Kopie zawierają **hasła i ciasteczka**. Nie commituj folderu `backups\`. Nie udostępniaj kopii osobom trzecim.

## Licencja

[MIT](LICENSE)
