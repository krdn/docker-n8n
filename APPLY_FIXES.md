# 수정사항 적용 가이드

이 문서는 발견된 문제점들의 수정사항을 안전하게 적용하는 방법을 설명합니다.

## 🔴 즉시 적용 필요 (서비스 재시작 필요)

### 1. Nginx 설정 업데이트
```bash
# Nginx 설정 파일 복사
sudo cp nginx-config/n8n.conf /etc/nginx/sites-available/n8n

# 설정 파일 검증
sudo nginx -t

# Nginx 재시작
sudo systemctl reload nginx
```

**변경 내용**: WebSocket Connection 헤더 충돌 해결 (실시간 workflow 모니터링 안정화)

---

### 2. Docker Compose 서비스 재시작

**주의**: PostgreSQL 보안 설정이 변경되어 인증 방식이 trust → scram-sha-256로 변경됩니다.

```bash
# 현재 서비스 상태 확인
docker-compose ps

# 서비스 중지
docker-compose down

# 서비스 시작 (새로운 설정 적용)
docker-compose up -d

# 헬스 체크 확인
docker-compose ps

# 로그 모니터링 (문제 발생 시)
docker-compose logs -f
```

**변경 내용**:
- Redis: fsync everysec 정책 추가
- PostgreSQL: listen_addresses 제한, 보안 강화
- n8n-worker: healthcheck 안정화

---

## 🟡 주의사항

### PostgreSQL 인증 변경 영향

pg_hba.conf가 `trust` → `scram-sha-256`로 변경되었습니다. 만약 서비스 시작 실패 시:

```bash
# 로그 확인
docker-compose logs postgres

# 인증 오류 발생 시 임시 조치
# pg_hba.conf의 scram-sha-256를 다시 trust로 변경하고 재시작
```

**영구 해결책**:
PostgreSQL 16은 기본적으로 scram-sha-256를 지원합니다. `.env`의 `POSTGRES_PASSWORD`가 올바르게 설정되어 있으면 문제없이 작동합니다.

---

## 🟢 자동 적용 (재시작 불필요)

다음 항목들은 이미 적용되었으며 다음 실행 시 자동으로 사용됩니다:

### 1. update.sh 개선사항
- ✅ 백업 복원 로직 수정
- ✅ 환경변수 검증 추가

### 2. backup.sh 개선사항
- ✅ 디스크 공간 체크 추가
- ✅ 에러 처리 강화
- ✅ 환경변수 검증 추가

### 3. CLAUDE.md 문서
- ✅ Redis 메모리 정보 업데이트

---

## 📊 적용 후 확인사항

### 1. 서비스 헬스 체크
```bash
docker-compose ps
# 모든 서비스가 "healthy" 상태여야 함
```

### 2. WebSocket 연결 테스트
```bash
# n8n 접속 후 workflow 실행
# 실시간 로그가 정상적으로 표시되는지 확인
```

### 3. PostgreSQL 연결 확인
```bash
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT version();"
# 정상 연결되면 PostgreSQL 버전 출력
```

### 4. Redis 설정 확인
```bash
docker-compose exec redis redis-cli CONFIG GET appendfsync
# "everysec" 반환 확인
```

### 5. 백업 스크립트 테스트
```bash
./scripts/backup.sh
# 디스크 공간 체크 및 백업 성공 확인
```

---

## 🚨 롤백 방법

문제 발생 시 이전 상태로 복원:

### Nginx 롤백
```bash
# 이전 설정으로 복원 (백업이 있는 경우)
sudo cp /etc/nginx/sites-available/n8n.backup /etc/nginx/sites-available/n8n
sudo nginx -t
sudo systemctl reload nginx
```

### Docker 서비스 롤백
```bash
# git으로 이전 버전 복원
git checkout HEAD~1 docker-compose.yml postgres-config/

# 서비스 재시작
docker-compose down
docker-compose up -d
```

---

## 📝 성능 모니터링

변경사항 적용 후 다음 항목들을 모니터링하세요:

```bash
# 1. Docker 리소스 사용량
docker stats

# 2. PostgreSQL 성능
docker-compose exec postgres psql -U n8n -d n8n -c "
  SELECT
    pg_size_pretty(pg_database_size('n8n')) as db_size,
    (SELECT count(*) FROM pg_stat_activity) as connections;
"

# 3. Redis 메모리 사용
docker-compose exec redis redis-cli INFO memory | grep used_memory_human

# 4. 서비스 로그 모니터링
docker-compose logs -f --tail=100
```

---

## ✨ 추가 최적화 (선택사항)

시스템 메모리가 8GB 이상인 경우:

### PostgreSQL 추가 튜닝
```bash
# postgres-config/postgresql.conf 편집
shared_buffers = 1GB           # 현재 512MB → 1GB
effective_cache_size = 3GB     # 현재 2GB → 3GB
```

### Redis 메모리 증가
```bash
# docker-compose.yml 편집
command: redis-server --appendonly yes --appendfsync everysec --maxmemory 2gb
```

변경 후 `docker-compose restart postgres redis`로 적용

---

## 📞 문제 발생 시

1. **로그 확인**: `docker-compose logs -f`
2. **서비스 상태**: `docker-compose ps`
3. **디스크 공간**: `df -h`
4. **네트워크**: `docker network inspect docker-n8n_n8n-network`

문제가 지속되면 GitHub Issues에 보고하거나 이전 버전으로 롤백하세요.
