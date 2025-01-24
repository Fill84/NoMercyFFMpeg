#!/bin/bash

run_test() {
  local name=$1
  local command=$2
  local expected_output=$3

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  echo "Testing $name... "

  if eval "$GITHUB_WORKSPACE/ffmpeg $command" 2>&1 | grep -q "$expected_output"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo "✅ PASSED"
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo "❌ FAILED"
  fi
}
