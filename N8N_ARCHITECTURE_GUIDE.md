# n8n vs n8n-worker: 완벽 가이드

현재 설정을 기반으로 두 컨테이너의 차이와 역할을 상세히 설명합니다.

---

## 📋 비교표

| 항목 | n8n (메인) | n8n-worker |
|------|-----------|------------|
| **실행 명령** | `node /usr/local/bin/n8n` | `node /usr/local/bin/n8n worker` |
| **주요 역할** | UI/API 서버 | 백그라운드 작업 실행기 |
| **포트 노출** | ✅ 5678 (Nginx 연결) | ❌ 없음 |
| **웹 UI 제공** | ✅ | ❌ |
| **REST API** | ✅ | ❌ |
| **Webhook 수신** | ✅ | ❌ |
| **워크플로우 실행** | ⚠️ 수동 실행만 (deprecated) | ✅ 자동/예약 실행 |
| **메모리 사용량** | 217MB (높음) | 150MB (중간) |
| **CPU 사용** | 높음 (UI 렌더링) | 낮음 (실행만) |
| **확장성** | 1개만 가능 | 여러 개 가능 |

---

## 🎯 n8n (메인 서비스)

### 핵심 기능

#### 1. 웹 인터페이스 (UI/UX)
- **비주얼 워크플로우 에디터**: 드래그 앤 드롭으로 노드 연결
- **실시간 미리보기**: 각 노드의 실행 결과 즉시 확인
- **테스트 실행**: "Execute Workflow" 버튼으로 수동 테스트
- **Credential 관리**: API 키, OAuth 토큰 등 저장/관리

#### 2. REST API 서버
```bash
# 외부 애플리케이션이 n8n을 제어
GET  /api/v1/workflows        # 워크플로우 목록
POST /api/v1/workflows/123/execute  # 워크플로우 실행
GET  /api/v1/executions       # 실행 이력 조회
```

#### 3. Webhook 엔드포인트
```
# 외부 서비스가 n8n 워크플로우 트리거
https://krdn-n8n.duckdns.org/webhook/uuid-here
https://krdn-n8n.duckdns.org/webhook-test/uuid-here
```

#### 4. Queue Producer (작업 생성자)
- 예약된 워크플로우를 Redis queue에 push
- Webhook 트리거를 queue에 추가
- 작업 우선순위 관리

#### 5. 메인 서비스 전용 환경변수
```yaml
- N8N_HOST=krdn-n8n.duckdns.org    # 도메인 설정
- N8N_PORT=5678                     # 웹 서버 포트
- WEBHOOK_URL=https://...           # Webhook URL
- N8N_BASIC_AUTH_ACTIVE=false       # 인증 설정
```

### 처리 흐름 (메인)
```
사용자 → Nginx (443) → n8n (5678) → UI 렌더링
                                   → API 응답
                                   → Webhook 수신 → Redis Queue에 추가
```

---

## ⚙️ n8n-worker

### 핵심 기능

#### 1. Queue Consumer (작업 소비자)
- Redis queue를 계속 모니터링 (polling)
- 새 작업이 들어오면 즉시 가져와서 실행
- 동시에 여러 워크플로우 병렬 처리

#### 2. 워크플로우 실행 엔진
```
Redis Queue → Worker가 작업 가져옴 → 워크플로우 실행
                                  → 노드별 순차 실행
                                  → 결과 DB 저장
                                  → Queue에서 제거
```

#### 3. 실행 타입별 처리

**✅ Worker가 처리하는 것:**
- ⏰ **Cron/Schedule 트리거**: 정기적 실행
- 🔔 **Webhook 트리거**: 외부 API 호출
- 🔄 **자동 실행**: 다른 워크플로우가 트리거
- 📧 **이메일 트리거**: IMAP 폴링

**❌ Worker가 처리 안 하는 것 (현재 deprecated):**
- 🖱️ **수동 실행**: UI에서 "Execute Workflow" 버튼
  - 메인 서비스가 직접 처리 (queue 우회)
  - 로그 경고: `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` 권장

