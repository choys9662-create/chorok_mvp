#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

scripts/build_website.sh
firebase deploy --only hosting:site
