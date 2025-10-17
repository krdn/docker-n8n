# AI 재현 프롬프트: Production-Ready n8n with Queue Mode

이 문서는 AI (Claude, ChatGPT 등)가 이 프로젝트를 처음부터 재현할 수 있도록 작성된 프롬프트입니다.

---

## 🎯 메인 프롬프트

```
n8n 워크플로우 자동화 플랫폼을 Docker Compose로 구축하는 프로덕션 환경을 만들어주세요.

### 요구사항

#### 1. 아키텍처 설계
- **실행 모드**: Queue 모드 (확장 가능한 구조)
- **서비스 구성**:
  - n8n 메인 서비스: UI/API/Webhook 제공
  - n8n-worker: 백그라운드 워크플로우 실행 전담
  - PostgreSQL 16: 메인 데이터베이스
  - Redis 7: Bull Queue 메시지 브로커
  - Nginx: 리버스 프록시 (시스템 레벨, Docker 외부)

#### 2. 보안 설정
- n8n 포트는 127.0.0.1만 바인딩 (외부 직접 접근 차단)
- PostgreSQL도 127.0.0.1 바인딩
- Redis는 Docker 내부 네트워크만 사용
- Nginx에서 SSL/TLS 종료 (Let's Encrypt 지원)
- 환경변수로 민감 정보 관리
- .env 파일은 .gitignore에 포함
- 암호화 키 자동 생성 및 영속성 보장

#### 3. Docker Compose 구성
**n8n 메인 서비스**:
- 이미지: docker.n8n.io/n8nio/n8n:latest
- 환경변수:
  - EXECUTIONS_MODE=queue
  - Queue 설정 (Redis 연결)
  - PostgreSQL 연결
  - 도메인, Webhook URL
  - 타임존 (Asia/Seoul)
  - NODE_FUNCTION_ALLOW_BUILTIN=crypto,os,fs
- 포트: 127.0.0.1:5678:5678
- 헬스체크: /healthz 엔드포인트
- depends_on: postgres, redis (조건: service_healthy)

**n8n-worker**:
- 같은 이미지 사용
- command: worker
- 환경변수: 메인과 동일한 DB, Queue, 암호화키 설정
  - ⚠️ 중요: NODE_FUNCTION_ALLOW_BUILTIN도 동일하게 설정
- 포트 노출 없음
- 헬스체크: pgrep -f "n8n worker"
- depends_on: postgres, redis, n8n (모두 healthy)

**PostgreSQL 16**:
- 이미지: postgres:16-alpine
- 환경변수: POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, PGDATA
- 포트: 127.0.0.1:5432:5432
- 볼륨: ./data/postgres
- 커스텀 설정 파일 마운트 (postgresql.conf, pg_hba.conf)
- 헬스체크: pg_isready
- shm_size: 128mb

**Redis 7**:
- 이미지: redis:7-alpine
- command: redis-server --appendonly yes --maxmemory 1gb --maxmemory-policy allkeys-lru
- 볼륨: ./data/redis
- 포트 노출 없음 (내부만)
- 헬스체크: redis-cli ping

**네트워크**:
- Bridge 네트워크 생성 (n8n-network)

#### 4. PostgreSQL 설정
**postgresql.conf**:
```conf
listen_addresses = '*'
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB
```

**pg_hba.conf**:
```conf
# Local connections
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust

# Docker network (172.16.0.0/12 범위)
host    all             all             172.16.0.0/12           trust

