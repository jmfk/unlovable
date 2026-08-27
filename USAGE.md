# Usage

## Install

```bash
make install
```

This installs `unlovable-local-supabase` to `~/.local/bin` and ensures `~/.zshrc` includes `~/.local/bin` on `PATH`.
It also installs `lovable-local-supabase` as a compatibility alias to the same script.

## Requirements

- Run the command inside a Lovable project git repository, or use `--project-root`
- Docker must be installed and running
- Supabase CLI is required

If the Supabase CLI is missing, `unlovable-local-supabase` will try to install it automatically:

- `brew install supabase/tap/supabase`
- `npm install -g supabase`

## Command

```bash
unlovable-local-supabase [--project-root <path>] [--skip-start] [--reset] [--no-seed]
```

Compatibility alias:

```bash
lovable-local-supabase [--project-root <path>] [--skip-start] [--reset] [--no-seed]
```

## Default Behavior

Running `unlovable-local-supabase`:

1. Detects the project root
2. Verifies Docker, git, and Supabase CLI
3. Sets `supabase/config.toml` `project_id` to a deterministic local value
4. Starts local Supabase if it is not already running
5. Applies pending migrations with `supabase db push --local`
6. Reads the local stack values from `supabase status`
7. Writes local Supabase values to `.env.local`
8. Creates `docs/supabase-status.md` if it does not already exist
9. Prints `supabase status`

Repeated runs are idempotent by default:

- existing local containers are reused when already running
- `.env.local` is rewritten with the same managed Supabase block on each run
- `supabase/config.toml` is kept aligned with the local project id
- the local database is not reset unless `--reset` is used
- the status markdown file is only created if missing

## Options

- `--project-root <path>`: run against a specific Lovable repository
- `--skip-start`: skip `supabase start`
- `--reset`: reset the local database and replay migrations
- `--no-seed`: skip `supabase/seed.sql` during `--reset`
- `--help`: show built-in help

## Examples

```bash
unlovable-local-supabase
unlovable-local-supabase --skip-start
unlovable-local-supabase --reset
unlovable-local-supabase --reset --no-seed
unlovable-local-supabase --project-root ~/code/my-lovable-app
```

## Start A Local Lovable App

If your app repo lives somewhere else, run the bootstrap command against that
repo and then start the app from there.

Example for `/Users/jmfk/code/monster-meadows`:

```bash
make install
unlovable-local-supabase --project-root /Users/jmfk/code/monster-meadows
cd /Users/jmfk/code/monster-meadows
npm i
npm run dev
```

After the bootstrap command finishes, the target repo will have:

- `.env.local` updated with `VITE_SUPABASE_URL` and local publishable key values
- `supabase/config.toml` updated with a deterministic local `project_id`
- `docs/supabase-status.md` created if it does not already exist

For `monster-meadows`, `npm run dev` starts the Vite app on port `8080`.
