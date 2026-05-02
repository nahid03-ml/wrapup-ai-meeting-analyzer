#!/usr/bin/env bash
# Health check for every external service WrapUp-AI depends on.
#
# Usage:
#   bash scripts/check_services.sh                    # auto-find .env
#   bash scripts/check_services.sh /path/to/.env      # explicit .env path
#
# Runs on macOS and Ubuntu/Oracle. Exits non-zero if any check fails.

set -u

# ---------- locate .env ----------
ENV_FILE="${1:-}"
if [ -z "$ENV_FILE" ]; then
  for candidate in "./.env" "./backend/.env" "$HOME/WrapUp-AI/.env"; do
    if [ -f "$candidate" ]; then ENV_FILE="$candidate"; break; fi
  done
fi
if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env file not found. Pass the path as an argument."
  exit 1
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

PASS=0
FAIL=0
pass() { printf "  ✅ %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ❌ %s\n" "$1"; FAIL=$((FAIL+1)); }
info() { printf "  ℹ️  %s\n" "$1"; }
section() { printf "\n== %s ==\n" "$1"; }

echo "================================================"
echo " WrapUp-AI service health check"
echo " .env:  $ENV_FILE"
echo " host:  $(hostname) ($(uname -s))"
echo "================================================"

# ---------- helpers ----------
http_code() {
  # http_code <url> [extra curl args...]
  local url="$1"; shift
  curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$@" "$url"
}

# ---------- Deepgram ----------
section "Deepgram"
check_deepgram_key() {
  local label="$1" key="$2"
  if [ -z "$key" ]; then fail "$label: not set"; return; fi
  local code
  code=$(http_code "https://api.deepgram.com/v1/projects" -H "Authorization: Token $key")
  if [ "$code" = "200" ]; then pass "$label: valid (200)"
  else fail "$label: HTTP $code — key rejected or no network"
  fi
}
check_deepgram_key "DEEPGRAM_API_KEY"        "${DEEPGRAM_API_KEY:-}"
if [ -n "${DEEPGRAM_API_KEYS_EXTRA:-}" ]; then
  check_deepgram_key "DEEPGRAM_API_KEYS_EXTRA" "${DEEPGRAM_API_KEYS_EXTRA:-}"
fi

# ---------- Groq ----------
section "Groq"
check_groq_key() {
  local label="$1" key="$2"
  if [ -z "$key" ]; then fail "$label: not set"; return; fi
  local code
  code=$(http_code "https://api.groq.com/openai/v1/models" -H "Authorization: Bearer $key")
  if [ "$code" = "200" ]; then pass "$label: valid (200)"
  else fail "$label: HTTP $code — key rejected or no network"
  fi
}
check_groq_key "GROQ_API_KEY"        "${GROQ_API_KEY:-}"
if [ -n "${GROQ_API_KEYS_EXTRA:-}" ]; then
  check_groq_key "GROQ_API_KEYS_EXTRA" "${GROQ_API_KEYS_EXTRA:-}"
fi

# ---------- Supabase ----------
section "Supabase"
SB_URL="${SUPABASE_URL:-${VITE_SUPABASE_URL:-}}"
SB_ANON="${SUPABASE_ANON_KEY:-${VITE_SUPABASE_PUBLISHABLE_KEY:-}}"
if [ -z "$SB_URL" ]; then
  fail "SUPABASE_URL: not set"
else
  # /auth/v1/settings accepts the anon key and returns 200 for a valid project.
  if [ -n "${SB_ANON:-}" ]; then
    code=$(http_code "$SB_URL/auth/v1/settings" -H "apikey: $SB_ANON")
    if [ "$code" = "200" ]; then pass "SUPABASE_URL + ANON_KEY: valid (200)"
    else fail "SUPABASE_URL + ANON_KEY: HTTP $code — URL or key wrong"
    fi
  else
    fail "SUPABASE_ANON_KEY: not set"
  fi
fi