# 주석으로 SSH 터널 사용법 안내
```

#### 5. Nginx 설정
**n8n.conf**:
- Upstream: 127.0.0.1:5678 (keepalive 64)
- HTTP → HTTPS 리다이렉트 (301)
- HTTPS 서버:
  - SSL/TLS 프로토콜: TLSv1.2, TLSv1.3
  - 최신 Cipher Suite
  - SSL Session 캐싱
  - OCSP Stapling
- Security Headers:
  - HSTS (max-age=63072000)
  - X-Content-Type-Options: nosniff
  - X-Frame-Options: SAMEORIGIN
  - X-XSS-Protection
  - Referrer-Policy
- WebSocket 지원:
  - proxy_set_header Upgrade $http_upgrade
  - proxy_set_header Connection "upgrade"
- Timeouts: 300초
- proxy_buffering off
- client_max_body_size: 50M
- /healthz 엔드포인트 (access_log off)

#### 6. 자동화 스크립트

**backup.sh**:
- PostgreSQL pg_dump 실행
- data/n8n 디렉토리 복사
- .env 파일 백업
- tar.gz 압축
- 30일 이상 백업 자동 삭제
- 컬러 로깅 (green/red)
- 에러 핸들링 (set -e)

**update.sh**:
- Docker 상태 검증
- 업데이트 전 자동 DB 백업
- docker-compose pull
- 이미지 ID 비교 (불필요한 재시작 방지)
- 서비스 중지 → 이미지 정리 → 재시작
- 헬스체크 대기 (최대 60초, 5초 간격)
- 실패 시 자동 롤백 (백업 복원)
- 로그 파일 저장 (logs/update.log)
- 30일 이상 로그 자동 삭제

#### 7. Systemd 자동화

**n8n-backup.timer**:
- OnCalendar: *-*-* 02:00:00
- RandomizedDelaySec: 15min
- Persistent: true

**n8n-backup.service**:
- WorkingDirectory: 프로젝트 경로
- ExecStart: ./scripts/backup.sh

**n8n-update.timer**:
- OnCalendar: Sun *-*-* 03:00:00
- RandomizedDelaySec: 30min
- Persistent: true

**n8n-update.service**:
- WorkingDirectory: 프로젝트 경로
- ExecStart: ./scripts/update.sh

#### 8. 환경변수 파일

**.env**:
```bash
N8N_HOST=krdn-n8n.duckdns.org
N8N_PROTOCOL=https
WEBHOOK_URL=https://krdn-n8n.duckdns.org
TIMEZONE=Asia/Seoul

POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=korea123  # ⚠️ 변경 필요 경고

REDIS_DB=0

# 자동 생성 (openssl rand -hex 32)
N8N_ENCRYPTION_KEY=<64자리 hex>

N8N_BASIC_AUTH_ACTIVE=false
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=korea123  # ⚠️ 변경 필요 경고
```

**.env.example**:
- 실제 값 대신 플레이스홀더 사용
- 주석으로 각 변수 설명

**.gitignore**:
```
.env
data/
backup/
logs/
*.log
.DS_Store
```

#### 9. 문서화 (Markdown)

**CLAUDE.md**:
- 아키텍처 개요
- 주요 명령어 (서비스 관리, 업데이트, 백업, DB 작업, 모니터링)
- Automation 시스템 (systemd 타이머 설명)
- Nginx 설정 가이드
- 성능 튜닝 (Worker 확장, Redis 메모리, PostgreSQL)
- 트러블슈팅 시나리오
- 데이터 영속성 설명
- 보안 노트

**N8N_ARCHITECTURE_GUIDE.md**:
- n8n vs n8n-worker 비교표
- 각 서비스별 핵심 기능 상세 설명
- Queue 모드 동작 원리 (다이어그램 포함)
- Webhook 실행 예시 (1단계 수신 → 2단계 처리)
- 확장성 시나리오 (단일 → 다중 worker)
- 공통점 및 주의사항
- 환경변수 일관성 중요성 강조

**SECURITY_UPDATE_GUIDE.md**:
- 강력한 비밀번호 생성 방법 (openssl rand -base64 24)
- PostgreSQL 비밀번호 변경 절차:
  1. 백업 생성
  2. .env 수정
  3. 서비스 중지
  4. PostgreSQL만 시작
  5. ALTER USER 실행
  6. 전체 재시작
- Basic Auth 활성화 가이드
- 보안 체크리스트
- ⚠️ N8N_ENCRYPTION_KEY 절대 변경 금지 강조

**DATAGRIP_CONNECTION_GUIDE.md**:
- SSH 터널 설정 방법
- DataGrip 연결 설정 스크린샷 가이드
- 테스트 스크립트 (test-ssh-tunnel.sh)

**INSTALLATION_COMPLETE.md**:
- 설치 완료 확인 사항
- 다음 단계 가이드
- 주요 URL 및 포트

**README.md**:
- 프로젝트 개요 및 현재 상태
- 디렉토리 구조 시각화
- 빠른 시작 (4단계)
- 보안 분석 (강점 + 취약점)
- 백업/복구 전체 절차
- 모니터링 및 로그 확인
- 트러블슈팅 시나리오
- 성능 튜닝 가이드
- 🚨 즉시 조치 필요 항목

#### 10. 추가 파일

**ENABLE_AUTOMATION.sh**:
- systemd 파일 존재 확인
- daemon-reload
- enable + start 타이머 (backup, update)
- 타이머 상태 출력 (list-timers)
- 사용법 안내 (수동 실행, 로그 확인)

**nginx-logrotate.conf**:
- daily, rotate 14일
- compress, delaycompress
- postrotate: nginx 시그널 (USR1)

**test-ssh-tunnel.sh**:
- SSH 터널 테스트
- PostgreSQL 연결 확인

#### 11. 디렉토리 구조
```
docker-n8n/
├── docker-compose.yml
├── .env
├── .env.example
├── .gitignore
├── README.md
├── CLAUDE.md
├── N8N_ARCHITECTURE_GUIDE.md
├── SECURITY_UPDATE_GUIDE.md
├── DATAGRIP_CONNECTION_GUIDE.md
├── INSTALLATION_COMPLETE.md
├── ENABLE_AUTOMATION.sh
├── nginx-logrotate.conf
├── test-ssh-tunnel.sh
├── data/
│   ├── n8n/
│   ├── postgres/
│   ├── redis/
│   └── local-files/
├── backup/
├── logs/
├── scripts/
│   ├── backup.sh
│   └── update.sh
├── systemd/
│   ├── n8n-backup.service
│   ├── n8n-backup.timer
│   ├── n8n-update.service
│   └── n8n-update.timer
├── nginx-config/
│   └── n8n.conf
└── postgres-config/
    ├── postgresql.conf
    └── pg_hba.conf
