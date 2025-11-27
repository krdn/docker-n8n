#!/bin/bash
# n8n 마이그레이션 설정 스크립트
# 새 서버에서 실행

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 프로젝트 디렉토리
PROJECT_DIR="/home/gon/docker-n8n"
cd "$PROJECT_DIR" || error "프로젝트 디렉토리를 찾을 수 없습니다: $PROJECT_DIR"

echo "=========================================="
echo "   n8n 마이그레이션 설정 스크립트"
echo "=========================================="
echo ""

# 단계 선택
echo "실행할 단계를 선택하세요:"
echo "1) 전체 설정 (1~7단계 모두)"
echo "2) 데이터 복원만 (5단계)"
echo "3) Nginx 설정만 (6단계)"
echo "4) Systemd 설정만 (7단계)"
echo "5) 상태 확인만"
echo ""
read -p "선택 [1-5]: " choice

case $choice in
    1)
        # 전체 설정
        log "=== 1단계: 환경 설정 ==="

        # 백업 파일 확인
        BACKUP_FILE=$(ls -t backup/n8n_full_backup_*.tar.gz 2>/dev/null | head -1)
        if [ -z "$BACKUP_FILE" ]; then
            error "백업 파일을 찾을 수 없습니다. backup/ 디렉토리를 확인하세요."
        fi
        log "백업 파일 발견: $BACKUP_FILE"

        # 백업 추출 확인
        if [ ! -d "backup/n8n_data" ]; then
            log "백업 파일 추출 중..."
            cd backup
            tar -xzf "$(basename $BACKUP_FILE)"
            cd ..
        fi

        # .env 파일 복원
        if [ -f "backup/env_backup" ]; then
            log ".env 파일 복원 중..."
            cp backup/env_backup .env
        else
            error "backup/env_backup 파일을 찾을 수 없습니다."
        fi

        # 스크립트 권한
        chmod +x scripts/*.sh

        log "=== 2단계: 데이터 디렉토리 준비 ==="
        mkdir -p data/{n8n,postgres,redis,local-files}

        # n8n 데이터 복원
        if [ -d "backup/n8n_data" ]; then
            log "n8n 데이터 복원 중..."
            cp -r backup/n8n_data/* data/n8n/
            sudo chown -R 1000:1000 data/n8n
        fi

        log "=== 3단계: Docker 서비스 시작 ==="
        log "PostgreSQL과 Redis 시작 중..."
        docker compose up -d postgres redis

        log "데이터베이스 시작 대기 (30초)..."
        sleep 30

        # 헬스체크
        if ! docker compose exec postgres pg_isready -U n8n &>/dev/null; then
            error "PostgreSQL이 준비되지 않았습니다."
        fi
        log "PostgreSQL 준비 완료"

        log "=== 4단계: 데이터베이스 복원 ==="
        if [ -f "backup/database.sql" ]; then
            log "PostgreSQL 덤프 복원 중..."
            docker compose exec -T postgres psql -U n8n -d n8n < backup/database.sql
            log "데이터베이스 복원 완료"
        else
            warn "database.sql 파일을 찾을 수 없습니다."
        fi

        log "=== 5단계: 전체 서비스 시작 ==="
        docker compose up -d

        log "서비스 시작 대기 (30초)..."
        sleep 30

        log "=== 6단계: 서비스 상태 확인 ==="
        docker compose ps

        # 헬스체크
        if curl -s http://localhost:5678/healthz | grep -q "ok"; then
            log "n8n 헬스체크 통과!"
        else
            warn "n8n 헬스체크 실패. 로그를 확인하세요: docker compose logs n8n"
        fi

        echo ""
        log "=========================================="
        log "Docker 서비스 설정 완료!"
        log "=========================================="
        echo ""
        echo "다음 단계:"
        echo "1. DNS를 새 서버 IP로 변경하세요"
        echo "2. 이 스크립트를 다시 실행하여 '3) Nginx 설정만' 선택"
        echo ""
        ;;

    2)
        # 데이터 복원만
        log "=== 데이터 복원 ==="

        BACKUP_FILE=$(ls -t backup/n8n_full_backup_*.tar.gz 2>/dev/null | head -1)
        if [ -z "$BACKUP_FILE" ]; then
            error "백업 파일을 찾을 수 없습니다."
        fi

        if [ ! -d "backup/n8n_data" ]; then
            log "백업 파일 추출 중..."
            cd backup && tar -xzf "$(basename $BACKUP_FILE)" && cd ..
        fi

        mkdir -p data/{n8n,postgres,redis,local-files}
        cp -r backup/n8n_data/* data/n8n/
        sudo chown -R 1000:1000 data/n8n

        docker compose up -d postgres redis
        sleep 30

        docker compose exec -T postgres psql -U n8n -d n8n < backup/database.sql
        docker compose up -d

        log "데이터 복원 완료!"
        docker compose ps
        ;;

    3)
        # Nginx 설정
        log "=== Nginx 설정 ==="

        sudo cp nginx-config/n8n.conf /etc/nginx/sites-available/n8n
        sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
        sudo rm -f /etc/nginx/sites-enabled/default

        log "Nginx 설정 복사 완료"

        # DNS 확인
        DOMAIN=$(grep N8N_HOST .env | cut -d'=' -f2)
        log "도메인: $DOMAIN"

        read -p "DNS가 새 서버를 가리키고 있습니까? (y/n): " dns_ready

        if [ "$dns_ready" = "y" ]; then
            log "SSL 인증서 발급 중..."
            sudo systemctl stop nginx 2>/dev/null || true
            sudo certbot certonly --standalone -d "$DOMAIN"
            sudo systemctl start nginx
            sudo systemctl enable nginx

            log "Nginx 설정 완료!"

            # 테스트
            if curl -sI "https://$DOMAIN" | grep -q "200\|301\|302"; then
                log "HTTPS 접속 성공!"
            else
                warn "HTTPS 접속 확인 필요"
            fi
        else
            warn "DNS 변경 후 다시 이 옵션을 실행하세요."
            sudo nginx -t && sudo systemctl restart nginx
        fi
        ;;

    4)
        # Systemd 설정
        log "=== Systemd 자동화 설정 ==="

        sudo cp systemd/*.service /etc/systemd/system/
        sudo cp systemd/*.timer /etc/systemd/system/
        sudo chmod 644 /etc/systemd/system/n8n-*.{service,timer}
        sudo systemctl daemon-reload

        sudo systemctl enable --now n8n-backup.timer
        sudo systemctl enable --now n8n-update.timer

        log "Systemd 타이머 활성화 완료!"
        sudo systemctl list-timers n8n-*
        ;;

    5)
        # 상태 확인
        log "=== 서비스 상태 ==="
        docker compose ps
        echo ""

        log "=== n8n 헬스체크 ==="
        curl -s http://localhost:5678/healthz && echo ""
        echo ""

        log "=== Nginx 상태 ==="
        sudo systemctl status nginx --no-pager || true
        echo ""

        log "=== Systemd 타이머 ==="
        sudo systemctl list-timers n8n-* --no-pager || true
        ;;

    *)
        error "잘못된 선택입니다."
        ;;
esac

echo ""
log "스크립트 완료!"
