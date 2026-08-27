# Lokal utveckling och self-hosted Supabase

## Sammanfattning

Det finns tva olika lokala arbetsfloden som ar enkla att blanda ihop:

1. **Lokal utveckling mot Supabase CLI**: anvand `unlovable-local-supabase` mot ditt Lovable-apprepo. Det startar den lokala Supabase-stacken, kor migrationerna och skriver `.env.local` sa att appen pratar med lokal Supabase.
2. **Self-hosted migration**: flytta bort fran Lovable/Supabase Cloud till en egen Docker Compose-installation av hela Supabase-stacken.

Om du bara vill starta din app lokalt mot en lokal Supabase-instans, folj snabbstarten nedan. Resten av dokumentet handlar om self-hosted migration.

---

## Snabbstart: kor en lokal Lovable-app mot lokal Supabase

Exempel med ett apprepo i `/Users/jmfk/code/monster-meadows`:

```bash
cd /Users/jmfk/code/unlovable
make install
unlovable-local-supabase --project-root /Users/jmfk/code/monster-meadows
cd /Users/jmfk/code/monster-meadows
npm i
npm run dev
```

Det har kommandot gor foljande i apprepot:

- startar lokal Supabase via Supabase CLI
- kor `supabase db push --local` mot `supabase/migrations/`
- skriver `.env.local` med `VITE_SUPABASE_URL` och lokal publishable key
- uppdaterar `supabase/config.toml` med ett deterministiskt lokalt `project_id`
- skapar `docs/supabase-status.md` om filen saknas

I ett vanligt Lovable/Vite-projekt ar det sedan `npm run dev` som startar den lokala appen mot den lokala Supabase-miljon.

---

## Self-hosted migration fran Lovable + Supabase Cloud

**Ja, det gar att kora Supabase lokalt (self-hosted) och migrera bort fran Lovable.** Supabase ar open source och erbjuder en officiell Docker Compose-stack som inkluderar alla komponenter: PostgreSQL, Auth (GoTrue), Realtime, Storage, Edge Functions och Studio-dashboarden. Det ar det enklaste och mest naturliga forsta steget innan en eventuell vidare migration till en helt annan stack.

---

## Steg 1: Exportera koden från Lovable

Lovable-projekt är standard React/TypeScript-applikationer (Vite-baserade). Koden exporteras via GitHub:

1. **Koppla ihop med GitHub** — I Lovable: Settings → Integrations → GitHub → Connect
2. **Synca projektet** — Lovable pushar hela kodbasen till ett GitHub-repo
3. **Klona lokalt** — `git clone` och kör `npm install && npm run dev`

Alternativt kan man ladda ner projektet som ZIP direkt från Lovable.

### Vad som följer med

| Komponent                  | Exporteras automatiskt? | Kommentar                                     |
| -------------------------- | ----------------------- | --------------------------------------------- |
| Frontend-kod (React/TS)    | Ja                      | Via GitHub eller ZIP                          |
| Supabase-migrationer (SQL) | Ja                      | Finns i `supabase/migrations/`                |
| `.env`-konfiguration       | Ja                      | Men pekar på Lovable Cloud — måste uppdateras |
| `supabase/config.toml`     | Ja                      | Projekt-ID måste ändras                       |
| Databasdata                | Nej                     | Måste exporteras separat (CSV eller pg_dump)  |
| Storage-filer              | Nej                     | Måste migreras separat                        |
| Auth-användare             | Delvis                  | Finns i databasen, men tokens invalideras     |

---

## Steg 2: Sätt upp Supabase Self-Hosted (Docker)

### Systemkrav (minimum)

- CPU: 2 kärnor (4+ rekommenderas)
- RAM: 4 GB (8 GB+ rekommenderas)
- Disk: 10 GB+
- Docker och Docker Compose installerat

### Installation

```bash
# Klona Supabase-repot
git clone https://github.com/supabase/supabase
cd supabase/docker

# Kopiera och konfigurera miljövariabler
cp .env.example .env

# Redigera .env:
#   - Sätt POSTGRES_PASSWORD (starkt lösenord, bara bokstäver + siffror)
#   - Generera nya JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY
#   - Konfigurera SITE_URL till din app-URL

# Starta alla tjänster
docker compose pull
docker compose up -d
```

### Vad som startar

Hela Supabase-stacken körs som Docker-containers:

- **PostgreSQL** — Databasen
- **PostgREST** — Auto-genererat REST API
- **GoTrue** — Autentisering (Auth)
- **Realtime** — WebSocket-baserade realtidsuppdateringar
- **Storage** — Filhantering (S3-kompatibelt)
- **Kong** — API Gateway (port 8000)
- **Studio** — Admin-dashboard (tillgängligt via port 8000)
- **Edge Functions** — Serverless functions (Deno)
- **Supavisor** — Connection pooler

Studio nås på `http://localhost:8000` efter uppstart.

---

## Steg 3: Migrera databasen

Supabase har en officiell guide för att flytta från deras Cloud-plattform till self-hosted. Rekommenderad metod är `supabase db dump` via CLI:n.

### 3a. Installera Supabase CLI

```bash
npm install -g supabase
# eller
brew install supabase/tap/supabase
```

### 3b. Exportera från Lovable Cloud / Supabase Cloud

```bash
# Logga in och länka till det gamla projektet
supabase login
supabase link --project-ref <ditt-lovable-cloud-projekt-id>

# Exportera roller, schema och data som separata SQL-filer
supabase db dump -f roles.sql --role-only
supabase db dump -f schema.sql
supabase db dump -f data.sql --data-only
```

> **Viktigt:** Använd `supabase db dump` och inte raw `pg_dump`. CLI:n filtrerar bort Supabase-interna scheman och lägger till idempotenta `IF NOT EXISTS`-satser som undviker permissionsfel vid restore.