#### 4. Worker 전용 특징
- **UI 없음**: 웹 인터페이스 미제공
- **API 없음**: REST API 서버 미실행
- **경량화**: UI/API 코드 로드 안 함 → 메모리 절약
- **command: worker**: 시작 명령으로 모드 전환

#### 5. Worker만의 환경변수
```yaml
# 메인과 다른 점: N8N_HOST, WEBHOOK_URL, N8N_BASIC_AUTH 설정 불필요
# 오직 Queue 연결과 워크플로우 실행에만 집중
```

---

## 🔄 Queue 모드 동작 원리

### 전체 아키텍처
```
┌─────────────────────────────────────────────────────────┐
│  사용자/외부 시스템                                        │
└─────────────────┬───────────────────────────────────────┘
                  ↓
         ┌────────────────┐
         │  Nginx (443)   │
         └────────┬───────┘
                  ↓
         ┌────────────────┐
         │  n8n (5678)    │ ← 메인 서비스
         │  - UI/API      │
         │  - Webhook     │
         └────────┬───────┘
                  ↓ (작업 추가)
         ┌────────────────┐
         │  Redis Queue   │ ← Bull Queue (작업 큐)
         │  [Job1, Job2]  │
         └────────┬───────┘
                  ↓ (작업 가져옴)
    ┌─────────────┴──────────────┐
    ↓                            ↓
┌──────────┐              ┌──────────┐
│ Worker-1 │              │ Worker-N │ ← 확장 가능
│ (실행기) │              │ (실행기) │
└────┬─────┘              └────┬─────┘
     ↓                         ↓
┌─────────────────────────────────┐
│  PostgreSQL                      │ ← 실행 결과 저장
│  - 워크플로우 정의               │
│  - 실행 이력                     │
│  - Credentials                   │
└──────────────────────────────────┘
```

### 실제 예시: Webhook 워크플로우 실행

**1단계: Webhook 수신 (n8n 메인)**
```bash
외부 서비스 → POST https://krdn-n8n.duckdns.org/webhook/abc123
             ↓
          Nginx → n8n 메인 (5678)
                   ↓
          Redis에 작업 추가: { workflowId: "abc123", payload: {...} }
                   ↓
          즉시 응답: 200 OK (비동기 처리)
```

**2단계: 작업 처리 (n8n-worker)**
```bash
Worker: Redis 폴링 중...
        ↓
Worker: 새 작업 감지!
        ↓
Worker: 작업 가져오기 (LPOP)
        ↓
Worker: 워크플로우 실행
        ├─ HTTP Request 노드
        ├─ Code 노드 (crypto, os, fs 사용 가능!)
        └─ Send Email 노드
        ↓
Worker: 결과를 PostgreSQL에 저장
        ↓
Worker: Queue에서 작업 제거 (완료)
```

---

## 🚀 확장성 (Scaling)

### 단일 Worker (현재 구성)
```yaml
n8n-worker:
  container_name: n8n-worker  # 1개만
```
- **처리량**: 동시 실행 약 3-5개 워크플로우
- **메모리**: 150MB
- **한계**: CPU 집약적 작업 시 병목

### 다중 Worker (확장 가능)
```yaml
n8n-worker:
  deploy:
    replicas: 3  # 3개 동시 실행
```
- **처리량**: 동시 실행 약 9-15개 워크플로우
- **메모리**: 450MB (150MB × 3)
- **자동 부하 분산**: Redis가 작업 자동 분배
- **고가용성**: 1개 실패해도 나머지 계속 작동

### Worker 추가 시나리오
```
워크플로우 10개 대기 중
├─ Worker-1: Job-1, Job-4, Job-7, Job-10 처리
├─ Worker-2: Job-2, Job-5, Job-8 처리
└─ Worker-3: Job-3, Job-6, Job-9 처리

→ 처리 시간: 1/3로 단축!
```

---

## 💡 공통점

