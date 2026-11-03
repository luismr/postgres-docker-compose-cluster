# Klaster PostgreSQL 17 z repliką odczytu

**Języki:** [English](README.md) | [Polski](README_PL.md)

![Docker](https://img.shields.io/badge/Docker-27.2.0-orange)
![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v1.29.2--desktop.2-orange)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-green)

## Przegląd

Ta konfiguracja Docker Compose tworzy klaster PostgreSQL 17 z instancją primary (odczyt/zapis) oraz repliką odczytu, zapewniając wysoką dostępność i skalowanie odczytu dla potrzeb Twojej bazy danych.

![Docker-compose Stack](docs/docker-compose-stack.png)

## Funkcje

### Najważniejsze funkcje PostgreSQL 17

PostgreSQL 17 wprowadza kilka istotnych usprawnień:

- **Ulepszona replikacja logiczna**: lepsza wydajność i niezawodność replikacji logicznej
- **Lepsza wydajność zapytań**: zoptymalizowane planowanie i wykonywanie zapytań
- **Ulepszone partycjonowanie**: rozszerzone możliwości partycjonowania tabel
- **Ulepszenia bezpieczeństwa**: nowe funkcje i usprawnienia w zakresie bezpieczeństwa
- **Ulepszenia monitorowania**: lepsze narzędzia do monitorowania i obserwacji
- **Optymalizacje wydajności**: różne usprawnienia wydajności w całym systemie

## ⚠️ Ważne zastrzeżenie

**To jest konfiguracja typu Proof of Concept (PoC) i NIE powinna być używana w środowiskach produkcyjnych.**

Ta konfiguracja jest przeznaczona do:
- celów edukacyjnych
- środowisk deweloperskich
- testowania koncepcji replikacji
- zrozumienia podstaw replikacji w PostgreSQL

**Kwestie produkcyjne:**
- Ta konfiguracja nie zawiera odpowiedniego utwardzenia bezpieczeństwa
- Nie zaimplementowano strategii tworzenia kopii zapasowych
- Nie skonfigurowano monitorowania ani alertów
- Brak funkcji wysokiej dostępności poza podstawową replikacją
- Brak procedur odzyskiwania po awarii
- Brak odpowiedniej izolacji sieci
- Brak szyfrowania SSL/TLS
- Brak odpowiedniego zarządzania użytkownikami i rolami
- Brak odpowiedniego logowania i audytu

W przypadku środowisk produkcyjnych warto rozważyć:
- wdrożenie odpowiednich środków bezpieczeństwa
- skonfigurowanie monitorowania i alertów
- skonfigurowanie odpowiednich procedur tworzenia kopii zapasowych i odzyskiwania
- korzystanie z zarządzanej usługi bazy danych
- konsultację z ekspertami ds. baz danych
- przestrzeganie najlepszych praktyk PostgreSQL

### Funkcje klastra

- Konfiguracja primary (odczyt/zapis) i repliki odczytu
- Fizyczna replikacja strumieniowa z dedykowanym slotem replikacji
- Automatyczne przygotowanie repliki za pomocą `pg_basebackup`
- Automatyczne tworzenie roli replikacji i slotu przy pierwszym uruchomieniu
- Trwałe przechowywanie danych w nazwanych wolumenach
- Sprawdzanie stanu (health checks) dla obu instancji
- Niestandardowy plik `pg_hba.conf` zezwalający na replikację z kontenera repliki

## Architektura

### Jak działa replikacja

Ta konfiguracja implementuje fizyczną replikację strumieniową między węzłem primary a repliką:

1. Węzeł primary (`rmf_classic_sugesstions`) przyjmuje operacje zapisu
2. Zmiany są zapisywane w logu Write-Ahead Log (WAL)
3. Replika (`rmf_classic_sugesstions_replica`) w sposób ciągły strumieniuje te rekordy WAL
4. Replika stosuje te zmiany, aby utrzymywać dokładną kopię primary
5. Replika działa w trybie hot standby, umożliwiając operacje odczytu

Przy pierwszym uruchomieniu replika czeka, aż primary zacznie przyjmować połączenia, a następnie klonuje go za pomocą `pg_basebackup`. Opcja `-R` tworzy plik `standby.signal` oraz automatycznie konfiguruje `primary_conninfo` i `primary_slot_name`.

Przy kolejnych uruchomieniach replika wykrywa istniejący plik `standby.signal`, pomija klonowanie i wznawia strumieniowanie WAL z primary.

### Konfiguracja Docker Compose

Plik `docker-compose.yml` zarządza dwoma kontenerami PostgreSQL:

- **Węzeł primary (`rmf_classic_sugesstions`)**:
  - Opublikowany na porcie hosta `9874`
  - Nasłuchuje na porcie kontenera `5432`
  - Obsługuje operacje odczytu i zapisu
  - Tworzy rolę `replica` oraz fizyczny slot replikacji `replica_slot` przy pierwszej inicjalizacji

- **Replika odczytu (`rmf_classic_sugesstions_replica`)**:
  - Opublikowana na porcie hosta `9873`
  - Automatycznie klonuje i łączy się z primary
  - Obsługuje operacje tylko do odczytu
  - Utrzymuje dokładną kopię danych primary

Konfiguracja obejmuje:
- sprawdzanie stanu (health checks) obu instancji
- trwałe wolumeny do przechowywania danych
- automatyczną konfigurację replikacji
- dedykowaną sieć do komunikacji między kontenerami