# /rest/v1/ requires service_role by design — perfect isolated check for that key.
if [ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ] && [ -n "$SB_URL" ]; then
  code=$(http_code "$SB_URL/rest/v1/" -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY")
  if [ "$code" = "200" ] || [ "$code" = "404" ]; then pass "SUPABASE_SERVICE_ROLE_KEY: valid ($code)"
  else fail "SUPABASE_SERVICE_ROLE_KEY: HTTP $code — key rejected"
  fi
fi

# Storage bucket list — works with anon in public mode, 401 with service_role is also fine.
if [ -n "${SB_ANON:-}" ] && [ -n "$SB_URL" ]; then
  code=$(http_code "$SB_URL/storage/v1/bucket" -H "apikey: $SB_ANON" -H "Authorization: Bearer $SB_ANON")
  if [ "$code" = "200" ] || [ "$code" = "400" ]; then pass "Supabase storage endpoint: reachable ($code)"
  else fail "Supabase storage endpoint: HTTP $code"
  fi
fi

# ---------- Backblaze B2 / R2 ----------
section "Backblaze B2 (R2-compatible)"
if [ -z "${R2_ACCESS_KEY_ID:-}" ] || [ -z "${R2_SECRET_ACCESS_KEY:-}" ] || [ -z "${R2_ENDPOINT_URL:-}" ]; then
  fail "R2_* credentials: incomplete (need ACCESS_KEY_ID + SECRET + ENDPOINT_URL)"
else
  info "R2_ENDPOINT_URL=$R2_ENDPOINT_URL  bucket=${R2_BUCKET_NAME:-wrapup-audio}"
  # reachability only — full AWS Sig v4 would need aws cli
  ep_host=$(echo "$R2_ENDPOINT_URL" | sed -E 's|^https?://||' | sed -E 's|/.*||')
  if curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$R2_ENDPOINT_URL" | grep -qE "^(200|400|403)$"; then
    pass "R2 endpoint $ep_host: reachable"
  else
    fail "R2 endpoint $ep_host: unreachable"
  fi
  if command -v aws >/dev/null 2>&1; then
    if AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
       AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
       aws --endpoint-url "$R2_ENDPOINT_URL" s3 ls "s3://${R2_BUCKET_NAME:-wrapup-audio}" --summarize >/dev/null 2>&1; then
      pass "R2 bucket '${R2_BUCKET_NAME:-wrapup-audio}': auth OK (AWS CLI list)"
    else
      fail "R2 bucket '${R2_BUCKET_NAME:-wrapup-audio}': AWS CLI list failed — check keys"
    fi
  else
    info "awscli not installed — skipped deep auth check. brew install awscli to enable."
  fi
fi

# ---------- HTTP endpoints ----------
section "HTTP endpoints"
check_endpoint() {
  local name="$1" url="$2" want="${3:-200}"
  local code; code=$(http_code "$url")
  if [ "$code" = "$want" ]; then pass "$name: $url ($code)"
  else fail "$name: $url — got $code, expected $want"
  fi
}
check_endpoint "Oracle backend /docs"        "http://92.4.79.17:8000/docs"
check_endpoint "Oracle backend openapi"      "http://92.4.79.17:8000/openapi.json"
check_endpoint "Vercel production"           "https://wrap-up-ai-2.vercel.app/"
check_endpoint "Vercel → Oracle proxy"       "https://wrap-up-ai-2.vercel.app/api/backend/docs"
if curl -s --max-time 2 -o /dev/null http://127.0.0.1:8002/docs 2>/dev/null; then
  check_endpoint "Local backend (8002)"      "http://127.0.0.1:8002/docs"
else
  info "Local backend (127.0.0.1:8002): not running (skipped)"
fi

# ---------- Pyannote (optional) ----------
section "Pyannote / Hugging Face (optional)"
if [ -n "${PYANNOTE_AUTH_TOKEN:-}" ]; then
  code=$(http_code "https://huggingface.co/api/whoami-v2" -H "Authorization: Bearer $PYANNOTE_AUTH_TOKEN")
  if [ "$code" = "200" ]; then pass "PYANNOTE_AUTH_TOKEN: valid HF token"
  else fail "PYANNOTE_AUTH_TOKEN: HTTP $code — HF rejected token"
  fi
else
  info "PYANNOTE_AUTH_TOKEN: not set (OK — diarization default disabled)"
fi

echo
echo "================================================"
if [ "$FAIL" -eq 0 ]; then
  echo "  Result: ✅ all $PASS checks passed"
  exit 0
else
  echo "  Result: $PASS passed, ❌ $FAIL failed"
  exit 1
fi
