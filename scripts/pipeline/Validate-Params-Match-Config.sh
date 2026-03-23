#!/usr/bin/env bash
# Validates compile-time parameters against runtime config values.
set -e

expected_env="${1:-}"
actual_env="${2:-}"
expected_location="${3:-}"
actual_location="${4:-}"

err=0
exp_env="$(echo "$expected_env" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
act_env="$(echo "$actual_env" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
if [[ -n "$exp_env" && -n "$act_env" && "$act_env" != "$exp_env" ]]; then
  echo "##vso[task.logissue type=error]Environment mismatch: pipeline parameter (environmentName=$exp_env) does not match config (environment=$actual_env)."
  err=1
fi

exp_loc="$(echo "$expected_location" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
act_loc="$(echo "$actual_location" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
if [[ -n "$exp_loc" && "$act_loc" != "$exp_loc" ]]; then
  echo "##vso[task.logissue type=error]Location mismatch: pipeline parameter (location=$exp_loc) does not match config (location=$actual_location)."
  err=1
fi

if [[ $err -eq 1 ]]; then exit 1; fi
echo "Config validation passed: parameters match config."
