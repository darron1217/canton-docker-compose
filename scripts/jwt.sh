#!/bin/sh
# ES256 JWT 생성기 (POSIX sh + openssl + xxd).
#
#   ./scripts/jwt.sh <audience> [subject] [ttl-seconds]
#
# 개인키 경로는 ADMIN_API_JWT_KEY 로 지정합니다 (기본: keys/private/admin-jwt.key).
set -eu

AUD="${1:?usage: jwt.sh <audience> [subject] [ttl-seconds]}"
SUB="${2:-admin}"
TTL="${3:-3600}"
KEY="${ADMIN_API_JWT_KEY:-$(dirname "$0")/../keys/private/admin-jwt.key}"
[ -r "$KEY" ] || { echo "개인키를 읽을 수 없습니다: $KEY (./scripts/gen-keys.sh 를 먼저 실행하세요)" >&2; exit 1; }

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# openssl 은 ECDSA 서명을 DER(SEQUENCE{r,s}) 로 내보내지만, JWS(ES256) 는 r||s (각 32바이트) 를 요구합니다.
der_to_jose() {
  openssl asn1parse -inform DER | awk -F: '/INTEGER/ {
    h = $NF
    while (length(h) < 64) h = "0" h
    printf "%s", substr(h, length(h) - 63)
  }' | xxd -r -p
}

NOW="$(date +%s)"
HEADER="$(printf '%s' '{"alg":"ES256","typ":"JWT"}' | b64url)"
PAYLOAD="$(printf '{"aud":"%s","sub":"%s","iat":%s,"exp":%s}' "$AUD" "$SUB" "$NOW" "$((NOW + TTL))" | b64url)"
SIG="$(printf '%s' "$HEADER.$PAYLOAD" | openssl dgst -sha256 -sign "$KEY" -binary | der_to_jose | b64url)"

printf '%s\n' "$HEADER.$PAYLOAD.$SIG"
