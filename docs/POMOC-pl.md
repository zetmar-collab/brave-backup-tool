# Brave Backup Tool — pomoc (PL)

Wersja **2.1** | [English help](HELP-en.md)

## Co robi program?

Tworzy **lokalne** kopie zapasowe profilu przeglądarki **Brave** (zakładki, hasła, historia, rozszerzenia, sesje). Dane **nie są wysyłane do internetu**.

## Szybki start

1. Pobierz `BraveBackup.exe` z [Releases](https://github.com/zetmar-collab/brave-backup-tool/releases/latest).
2. Uruchom plik (bez instalacji).
3. Przy pierwszym starcie przejdź **onboarding** (3 kroki).
4. Kliknij **Ustaw folder kopii** i wybierz dysk (np. dysk zewnętrzny).
5. Zamknij Brave — program zapyta i zamknie procesy.
6. Kliknij **Utwórz kopię zapasową** (zalecane: kluczowe dane) lub **Pełna kopia**.

## Przyciski główne

| Przycisk | Działanie |
|----------|-----------|
| **Utwórz kopię zapasową** | Kopia kluczowych danych (mniejsza, na co dzień) |
| **Kluczowe dane** | To samo — zakładki, loginy, cookies, historia, rozszerzenia |
| **Pełna kopia** | Prawie cały profil bez cache (większa; przed formatowaniem PC) |
| **Przywróć** | Przywraca wybraną kopię z listy |
| **Usuń** | Usuwa wybraną kopię (z potwierdzeniem i nazwą folderu) |
| **Odśwież** | Odświeża listę kopii |
| **Ustaw folder kopii** | Zmienia miejsce zapisu kopii |

## Pasek statusu

- **Brave** — czy przeglądarka jest uruchomiona
- **Folder kopii** — czy folder jest ustawiony i gdzie leży
- **Ostatnia kopia** — data ostatniej kopii na liście
- **Kopie: X/Y** — liczba kopii i limit rotacji

## Ustawienia

Otwórz **Ustawienia** (prawy górny róg):

- **Maksymalna liczba kopii** — wybierz **5, 10, 15 lub 20** (najstarsze są usuwane automatycznie)
- **Język** — Polski (PL) lub English (EN)
- **Sprawdź aktualizacje** — otwiera stronę Releases na GitHub

Przełącznik **EN / PL** w nagłówku okna zmienia język od razu.

## Przywracanie

1. Zaznacz kopię na liście.
2. Kliknij **Przywróć**.
3. Zaznacz, że rozumiesz nadpisanie profilu.
4. Opcjonalnie: **kopia zapasowa przed przywróceniem** (zalecane).
5. Wybierz tryb:
   - **Nadpisz tylko pliki z kopii** — bezpieczniejsze
   - **Wyczyść profil i przywróć** — pełne przywrócenie

Po zakończeniu uruchom Brave ręcznie.

## Bezpieczeństwo

- Kopie są **tylko na Twoim dysku**.
- Zawierają **hasła i ciasteczka** — nie udostępniaj folderu innym.
- Program zamyka Brave, aby skopiować zablokowane pliki.
- Kod źródłowy: MIT na GitHub.

## Tryb konsoli

```text
BraveBackup.exe -end -Console
```

Menu: pełna kopia, kluczowe dane, przywróć, usuń, wyjście.

## Parametry uruchomienia

| Parametr | Opis |
|----------|------|
| `-Lang pl` | Interfejs po polsku |
| `-Lang en` | Interfejs po angielsku |
| `-Console` | Tryb tekstowy (wymaga `-end` w EXE) |

Przykład:

```text
BraveBackup.exe -end -Lang en
```

## Pliki i foldery

| Element | Opis |
|---------|------|
| `backups\` | Domyślny folder kopii (obok programu) |
| `backup-settings.json` | Folder kopii, język, limit kopii, onboarding |
| `YYYY-MM-DD_HH-mm-ss_wybrane` | Kopia kluczowych danych |
| `YYYY-MM-DD_HH-mm-ss_pelna` | Pełna kopia |

## Rozwiązywanie problemów

**Okno nie odpowiada podczas kopii** — to normalne przy dużym profilu; poczekaj na komunikat w logu.

**Brave się nie zamyka** — zamknij ręcznie wszystkie okna Brave i spróbuj ponownie.

**Brak danych Brave** — upewnij się, że Brave był kiedyś uruchomiony na tym PC (`%LOCALAPPDATA%\BraveSoftware\...`).

**Błąd przy starcie EXE** — pobierz najnowszy build z Releases.

## Kontakt i kod źródłowy

https://github.com/zetmar-collab/brave-backup-tool
