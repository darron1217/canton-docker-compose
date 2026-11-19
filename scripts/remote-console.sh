#!/usr/bin/env bash
# tokens 서비스가 발급한 JWT 를 환경변수로 올린 뒤 Canton 원격 콘솔을 실행합니다.
# (config/remote.conf 가 이 환경변수들을 token 필드로 참조합니다.)
set -euo pipefail

export PARTICIPANT_ADMIN_TOKEN="$(cat /tokens/participant.jwt)"
export SEQUENCER_ADMIN_TOKEN="$(cat /tokens/sequencer.jwt)"
export MEDIATOR_ADMIN_TOKEN="$(cat /tokens/mediator.jwt)"

# 이미지의 logback 설정을 명시해 "logback.xml occurs multiple times" 경고를 없앱니다.
export JAVA_TOOL_OPTIONS="-Dlogback.configurationFile=/app/logback.xml ${JAVA_TOOL_OPTIONS:-}"

exec /app/bin/canton "$@" \
  --config /config/remote.conf \
  --log-file-appender=off \
  --log-level-stdout="${LOG_LEVEL_STDOUT:-WARN}"