```

#### 12. 중요한 설계 결정 사항

1. **Queue 모드 선택 이유**:
   - 수평 확장 가능 (worker replicas 증가)
   - 메인 서비스와 실행 엔진 분리 (관심사의 분리)
   - 고가용성 (worker 실패해도 다른 worker가 처리)

2. **Localhost 바인딩 이유**:
   - 외부 직접 접근 차단
   - Nginx를 통해서만 접근 (SSL/TLS 종료)
   - PostgreSQL 보안 강화

3. **환경변수 일관성 중요성**:
   - n8n과 worker는 같은 NODE_FUNCTION_ALLOW_BUILTIN 필요
   - 암호화 키 동일해야 credentials 공유 가능
   - DB 연결 정보 동일

4. **자동화 설계 철학**:
   - Zero-downtime 지향 (업데이트 시 백업 → 검증 → 롤백)
   - Idempotent (여러 번 실행해도 안전)
   - Randomized delay (부하 분산)

5. **백업 전략**:
   - Full 백업 (DB + data + .env)
   - 30일 보관 (공간 절약)
   - 압축 (tar.gz)

### 출력 형식

모든 파일을 생성하고, 각 파일의 전체 내용을 제공해주세요.
특히 다음 사항을 반드시 포함:

1. docker-compose.yml에서 healthcheck 모든 서비스에 구현
2. n8n-worker의 NODE_FUNCTION_ALLOW_BUILTIN 설정
3. PostgreSQL 커스텀 설정 파일 마운트
4. Redis 1GB maxmemory 설정
5. Nginx WebSocket 지원 설정
6. 백업 스크립트의 에러 핸들링
7. 업데이트 스크립트의 자동 롤백 로직
8. Systemd 타이머의 RandomizedDelaySec
9. .env에 암호화 키 자동 생성
10. 문서에 보안 경고 및 즉시 조치 항목

각 파일에 주석으로 설명을 추가하고, Markdown 문서에는 이모지와
코드 블록을 활용해 가독성을 높여주세요.
```

---

## 🔧 단계별 재현 프롬프트

AI에게 단계별로 요청하고 싶다면 아래 프롬프트를 순서대로 사용하세요.

### Step 1: 기본 구조 생성

