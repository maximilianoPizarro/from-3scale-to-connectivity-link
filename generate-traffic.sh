#!/bin/bash
#
# Traffic generator for user1-neuralbank dashboards
# Generates varied HTTP traffic patterns: 200/401/404/429 responses
# to populate Grafana and Kuadrant Connectivity Link dashboards.
#

set -euo pipefail

BACKEND_URL="https://neuralbank-backend-user1-neuralbank.apps.cluster-lfm7v.dynamic2.redhatworkshops.io"
API_KEY="oyImFCpKew59Q8LxX1pjyncpJgiQrBLPEOKoUgTfuwA="

DURATION_SECONDS=${1:-300}
CONCURRENCY=${2:-3}

declare -i total=0 ok=0 client_err=0 server_err=0 rate_limited=0

log() { echo "[$(date +%H:%M:%S)] $*"; }

record() {
  local code=$1
  ((total++)) || true
  if   (( code >= 200 && code < 300 )); then ((ok++)) || true
  elif (( code == 429 ));               then ((rate_limited++)) || true
  elif (( code >= 400 && code < 500 )); then ((client_err++)) || true
  else                                       ((server_err++)) || true
  fi
}

send() {
  local method=$1 path=$2 key=${3:-""} data=${4:-""}
  local -a args=(-sk -o /dev/null -w '%{http_code}' --max-time 10)
  [[ -n "$key"  ]] && args+=(-H "X-API-Key: $key")
  [[ "$method" == "POST" ]] && args+=(-X POST -H "Content-Type: application/json" -d "$data")
  local code
  code=$(curl "${args[@]}" "${BACKEND_URL}${path}" 2>/dev/null || echo "000")
  record "$code"
  echo -n "${code} "
}

# ── Traffic patterns ────────────────────────────────────────────

normal_read_traffic() {
  send GET "/api/customers" "$API_KEY"
  send GET "/api/credits"   "$API_KEY"
  send GET "/q/health"      "$API_KEY"
  send GET "/q/health/live" "$API_KEY"
  send GET "/q/health/ready" "$API_KEY"
}

write_traffic() {
  local ids=("CR001" "CR002" "CR003")
  local id=${ids[$((RANDOM % ${#ids[@]}))]}
  send POST "/api/credits/${id}/update" "$API_KEY" "{\"amount\":$((RANDOM % 50000 + 1000))}"
}

unauthenticated_traffic() {
  send GET "/api/customers" ""
  send GET "/api/credits"   ""
}

bad_key_traffic() {
  send GET "/api/customers" "invalid-key-$(( RANDOM % 100 ))"
  send GET "/api/credits"   "bad-api-key"
}

not_found_traffic() {
  local paths=("/api/nonexistent" "/api/customers/CXXX" "/api/credits/NONE" "/api/v1/accounts" "/api/loans")
  local path=${paths[$((RANDOM % ${#paths[@]}))]}
  send GET "$path" "$API_KEY"
}

burst_traffic() {
  for _ in $(seq 1 15); do
    send GET "/api/customers" "$API_KEY" &
  done
  wait
}

# ── Main loop ───────────────────────────────────────────────────

END_TIME=$(( $(date +%s) + DURATION_SECONDS ))

log "Starting traffic generation for ${DURATION_SECONDS}s with concurrency=${CONCURRENCY}"
log "Target: $BACKEND_URL"
log "Rate limits: global 120/min, plans: free 10/min, basic 60/min, pro 300/min"
echo ""

ITERATION=0
while (( $(date +%s) < END_TIME )); do
  ((ITERATION++)) || true
  REMAINING=$(( END_TIME - $(date +%s) ))
  log "── Iteration $ITERATION (${REMAINING}s remaining) | ok=$ok err=$client_err rate=$rate_limited total=$total ──"

  # ~60% normal reads
  for _ in $(seq 1 $CONCURRENCY); do
    normal_read_traffic &
  done
  wait
  echo ""

  # ~15% write operations
  for _ in $(seq 1 2); do
    write_traffic &
  done
  wait
  echo ""

  # ~10% unauthenticated (generate 401s)
  unauthenticated_traffic
  echo ""

  # ~5% bad keys (generate 401/403s)
  bad_key_traffic
  echo ""

  # ~5% not-found paths (generate 404s)
  not_found_traffic
  echo ""

  # Every 5th iteration, send a burst to trigger rate limits (429s)
  if (( ITERATION % 5 == 0 )); then
    log ">> BURST: triggering rate limit"
    burst_traffic
    echo ""
  fi

  sleep $(( RANDOM % 3 + 1 ))
done

echo ""
log "════════════════════════════════════════════════"
log "  Traffic generation complete"
log "  Total requests: $total"
log "  2xx OK:         $ok"
log "  4xx errors:     $client_err"
log "  429 rate-limit: $rate_limited"
log "  5xx errors:     $server_err"
log "════════════════════════════════════════════════"
