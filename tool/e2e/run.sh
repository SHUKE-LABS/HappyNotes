#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
STATE_FILE=""
EVIDENCE_DIR=""
RUN_TMP_DIR=""

usage() {
  printf 'Usage: %s <run-state-file> <evidence-dir>\n' "$0" >&2
}

die() {
  printf 'e2e: %s\n' "$1" >&2
  exit 2
}

state_value() {
  local key="$1"
  awk -F= -v wanted="$key" '$1 == wanted {sub(/^[^=]*=/, ""); print; exit}' "$STATE_FILE"
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  if [[ -e "$ENV_FILE" || -L "$ENV_FILE" ]]; then
    rm -f -- "$ENV_FILE"
  fi
  if [[ -n "$RUN_TMP_DIR" && -d "$RUN_TMP_DIR" ]]; then
    rm -rf -- "$RUN_TMP_DIR"
  fi

  exit "$status"
}

if [[ "$#" -ne 2 ]]; then
  usage
  exit 2
fi

STATE_FILE="$1"
if [[ "$STATE_FILE" != /* ]]; then
  STATE_FILE="${PWD}/${STATE_FILE}"
fi
[[ -f "$STATE_FILE" ]] || die "run-state-file does not exist: ${STATE_FILE}"

mkdir -p -- "$2"
EVIDENCE_DIR="$(cd -- "$2" && pwd)"

for command_name in awk flutter xvfb-run mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command not found: ${command_name}"
done

state_status="$(state_value E2E_STATE)"
[[ "$state_status" == "running" ]] || die "run state is not running: ${state_status:-missing}"

api_base_url="$(state_value E2E_API_URL)"
seed_username="$(state_value E2E_SEED_USERNAME)"
seed_password="$(state_value E2E_SEED_PASSWORD)"

[[ "$api_base_url" =~ ^https?://[^[:space:]]+$ ]] || die 'run state has an invalid E2E_API_URL'
[[ -n "$seed_username" ]] || die 'run state is missing E2E_SEED_USERNAME'
[[ -n "$seed_password" ]] || die 'run state is missing E2E_SEED_PASSWORD'

if [[ -e "$ENV_FILE" || -L "$ENV_FILE" ]]; then
  die "refusing to overwrite ${ENV_FILE}; run from a dedicated clone or worktree without .env"
fi

original_pub_cache="${PUB_CACHE:-${HOME:-}/.pub-cache}"
RUN_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/happynotes-e2e-app-XXXXXX")"
mkdir -p -- "${RUN_TMP_DIR}/home" "${RUN_TMP_DIR}/xdg-data" "${RUN_TMP_DIR}/xdg-config" "${RUN_TMP_DIR}/xdg-cache"

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'API_BASE_URL=%s\nPRIVATE_NOTE_ONLY=0\n' "$api_base_url" >"$ENV_FILE"

export HOME="${RUN_TMP_DIR}/home"
export XDG_DATA_HOME="${RUN_TMP_DIR}/xdg-data"
export XDG_CONFIG_HOME="${RUN_TMP_DIR}/xdg-config"
export XDG_CACHE_HOME="${RUN_TMP_DIR}/xdg-cache"
export PUB_CACHE="$original_pub_cache"
export HAPPYNOTES_E2E_STATE="$STATE_FILE"
export E2E_SEED_USERNAME="$seed_username"
export E2E_SEED_PASSWORD="$seed_password"
export HAPPYNOTES_E2E_EVIDENCE_DIR="$EVIDENCE_DIR"

cd -- "$REPO_ROOT"
printf 'e2e: running Linux desktop smoke test; evidence=%s\n' "$EVIDENCE_DIR"

set +e
xvfb-run -a -s '-screen 0 1280x800x24' \
  flutter test integration_test/core_smoke_test.dart -d linux 2>&1 \
  | tee "${EVIDENCE_DIR}/runner.log"
pipeline_status=("${PIPESTATUS[@]}")
test_status=${pipeline_status[0]}
tee_status=${pipeline_status[1]}
set -e

if ((tee_status != 0)); then
  exit "$tee_status"
fi
exit "$test_status"
