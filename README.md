● 🚀 n8n Docker 프로젝트 완벽 설명서

  📌 프로젝트 개요

  이 프로젝트는 프로덕션 환경을 위한 엔터프라이즈급 n8n 워크플로우 자동화 플랫폼입니다.

  기본 정보

  - 프로젝트명: n8n Docker 프로덕션 배포
  - 아키텍처: 큐 기반 마이크로서비스 (Queue Mode)
  - 현재 버전: n8n 1.115.3
  - 배포 방식: Docker Compose
  - 도메인: n8n.krdn.kr
  - 상태: ✅ 완전 가동 중 (모든 서비스 healthy)

  ---
  🏗️ 아키텍처 설명

  시스템 구성도

  ┌─────────────────────────────────────────────────┐
  │              인터넷 (HTTPS)                      │
  └───────────────────┬─────────────────────────────┘
                      │
           ┌──────────▼──────────┐
           │  Nginx (호스트)      │  SSL/TLS 종료
           │  Port 443           │  역방향 프록시
           └──────────┬──────────┘
                      │
           ┌──────────▼──────────┐
           │  n8n (주 인스턴스)   │  127.0.0.1:5678
           │  164.7MB 메모리     │  UI/API/Webhook
           └──────────┬──────────┘
                      │
           ┌──────────▼──────────┐
           │  Redis Queue        │  6379 (내부)
           │  1.49MB/1GB         │  Bull Queue
           └──────────┬──────────┘
                      │
           ┌──────────▼──────────┐
           │  n8n-worker         │  워크플로우 실행
           │  137.3MB 메모리     │  동시성: 10
           └──────────┬──────────┘
                      │
           ┌──────────▼──────────┐
           │  PostgreSQL 16      │  127.0.0.1:5432
           │  46.95MB 메모리     │  데이터베이스: 11MB
           └─────────────────────┘

  핵심 아키텍처 결정 사항

  1. 큐 기반 모드 (Queue Mode)
  - 장점: 수평 확장 가능, UI와 실행 분리, 안정성 향상
  - 구현: Redis Bull Queue를 통한 작업 분배
  - 확장성: 워커를 3-5개까지 증설 가능

  2. 마이크로서비스 분리
  - n8n 주 인스턴스: 사용자 인터페이스, API, Webhook 처리
  - n8n-worker: 워크플로우 실행 전용 (백그라운드)
  - 이유: 리소스 격리, 안정성, 성능 최적화

  3. 컨테이너화
  - Docker Compose: 멀티 컨테이너 오케스트레이션
  - 네트워크 격리: 브리지 네트워크 (172.18.0.0/16)
  - 볼륨 마운트: 데이터 영속성 보장

  ---
  🐳 Docker 컨테이너 상세

  1. n8n (메인 인스턴스)

  이미지: docker.n8n.io/n8nio/n8n:latest (1.115.3)
  포트: 127.0.0.1:5678 → 5678 (localhost만 접근 가능)
  메모리: 164.7MB / 15.31GiB (1.05%)
  CPU: 0.67%
  상태: healthy
  IP: 172.18.0.4

  환경 변수 (48개):
  - Queue 설정: EXECUTIONS_MODE=queue
  - 데이터베이스: PostgreSQL 연결 정보
  - 보안: 암호화 키, Basic Auth 설정
  - 성능: N8N_METRICS=true, Node.js 모듈 허용

  역할:
  - 웹 UI 제공 (Workflow 편집기)
  - REST API 엔드포인트
  - Webhook 수신
  - 워크플로우를 Redis 큐에 전송

  ---
  2. n8n-worker (워커)

  이미지: docker.n8n.io/n8nio/n8n:latest (1.115.3)
  커맨드: worker
  메모리: 137.3MB / 15.31GiB (0.88%)
  CPU: 0.17%
  상태: healthy
  IP: 172.18.0.5
  동시성: 10개 워크플로우

  환경 변수 (18개):
  - Queue 설정: Redis 연결 정보
  - 데이터베이스: PostgreSQL (실행 결과 저장)
  - 보안: 동일한 암호화 키 사용

  역할:
  - Redis 큐에서 작업 가져오기
  - 워크플로우 실행 (백그라운드)
  - 실행 결과를 PostgreSQL에 저장
  - 메인 인스턴스와 독립적으로 작동

  확장 방법:
  # docker-compose.yml 수정
  n8n-worker:
    deploy:
      replicas: 3  # 워커 3개로 증설

  ---
  3. PostgreSQL 16

  이미지: postgres:16-alpine
  포트: 127.0.0.1:5432 → 5432
  메모리: 46.95MB / 15.31GiB (0.30%)
  CPU: 3.08%
  데이터베이스 크기: 11MB
  상태: healthy
  IP: 172.18.0.3

  설정 파일: postgres-config/postgresql.conf
  max_connections = 200
  shared_buffers = 512MB
  effective_cache_size = 2GB
  work_mem = 5242kB

  현재 연결 상태:
  - 총 연결: 8/200 (4% 사용)
  - Active: 1개, Idle: 2개, Null: 5개

  저장 데이터:
  - 워크플로우 정의
  - 실행 히스토리
  - 자격 증명 (암호화됨)
  - 설정 데이터

  보안 설정 (pg_hba.conf):
  # 로컬 연결
  local   all   all                   trust
  host    all   all   127.0.0.1/32    trust

  # Docker 네트워크
  host    all   all   172.16.0.0/12   trust

  ---
  4. Redis 7

  이미지: redis:7-alpine
  포트: 6379 (내부 네트워크만)
  메모리: 2.14MB / 15.31GiB (0.01%)
  사용 중 메모리: 1.49MB / 1GB
  CPU: 3.71%
  상태: healthy
  IP: 172.18.0.2

  설정:
  redis-server \
    --appendonly yes \              # AOF 지속성
    --appendfsync everysec \        # 매초 디스크 동기화
    --maxmemory 1gb \               # 최대 메모리 제한
    --maxmemory-policy allkeys-lru  # LRU 제거 정책

  역할:
  - Bull Queue 저장소
  - n8n과 worker 간 메시지 브로커
  - 작업 상태 추적
  - 재시도 메커니즘

  성능 지표:
  - 메모리 파편화 비율: 6.24 (정상)
  - 지속성: AOF 모드 (안전성 우선)

  ---
  🌐 네트워크 아키텍처

  Docker 네트워크

  네트워크명: docker-n8n_n8n-network
  드라이버: bridge
  서브넷: 172.18.0.0/16
  게이트웨이: 172.18.0.1

  컨테이너 IP:
  ├─ n8n-redis:     172.18.0.2
  ├─ n8n-postgres:  172.18.0.3
  ├─ n8n:           172.18.0.4
  └─ n8n-worker:    172.18.0.5

  포트 매핑

  | 서비스        | 내부 포트 | 외부 바인딩         | 접근 범위    |
  |------------|-------|----------------|----------|
  | n8n        | 5678  | 127.0.0.1:5678 | 로컬호스트만   |
  | PostgreSQL | 5432  | 127.0.0.1:5432 | 로컬호스트만   |
  | Redis      | 6379  | 바인딩 없음         | 내부 네트워크만 |
  | Nginx      | 443   | 0.0.0.0:443    | 전체 인터넷   |

  외부 접근 흐름

  1. 사용자 → https://n8n.krdn.kr
  2. Let's Encrypt SSL/TLS 인증서로 암호화
  3. Nginx (호스트의 443 포트)
  4. 프록시 패스 → http://127.0.0.1:5678
  5. n8n 컨테이너 응답
  6. Nginx → 사용자에게 HTTPS로 응답

  ---
  🔒 보안 계층

  1. 네트워크 보안

  계층 1: 방화벽 (UFW)
    ├─ 22/tcp   (SSH)
    ├─ 80/tcp   (HTTP → HTTPS 리다이렉트)
    ├─ 443/tcp  (HTTPS)
    └─ 5432     (PostgreSQL, 192.168.0.0/24만 허용)

  계층 2: Nginx SSL/TLS
    ├─ TLSv1.2, TLSv1.3 only
    ├─ 강력한 암호화 스위트
    └─ HSTS 활성화 (2년)

  계층 3: localhost 바인딩
    ├─ n8n: 127.0.0.1만
    ├─ PostgreSQL: 127.0.0.1만
    └─ Redis: 내부 네트워크만

  계층 4: Docker 네트워크 격리
    └─ 브리지 네트워크 (172.18.0.0/16)

  2. SSL/TLS 인증서

  발급 기관: Let's Encrypt
  도메인: n8n.krdn.kr
  키 타입: ECDSA
  만료일: 2026-01-11 (85일 남음)
  자동 갱신: Certbot systemd timer

  Nginx 보안 헤더:
  Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
  X-Content-Type-Options: nosniff
  X-Frame-Options: SAMEORIGIN
  X-XSS-Protection: 1; mode=block
  Referrer-Policy: no-referrer-when-downgrade

  3. 암호화 및 인증

  n8n 암호화 키:
  N8N_ENCRYPTION_KEY=583b6ebb961bea758b871dee46e198f9f3f70a3d8f5eafb760d01534274bf83b
  ⚠️ 절대 변경 금지 - 모든 자격 증명이 이 키로 암호화됨

  Basic Authentication (현재 비활성화):
  N8N_BASIC_AUTH_ACTIVE=false
  N8N_BASIC_AUTH_USER=admin
  N8N_BASIC_AUTH_PASSWORD=korea123

  ---
  💾 데이터 관리

  데이터 저장소

  data/
  ├── n8n/                    # n8n 애플리케이션 데이터
  │   ├── config              # 설정 파일 (권한: 0644 → 0600 권장)
  │   ├── binaryData/         # 바이너리 데이터
  │   ├── nodes/              # 커스텀 노드
  │   ├── ssh/                # SSH 키
  │   └── *.log               # 이벤트 로그
  ├── postgres/pgdata/        # PostgreSQL 데이터 (11MB)
  ├── redis/                  # Redis AOF 파일
  │   ├── appendonlydir/
  │   └── dump.rdb
  └── local-files/            # 워크플로우 업로드 파일

  백업 시스템

  1. 전체 백업 (Daily)
  스케줄: 매일 02:00 AM (±15분 랜덤 지연)
  서비스: n8n-backup.timer + n8n-backup.service
  스크립트: scripts/backup.sh
  내용:
    - PostgreSQL 전체 덤프
    - data/n8n/ 디렉터리
    - .env 파일 (암호화 키 포함)
  압축: tar.gz
  보관 기간: 30일
  위치: backup/n8n_full_backup_YYYYMMDD_HHMMSS.tar.gz

  현재 백업 상황:
  backup/
  ├── n8n_full_backup_20251017_020213.tar.gz  (73.9KB) ← 최신
  ├── n8n_full_backup_20251016_021453.tar.gz  (48.3KB)
  ├── n8n_full_backup_20251015_021013.tar.gz  (17.6KB)
  ├── n8n_full_backup_20251014_020524.tar.gz  (17.6KB)
  └── n8n_full_backup_20251013_135518.tar.gz  (15.2KB)

  총 5개 백업, 332KB

  2. 업데이트 백업 (Weekly)
  스케줄: 매주 일요일 03:00 AM (±30분)
  서비스: n8n-update.timer + n8n-update.service
  스크립트: scripts/update.sh
  내용: PostgreSQL 덤프만
  압축: gzip
  보관 기간: 최근 7개

  백업 스크립트 기능

  scripts/backup.sh:
  ✓ 디스크 공간 확인 (최소 1GB 필요)
  ✓ 환경 변수 검증 (암호화 키 확인)
  ✓ PostgreSQL pg_dump
  ✓ n8n 데이터 복사
  ✓ .env 파일 백업
  ✓ tar.gz 압축
  ✓ 30일 이상 백업 자동 삭제
  ✓ 에러 발생 시 중단 (set -e)
  ✓ 상세 로깅 (색상 출력)

  ---
  🔄 자동화 시스템

  Systemd 타이머

  설치 위치: /etc/systemd/system/

  n8n-backup.service
  n8n-backup.timer      ← 매일 02:00, Persistent=true
  n8n-update.service
  n8n-update.timer      ← 매주 일요일 03:00

  타이머 구성 (n8n-backup.timer):
  [Timer]
  OnCalendar=*-*-* 02:00:00           # 매일 02:00
  Persistent=true                      # 부팅 후 놓친 작업 실행
  RandomizedDelaySec=15m               # ±15분 랜덤 지연

  [Install]
  WantedBy=timers.target

  서비스 구성 (n8n-backup.service):
  [Service]
  Type=oneshot
  User=gon
  WorkingDirectory=/home/gon/docker-n8n
  ExecStart=/home/gon/docker-n8n/scripts/backup.sh
  NoNewPrivileges=true
  PrivateTmp=true
  StandardOutput=journal

  현재 타이머 상태:
  n8n-backup.timer
    다음 실행: 2025-10-18 02:04:44 (12시간 후)
    마지막 실행: 2025-10-17 02:02:13 (11시간 전)

  n8n-update.timer
    다음 실행: 2025-10-19 03:06:33 (1일 13시간 후)

  업데이트 스크립트 상세

  scripts/update.sh 워크플로우:

  1. ✓ Docker 실행 확인
  2. ✓ 백업 생성 (롤백용)
  3. ✓ 이미지 pull (docker-compose pull)
  4. ✓ 이미지 ID 비교
     ├─ 변경 없음 → 종료
     └─ 변경 있음 → 계속
  5. ✓ 서비스 중지 (docker-compose down)
  6. ✓ 구 이미지 정리 (docker image prune)
  7. ✓ 서비스 시작 (docker-compose up -d)
  8. ✓ 헬스체크 대기 (최대 60초)
     ├─ 성공 → 완료
     └─ 실패 → 롤백 시도
  9. ✓ 버전 확인 및 로깅

  자동 롤백 기능:
  if 서비스 시작 실패; then
    1. 백업 파일 확인
    2. docker-compose down
    3. PostgreSQL만 시작
    4. 데이터베이스 복원
    5. 전체 서비스 재시작
    6. 에러 로그 출력
  fi

  ---
  ⚙️ 환경 변수 전체

  .env 파일 구조

  # ===== 도메인 설정 =====
  N8N_HOST=n8n.krdn.kr
  N8N_PROTOCOL=https
  WEBHOOK_URL=https://n8n.krdn.kr

  # ===== 타임존 =====
  TIMEZONE=Asia/Seoul

  # ===== PostgreSQL =====
  POSTGRES_DB=n8n
  POSTGRES_USER=n8n
  POSTGRES_PASSWORD=hCSGG48nmiaaUkCIl9WW9yRO+Bc5Iq2r  # 강력한 비밀번호

  # ===== Redis =====
  REDIS_DB=0

  # ===== n8n 암호화 (절대 변경 금지!) =====
  N8N_ENCRYPTION_KEY=583b6ebb961bea758b871dee46e198f9f3f70a3d8f5eafb760d01534274bf83b

  # ===== Basic Auth (비활성화 중) =====
  N8N_BASIC_AUTH_ACTIVE=false
  N8N_BASIC_AUTH_USER=admin
  N8N_BASIC_AUTH_PASSWORD=kw0AnUrZQWDozQZzzf7QHasdVT6t+0Cq

  docker-compose.yml 환경 변수

  n8n 서비스 (48개 환경 변수):
  - N8N_HOST, N8N_PORT, N8N_PROTOCOL
  - WEBHOOK_URL
  - TIMEZONE (GENERIC_TIMEZONE, TZ)
  - DB_TYPE=postgresdb
  - DB_POSTGRESDB_* (호스트, 포트, 사용자, 비밀번호)
  - N8N_ENCRYPTION_KEY
  - EXECUTIONS_MODE=queue
  - QUEUE_BULL_REDIS_* (호스트, 포트, DB)
  - N8N_METRICS=true
  - NODE_FUNCTION_ALLOW_BUILTIN=crypto,os,fs

  n8n-worker (18개 환경 변수):
  - NODE_ENV=production
  - TIMEZONE (GENERIC_TIMEZONE, TZ)
  - DB_POSTGRESDB_* (동일 설정)
  - N8N_ENCRYPTION_KEY (동일)
  - EXECUTIONS_MODE=queue
  - QUEUE_BULL_REDIS_* (동일)
  - NODE_FUNCTION_ALLOW_BUILTIN=crypto,os,fs

  ---
  📊 성능 및 리소스

  현재 리소스 사용량

  시스템 총 메모리: 15.31 GiB
  Docker 총 사용량: 418 MB (2.7%)
  총 CPU 사용량: 4.68%
  디스크 사용량: 38GB / 233GB (18%)

  컨테이너별:
  ┌──────────────┬────────────┬────────┬──────────┐
  │ 컨테이너     │ 메모리     │ CPU    │ 상태     │
  ├──────────────┼────────────┼────────┼──────────┤
  │ n8n          │ 164.7 MB   │ 0.67%  │ healthy  │
  │ n8n-worker   │ 137.3 MB   │ 0.17%  │ healthy  │
  │ postgres     │  46.95 MB  │ 3.08%  │ healthy  │
  │ redis        │   2.14 MB  │ 3.71%  │ healthy  │
  └──────────────┴────────────┴────────┴──────────┘

  PostgreSQL 성능 튜닝

  postgresql.conf 설정:
  max_connections = 200
  shared_buffers = 512MB          # RAM의 25%
  effective_cache_size = 2GB      # RAM의 50%
  maintenance_work_mem = 128MB
  work_mem = 5242kB
  random_page_cost = 1.1          # SSD 최적화
  effective_io_concurrency = 200

  WAL (Write-Ahead Logging):
  wal_buffers = 16MB
  min_wal_size = 1GB
  max_wal_size = 4GB
  checkpoint_completion_target = 0.9

  Redis 메모리 관리

  최대 메모리: 1GB
  현재 사용: 1.49MB (0.15%)
  메모리 정책: allkeys-lru (가장 오래된 키 제거)
  지속성: AOF (everysec)
  파편화 비율: 6.24 (정상)

  확장성 고려사항

  워커 수평 확장:
  # 현재: 1개 워커
  메모리: 137.3MB
  동시성: 10개 워크플로우

  # 3개 워커로 확장 시
  총 메모리: ~412MB (137.3MB × 3)
  동시성: 30개 워크플로우
  Redis 부하: 적정 수준 (1GB 제한)

  병목 지점 분석:
  1. Redis: 1GB 제한 (여유 충분, 1.49MB 사용 중)
  2. PostgreSQL: 200 연결 (8개 사용 중, 여유 충분)
  3. 네트워크: Bridge 네트워크 (충분)
  4. 디스크: 183GB 여유 (충분)

  결론: 워커 5개까지 증설 가능 (메모리 ~750MB 추가 필요)

  ---
  📁 프로젝트 구조

  docker-n8n/                     # 프로젝트 루트
  │
  ├── 핵심 설정 파일
  │   ├── docker-compose.yml      # Docker Compose 정의
  │   ├── .env                    # 환경 변수 (비밀번호, 암호화 키)
  │   └── .env.example            # 환경 변수 템플릿
  │
  ├── 데이터 디렉터리 (영속성)
  │   ├── data/n8n/               # n8n 애플리케이션 데이터
  │   ├── data/postgres/          # PostgreSQL 데이터베이스
  │   ├── data/redis/             # Redis AOF 파일
  │   └── data/local-files/       # 워크플로우 업로드 파일
  │
  ├── 백업
  │   └── backup/                 # 자동 백업 저장소
  │       ├── n8n_full_backup_*.tar.gz  (5개)
  │       └── n8n_backup_*.sql.gz       (4개)
  │
  ├── 스크립트
  │   └── scripts/
  │       ├── backup.sh           # 백업 자동화 스크립트
  │       └── update.sh           # 업데이트 자동화 스크립트
  │
  ├── 시스템 설정
  │   ├── systemd/                # Systemd 타이머 정의
  │   │   ├── n8n-backup.{service,timer}
  │   │   └── n8n-update.{service,timer}
  │   ├── nginx-config/           # Nginx 설정
  │   │   └── n8n.conf
  │   └── postgres-config/        # PostgreSQL 설정
  │       ├── postgresql.conf
  │       └── pg_hba.conf
  │
  ├── 로그
  │   └── logs/
  │       └── update.log          # 업데이트 로그
  │
  └── 문서화
      ├── CLAUDE.md               # Claude Code 프로젝트 가이드 ⭐
      ├── README.md               # 메인 문서 (한글, 깨짐)
      ├── N8N_ARCHITECTURE_GUIDE.md     # 아키텍처 상세 설명
      ├── SECURITY_UPDATE_GUIDE.md      # 보안 업데이트 가이드
      ├── DATAGRIP_CONNECTION_GUIDE.md  # DataGrip SSH 터널 가이드
      ├── INSTALLATION_COMPLETE.md      # 설치 완료 보고서
      └── AI_RECREATION_PROMPT.md       # AI 재생성 프롬프트

  ---
  🛠️ 주요 명령어

  서비스 관리

  # 시작/중지
  docker-compose up -d              # 백그라운드 시작
  docker-compose down               # 전체 중지

  # 상태 확인
  docker-compose ps                 # 컨테이너 상태
  docker stats --no-stream          # 리소스 사용량
  docker-compose logs -f n8n        # 실시간 로그
  docker-compose logs -f n8n-worker # 워커 로그

  # 재시작
  docker-compose restart n8n        # n8n만 재시작
  docker-compose restart            # 전체 재시작

  백업/복원

  # 수동 백업
  ./scripts/backup.sh

  # 수동 업데이트
  ./scripts/update.sh

  # 자동화 활성화 (타이머 설정)
  sudo bash ENABLE_AUTOMATION.sh

  # 타이머 상태 확인
  sudo systemctl list-timers n8n-*

  # 백업 복원 (예시)
  cd backup
  tar -xzf n8n_full_backup_20251017_020213.tar.gz
  # README.md의 복원 절차 참조

  데이터베이스 작업

  # PostgreSQL 접속
  docker-compose exec postgres psql -U n8n -d n8n

  # 데이터베이스 크기 확인
  docker-compose exec -T postgres psql -U n8n -d n8n -c \
    "SELECT pg_size_pretty(pg_database_size('n8n'));"

  # 연결 상태 확인
  docker-compose exec -T postgres psql -U n8n -d n8n -c \
    "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

  # VACUUM (성능 최적화)
  docker-compose exec postgres psql -U n8n -d n8n -c "VACUUM ANALYZE;"

  # 수동 백업
  docker-compose exec -T postgres pg_dump -U n8n n8n > manual_backup.sql

  Redis 작업

  # Redis CLI 접속
  docker-compose exec redis redis-cli

  # 메모리 사용량 확인
  docker-compose exec -T redis redis-cli INFO memory | grep used_memory_human

  # 큐 상태 확인
  docker-compose exec redis redis-cli LLEN bull:n8n:default

  # PING 테스트
  docker-compose exec redis redis-cli ping

  헬스체크

  # n8n 헬스체크
  curl http://localhost:5678/healthz
  # 응답: {"status":"ok"}

  # PostgreSQL 헬스체크
  docker-compose exec postgres pg_isready -U n8n

  # Redis 헬스체크
  docker-compose exec redis redis-cli ping

  # 모든 서비스 헬스체크
  docker-compose ps | grep healthy

  Nginx 관리

  # 설정 테스트
  sudo nginx -t

  # 설정 적용 (재시작 없이)
  sudo systemctl reload nginx

  # Nginx 상태 확인
  sudo systemctl status nginx

  # Nginx 로그 확인
  sudo tail -f /var/log/nginx/n8n-access.log
  sudo tail -f /var/log/nginx/n8n-error.log

  ---
  🎯 핵심 기술적 의사결정

  1. Queue Mode를 선택한 이유

  Simple Mode vs Queue Mode:

  | 특성     | Simple Mode       | Queue Mode (선택됨) |
  |--------|-------------------|------------------|
  | 확장성    | ❌ 단일 인스턴스만        | ✅ 워커 수평 확장 가능    |
  | 안정성    | ⚠️ UI 크래시 시 실행 중단 | ✅ UI와 실행 분리      |
  | 리소스 관리 | ⚠️ UI와 실행이 리소스 경쟁 | ✅ 독립적 리소스 할당     |
  | 복잡도    | ✅ 간단              | ⚠️ Redis 추가 필요   |
  | 비용     | ✅ 낮음              | ⚠️ Redis 메모리 필요  |

  결정: 프로덕션 환경에서는 안정성과 확장성이 우선 → Queue Mode

  ---
  2. NODE_FUNCTION_ALLOW_BUILTIN 설정의 중요성

  문제: Code Node에서 crypto, fs 등 Node.js 빌트인 모듈 사용 불가

  증상:
  // Code Node에서
  const crypto = require('crypto');  // ❌ Error: crypto is not allowed

  해결:
  # docker-compose.yml - n8n AND n8n-worker 둘 다 필요!
  environment:
    - NODE_FUNCTION_ALLOW_BUILTIN=crypto,os,fs

  중요: 워커에도 동일한 설정이 필요함 (실행은 워커에서 발생)

  ---
  3. PostgreSQL Trust 인증의 트레이드오프

  현재 설정 (pg_hba.conf):
  host all all 172.16.0.0/12 trust  # 비밀번호 없이 접속 허용

  장점:
  - Docker 컨테이너 간 연결 간소화
  - 환경 변수 관리 단순화

  단점:
  - Docker 네트워크 내부 보안 약화
  - 컨테이너 침해 시 데이터베이스 접근 가능

  권장:
  host all all 172.16.0.0/12 scram-sha-256  # 비밀번호 인증 강제

  ---
  4. Localhost 바인딩의 보안 효과

  ports:
    - "127.0.0.1:5678:5678"  # ✅ 로컬호스트만
    # - "5678:5678"          # ❌ 전체 네트워크 노출

  효과:
  - n8n 웹 UI를 직접 접근 불가
  - 반드시 Nginx를 통해서만 접근
  - SSL/TLS 강제 적용
  - 보안 헤더 강제 적용

  ---
  5. systemd vs cron의 선택

  선택: systemd timers

  이유:
  systemd 장점:
  ✓ Persistent=true → 부팅 중 놓친 작업 자동 실행
  ✓ RandomizedDelaySec → 서버 부하 분산
  ✓ journalctl 통합 로깅
  ✓ 의존성 관리 (Requires=docker.service)
  ✓ 보안 옵션 (NoNewPrivileges, PrivateTmp)

  cron 단점:
  ✗ 부팅 중 놓친 작업 실행 안 함
  ✗ 로깅 수동 설정 필요
  ✗ 보안 옵션 부족

  ---
  🚨 현재 알려진 문제점

  1. [중요] Express Trust Proxy 미설정

  증상:
  ValidationError: The 'X-Forwarded-For' header is set but the Express 'trust proxy' setting is false

  영향:
  - Rate limiting 오작동
  - 클라이언트 IP 추적 불가
  - 로그에 모든 요청이 127.0.0.1로 기록됨

  해결 방법:
  # docker-compose.yml - n8n 서비스에 추가
  environment:
    - N8N_PROXY_HOPS=1

  ---
  2. [보안] 불필요한 방화벽 포트

  27017/tcp    ALLOW    Anywhere    # MongoDB (사용 안 함)
  3389/tcp     ALLOW    Anywhere    # RDP (Linux에서 불필요)

  해결:
  sudo ufw delete allow 27017
  sudo ufw delete allow 3389/tcp

  ---
  3. [경고] Deprecation 경고

  n8n 1.115.3에서 여러 기능이 곧 변경됨:

  추가 권장 환경 변수:
  # .env에 추가
  N8N_RUNNERS_ENABLED=true
  N8N_BLOCK_ENV_ACCESS_IN_NODE=false
  N8N_GIT_NODE_DISABLE_BARE_REPOS=true
  OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true

  ---
  💡 베스트 프랙티스

  1. 암호화 키 관리

  # ✅ 올바른 방법
  # 1. 초기 생성
  openssl rand -base64 32 > encryption_key.txt

  # 2. .env에 저장
  echo "N8N_ENCRYPTION_KEY=$(cat encryption_key.txt)" >> .env

  # 3. 안전한 곳에 백업 (외부 저장소)
  cp encryption_key.txt /secure/backup/location/

  # ❌ 절대 하지 말 것
  # - 암호화 키 변경 (모든 자격 증명 손실)
  # - Git에 커밋
  # - 평문 공유

  ---
  2. 백업 복원 절차

  # 1. 서비스 중지
  docker-compose down

  # 2. 백업 압축 해제
  cd backup
  tar -xzf n8n_full_backup_20251017_020213.tar.gz

  # 3. 데이터 복원
  cd ..
  rm -rf data/n8n data/postgres
  cp -r backup/n8n_full_backup_*_temp/n8n_data data/n8n

  # 4. .env 복원 (필요시)
  cp backup/n8n_full_backup_*_temp/env_backup .env

  # 5. PostgreSQL 복원
  docker-compose up -d postgres
  sleep 10
  docker-compose exec -T postgres psql -U n8n -d postgres -c "DROP DATABASE IF EXISTS n8n;"
  docker-compose exec -T postgres psql -U n8n -d postgres -c "CREATE DATABASE n8n;"
  cat backup/n8n_full_backup_*_temp/database.sql | \
    docker-compose exec -T postgres psql -U n8n -d n8n

  # 6. 전체 서비스 시작
  docker-compose up -d

  # 7. 헬스체크
  docker-compose ps
  curl http://localhost:5678/healthz

  ---
  3. 워커 확장 절차

  # 1. docker-compose.yml 수정
  nano docker-compose.yml

  # n8n-worker 섹션 수정:
  n8n-worker:
    image: docker.n8n.io/n8nio/n8n:latest
    deploy:
      replicas: 3  # 워커 3개로 증설
    # ... 나머지 설정 동일

  # 2. 서비스 재시작
  docker-compose up -d --scale n8n-worker=3

  # 3. 확인
  docker-compose ps | grep worker
  # 출력:
  # n8n-worker_1
  # n8n-worker_2
  # n8n-worker_3

  # 4. 워커별 리소스 확인
  docker stats | grep worker

  ---
  📚 문서화 자산

  프로젝트에는 6개의 상세 가이드 문서가 포함되어 있습니다:

  1. CLAUDE.md (8KB) ⭐ 최우선 참고 문서

  - Claude Code를 위한 프로젝트 가이드
  - 아키텍처 개요
  - 주요 명령어
  - 트러블슈팅

  2. N8N_ARCHITECTURE_GUIDE.md (12KB)

  - n8n vs worker 역할 상세 비교
  - Queue Mode 작동 원리
  - Bull Queue 메커니즘
  - 성능 튜닝 가이드

  3. SECURITY_UPDATE_GUIDE.md (4KB)

  - 비밀번호 변경 단계별 절차
  - PostgreSQL 비밀번호 업데이트
  - Basic Auth 활성화 방법

  4. DATAGRIP_CONNECTION_GUIDE.md (12KB)

  - SSH 터널링을 통한 PostgreSQL 접속
  - DataGrip 설정 스크린샷
  - 포트 포워딩 설정

  5. INSTALLATION_COMPLETE.md (8KB)

  - 초기 설치 완료 보고서
  - 설정 검증 체크리스트
  - 배포 후 확인 사항

  6. AI_RECREATION_PROMPT.md

  - AI를 사용한 프로젝트 재생성 프롬프트
  - 전체 아키텍처 설명

  ---
  🔍 트러블슈팅

  서비스가 시작되지 않을 때

  # 1. Docker 상태 확인
  sudo systemctl status docker

  # 2. 로그 확인
  docker-compose logs -f

  # 3. 디스크 공간 확인
  df -h

  # 4. 컨테이너 강제 재생성
  docker-compose down
  docker-compose up -d --force-recreate

  # 5. 이미지 재다운로드
  docker-compose pull
  docker-compose up -d

  워크플로우가 실행되지 않을 때

  # 1. Redis 연결 확인
  docker-compose exec redis redis-cli ping
  # 응답: PONG

  # 2. 워커 로그 확인
  docker-compose logs -f n8n-worker

  # 3. 큐 상태 확인
  docker-compose exec redis redis-cli LLEN bull:n8n:default

  # 4. 워커 재시작
  docker-compose restart n8n-worker

  데이터베이스 연결 오류

  # 1. PostgreSQL 상태 확인
  docker-compose exec postgres pg_isready -U n8n

  # 2. 연결 수 확인
  docker-compose exec -T postgres psql -U n8n -d n8n -c \
    "SELECT count(*) FROM pg_stat_activity;"

  # 3. max_connections 초과 시
  docker-compose restart postgres

  # 4. 비밀번호 확인
  cat .env | grep POSTGRES_PASSWORD

  SSL 인증서 갱신 실패

  # 1. Certbot 상태 확인
  sudo certbot certificates

  # 2. 수동 갱신
  sudo certbot renew --nginx

  # 3. Nginx 설정 테스트
  sudo nginx -t

  # 4. Nginx 재시작
  sudo systemctl reload nginx

  # 5. 갱신 타이머 확인
  sudo systemctl list-timers | grep certbot

  ---
  ★ Insight ─────────────────────────────────────
  - 마이크로서비스 분리의 가치: n8n과 worker를 분리함으로써 UI 크래시가 실행 중인 워크플로우에 영향을 주지 않습니다. 이는 "Separation of Concerns" 원칙의 실용적 적용입니다.
  - 자동화의 중요성: systemd timers를 통한 백업/업데이트 자동화는 운영 부담을 크게 줄입니다. Persistent=true 옵션은 서버 재부팅 후에도 놓친 작업을 자동 실행하여 안정성을 높입니다.
  - 보안 계층화: 네트워크 격리(localhost 바인딩) → SSL/TLS (Nginx) → 방화벽 (UFW) → Docker 네트워크 격리 → 암호화 (N8N_ENCRYPTION_KEY)의 5단계 보안은 "Defense in Depth" 전략을 구현합니다.
  ─────────────────────────────────────────────────

