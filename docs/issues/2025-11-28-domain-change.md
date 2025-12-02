# 도메인 변경 기록 (2025-11-28)

## 변경 내용

| 항목 | 이전 | 현재 |
|------|------|------|
| 도메인 | `n8n.krdn.kr` | `n8n.krdn.kr` |
| SSL 인증서 | `/etc/letsencrypt/live/n8n.krdn.kr/` | `/etc/letsencrypt/live/n8n.krdn.kr/` |
| N8N_HOST | `n8n.krdn.kr` | `n8n.krdn.kr` |
| WEBHOOK_URL | `https://n8n.krdn.kr` | `https://n8n.krdn.kr` |

## 수정된 파일

### 1. `/etc/nginx/sites-available/n8n`
- `server_name` → `n8n.krdn.kr`
- SSL 인증서 경로 → `/etc/letsencrypt/live/n8n.krdn.kr/`
- 기존 duckdns 도메인 제거

### 2. `/home/gon/docker-n8n/.env`
```env
N8N_HOST=n8n.krdn.kr
WEBHOOK_URL=https://n8n.krdn.kr
```

### 3. 새 SSL 인증서 발급
```bash
sudo certbot --nginx -d n8n.krdn.kr
```

## 작업 순서

1. DNS A 레코드 설정 (`n8n.krdn.kr` → `222.112.46.131`)
2. Nginx에 새 도메인 임시 추가 (Certbot 검증용)
3. SSL 인증서 발급 (`certbot --nginx -d n8n.krdn.kr`)
4. Nginx 설정 정리 (새 도메인만 유지)
5. `.env` 파일 수정
6. n8n 서비스 재시작 (`docker compose down && docker compose up -d`)

## 발생한 이슈 및 해결

### 이슈 1: SSL 인증서 발급 실패 (NXDOMAIN)
- **원인**: DNS A 레코드 미설정
- **해결**: 도메인 관리 패널에서 `n8n` A 레코드 추가 → IP `222.112.46.131`

### 이슈 2: Certbot 인증 실패 (DNS는 전파됨)
- **원인**: Nginx `server_name`에 새 도메인 미등록 → HTTP 404 반환
- **해결**: `server_name`에 `n8n.krdn.kr` 추가 후 `nginx reload`

### 이슈 3: 기존 도메인 HTTPS 접속 실패
- **원인**: SSL 인증서가 `n8n.krdn.kr`만 포함
- **해결**: 기존 도메인(`n8n.krdn.kr`) 설정 제거

## 주의사항

- **기존 Webhook URL 변경 필요**: 외부 서비스에서 `https://n8n.krdn.kr/webhook/...` 형태로 등록한 webhook이 있다면 `https://n8n.krdn.kr/webhook/...`로 변경 필요
- **기존 인증서 정리**: 필요시 아래 명령으로 삭제 가능
  ```bash
  sudo certbot delete --cert-name n8n.krdn.kr
  ```

## 생성된 설정 파일

| 파일 | 설명 | 비고 |
|------|------|------|
| `nginx-config/n8n-new-domain.conf` | 새 도메인 전용 Nginx 설정 템플릿 | 유지 |
| `nginx-config/n8n-temp-both-domains.conf` | 전환 중 임시 사용 | 삭제 가능 |

## 최종 확인

```bash
# 서비스 상태
docker compose ps

# HTTPS 접속 테스트
curl -I https://n8n.krdn.kr/healthz
```

✅ 모든 서비스 정상 동작 확인 (2025-11-28 14:45 KST)
