#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
INSTALL_BIN="${TMP_DIR}/bin"
MOCK_BIN="${TMP_DIR}/mock-bin"
CALLS_FILE="${TMP_DIR}/supabase-calls.log"
STARTED_FILE="${TMP_DIR}/supabase-started"
CONFLICT_RESOLVED_FILE="${TMP_DIR}/supabase-conflict-resolved"
export CALLS_FILE
export STARTED_FILE
export CONFLICT_RESOLVED_FILE

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${INSTALL_BIN}" "${MOCK_BIN}"

cat > "${MOCK_BIN}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "info" ]]; then
  exit 0
fi
if [[ "${1:-}" == "ps" && "${2:-}" == "--format" ]]; then
  if [[ -n "${DOCKER_PORT_OWNER:-}" ]]; then
    printf '%s 0.0.0.0:54322->5432/tcp\n' "${DOCKER_PORT_OWNER}"
  fi
  exit 0
fi
echo "unexpected docker invocation: $*" >&2
exit 1
EOF
chmod +x "${MOCK_BIN}/docker"

cat > "${MOCK_BIN}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${MOCK_BIN}/git"

cat > "${MOCK_BIN}/supabase" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${CALLS_FILE}"

case "${1:-}" in
  status)
    if [[ ! -f "${STARTED_FILE}" ]]; then
      exit 1
    fi
    if [[ "${2:-}" == "-o" && "${3:-}" == "env" ]]; then
      cat <<'ENVEOF'
export API_URL="http://127.0.0.1:54321"
export ANON_KEY="local-anon-key"
export DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
export STUDIO_URL="http://127.0.0.1:54323"
export SERVICE_ROLE_KEY="local-service-role-key"
export JWT_SECRET="local-jwt-secret"
ENVEOF
      exit 0
    fi
    cat <<'STATUSEOF'
API URL: http://127.0.0.1:54321
DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
Studio URL: http://127.0.0.1:54323
STATUSEOF
    exit 0
    ;;
  db)
    if [[ "${2:-}" == "push" && "${3:-}" == "--local" ]]; then
      echo "Remote database is up to date."
      exit 0
    fi
    if [[ "${2:-}" == "reset" && "${3:-}" == "--local" ]]; then
      echo "Reset database."
      exit 0
    fi
    ;;
  start)
    if [[ "${SUPABASE_CONFLICT_ON_START:-0}" == "1" && ! -f "${CONFLICT_RESOLVED_FILE}" ]]; then
      cat <<'STARTEOF' >&2
failed to start docker container: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint supabase_db_conflict_project (f500edd51d04b9bb8e75dbb092f4aad46dd4a9c956776b9c7d407a10b851499e): Bind for 0.0.0.0:54322 failed: port is already allocated
STARTEOF
      exit 1
    fi
    touch "${STARTED_FILE}"
    echo "Started local stack."
    exit 0
    ;;
  stop)
    if [[ "${2:-}" == "--project-id" && -n "${3:-}" ]]; then
      touch "${CONFLICT_RESOLVED_FILE}"
      rm -f "${STARTED_FILE}"
      echo "Stopped project ${3}"
      exit 0
    fi
    ;;
  --version)
    echo "2.75.0"
    exit 0
    ;;
esac

echo "unexpected supabase invocation: $*" >&2
exit 1
EOF
chmod +x "${MOCK_BIN}/supabase"

assert_contains() {
  local file_path="$1"
  local expected="$2"

  python3 - "$file_path" "$expected" <<'PY'
import pathlib
import sys

file_path = pathlib.Path(sys.argv[1])
expected = sys.argv[2]
content = file_path.read_text()
if expected not in content:
    raise SystemExit(f"expected {expected!r} in {file_path}")
PY
}

assert_occurrences() {
  local file_path="$1"
  local needle="$2"
  local expected_count="$3"

  python3 - "$file_path" "$needle" "$expected_count" <<'PY'
import pathlib
import sys

file_path = pathlib.Path(sys.argv[1])
needle = sys.argv[2]
expected_count = int(sys.argv[3])
content = file_path.read_text()
actual_count = content.count(needle)
if actual_count != expected_count:
    raise SystemExit(
        f"expected {expected_count} occurrences of {needle!r} in {file_path}, found {actual_count}"
    )
PY
}

