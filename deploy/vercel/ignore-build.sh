#!/usr/bin/env bash
# Compatibility wrapper — canonical script is scripts/vercel-ignore-build.sh
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/vercel-ignore-build.sh"
