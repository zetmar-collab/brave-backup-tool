# Brave Backup Tool v2

Narzędzie na **Windows** do kopii zapasowej i przywracania profilu przeglądarki **Brave** — zakładki, hasła, historia, rozszerzenia, sesje kart.

![Windows](https://img.shields.io/badge/platform-Windows-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Pobieranie

**[Pobierz BraveBackup.exe z Releases](https://github.com/zetmar-collab/brave-backup-tool/releases/latest)** — jeden plik, bez instalacji.

Alternatywnie: sklonuj repozytorium i uruchom `Uruchom.bat`.

## Szybki start

1. Pobierz i uruchom `BraveBackup.exe`.
2. Kliknij **Ustaw folder kopii** i wybierz dysk (np. `E:\Brave_kopia`).
3. Zamknij Brave (program zapyta i zamknie procesy).
4. Wybierz **Pełna kopia** lub **Kluczowe dane**.
5. Po zakończeniu kopia pojawi się na liście.

## Funkcje

| Funkcja | Opis |
|--------|------|
| Pełna kopia | Profil bez cache (mniejszy rozmiar) |
| Kluczowe dane | Zakładki, loginy, cookies, historia, rozszerzenia, sesje |
| Przywracanie | Nadpisanie lub pełne przywrócenie profilu |
| Folder kopii | Dowolna ścieżka, zapisywana w ustawieniach |
| Rotacja | Maks. 10 kopii, najstarsze usuwane automatycznie |

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

## Struktura projektu

```text
brave-backup-tool/
  BraveBackup.exe      # build / release
  assets/              # ikona aplikacji
  scripts/
    BraveBackupTool.ps1
    Build-Exe.ps1
  docs/
    NAFFY-OPIS.md      # opis pod listing naffy.io
```

## Bezpieczeństwo

Kopie zawierają **hasła i ciasteczka**. Nie commituj folderu `backups\`. Nie udostępniaj kopii osobom trzecim.

## Licencja

[MIT](LICENSE)