● ---
  📊 요약

  이 프로젝트는 엔터프라이즈급 n8n 워크플로우 자동화 플랫폼으로, 다음과 같은 특징을 가집니다:

  ✅ 강점

  1. Queue 기반 아키텍처 - 수평 확장 가능, UI와 실행 분리
  2. 완전 자동화 - 백업/업데이트 systemd timers
  3. 5단계 보안 - 네트워크 격리, SSL/TLS, 방화벽, Docker, 암호화
  4. 상세한 문서화 - 6개 가이드 문서, CLAUDE.md
  5. 안정적 운영 - 모든 서비스 healthy, 리소스 2.7% 사용

  ⚠️ 개선 필요

  1. Express Trust Proxy 설정 (Rate limiting 오작동)
  2. 불필요한 방화벽 포트 차단 (MongoDB, RDP)
  3. Deprecation 경고 해결 (향후 호환성)
  4. 설정 파일 권한 강화 (0644 → 0600)

  📈 확장 가능성

  - 현재 리소스 사용량: 매우 낮음 (2.7%)
  - 워커 확장 가능: 1개 → 5개 (메모리 750MB 추가)
  - 디스크 여유: 183GB (충분)
  - 데이터베이스: 11MB / 200 연결 중 8개 사용

  추가 질문이나 수정이 필요하시면 말씀해 주세요!