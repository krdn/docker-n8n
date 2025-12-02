# MongoDB Compass SSH 터널링 접속 가이드

## 현재 환경

| 항목 | 상태 |
|------|------|
| DNS (mongo.krdn.kr) | ✅ `222.112.46.131` 설정됨 |
| MongoDB 컨테이너 | ✅ `gonsai2-mongodb-prod` (포트 27018) |
| MongoDB 바인딩 | `0.0.0.0:27018 → 27017` (컨테이너 내부) |
| 방화벽 (UFW) | 27018은 내부망(192.168.0.0/24)만 허용 |
| SSH 포트 | 2222 (외부 허용됨) |

## SSH 터널링이란?

```
[MongoDB Compass] → [SSH 터널] → [서버] → [MongoDB 컨테이너]
     (로컬)         (암호화)      (2222)     (27018→27017)
```

SSH 터널링은 암호화된 SSH 연결을 통해 원격 서버의 포트에 접근하는 방식입니다.
MongoDB 포트(27018)를 직접 외부에 노출하지 않고도 안전하게 접속할 수 있습니다.

---

## MongoDB Compass 설정 방법

### 1. MongoDB Compass 실행 → "New Connection" 클릭

### 2. "Advanced Connection Options" 확장

### 3. 탭별 설정

#### **General 탭**
| 항목 | 값 |
|------|-----|
| Connection String | (사용 안 함, 아래 개별 설정) |

#### **Authentication 탭**
| 항목 | 값 |
|------|-----|
| Authentication | Username / Password |
| Username | `[MongoDB 사용자명]` |
| Password | `[MongoDB 비밀번호]` |
| Authentication Database | `admin` |

#### **Proxy/SSH 탭** ⭐ 핵심 설정
| 항목 | 값 |
|------|-----|
| SSH Tunnel | ✅ 체크 |
| SSH Hostname | `mongo.krdn.kr` (또는 `222.112.46.131`) |
| SSH Port | `2222` |
| SSH Username | `gon` |
| SSH Identity File | `[로컬 PC의 SSH 개인키 경로]` |
| SSH Passphrase | (개인키에 암호가 있으면 입력) |

> **SSH 키 경로 예시:**
> - Windows: `C:\Users\사용자명\.ssh\id_rsa`
> - macOS/Linux: `~/.ssh/id_rsa`

#### **Host 탭** (터널 통과 후 접속할 주소)
| 항목 | 값 |
|------|-----|
| Hostname | `127.0.0.1` |
| Port | `27018` |

> ⚠️ **중요**: SSH 터널을 사용하면 `Hostname`은 **서버 내부 관점**에서의 주소입니다.
> 서버에서 MongoDB는 `127.0.0.1:27018`에서 리스닝 중이므로 이 값을 사용합니다.

### 4. "Connect" 클릭

---

## 연결 문자열 형식 (참고용)

```
mongodb://[사용자명]:[비밀번호]@127.0.0.1:27018/?authSource=admin
```

---

## 서버 측 필수 조건 (이미 충족됨 ✅)

| 항목 | 상태 | 설명 |
|------|------|------|
| SSH 포트 2222 | ✅ 열림 | UFW에서 외부 허용 |
| SSH 키 인증 | ✅ 설정됨 | 비밀번호 대신 키 사용 권장 |
| MongoDB 27018 | ✅ 리스닝 | 로컬에서만 접근 가능 |

---

## 로컬 PC에서 SSH 키 설정 (아직 없다면)

### Windows (PowerShell)
```powershell
# 키 생성
ssh-keygen -t ed25519 -C "your-email@example.com"

# 공개키를 서버에 복사
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh -p 2222 gon@mongo.krdn.kr "cat >> ~/.ssh/authorized_keys"
```

### macOS/Linux
```bash
# 키 생성
ssh-keygen -t ed25519 -C "your-email@example.com"

# 공개키를 서버에 복사
ssh-copy-id -p 2222 gon@mongo.krdn.kr
```

---

## 연결 테스트 (터미널에서)

SSH 터널이 정상 작동하는지 먼저 테스트:

```bash
# SSH 터널 생성 (로컬 27017 → 서버 27018)
ssh -p 2222 -L 27017:127.0.0.1:27018 gon@mongo.krdn.kr -N

# 다른 터미널에서 mongosh 테스트
mongosh "mongodb://127.0.0.1:27017"
```

---

## 트러블슈팅

| 오류 | 원인 | 해결 |
|------|------|------|
| `Connection refused` | SSH 연결 실패 | SSH 키/포트 확인 |
| `Authentication failed` | MongoDB 인증 실패 | 사용자명/비밀번호/authSource 확인 |
| `Network timeout` | 터널 설정 오류 | Host를 `127.0.0.1`로 설정했는지 확인 |

---

## 보안 참고사항

- MongoDB 포트(27018)는 외부에 직접 노출되지 않음
- 모든 트래픽이 SSH로 암호화됨
- SSH 키 인증 사용 권장 (비밀번호 인증보다 안전)

---

*작성일: 2025-11-28*