### 3c. Importera till self-hosted

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "postgres://postgres.your-tenant-id:<POSTGRES_PASSWORD>@localhost:5432/postgres"
```

### 3d. Alternativ: Kör migrationer manuellt

Om ditt Lovable-projekt har SQL-migrationsfiler i `supabase/migrations/`:

```bash
# Pusha migrationer till self-hosted instansen
supabase db push --db-url "postgres://postgres:<POSTGRES_PASSWORD>@localhost:5432/postgres"
```

Eller kör varje migrering manuellt i kronologisk ordning (filnamnen har timestamps) via Studio:s SQL-editor.

---

## Steg 4: Uppdatera app-konfigurationen

### `.env`

```env
VITE_SUPABASE_URL="http://localhost:8000"
VITE_SUPABASE_PUBLISHABLE_KEY="<din-nya-ANON_KEY>"
VITE_SUPABASE_PROJECT_ID="<din-nya-tenant-id>"
```

### `supabase/config.toml`

Uppdatera `project_id` till ditt nya self-hosted projekt-ID.

---

## Steg 5: Hantera Auth och användare

Autentiseringsdata (tabellen `auth.users`) ingår i databas-dumpen, men det finns viktiga saker att tänka på:

- **JWT-secrets skiljer sig** mellan Cloud och self-hosted. Befintliga tokens blir ogiltiga — användare måste logga in på nytt.
- **OAuth-providers** (Google, GitHub, etc.) måste konfigureras i `.env` via `GOTRUE_EXTERNAL_*`-variabler.
- **Redirect-URLs** i OAuth-providerns konsol (Google Cloud Console etc.) måste uppdateras från `*.supabase.co` till din nya domän/localhost.

---

## Steg 6: Migrera Storage (filer)

Storage-objekt ingår **inte** i databas-dumpen. Om du har filer lagrade i Supabase Storage:

1. Ladda ner filerna från Lovable Cloud (via Storage-dashboarden eller Supabase API)
2. Ladda upp dem till din self-hosted instans
3. Storage-metadata finns i `storage`-schemat i databasen — URL:er kan behöva uppdateras

---

## Viktiga saker att tänka på

### Postgres-versioner

Supabase Cloud kan köra PostgreSQL 17, medan self-hosted Docker-imagen för närvarande använder PostgreSQL 15. SQL-dumparna från `supabase db dump` är kompatibla mellan versionerna, men var medveten om skillnaden. PostgreSQL 15 når end-of-life i maj 2026.

### Edge Functions

Edge Functions lagras lokalt i `volumes/functions/` i Docker-installationen. Dina functions från Lovable-projektet finns i `supabase/functions/` i kodbasen — kopiera dem till rätt plats.

### Produktion vs utveckling

Docker-installationen fungerar utmärkt för lokal utveckling. För produktion behövs:

- Reverse proxy (Nginx/Caddy) med TLS/SSL
- Backuplösning för databasen
- Monitorering
- SMTP-server för e-post (Auth-flöden)
- Eventuellt S3-kompatibel storage (MinIO, Cloudflare R2, etc.)

### Verktyg som förenklar produktionsdrift

Om du planerar att köra self-hosted i produktion (inte bara lokalt) finns det verktyg som förenklar:

- **Coolify** — Self-hosted PaaS (typ Heroku) — gratis, enkel setup
- **EasyPanel** — Enklare UI för Docker-deploys
- **Dokploy** — Lightweight deploy-verktyg

---

## Migrationsstrategi: Steg för steg

```
Fas 1: Förberedelse
├── Exportera kod via GitHub
├── Dokumentera alla env-variabler och integrationer
├── Inventera databastabeller, Storage och Auth-providers
└── Ta backup av allt

Fas 2: Self-hosted setup
├── Installera Docker och Supabase self-hosted
├── Konfigurera .env med nya nycklar
├── Verifiera att Studio och alla tjänster startar
└── Testa grundläggande API-access

Fas 3: Datamigrering
├── Dumpa roller, schema och data från Cloud
├── Importera till self-hosted
├── Migrera Storage-filer
└── Verifiera dataintegritet

Fas 4: App-anpassning
├── Uppdatera .env i frontend-koden
├── Uppdatera config.toml
├── Konfigurera OAuth-providers
└── Testa auth-flöden (login, signup, reset password)

Fas 5: Validering
├── Kör appen lokalt mot self-hosted Supabase
├── Testa alla CRUD-operationer
├── Testa RLS-policies
├── Testa Storage (upload/download)
└── Testa Realtime-subscriptions

Fas 6: Cutover
├── Final data-sync (om det behövs)
├── Byt app-konfiguration till self-hosted
├── Verifiera allt i produktion
└── Behåll Cloud-projektet som fallback tills allt är verifierat
```

---

## Framtida steg: Bort från Supabase helt

När projektet väl kör på self-hosted Supabase har du full kontroll och kan gradvis migrera bort:

1. **Byt ut Auth** — Ersätt GoTrue med t.ex. Keycloak, Authelia, eller bygga egen auth
2. **Byt ut PostgREST** — Skriv egna API:er (Express, Fastify, etc.) direkt mot PostgreSQL
3. **Byt ut Realtime** — Använd egen WebSocket-server eller t.ex. Socket.io
4. **Byt ut Storage** — Direkt MinIO/S3-integration eller lokal fillagring
5. **Behåll PostgreSQL** — Databasen är standard Postgres och fungerar oberoende av Supabase

Fördelen med att gå via self-hosted Supabase först är att appen fortsätter fungera under hela migrationsprocessen — du kan byta ut en komponent i taget.