### 1. 동일한 Docker 이미지
```yaml
n8n:        image: docker.n8n.io/n8nio/n8n:latest
n8n-worker: image: docker.n8n.io/n8nio/n8n:latest  # 같은 이미지!
```
- 차이는 **시작 명령어**만: `command: worker`

### 2. 공유 환경변수 (필수 동일)
```yaml
# 양쪽 모두 필요
- DB_TYPE=postgresdb              # 같은 DB 연결
- N8N_ENCRYPTION_KEY=...          # 같은 암호화 키
- NODE_FUNCTION_ALLOW_BUILTIN=... # 같은 모듈 허용 (중요!)
- EXECUTIONS_MODE=queue           # Queue 모드 활성화
```

### 3. 공유 볼륨
```yaml
volumes:
  - ./data/n8n:/home/node/.n8n       # 워크플로우 정의
  - ./data/local-files:/files        # 파일 저장소
```
- Worker도 같은 파일에 접근 가능
- Credential, 워크플로우 정의 공유

---

## ⚠️ 주의사항 및 권장사항

### 1. 환경변수 불일치 문제
```yaml
# ❌ 잘못된 예: Worker에만 설정
n8n-worker:
  environment:
    - SOME_API_KEY=secret123  # 메인에는 없음!

# ✅ 올바른 예: 양쪽 모두 설정
n8n:
  environment:
    - SOME_API_KEY=secret123
n8n-worker:
  environment:
    - SOME_API_KEY=secret123  # 동일!
```

### 2. 수동 실행 설정 (권장)
현재 로그에서 경고 발생:
```
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS -> Running manual executions
in the main instance in scaling mode is deprecated.
```

**해결 방법:**
```yaml
n8n:
  environment:
    - OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true  # 추가!
```
- 메인의 메모리 부담 감소
- 모든 실행을 worker에게 위임

### 3. Worker 리소스 할당
```yaml
n8n-worker:
  deploy:
    resources:
      limits:
        cpus: '2'      # CPU 2코어 제한
        memory: 512M   # 메모리 512MB 제한
```

---

## 🧠 핵심 인사이트

### Queue 모드의 설계 철학
n8n의 queue 모드는 "관심사의 분리(Separation of Concerns)"를 구현합니다. 메인 서비스는 사용자 인터페이스와 외부 통신에만 집중하고, worker는 순수하게 워크플로우 실행에만 집중합니다. 이는 마치 레스토랑에서 주문 접수(프론트)와 요리(백엔드)를 분리하는 것과 같습니다.

### Redis의 역할
Bull Queue는 단순한 메시지 브로커가 아닙니다. 작업 우선순위, 재시도 로직, 실패 처리, 진행률 추적 등 복잡한 작업 관리를 제공합니다. Worker가 크래시해도 Redis에 작업이 남아있어 복구 가능하며, 이는 "최소 1회 실행(At-least-once delivery)" 보장을 제공합니다.

### NODE_FUNCTION_ALLOW_BUILTIN의 중요성
이 설정이 불일치하면 "Heisenbug"가 발생합니다. 개발 중에는 메인 서비스에서 수동 테스트하므로 정상 작동하지만, 프로덕션에서는 worker가 실행하므로 갑자기 `crypto is not allowed` 오류가 발생합니다. 환경변수는 반드시 양쪽에 동일하게 설정해야 합니다.

---

## 📚 추가 자료

### 관련 문서
- [CLAUDE.md](./CLAUDE.md) - 프로젝트 아키텍처 개요
- [SECURITY_UPDATE_GUIDE.md](./SECURITY_UPDATE_GUIDE.md) - 보안 설정 가이드
- [README.md](./README.md) - 전체 설치 및 운영 가이드

### 주요 명령어
```bash
# 서비스 상태 확인
docker-compose ps

# Worker 로그 확인
docker-compose logs -f n8n-worker

# Redis Queue 상태 확인
docker-compose exec redis redis-cli LLEN bull:default:wait

# Worker 3개로 확장
docker-compose up -d --scale n8n-worker=3
```

---

**문서 버전**: 1.0
**마지막 업데이트**: 2025-10-17
**n8n 버전**: 1.115.3
