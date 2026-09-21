#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='004'
  APP_IMAGE=1
  SHARED_ASSETS=()
}
if [[ -z "${PUSHING:-}" ]]; then
  stage_shared_assets
fi