create_project() {
  local project_dir="$1"

  mkdir -p "${project_dir}/supabase/migrations"
  cat > "${project_dir}/supabase/config.toml" <<'EOF'
project_id = "cloud_project"
EOF
  cat > "${project_dir}/supabase/migrations/20260321000000_initial.sql" <<'EOF'
select 1;
EOF
}

run_bootstrap() {
  local command_name="$1"
  local project_dir="$2"

  PATH="${MOCK_BIN}:${INSTALL_BIN}:/usr/bin:/bin" \
    "${command_name}" --project-root "${project_dir}"
}

run_bootstrap_with_conflict() {
  local command_name="$1"
  local project_dir="$2"

  PATH="${MOCK_BIN}:${INSTALL_BIN}:/usr/bin:/bin" \
    DOCKER_PORT_OWNER="supabase_db_reqlmfxyyrzcfszcncyv" \
    SUPABASE_CONFLICT_ON_START=1 \
    "${command_name}" --project-root "${project_dir}"
}

PATH="${MOCK_BIN}:/usr/bin:/bin" make -C "${ROOT_DIR}" install-script BINDIR="${INSTALL_BIN}"

[[ -x "${INSTALL_BIN}/unlovable-local-supabase" ]]
[[ -L "${INSTALL_BIN}/lovable-local-supabase" ]]
[[ "$(readlink "${INSTALL_BIN}/lovable-local-supabase")" == "${INSTALL_BIN}/unlovable-local-supabase" ]]

CANONICAL_PROJECT="${TMP_DIR}/canonical-project"
create_project "${CANONICAL_PROJECT}"
run_bootstrap "unlovable-local-supabase" "${CANONICAL_PROJECT}"
run_bootstrap "lovable-local-supabase" "${CANONICAL_PROJECT}"

assert_contains "${CANONICAL_PROJECT}/supabase/config.toml" 'project_id = "canonical_project_local"'
assert_contains "${CANONICAL_PROJECT}/.env.local" '# BEGIN unlovable-local-supabase'
assert_contains "${CANONICAL_PROJECT}/.env.local" 'VITE_SUPABASE_URL="http://127.0.0.1:54321"'
assert_contains "${CANONICAL_PROJECT}/.env.local" 'VITE_SUPABASE_PUBLISHABLE_KEY="local-anon-key"'
assert_occurrences "${CANONICAL_PROJECT}/.env.local" '# BEGIN unlovable-local-supabase' 1
assert_contains "${CANONICAL_PROJECT}/docs/supabase-status.md" '*Generated by unlovable-local-supabase*'

LEGACY_PROJECT="${TMP_DIR}/legacy-project"
create_project "${LEGACY_PROJECT}"
run_bootstrap "lovable-local-supabase" "${LEGACY_PROJECT}"

assert_contains "${LEGACY_PROJECT}/supabase/config.toml" 'project_id = "legacy_project_local"'
assert_contains "${LEGACY_PROJECT}/.env.local" '# BEGIN unlovable-local-supabase'
assert_contains "${LEGACY_PROJECT}/.env.local" 'VITE_SUPABASE_PROJECT_ID="legacy_project_local"'
assert_contains "${LEGACY_PROJECT}/docs/supabase-status.md" '*Generated by lovable-local-supabase*'
assert_contains "${CALLS_FILE}" 'db push --local'

rm -f "${STARTED_FILE}" "${CONFLICT_RESOLVED_FILE}"
CONFLICT_PROJECT="${TMP_DIR}/conflict-project"
create_project "${CONFLICT_PROJECT}"
run_bootstrap_with_conflict "unlovable-local-supabase" "${CONFLICT_PROJECT}"

assert_contains "${CONFLICT_PROJECT}/supabase/config.toml" 'project_id = "conflict_project_local"'
assert_contains "${CALLS_FILE}" 'stop --project-id reqlmfxyyrzcfszcncyv'

echo "verify-local-supabase-bootstrap: ok"
