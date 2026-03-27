#!/bin/zsh

set -u

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

pass() {
  printf "${GREEN}PASS${RESET} %s\n" "$1"
}

warn() {
  printf "${YELLOW}WARN${RESET} %s\n" "$1"
}

fail() {
  printf "${RED}FAIL${RESET} %s\n" "$1"
}

check_launchd_job() {
  local label="$1"
  local output
  output="$(launchctl list | rg "${label}" || true)"
  if [[ -z "$output" ]]; then
    fail "launchd job missing: ${label}"
    return 1
  fi

  local exit_code
  exit_code="$(echo "$output" | awk '{print $2}')"
  if [[ "$exit_code" == "0" ]]; then
    pass "launchd job running: ${label}"
    return 0
  fi

  warn "launchd job loaded but non-zero exit (${exit_code}): ${label}"
  return 1
}

check_http_200() {
  local url="$1"
  local name="$2"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || true)"
  if [[ "$code" == "200" ]]; then
    pass "${name} reachable (${url})"
    return 0
  fi

  fail "${name} not healthy (${url}) [http=${code}]"
  return 1
}

check_fly_secret_name() {
  local secret="$1"
  if fly secrets list -a golf-tip-app | rg -q "^${secret}[[:space:]]"; then
    pass "Fly secret present: ${secret}"
    return 0
  fi

  fail "Fly secret missing: ${secret}"
  return 1
}

echo "=== Personal Golf Coach Stack Check ==="
echo "Time: $(date)"
echo

failures=0

check_launchd_job "com.personal-golf.coach-api" || failures=$((failures + 1))
check_launchd_job "com.personal-golf.coach-tunnel" || failures=$((failures + 1))
check_http_200 "http://127.0.0.1:4317/health" "Local coach API" || failures=$((failures + 1))
check_http_200 "https://coach-bridge.golf-tip.org/health" "Tunnel endpoint" || failures=$((failures + 1))
check_fly_secret_name "ENABLE_COACH_AGENT" || failures=$((failures + 1))
check_fly_secret_name "CLAW_SIBLING_URL" || failures=$((failures + 1))
check_fly_secret_name "CLAW_SIBLING_TOKEN" || failures=$((failures + 1))

echo
if [[ "$failures" -eq 0 ]]; then
  pass "All checks passed"
  exit 0
fi

fail "${failures} check(s) failed"
exit 1
