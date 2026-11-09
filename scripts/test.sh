#!/usr/bin/env bash
set -euo pipefail
cd app
tests=()
for test in test/*_test.dart; do
  [[ "$test" == test/live_agent_test.dart ]] && continue
  [[ "${RUNNER_OS:-}" != Windows && "$test" == test/desktop_readiness_test.dart ]] && continue
  tests+=("$test")
done
flutter test --no-pub --reporter expanded "${tests[@]}"
