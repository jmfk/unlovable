# unlovable

`unlovable` provides a small helper for bootstrapping local Supabase development in a Lovable project.

The main command is `unlovable-local-supabase` and `lovable-local-supabase` remains available as a compatibility alias. Both names run the same bootstrap flow, which:

- detects the current Lovable git repo
- ensures Docker is running
- auto-installs the Supabase CLI if it is missing
- rewrites `.env.local` to point the app at local Supabase
- updates `supabase/config.toml` to a deterministic local project id
- starts local Supabase if needed
- applies pending local migrations without resetting by default
- supports an explicit reset flow when needed
- creates `docs/supabase-status.md` if it does not already exist

## Install

```bash
make install
```

This installs the command into `~/.local/bin` and ensures `~/.zshrc` includes that path.

## Run

```bash
unlovable-local-supabase
```

Useful variants:

```bash
unlovable-local-supabase --skip-start
unlovable-local-supabase --reset
unlovable-local-supabase --reset --no-seed
unlovable-local-supabase --project-root ~/code/my-lovable-app
```

Compatibility alias:

```bash
lovable-local-supabase
```

## Local Dev Flow

Use this when your Lovable app lives in a separate repo, such as
`/Users/jmfk/code/monster-meadows`.

```bash
make install
unlovable-local-supabase --project-root /Users/jmfk/code/monster-meadows
cd /Users/jmfk/code/monster-meadows
npm i
npm run dev
```

What happens:

- `unlovable-local-supabase` starts local Supabase for the target app repo
- it writes `.env.local` in that repo with the local Supabase URL and keys
- it updates `supabase/config.toml` to a deterministic local project id
- it creates `docs/supabase-status.md` if that file does not already exist
- after that, `npm run dev` starts the app against the local Supabase instance

## Behavior

- default reruns are idempotent and preserve the existing local database state
- the repo is wired to local Supabase through `.env.local`
- `supabase/config.toml` is kept aligned with the local project id
- pending migrations are applied with `supabase db push --local`
- `--reset` performs a clean rebuild of the local database

## Documentation

- `USAGE.md` for installation and command details
- `docs/local-supabase.md` for local dev notes and self-hosted migration guidance
- `docs/supabase-status.md` for generated local runtime status
