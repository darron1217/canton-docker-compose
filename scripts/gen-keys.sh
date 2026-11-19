#!/bin/sh
# Admin API JWT(ES256) 서명용 EC P-256 키쌍과 자체 서명 인증서를 생성합니다.
#   keys/private/admin-jwt.key  개인키 — 토큰 발급자만 보유
#   keys/public/admin-jwt.crt   인증서 — 각 노드가 서명 검증에 사용
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)/keys"
KEY="$DIR/private/admin-jwt.key"
CRT="$DIR/public/admin-jwt.crt"

if [ -f "$KEY" ] && [ "${1:-}" != "--force" ]; then
  echo "이미 존재합니다: $KEY  (다시 만들려면 --force)" >&2
  exit 0
fi

mkdir -p "$DIR/private" "$DIR/public"
openssl ecparam -name prime256v1 -genkey -noout -out "$KEY"
openssl req -new -x509 -key "$KEY" -out "$CRT" -days 365 -subj "/CN=canton-admin-api-jwt"
chmod 600 "$KEY"
chmod 644 "$CRT"
echo "생성 완료: $KEY, $CRT"
