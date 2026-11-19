#!/bin/sh
# 노드별 Admin API 토큰을 발급해 /tokens 볼륨에 저장합니다.
set -eu
TTL="${ADMIN_TOKEN_TTL_SECONDS:-3600}"
umask 022
/scripts/jwt.sh "$PARTICIPANT_ADMIN_AUDIENCE" bootstrap "$TTL" > /tokens/participant.jwt
/scripts/jwt.sh "$SEQUENCER_ADMIN_AUDIENCE"   bootstrap "$TTL" > /tokens/sequencer.jwt
/scripts/jwt.sh "$MEDIATOR_ADMIN_AUDIENCE"    bootstrap "$TTL" > /tokens/mediator.jwt
echo "issued admin tokens (ttl=${TTL}s)"