```
Docker Compose 기반 n8n 프로젝트의 기본 구조를 만들어주세요.

1. 디렉토리 구조 생성:
   - docker-compose.yml
   - .env, .env.example
   - .gitignore
   - data/, backup/, logs/, scripts/, systemd/, nginx-config/, postgres-config/

2. docker-compose.yml 작성:
   - n8n 메인 서비스 (queue 모드, localhost:5678)
   - n8n-worker (command: worker)
   - PostgreSQL 16 (localhost:5432)
   - Redis 7 (내부만)
   - 모든 서비스에 healthcheck 구현
   - Bridge 네트워크

3. .env 파일:
   - 도메인, 타임존 설정
   - PostgreSQL 접속 정보
   - Redis DB 번호
   - 암호화 키 자동 생성 (openssl rand -hex 32)
   - Basic Auth 설정

4. .gitignore:
   - .env, data/, backup/, logs/

각 파일의 전체 내용을 제공하고, 주석으로 설명을 추가해주세요.
```

### Step 2: 설정 파일 작성

```
PostgreSQL과 Nginx 설정 파일을 작성해주세요.

1. postgres-config/postgresql.conf:
   - max_connections: 200
   - shared_buffers: 256MB
   - effective_cache_size: 1GB
   - WAL 설정 (1GB ~ 4GB)
   - 성능 튜닝 파라미터

2. postgres-config/pg_hba.conf:
   - Local connections (trust)
   - Docker network (172.16.0.0/12, trust)
   - SSH 터널 사용법 주석

3. nginx-config/n8n.conf:
   - Upstream (127.0.0.1:5678, keepalive 64)
   - HTTP → HTTPS 리다이렉트
   - SSL/TLS 설정 (TLSv1.2, TLSv1.3)
   - Security Headers (HSTS, CSP 등)
   - WebSocket 지원
   - Timeout 300초
   - /healthz 엔드포인트

전체 파일 내용을 주석과 함께 제공해주세요.
```

### Step 3: 자동화 스크립트

```
백업 및 업데이트 자동화 스크립트를 작성해주세요.

1. scripts/backup.sh:
   - PostgreSQL pg_dump
   - data/n8n 디렉토리 복사
   - .env 백업
   - tar.gz 압축
   - 30일 이상 백업 삭제
   - 컬러 로깅 (green/red)
   - set -e (에러 시 중단)

2. scripts/update.sh:
   - Docker 상태 검증
   - 자동 백업
   - 이미지 pull
   - 이미지 ID 비교
   - 서비스 재시작
   - 헬스체크 대기 (60초)
   - 실패 시 롤백
   - 로그 파일 저장

3. systemd 타이머 파일 (4개):
   - n8n-backup.timer (매일 02:00)
   - n8n-backup.service
   - n8n-update.timer (일요일 03:00)
   - n8n-update.service
   - RandomizedDelaySec 포함

모든 스크립트를 bash 모범 사례에 따라 작성하고,
각 섹션에 주석으로 설명을 추가해주세요.
```

### Step 4: 문서화

```
프로젝트 문서를 Markdown으로 작성해주세요.

1. CLAUDE.md:
   - 아키텍처 개요
   - 주요 명령어
   - Automation 시스템
   - 트러블슈팅
   - 보안 노트

2. N8N_ARCHITECTURE_GUIDE.md:
   - n8n vs worker 비교표
   - Queue 모드 동작 원리 (ASCII 다이어그램)
   - 확장성 시나리오
   - 환경변수 일관성 중요성

3. SECURITY_UPDATE_GUIDE.md:
   - 비밀번호 변경 절차
   - Basic Auth 활성화
   - 보안 체크리스트
   - ⚠️ 경고 사항

4. README.md:
   - 프로젝트 개요
   - 빠른 시작 (4단계)
   - 보안 분석
   - 백업/복구 절차
   - 모니터링
   - 트러블슈팅
   - 🚨 즉시 조치 필요 항목

각 문서에 이모지, 코드 블록, 테이블을 활용해
가독성을 높이고, 실행 가능한 명령어를 포함해주세요.
```

### Step 5: 유틸리티 스크립트

```
추가 유틸리티 파일을 작성해주세요.

1. ENABLE_AUTOMATION.sh:
   - systemd 파일 존재 확인
   - daemon-reload
   - 타이머 enable + start
   - 상태 출력 (list-timers)
   - 사용법 안내

2. nginx-logrotate.conf:
   - daily, rotate 14일
   - compress
   - postrotate (nginx reload)

3. test-ssh-tunnel.sh:
   - SSH 터널 테스트
   - PostgreSQL 연결 확인

4. DATAGRIP_CONNECTION_GUIDE.md:
   - SSH 터널 설정 단계
   - DataGrip 설정 가이드

모든 스크립트를 실행 가능한 형태로 작성하고,
각 단계에 설명을 추가해주세요.
```

