#!/bin/bash

##############################################
# Systemd 타이머 활성화 스크립트
# n8n 자동 백업 및 업데이트 타이머 활성화
##############################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

log "========================================="
log "n8n Automation 활성화 시작"
log "========================================="

# 권한 체크
if [ "$EUID" -ne 0 ]; then
    error "이 스크립트는 root 권한이 필요합니다."
    echo "실행: sudo bash $0"
    exit 1
fi

# systemd 파일 존재 확인
if [ ! -f "/etc/systemd/system/n8n-backup.timer" ]; then
    error "systemd 타이머 파일이 없습니다."
    error "systemd 디렉토리에서 파일을 복사하세요:"
    error "sudo cp systemd/*.{service,timer} /etc/systemd/system/"
    exit 1
fi

# systemd 데몬 리로드
log "systemd 데몬 리로드..."
systemctl daemon-reload

# 백업 타이머 활성화
log "n8n-backup.timer 활성화..."
systemctl enable n8n-backup.timer
systemctl start n8n-backup.timer

# 업데이트 타이머 활성화
log "n8n-update.timer 활성화..."
systemctl enable n8n-update.timer
systemctl start n8n-update.timer

log "========================================="
log "타이머 상태 확인"
log "========================================="

# 타이머 상태 출력
systemctl status n8n-backup.timer --no-pager || true
echo ""
systemctl status n8n-update.timer --no-pager || true
echo ""

log "========================================="
log "예약된 타이머 목록"
log "========================================="
systemctl list-timers n8n-* --no-pager

log "========================================="
log "활성화 완료!"
log "========================================="
log "백업: 매일 02:00 (±15분 랜덤)"
log "업데이트: 매주 일요일 03:00 (±30분 랜덤)"
log ""
log "수동 실행:"
log "  - 백업: sudo systemctl start n8n-backup.service"
log "  - 업데이트: sudo systemctl start n8n-update.service"
log ""
log "로그 확인:"
log "  - journalctl -u n8n-backup.service -f"
log "  - journalctl -u n8n-update.service -f"

exit 0
