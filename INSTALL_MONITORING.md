# n8n 모니터링 시스템 설치 가이드

## 1. Systemd 타이머 설치

다음 명령어를 실행하여 자동 모니터링을 활성화하세요:

```bash
sudo /home/gon/docker-n8n/systemd/install-monitor.sh
```

## 2. 설치 확인

타이머가 정상적으로 작동하는지 확인:

```bash
# 타이머 상태 확인
systemctl status n8n-monitor.timer

# 다음 실행 예정 시간 확인
systemctl list-timers n8n-monitor.timer

# 로그 확인 (실시간)
journalctl -u n8n-monitor.service -f
```

## 3. 수동 테스트

모니터링 스크립트를 즉시 실행하여 테스트:

```bash
# 수동 실행
sudo systemctl start n8n-monitor.service

# 로그 확인
journalctl -u n8n-monitor.service -n 50
```

## 4. 모니터링 동작 원리

### 📊 모니터링 주기
- **부팅 후**: 2분 후 첫 실행
- **이후**: 매 5분마다 자동 실행
- **정확도**: ±30초 (시스템 부하 고려)

### 🔍 체크 항목
1. n8n 메인 서비스
2. n8n-worker (백그라운드 워커)
3. PostgreSQL 데이터베이스
4. Redis 큐 시스템

### 📧 이메일 알림 발송 시점
1. **장애 감지 시**: 서비스 상태, 로그, 시스템 정보 포함
2. **자동 복구 시도 후**: 복구 성공/실패 여부
3. **수신자**: krdn.net@gmail.com

### 🔧 자동 복구 프로세스
1. 장애 서비스 감지
2. 이메일 알림 발송 (장애 상세 정보)
3. `docker-compose restart` 실행
4. 30초 대기
5. 복구 상태 확인
6. 이메일 알림 발송 (복구 결과)

## 5. 로그 위치

- **모니터링 로그**: `/home/gon/docker-n8n/logs/monitor.log`
- **이메일 로그**: `~/.msmtp.log`
- **Systemd 로그**: `journalctl -u n8n-monitor.service`

## 6. 유용한 명령어

```bash
# 타이머 중지
sudo systemctl stop n8n-monitor.timer

# 타이머 비활성화 (재부팅 후에도 실행 안 함)
sudo systemctl disable n8n-monitor.timer

# 타이머 다시 활성화
sudo systemctl enable n8n-monitor.timer
sudo systemctl start n8n-monitor.timer

# 전체 모니터링 로그 보기
tail -f /home/gon/docker-n8n/logs/monitor.log

# 최근 이메일 발송 기록
tail -20 ~/.msmtp.log
```

## 7. 테스트 시나리오

### 서비스 중단 테스트

```bash
# 1. n8n 서비스 중지
docker-compose stop n8n

# 2. 5분 이내 이메일 수신 확인
# 3. 자동 복구 확인 (서비스가 자동으로 재시작됨)
# 4. 복구 완료 이메일 수신 확인

# 5. 서비스 상태 확인
docker-compose ps
```

## 8. 문제 해결

### 이메일이 발송되지 않는 경우

```bash
# msmtp 설정 확인
cat ~/.msmtprc

# 권한 확인 (600이어야 함)
ls -la ~/.msmtprc

# 테스트 이메일 발송
echo "Test" | msmtp krdn.net@gmail.com

# 이메일 로그 확인
tail ~/.msmtp.log
```

### 타이머가 실행되지 않는 경우

```bash
# Systemd 데몬 리로드
sudo systemctl daemon-reload

# 타이머 재시작
sudo systemctl restart n8n-monitor.timer

# 타이머 상태 확인
systemctl status n8n-monitor.timer
```

### 서비스가 자동 복구되지 않는 경우

```bash
# Docker 상태 확인
systemctl status docker

# Docker Compose 파일 확인
cd /home/gon/docker-n8n
docker-compose config

# 수동 복구
docker-compose restart
```

## 9. 보안 참고사항

- Gmail 앱 비밀번호는 `~/.msmtprc` 파일에 저장됨 (권한: 600)
- 파일 권한이 600이 아니면 msmtp가 작동하지 않음
- 앱 비밀번호는 Google 계정 보안 설정에서 언제든지 삭제 가능

## 10. 기존 시스템과의 통합

이 모니터링 시스템은 기존 자동화 시스템과 함께 작동합니다:

- **n8n-backup.timer**: 매일 2:00 AM 백업
- **n8n-update.timer**: 매주 일요일 3:00 AM 업데이트
- **n8n-monitor.timer**: 매 5분마다 헬스 체크 ← 새로 추가됨

모든 타이머 확인:
```bash
sudo systemctl list-timers n8n-*
```
