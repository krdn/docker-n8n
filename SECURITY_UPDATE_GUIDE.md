# 보안 강화 가이드

## ⚠️ 중요: 비밀번호 변경 필수

현재 `.env` 파일에 약한 비밀번호가 사용되고 있습니다. 아래 단계를 따라 변경하세요.

## 1. 강력한 비밀번호 생성

```bash
# PostgreSQL 비밀번호 생성 (32자)
openssl rand -base64 24

# Basic Auth 비밀번호 생성 (32자)
openssl rand -base64 24
```

## 2. 비밀번호 변경 절차

### 2.1 데이터베이스 백업 (필수)
```bash
./scripts/backup.sh
```

### 2.2 .env 파일 수정
```bash
nano .env
```

다음 항목 변경:
- `POSTGRES_PASSWORD=korea123` → 새 비밀번호로 변경
- `N8N_BASIC_AUTH_PASSWORD=korea123` → 새 비밀번호로 변경 (Basic Auth 사용 시)

### 2.3 PostgreSQL 비밀번호 업데이트
```bash
# 서비스 중지
docker-compose down

# PostgreSQL만 시작
docker-compose up -d postgres

# 대기 (10초)
sleep 10

# 비밀번호 변경 (NEW_PASSWORD를 실제 비밀번호로 교체)
docker-compose exec postgres psql -U n8n -d n8n -c "ALTER USER n8n WITH PASSWORD 'NEW_PASSWORD';"

# 전체 서비스 재시작
docker-compose down
docker-compose up -d
```

### 2.4 동작 확인
```bash
# 서비스 상태 확인
docker-compose ps

# 헬스 체크
curl http://localhost:5678/healthz
```

## 3. Basic Authentication 활성화 (선택사항)

추가 보안 계층을 위해 Basic Auth를 활성화할 수 있습니다:

```bash
nano .env
```

다음 항목 변경:
```
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin  # 원하는 사용자명으로 변경
N8N_BASIC_AUTH_PASSWORD=강력한_비밀번호
```

재시작:
```bash
docker-compose restart n8n n8n-worker
```

## 4. 보안 체크리스트

- [ ] PostgreSQL 비밀번호 변경 완료
- [ ] Basic Auth 비밀번호 변경 완료 (사용 시)
- [ ] 백업 파일 생성 확인
- [ ] 서비스 정상 동작 확인
- [ ] `.env` 파일 권한 확인: `chmod 600 .env`
- [ ] 변경된 비밀번호 안전한 곳에 보관

## 주의사항

⚠️ **절대 변경하면 안 되는 값**:
- `N8N_ENCRYPTION_KEY`: 모든 인증 정보가 암호화된 키. 변경 시 모든 credential 손실

⚠️ **SSH 터널 사용 시**:
- DataGrip 등 외부 도구의 저장된 비밀번호도 함께 업데이트 필요
