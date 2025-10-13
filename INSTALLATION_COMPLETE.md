# n8n 설치 완료 보고서

## 설치 일시
2025-10-13 13:56 KST

## 설치된 구성 요소

### 1. Docker 서비스
- ✅ n8n (메인 애플리케이션) - 상태: healthy
- ✅ n8n-worker (백그라운드 워커) - 상태: healthy
- ✅ PostgreSQL 16 (데이터베이스) - 상태: healthy
- ✅ Redis 7 (큐 관리) - 상태: healthy

### 2. 시스템 서비스
- ✅ Nginx (리버스 프록시) - 상태: active (running)
- ✅ Docker - 상태: enabled
- ✅ Certbot - SSL 자동 갱신 활성화

### 3. SSL/TLS 인증서
- ✅ 도메인: krdn-n8n.duckdns.org
- ✅ 인증서 발급 완료
- ✅ 만료일: 2026-01-11
- ✅ 자동 갱신: 활성화됨

### 4. 자동화 서비스
- ✅ 자동 업데이트: 매주 일요일 03:00 (다음 실행: 2025-10-19 03:14)
- ✅ 자동 백업: 매일 02:00 (다음 실행: 2025-10-14 02:05)

### 5. 보안 설정
- ✅ UFW 방화벽: 활성화
- ✅ 허용 포트: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- ✅ HTTPS 리다이렉트: 활성화
- ✅ 보안 헤더: 설정 완료

## 접속 정보

### 웹 인터페이스
- URL: https://krdn-n8n.duckdns.org
- 프로토콜: HTTPS (SSL/TLS 보안)

### 데이터베이스
- 유형: PostgreSQL 16
- 데이터베이스명: n8n
- 사용자: n8n
- 비밀번호: .env 파일 참조

### 암호화 키
- 위치: /home/gon/docker-n8n/.env
- 키: N8N_ENCRYPTION_KEY (절대 분실 금지!)

## 디렉토리 구조

```
/home/gon/docker-n8n/
├── docker-compose.yml          # Docker 구성
├── .env                         # 환경 변수 (보안 중요!)
├── data/                        # 영구 데이터
│   ├── n8n/                    # n8n 데이터
│   ├── postgres/               # PostgreSQL 데이터
│   ├── redis/                  # Redis 데이터
│   └── local-files/            # 파일 저장소
├── backup/                      # 백업 파일
├── logs/                        # 로그 파일
├── scripts/                     # 스크립트
│   ├── update.sh               # 업데이트 스크립트
│   └── backup.sh               # 백업 스크립트
└── nginx-config/                # Nginx 설정
```

## 시스템 설정 파일

### Nginx
- 설정 파일: /etc/nginx/sites-available/n8n
- 심볼릭 링크: /etc/nginx/sites-enabled/n8n

### Systemd 서비스
- /etc/systemd/system/n8n-update.service
- /etc/systemd/system/n8n-update.timer
- /etc/systemd/system/n8n-backup.service
- /etc/systemd/system/n8n-backup.timer

## 유용한 명령어

### 서비스 상태 확인
```bash
# Docker 서비스 상태
docker-compose ps

# Nginx 상태
sudo systemctl status nginx

# 타이머 상태
sudo systemctl list-timers n8n-*
```

### 로그 확인
```bash
# n8n 로그
docker-compose logs -f n8n

# 전체 로그
docker-compose logs -f

# Nginx 로그
sudo tail -f /var/log/nginx/n8n-access.log
sudo tail -f /var/log/nginx/n8n-error.log

# 업데이트 로그
cat logs/update.log

# Systemd 로그
sudo journalctl -u n8n-update.service -f
sudo journalctl -u n8n-backup.service -f
```

### 수동 작업
```bash
# 수동 업데이트
./scripts/update.sh

# 수동 백업
./scripts/backup.sh

# 서비스 재시작
docker-compose restart

# Nginx 재시작
sudo systemctl restart nginx
```

## 백업 정보

### 자동 백업
- 빈도: 매일 02:00
- 위치: /home/gon/docker-n8n/backup/
- 보관 기간: 30일
- 포함 내용: 데이터베이스 + n8n 데이터 + 환경 설정

### 백업 복원
```bash
cd backup
tar -xzf n8n_full_backup_YYYYMMDD_HHMMSS.tar.gz
# README.md의 복원 가이드 참조
```

## 보안 권장사항

### ✅ 완료된 보안 설정
1. SSL/TLS 인증서 활성화
2. HTTPS 강제 리다이렉트
3. 방화벽 활성화
4. 보안 헤더 설정
5. 암호화 키 생성

### 🔴 추가 권장 사항
1. .env 파일의 기본 비밀번호 변경
   - POSTGRES_PASSWORD
   - N8N_BASIC_AUTH_PASSWORD (필요시)

2. 암호화 키 백업
   ```bash
   # 안전한 외부 저장소에 백업
   cat .env | grep N8N_ENCRYPTION_KEY
   ```

3. SSH 키 인증 사용 (비밀번호 로그인 비활성화)

4. 정기적인 보안 업데이트
   ```bash
   sudo apt update && sudo apt upgrade
   ```

## 모니터링

### 헬스체크
```bash
# n8n 헬스체크
curl http://localhost:5678/healthz

# PostgreSQL
docker-compose exec postgres pg_isready -U n8n

# Redis
docker-compose exec redis redis-cli ping
```

### 리소스 사용량
```bash
# Docker 컨테이너 리소스
docker stats

# 디스크 사용량
df -h

# 백업 크기
du -sh backup/
```

## 업데이트 정보

### 자동 업데이트
- 빈도: 매주 일요일 03:00
- 다음 실행: 2025-10-19 03:14:33 KST
- 기능:
  - 자동 백업 생성
  - 최신 이미지 다운로드
  - 무중단 업데이트
  - 헬스체크 검증

### 업데이트 로그 확인
```bash
cat logs/update.log
```

## 트러블슈팅

### 서비스가 시작되지 않을 때
```bash
# 로그 확인
docker-compose logs

# Docker 재시작
sudo systemctl restart docker
docker-compose up -d
```

### 웹사이트 접속 불가
```bash
# Nginx 상태 확인
sudo systemctl status nginx

# Nginx 재시작
sudo systemctl restart nginx

# 방화벽 확인
sudo ufw status
```

### 데이터베이스 문제
```bash
# PostgreSQL 로그
docker-compose logs postgres

# 데이터베이스 연결 확인
docker-compose exec postgres pg_isready -U n8n
```

## 지원 및 문서

- n8n 공식 문서: https://docs.n8n.io
- n8n 커뮤니티: https://community.n8n.io
- 설치 가이드: /home/gon/docker-n8n/README.md

## 다음 단계

1. ✅ https://krdn-n8n.duckdns.org 접속
2. ✅ 관리자 계정 생성
3. ✅ 첫 워크플로우 만들기
4. ⚠️ .env 파일의 비밀번호 변경 (강력 권장)
5. ⚠️ 암호화 키 백업 (필수!)

## 설치 완료!

모든 설정이 성공적으로 완료되었습니다.
프로덕션 환경에서 안전하게 사용할 수 있습니다.

설치 날짜: 2025-10-13
설치 버전: n8n latest (Docker)
설치 위치: /home/gon/docker-n8n