### Pliki projektu

| Ścieżka | Przeznaczenie |
| --- | --- |
| `docker-compose.yml` | Definiuje primary, replikę, wolumeny i health checks |
| `.env` | Nazwa bazy danych, użytkownik i hasło (kopiowane z `.env.example`) |
| `initdb.d/00_init.sh` | Tworzy rolę `replica` i slot `replica_slot` przy pierwszej inicjalizacji |
| `config/pg_hba.conf` | Reguły uwierzytelniania, w tym replikacja z kontenera repliki |

> Kontener primary korzysta z `config/pg_hba.conf` poprzez ustawienie `hba_file`. Bez wpisu replikacji połączenia kończą się błędem `no pg_hba.conf entry for replication connection`.

## Szybki start

1. Sklonuj repozytorium:
```bash
git clone https://github.com/ArekSawicki/postgres-docker-compose-cluster.git
cd postgres-docker-compose-cluster
```

2. Utwórz plik środowiskowy:
```bash
cp .env.example .env
```

Następnie w razie potrzeby dostosuj `POSTGRES_DB`, `POSTGRES_USER` i `POSTGRES_PASSWORD`. Replika używa tych samych wartości podczas łączenia się z primary.

3. Uruchom klaster:
```bash
docker compose up -d
```

4. Sprawdź, czy usługi działają:
```bash
docker compose ps
```

5. (Opcjonalnie) Śledź logi przygotowania repliki:
```bash
docker compose logs -f rmf_classic_sugesstions_replica
```

## Użytkowanie

### Dane połączenia

| Instancja | Host | Port | Dostęp |
| --- | --- | --- | --- |
| Primary | `localhost` | `9874` | Odczyt / zapis |
| Replica | `localhost` | `9873` | Tylko odczyt |

Użyj wartości z pliku `.env` jako nazwy bazy danych, użytkownika i hasła. W poniższych przykładach jako nazwa bazy danych używana jest `rmf_classic_sugesstions`, a jako superużytkownik `postgres`.

### Sprawdzanie stanu replikacji

```bash
# Połączenie z primary
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "SELECT * FROM pg_stat_replication;"

# Połączenie z repliką
docker compose exec rmf_classic_sugesstions_replica psql -U postgres -d rmf_classic_sugesstions -c "SELECT pg_is_in_recovery();"
```

`pg_is_in_recovery()` powinno zwracać `t` na replice oraz `f` na primary.

Możesz także sprawdzić slot replikacji na primary:

```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "SELECT slot_name, active FROM pg_replication_slots;"
```

### Testowanie replikacji

1. Utwórz tabelę na primary:
```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "CREATE TABLE test (id SERIAL PRIMARY KEY, data TEXT);"
```

2. Wstaw dane na primary:
```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "INSERT INTO test (data) VALUES ('test data');"
```

3. Sprawdź, czy dane zostały zreplikowane do repliki odczytu:
```bash
docker compose exec rmf_classic_sugesstions_replica psql -U postgres -d rmf_classic_sugesstions -c "SELECT * FROM test;"
```

### Zatrzymywanie klastra

Aby zatrzymać klaster:
```bash
docker compose down
```

Aby zatrzymać i usunąć wolumeny (spowoduje to usunięcie wszystkich danych):
```bash
docker compose down -v
```

### Odbudowa repliki

Replikę można w dowolnym momencie ponownie sklonować z primary. Zatrzymaj ją i usuń jej wolumen danych:

```bash
docker compose rm -sf rmf_classic_sugesstions_replica
docker volume rm postgresql17cluster_rmf_classic_sugesstions_replica_data
docker compose up -d rmf_classic_sugesstions_replica
```

> Nazwa wolumenu zależy od nazwy projektu Compose (domyślnie od nazwy katalogu).

## Rozwiązywanie problemów

### `no pg_hba.conf entry for replication connection`

Upewnij się, że primary korzysta z niestandardowego pliku `pg_hba.conf`:

```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -c "SHOW hba_file;"
```

Powinno zwrócić `/etc/postgresql/pg_hba.conf`. Plik musi zawierać:

```conf
host    replication     replica         all                     scram-sha-256
```

### `password authentication failed for user "replica"`

Rola `replica` jest tworzona tylko przy pierwszej inicjalizacji katalogu danych primary. Jeśli hasło roli nie odpowiada wartości `POSTGRES_PASSWORD` (na przykład po zmianie `.env`), zaktualizuj je ręcznie:

```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -c "ALTER ROLE replica WITH REPLICATION LOGIN PASSWORD 'your_password';"
```

### Rozpoczęcie od czystego klastra

Jeśli nie musisz zachowywać danych, usuń wolumeny i pozwól skryptom inicjalizacyjnym uruchomić się ponownie:

```bash
docker compose down -v
docker compose up -d
```

## Współpraca

Zapraszamy do współtworzenia projektu! Aby wnieść wkład:

1. Zrób fork repozytorium
2. Utwórz gałąź funkcji (`git checkout -b feature/amazing-feature`)
3. Zatwierdź zmiany (`git commit -m 'Add some amazing feature'`)
4. Wypchnij gałąź (`git push origin feature/amazing-feature`)
5. Otwórz Pull Request

## Licencja

Projekt jest objęty licencją MIT – szczegóły znajdują się w pliku [LICENSE.md](LICENSE.md).
