#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
bash "$PROJECT_ROOT/scripts/build-app.sh"
open "$PROJECT_ROOT/dist/flowmo.app"