---

## 🧪 검증 프롬프트

AI가 생성한 결과물을 검증하기 위한 프롬프트:

```
생성한 n8n 프로젝트가 올바른지 검증해주세요.

다음 항목을 확인:

1. ✅ docker-compose.yml:
   - n8n과 worker 모두 NODE_FUNCTION_ALLOW_BUILTIN 설정 있는가?
   - 모든 서비스에 healthcheck 있는가?
   - depends_on에 condition: service_healthy 있는가?
   - n8n 포트가 127.0.0.1:5678로 바인딩 되었는가?
   - PostgreSQL 포트가 127.0.0.1:5432로 바인딩 되었는가?
   - Redis maxmemory 1gb 설정 있는가?

2. ✅ 스크립트:
   - backup.sh에 set -e가 있는가?
   - update.sh에 롤백 로직이 있는가?
   - systemd 타이머에 RandomizedDelaySec가 있는가?

3. ✅ 보안:
   - .env가 .gitignore에 포함되었는가?
   - Nginx에 HSTS 헤더가 있는가?
   - PostgreSQL pg_hba.conf에 trust 인증 사용 중인가?

4. ✅ 문서:
   - README에 즉시 조치 필요 항목이 명시되어 있는가?
   - SECURITY_UPDATE_GUIDE에 비밀번호 변경 절차가 있는가?
   - N8N_ARCHITECTURE_GUIDE에 worker 환경변수 중요성이 설명되어 있는가?

각 항목별로 확인 결과를 제공하고,
누락된 부분이 있다면 수정 방법을 제안해주세요.
```

---

## 🎨 스타일 가이드 프롬프트

문서 작성 스타일을 통일하고 싶다면:

```
모든 Markdown 문서를 다음 스타일 가이드에 맞춰 작성해주세요:

1. 제목:
   - H1: 이모지 + 제목 (예: # 📊 프로젝트 개요)
   - H2: 이모지 + 제목 (예: ## 🔐 보안 분석)
   - H3: 이모지 없음 (예: ### 백업 절차)

2. 코드 블록:
   - 언어 지정 (```bash, ```yaml, ```conf)
   - 주석으로 설명 추가
   - 실행 가능한 형태로 작성

3. 경고/알림:
   - ⚠️ 경고
   - ✅ 완료/양호
   - ❌ 문제/오류
   - 🚨 긴급
   - 💡 팁

4. 리스트:
   - 체크박스 사용 (- [ ] 작업, - [x] 완료)
   - 우선순위 별표 (⭐⭐⭐⭐⭐)

5. 테이블:
   - 헤더에 굵게 표시
   - 정렬 사용 (좌측, 중앙, 우측)

6. 링크:
   - 상대 경로 사용 (./CLAUDE.md)
   - 설명적인 링크 텍스트

7. 섹션 구분:
   - 3개 이상의 대시 (---)

이 스타일 가이드를 따라 모든 문서를 다시 작성해주세요.
```

---

## 📌 핵심 체크리스트

AI가 반드시 구현해야 할 항목:

- [ ] Queue 모드 (EXECUTIONS_MODE=queue)
- [ ] Worker에 NODE_FUNCTION_ALLOW_BUILTIN 설정
- [ ] Localhost 포트 바인딩 (n8n, PostgreSQL)
- [ ] 모든 서비스 healthcheck
- [ ] PostgreSQL 커스텀 설정 (200 connections, 256MB buffers)
- [ ] Redis 1GB maxmemory
- [ ] Nginx WebSocket 지원
- [ ] 백업 스크립트 에러 핸들링 (set -e)
- [ ] 업데이트 스크립트 롤백 로직
- [ ] Systemd RandomizedDelaySec
- [ ] .env에 암호화 키 자동 생성
- [ ] .gitignore에 민감 정보 제외
- [ ] 보안 경고 문서화
- [ ] 즉시 조치 항목 명시
- [ ] 아키텍처 다이어그램
- [ ] 실행 가능한 명령어 예시

---

**문서 버전**: 1.0
**작성 날짜**: 2025-10-17
**대상 AI**: Claude 3.5+, ChatGPT-4+, Gemini Pro+
**예상 재현 시간**: 15-30분
