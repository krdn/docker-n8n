# n8n 서버 마이그레이션 가이드

이 문서는 현재 서버의 n8n을 새 서버로 이전하는 단계별 가이드입니다.

---

## 준비된 파일

현재 서버에서 준비된 파일:

| 파일 | 위치 | 용도 |
|------|------|------|
| 프로젝트 압축 | `/home/gon/docker-n8n-project.tar.gz` | 설정 파일 포함 |
| 최신 백업 | `/home/gon/docker-n8n/backup/n8n_full_backup_20251125_133809.tar.gz` | 데이터 복원용 |

---

## 1단계: 파일 전송 (현재 서버에서 실행)

```bash
# 새 서버 정보 설정
NEW_SERVER_IP="새서버IP"
NEW_SERVER_USER="gon"

# 1. 프로젝트 파일 전송
scp /home/gon/docker-n8n-project.tar.gz ${NEW_SERVER_USER}@${NEW_SERVER_IP}:/home/${NEW_SERVER_USER}/

# 2. 최신 백업 파일 전송
scp /home/gon/docker-n8n/backup/n8n_full_backup_20251125_133809.tar.gz \
    ${NEW_SERVER_USER}@${NEW_SERVER_IP}:/home/${NEW_SERVER_USER}/
```

---

## 2단계: 새 서버 기본 설정

### 2.1 필수 패키지 설치

```bash
# 시스템 업데이트
sudo apt-get update && sudo apt-get upgrade -y

# Docker 설치
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 새 세션 시작 (docker 그룹 적용)
newgrp docker

# Docker Compose 확인
docker compose version

# 기타 필수 패키지
sudo apt-get install -y nginx certbot python3-certbot-nginx curl wget
```

### 2.2 방화벽 설정

```bash
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status
```

---

## 3단계: 프로젝트 파일 추출

```bash
cd /home/gon

# 프로젝트 파일 추출
tar -xzvf docker-n8n-project.tar.gz

# 백업 파일 이동
mkdir -p /home/gon/docker-n8n/backup
mv n8n_full_backup_20251125_133809.tar.gz /home/gon/docker-n8n/backup/

# 백업 파일 추출
cd /home/gon/docker-n8n/backup
tar -xzvf n8n_full_backup_20251125_133809.tar.gz
```

---

## 4단계: 환경 설정

```bash
cd /home/gon/docker-n8n

# 백업에서 .env 파일 복원
cp backup/env_backup .env

# 스크립트 권한 설정
chmod +x scripts/*.sh
```

### 중요: 환경변수 확인

```bash
cat .env
```

**절대 변경하지 말 것:**
- `N8N_ENCRYPTION_KEY` - 변경 시 모든 자격증명 복호화 불가!

---

## 5단계: 데이터 복원

### 5.1 n8n 데이터 복원

```bash
cd /home/gon/docker-n8n

# 데이터 디렉토리 생성
mkdir -p data/{n8n,postgres,redis,local-files}

# n8n 데이터 복원
cp -r backup/n8n_data/* data/n8n/

# 권한 설정
sudo chown -R 1000:1000 data/n8n
```

### 5.2 데이터베이스 시작 및 복원

```bash
# PostgreSQL과 Redis만 먼저 시작
docker compose up -d postgres redis

# 헬스체크 대기 (30초)
echo "데이터베이스 시작 대기..."
sleep 30

# 상태 확인
docker compose ps

# PostgreSQL 덤프 복원
docker compose exec -T postgres psql -U n8n -d n8n < backup/database.sql

# 복원 확인
docker compose exec postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity;"
```

### 5.3 전체 서비스 시작

```bash
# 모든 서비스 시작
docker compose up -d

# 헬스체크 (모두 healthy여야 함)
docker compose ps

# n8n 응답 확인
curl http://localhost:5678/healthz
```

---

## 6단계: Nginx 설정

### 6.1 설정 파일 복사

```bash
# 설정 파일 복사
sudo cp /home/gon/docker-n8n/nginx-config/n8n.conf /etc/nginx/sites-available/n8n

# 심볼릭 링크
sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# 기본 설정 제거
sudo rm -f /etc/nginx/sites-enabled/default

# 설정 검증
sudo nginx -t
```

### 6.2 SSL 인증서 발급

**DNS를 새 서버 IP로 변경한 후 실행하세요!**

```bash
# DNS 확인
nslookup krdn-n8n.duckdns.org

# Let's Encrypt 인증서 발급 (standalone 모드)
sudo systemctl stop nginx
sudo certbot certonly --standalone -d krdn-n8n.duckdns.org
sudo systemctl start nginx

# 또는 nginx 플러그인 사용
sudo certbot --nginx -d krdn-n8n.duckdns.org
```

### 6.3 Nginx 시작

```bash
sudo systemctl restart nginx
sudo systemctl enable nginx
sudo systemctl status nginx
```

---

## 7단계: Systemd 자동화 설정

```bash
# systemd 파일 복사
sudo cp /home/gon/docker-n8n/systemd/*.service /etc/systemd/system/
sudo cp /home/gon/docker-n8n/systemd/*.timer /etc/systemd/system/

# 권한 설정
sudo chmod 644 /etc/systemd/system/n8n-*.{service,timer}

# systemd 데몬 리로드
sudo systemctl daemon-reload

# 타이머 활성화
sudo systemctl enable --now n8n-backup.timer
sudo systemctl enable --now n8n-update.timer

# 타이머 확인
sudo systemctl list-timers n8n-*
```

---

## 8단계: 최종 검증

```bash
# 1. 서비스 상태
docker compose ps

# 2. HTTPS 접속 테스트
curl -I https://krdn-n8n.duckdns.org

# 3. 브라우저에서 확인
# https://krdn-n8n.duckdns.org 접속

# 4. 워크플로우 확인
# - 기존 워크플로우 목록 확인
# - 자격증명 연결 상태 확인
# - 테스트 워크플로우 실행
```

---

## 체크리스트

### 새 서버 설정
- [ ] Docker 설치 및 확인
- [ ] Nginx 설치
- [ ] UFW 방화벽 설정

### 파일 복원
- [ ] 프로젝트 파일 추출
- [ ] .env 파일 복원
- [ ] n8n 데이터 복원
- [ ] PostgreSQL 덤프 복원

### 서비스 시작
- [ ] Docker 서비스 시작 (모두 healthy)
- [ ] Nginx 설정 및 시작
- [ ] SSL 인증서 발급

### 자동화
- [ ] systemd 타이머 활성화

### 검증
- [ ] DNS 변경 완료
- [ ] HTTPS 접속 확인
- [ ] n8n UI 접속
- [ ] 워크플로우 목록 확인
- [ ] 자격증명 연결 확인

---

## 롤백 방법

문제 발생 시:

1. DNS를 이전 서버 IP로 변경
2. 이전 서버에서:
   ```bash
   cd /home/gon/docker-n8n
   docker compose up -d
   ```

---

## 주의사항

**N8N_ENCRYPTION_KEY**
- 절대 변경 금지!
- 변경 시 모든 자격증명 복구 불가

**DNS 전파**
- DNS 변경 후 전파에 시간이 걸릴 수 있음
- DuckDNS는 보통 수 분 내 전파

**데이터베이스 복원 순서**
- PostgreSQL 먼저 시작
- 덤프 복원
- 그 후 n8n 서비스 시작
