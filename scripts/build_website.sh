#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Missing .env; cannot create website/config.js." >&2
  exit 1
fi

supabase_url="$(awk -F= '$1 == "SUPABASE_URL" {print substr($0, index($0, "=") + 1)}' .env)"
supabase_anon_key="$(awk -F= '$1 == "SUPABASE_ANON_KEY" {print substr($0, index($0, "=") + 1)}' .env)"

if [[ -z "$supabase_url" || -z "$supabase_anon_key" ]]; then
  echo "SUPABASE_URL and SUPABASE_ANON_KEY are required." >&2
  exit 1
fi

cat > website/config.js <<EOF
window.CHOROK_CONFIG = {
  supabaseUrl: '${supabase_url}',
  supabaseAnonKey: '${supabase_anon_key}',
};
EOF

if rg -q 'NAVER_CLIENT_SECRET|GOOGLE_CLOUD_VISION_API_KEY|GOOGLE_SERVER_CLIENT_ID|GOOGLE_IOS_CLIENT_ID|ALADIN_API_KEY|SERVICE_ROLE|service_role' website; then
  echo "Private env key found in website output." >&2
  exit 1
fi
