#!/usr/bin/env bash
# Fast Flutter web preview → Vercel (prebuilt). For local/CI iteration.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VERCEL_ORG_ID="${VERCEL_ORG_ID:-team_5uxQCVdAhb1FImpmmkm9rAa5}"
exec bash "$ROOT/scripts/deploy-vercel-web.sh" --preview
