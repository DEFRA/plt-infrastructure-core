#!/usr/bin/env bash
# Validates compile-time parameters against runtime config values.
# Args:
#   1 expected environmentName (pipeline parameter, e.g. snd4)
#   2 config subType (e.g. SND)
#   3 config deploymentEnvInstance (e.g. 4)
#   4 expected location (pipeline parameter)
#   5 actual location (resolved from config variables)
set -e

expected_env="${1:-}"
config_sub_type="${2:-}"
config_deployment_env_instance="${3:-}"
expected_location="${4:-}"
actual_location="${5:-}"

err=0
exp_env="$(echo "$expected_env" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
cfg_sub="$(echo "$config_sub_type" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
cfg_inst="$(echo "$config_deployment_env_instance" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
# environmentName is a logical value (snd4), so compare it to config-derived subType+deploymentEnvInstance.
cfg_env="${cfg_sub}${cfg_inst}"
if [[ -n "$exp_env" && -n "$cfg_env" && "$cfg_env" != "$exp_env" ]]; then
  echo "##vso[task.logissue type=error]Environment mismatch: pipeline parameter (environmentName=$exp_env) does not match config (subType+deploymentEnvInstance=$cfg_env)."
  err=1
fi

exp_loc="$(echo "$expected_location" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
act_loc="$(echo "$actual_location" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
# Keep location validation as a direct parameter-vs-config check.
if [[ -n "$exp_loc" && "$act_loc" != "$exp_loc" ]]; then
  echo "##vso[task.logissue type=error]Location mismatch: pipeline parameter (location=$exp_loc) does not match config (location=$actual_location)."
  err=1
fi

if [[ $err -eq 1 ]]; then exit 1; fi
echo "Config validation passed: parameters match config."
