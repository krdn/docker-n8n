# 프로젝트 수정 사항 보고서
**날짜**: 2025-10-17
**작업자**: Claude Code

## ✅ 적용된 수정 사항

### 1. **Trust Proxy 설정 추가** 🔧
**문제**: Nginx 역프록시를 사용하지만 n8n이 프록시를 신뢰하도록 설정되지 않아 rate limiting과 IP 식별이 제대로 작동하지 않음

**수정**:
- `.env` 파일에 `N8N_PROXY_HOPS=1` 추가
- `docker-compose.yml`의 n8n 서비스에 환경변수 설정 추가

**결과**: ✅ ValidationError 완전히 제거됨 (로그 확인 완료)

---

### 2. **불필요한 방화벽 포트 제거** 🔒
**문제**: n8n과 무관한 포트들이 UFW에 개방되어 보안 위험 존재

**수정**:
```bash
sudo ufw delete allow 27017  # MongoDB
sudo ufw delete allow 3389/tcp  # RDP
sudo ufw delete allow from 192.168.0.0/24 to any port 5432  # PostgreSQL
```

**현재 UFW 상태** (필요한 포트만 개방):
- 22/tcp (SSH)
- 80/tcp (HTTP)
- 443 (HTTPS)

**참고**: MongoDB(27017)와 xrdp(3389)는 별도 서비스로 사용자 요청에 따라 유지됨

---

### 3. **PostgreSQL 포트 바인딩 제거** 🛡️
**문제**: PostgreSQL이 127.0.0.1:5432로 바인딩되어 불필요한 노출 위험

**수정**:
- `docker-compose.yml`에서 PostgreSQL 포트 바인딩 주석 처리
- SSH 터널 사용 가이드 주석 추가

**결과**: PostgreSQL은 이제 Docker 네트워크 내부에서만 접근 가능

**외부 접근 필요 시**:
```bash
ssh -L 5432:localhost:5432 user@server
```

---

### 4. **Nginx OCSP Stapling 경고 제거** ⚙️
**문제**: Let's Encrypt 인증서에 OCSP responder URL이 없어 경고 발생

**수정**:
- `nginx-config/n8n.conf`에서 OCSP stapling 설정 주석 처리
- 설정 파일을 `/etc/nginx/sites-available/n8n`에 복사
- Nginx 재로드

**결과**: ✅ `nginx -t` 경고 제거됨

---

### 5. **환경 변수 파일 권한 강화** 🔐
**문제**: `.env` 파일에 민감한 정보(암호화 키, DB 비밀번호)가 너무 느슨한 권한으로 저장됨

**수정**:
```bash
chmod 600 .env
```

**결과**: 파일 소유자만 읽기/쓰기 가능 (현재: `-rw-------`)

---

### 6. **백업 보관 정책 통일** 📦
**문제**: `backup.sh`와 `update.sh`의 백업 보관 정책이 불일치 (30일 vs 7개)

**수정**:
- `update.sh`의 백업 정리 로직을 30일 기준으로 변경
- 두 스크립트 모두 동일한 정책 적용

**통일된 정책**: 모든 백업 30일간 보관

---

## 📊 검증 결과

### 서비스 상태
```
n8n            Up (healthy)   127.0.0.1:5678->5678/tcp
n8n-postgres   Up (healthy)   5432/tcp (외부 노출 없음)
n8n-redis      Up (healthy)   6379/tcp
n8n-worker     Up (healthy)   5678/tcp
```

### 환경 변수 확인
```
N8N_HOST=krdn-n8n.duckdns.org
WEBHOOK_URL=https://krdn-n8n.duckdns.org
N8N_PROXY_HOPS=1  ✅ (새로 추가됨)
```

### 로그 확인
- ✅ Trust proxy ValidationError 완전히 제거
- ✅ n8n 정상 시작: "n8n ready on ::, port 5678"
- ✅ 헬스체크 성공: `{"status":"ok"}`

### 보안 개선 사항
- ✅ PostgreSQL 외부 접근 차단
- ✅ .env 파일 권한 강화 (600)
- ✅ UFW에서 불필요한 규칙 제거
- ✅ Nginx 설정 최적화

---

## ⚠️ 알림 사항

### n8n 권장 설정 (향후 적용 고려)
n8n 로그에서 다음 deprecation 경고가 표시됩니다:

1. **Task Runners** (권장):
   ```
   N8N_RUNNERS_ENABLED=true
   ```

2. **Manual Executions Offload** (큐 모드 최적화):
   ```
   OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true
   ```

3. **환경 변수 접근 제한** (보안):
   ```
   N8N_BLOCK_ENV_ACCESS_IN_NODE=true
   ```

4. **Git Node Bare Repos** (보안):
   ```
   N8N_GIT_NODE_DISABLE_BARE_REPOS=true
   ```

### 외부 서비스 (n8n 프로젝트와 무관)
다음 서비스들은 사용자 요청에 따라 현재 상태 유지:
- **MongoDB**: 0.0.0.0:27017 (전체 인터넷 노출)
- **xrdp**: 0.0.0.0:3389 (전체 인터넷 노출)

**보안 권고**: 이들 서비스가 필요하지 않다면 중지하거나, 필요하다면 방화벽 규칙으로 접근 제한을 고려하세요.

---

## 📝 변경된 파일 목록

1. `.env` - Trust proxy 설정 추가, 권한 600으로 변경
2. `docker-compose.yml` - Trust proxy 환경변수 추가, PostgreSQL 포트 바인딩 제거
3. `nginx-config/n8n.conf` - OCSP stapling 비활성화
4. `scripts/update.sh` - 백업 보관 정책 30일로 통일
5. `/etc/nginx/sites-available/n8n` - Nginx 설정 업데이트

---

## 🎯 최종 상태

**프로젝트 상태**: ✅ 모든 주요 문제 수정 완료
**보안 수준**: 🟢 개선됨 (n8n 관련 취약점 제거)
**서비스 가용성**: ✅ 모든 서비스 정상 작동
**n8n 버전**: 1.115.3
**SSL 인증서**: 유효 (85일 남음)

---

## 다음 단계 (선택사항)

1. **Worker 스케일링**: 워크로드 증가 시 `docker-compose.yml`에서 worker replicas 증가 고려
2. **n8n 권장 설정 적용**: 위의 deprecation 경고 해결
3. **외부 서비스 보안 강화**: MongoDB와 xrdp 접근 제한 검토
4. **모니터링 설정**: 리소스 사용량 및 로그 모니터링 시스템 구축

---

**작업 완료 시각**: 2025-10-17 14:20 KST
