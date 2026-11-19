# Canton 3.7.1 — Admin API ES256(JWT) 인증 docker compose 예제

Participant / Sequencer / Mediator 의 **Admin API** 에 ES256(ECDSA P-256) 서명 JWT 인증을 적용한 최소 구성입니다.
개인키는 토큰 발급자만 갖고, 노드에는 검증용 인증서만 올라갑니다.

| 서비스 | 이미지 | 포트 (127.0.0.1) |
| --- | --- | --- |
| `participant` | `canton-participant:3.7.1` | 5002 admin (JWT), 5001 ledger gRPC, 7575 ledger JSON |
| `sequencer` | `canton-sequencer:3.7.1` | 5009 admin (JWT), 5008 public |
| `mediator` | `canton-mediator:3.7.1` | 5007 admin (JWT) |
| `postgres` | `postgres:17` | – |
| `tokens` | `alpine/openssl` | 노드별 JWT 를 발급하고 종료 |
| `bootstrap` | `canton-participant:3.7.1` | JWT 로 접속해 synchronizer 초기화 후 종료 |

## 실행

```sh
cp .env.example .env
./scripts/gen-keys.sh           # keys/private/admin-jwt.key, keys/public/admin-jwt.crt 생성
docker compose up -d --wait
docker compose logs bootstrap   # "bootstrap complete: ..." 가 보이면 성공
```

## 인증 설정

각 노드의 `admin-api` 에 아래 블록이 들어갑니다 (`config/*.conf`).

```hocon
admin-api {
  auth-services = [{
    type = jwt-es-256-crt                 # ES256
    certificate = "/keys/admin-jwt.crt"   # 검증용 X.509 인증서 (공개키)
    target-audience = ${SEQUENCER_ADMIN_AUDIENCE}   # 토큰의 aud 와 일치해야 함
    privileged = true                     # 서명 + aud 가 맞으면 sub 와 무관하게
    access-level = admin                  #   Admin 권한 부여 (소문자)
    max-token-life = 24h                  # exp 가 없거나 너무 긴 토큰 거부
  }]
}
```

토큰 페이로드는 `{"aud": "<노드 audience>", "sub": "...", "iat": ..., "exp": ...}` 형태입니다.
audience 를 노드마다 다르게 두었기 때문에, 서명 키가 같아도 participant 용 토큰으로 sequencer 를 호출할 수 없습니다.

`keys/` 는 `.gitignore` 에 들어 있습니다. 노드 컨테이너에는 `keys/public` 만, `tokens` 서비스에는 `keys/private` 만 마운트됩니다.

## 토큰 발급과 호출

```sh
# ./scripts/jwt.sh <audience> [subject] [ttl-seconds]   (keys/private/admin-jwt.key 로 서명)
TOKEN=$(./scripts/jwt.sh https://canton.local/participant/admin alice 600)

grpcurl -plaintext -H "Authorization: Bearer $TOKEN" localhost:5002 \
  com.digitalasset.canton.topology.admin.v30.IdentityInitializationService/GetId
```

토큰이 없거나, aud 가 다르거나, 다른 키로 서명됐거나, 만료됐거나, 유효기간이 `max-token-life` 를 넘으면 `Unauthenticated` 로 거부됩니다.
(gRPC reflection 도 Admin API 위에 있으므로 토큰 없이는 `list` 도 되지 않습니다.)

## 원격 콘솔

```sh
docker compose run --rm console
```

`tokens` 서비스가 새 토큰을 발급하고, `config/remote.conf` 의 `remote-*.token` 필드로 전달됩니다.
토큰 유효기간은 기본 1시간(`ADMIN_TOKEN_TTL_SECONDS`)이므로 그보다 오래 쓰는 콘솔은 다시 띄워야 합니다.

## 알아둘 점

- 키를 교체할 때는 `./scripts/gen-keys.sh --force` 후 노드를 재시작하세요 (`docker compose restart participant sequencer mediator`).
  재시작 없는 키 로테이션이 필요하면 `type = jwt-jwks` + `url` 로 IdP 의 JWKS 를 쓰세요.
- 예제 인증서는 자체 서명이며 유효기간은 365일입니다.
- 이 예제는 TLS 를 켜지 않았습니다. 토큰이 평문으로 오가므로 포트를 `127.0.0.1` 에만 바인딩했습니다.
- 인증 대상은 Admin API 뿐입니다. Participant 의 Ledger API(5001/7575)는 인증 없이 열려 있고,
  Sequencer Public API(5008)는 Canton 자체 멤버 인증을 사용합니다.
- 헬스체크는 인증이 없는 별도 gRPC health 포트(5061, 컨테이너 내부)를 사용합니다.
- 3.7.1 에서 `admin-api.max-token-lifetime` (서버 단위 설정)은 토큰을 거부하지 않았고 (HS256 구성에서 확인),
  `auth-services` 항목 안의 `max-token-life` 만 실제로 토큰을 거부했습니다.

## 정리

```sh
docker compose down -v
```
