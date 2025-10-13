# DataGrip에서 SSH 터널을 통한 PostgreSQL 연결 가이드

Windows 11 + DataGrip 환경에서 SSH 터널을 통해 Docker PostgreSQL에 연결하는 방법입니다.

---

## 📋 연결 정보 요약

```
서버 정보:
- SSH Host: krdn-n8n.duckdns.org
- SSH Port: 22
- SSH User: gon

PostgreSQL 정보:
- Host: localhost (SSH 터널을 통해 접근)
- Port: 5432
- Database: n8n
- User: n8n
- Password: korea123
```

---

## 🎯 DataGrip 연결 설정 (단계별)

### **1단계: 새 데이터 소스 생성**

1. DataGrip 실행
2. 상단 메뉴: `File` → `New` → `Data Source` → `PostgreSQL`
   - 또는 좌측 Database 패널에서 `+` 버튼 → `Data Source` → `PostgreSQL`

---

### **2단계: General 탭 설정**

```
Name: n8n Production DB (또는 원하는 이름)

[Connection Settings]
Host: localhost
Port: 5432
Authentication: User & Password
User: n8n
Password: korea123
Database: n8n
URL: jdbc:postgresql://localhost:5432/n8n
```

**중요**: Host는 반드시 `localhost`로 입력! (서버 IP 아님)

**체크박스 설정**:
- ☐ Auto-sync (선택사항)
- ☑ Save password (권장)

---

### **3단계: SSH/SSL 탭 설정** ⭐ 가장 중요!

1. **SSH/SSL 탭 클릭**

2. **SSH Configuration 섹션**:
   ```
   ☑ Use SSH tunnel

   [SSH Configuration]
   Host: krdn-n8n.duckdns.org
   Port: 22
   User name: gon
   Authentication type: Password (또는 Key pair)
   ```

3. **Authentication Type 선택**:

   **옵션 A: Password 방식** (간단함)
   ```
   Authentication type: Password
   Password: [Windows 11에서 서버 SSH 접속할 때 사용하는 비밀번호]
   ☑ Save password
   ```

   **옵션 B: Key pair 방식** (권장 - 더 안전)
   ```
   Authentication type: Key pair
   Private key file: C:\Users\[사용자명]\.ssh\id_rsa
   Passphrase: [키 생성 시 설정한 passphrase, 없으면 비워둠]
   ```

4. **Test Connection 버튼** 클릭 (SSH 연결 테스트)
   - 성공 시: "Successfully connected to..."
   - 실패 시: 오류 메시지 확인 (아래 문제 해결 참고)

---

### **4단계: 연결 테스트 및 저장**

1. **General 탭으로 돌아가기**

2. **Test Connection 버튼** 클릭 (PostgreSQL 연결 테스트)
   - 성공 시: "Connected successfully" 메시지
   - Driver 파일 다운로드 필요 시 자동으로 다운로드됨

3. **OK 버튼** 클릭하여 저장

4. 좌측 Database 패널에서 연결 확인:
   - 연결 아이콘이 초록색으로 표시됨
   - `n8n` 데이터베이스 → `schemas` → `public` 펼쳐서 테이블 확인

---

## 🖼️ 설정 화면 레이아웃

```
┌────────────────────────────────────────────────────────┐
│ Data Sources and Drivers                               │
├────────────────────────────────────────────────────────┤
│ [General] [Options] [SSH/SSL] [Advanced]              │
├────────────────────────────────────────────────────────┤
│                                                         │
│ General Tab:                                           │
│   Name: n8n Production DB                              │
│                                                         │
│   Host: localhost             Port: 5432              │
│   Authentication: User & Password                      │
│   User: n8n                                            │
│   Password: ••••••••                                   │
│   Database: n8n                                        │
│                                                         │
│   [Test Connection]                                    │
│                                                         │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│ SSH/SSL Tab:                                           │
├────────────────────────────────────────────────────────┤
│                                                         │
│   ☑ Use SSH tunnel                                     │
│                                                         │
│   Proxy host:                                          │
│     Host: krdn-n8n.duckdns.org                        │
│     Port: 22                                           │
│     User name: gon                                     │
│     Authentication type: [Password ▼]                  │
│     Password: ••••••••                                 │
│     ☑ Save password                                    │
│                                                         │
│   [Test Connection]                                    │
│                                                         │
└────────────────────────────────────────────────────────┘
```

---

## 🔍 문제 해결 (Troubleshooting)

### ❌ **문제 1: "SSH: Connection refused"**

**원인**:
- SSH 서버에 연결할 수 없음
- 잘못된 호스트/포트

**해결**:
1. Windows PowerShell에서 SSH 연결 테스트:
   ```powershell
   ssh gon@krdn-n8n.duckdns.org
   ```

2. 방화벽 확인:
   - Windows Defender 방화벽에서 아웃바운드 연결 허용 확인

3. 인터넷 연결 확인:
   ```powershell
   ping krdn-n8n.duckdns.org
   ```

---

### ❌ **문제 2: "SSH: Auth fail"**

**원인**: SSH 인증 실패

**해결**:
1. **비밀번호 방식**:
   - SSH 비밀번호가 정확한지 확인
   - 특수문자가 포함된 경우 복사/붙여넣기 시도

2. **Key pair 방식**:
   - 올바른 Private key 파일 경로 확인
   - Key 파일 형식 확인 (OpenSSH 형식: `-----BEGIN OPENSSH PRIVATE KEY-----`)

3. PowerShell에서 수동 연결 테스트:
   ```powershell
   ssh -v gon@krdn-n8n.duckdns.org
   # verbose 모드로 자세한 오류 확인
   ```

---

### ❌ **문제 3: "Connection to localhost:5432 refused"**

**원인**: SSH 터널은 성공했으나 PostgreSQL 연결 실패

**해결**:
1. **General 탭에서 Host 확인**:
   - 반드시 `localhost` 또는 `127.0.0.1`
   - 서버 IP나 도메인 입력 시 실패

2. **Port 확인**: `5432` 정확히 입력

3. **PostgreSQL 자격 증명 확인**:
   - User: `n8n`
   - Password: `korea123`
   - Database: `n8n`

---

### ❌ **문제 4: "Driver not found"**

**원인**: PostgreSQL JDBC 드라이버 미설치

**해결**:
1. DataGrip이 자동으로 드라이버 다운로드 제안:
   - "Download" 버튼 클릭

2. 수동 다운로드:
   - General 탭 하단 "Driver: PostgreSQL" 옆 렌치 아이콘 클릭
   - "Driver Files" 탭에서 최신 버전 다운로드

---

### ❌ **문제 5: "Unknown database 'n8n'"**

**원인**: 데이터베이스 이름 오타 또는 존재하지 않음

**해결**:
1. General 탭에서 Database 필드를 비워두고 연결
2. 연결 후 Database 패널에서 사용 가능한 데이터베이스 확인
3. `n8n` 데이터베이스 선택

---

## ⚡ 빠른 연결 테스트 (PowerShell)

DataGrip 설정 전에 SSH 터널이 정상 작동하는지 확인:

```powershell
# 1. SSH 연결 테스트
ssh gon@krdn-n8n.duckdns.org "echo 'SSH OK'"

# 2. SSH 터널 생성 (이 창은 열어둔 채로)
ssh -L 5432:localhost:5432 gon@krdn-n8n.duckdns.org

# 3. 새 PowerShell 창에서 포트 확인
Test-NetConnection localhost -Port 5432

# 성공 시 DataGrip 설정 진행
```

---

## 🔐 SSH 키 생성 및 등록 (권장 방법)

비밀번호 입력 없이 안전하게 연결:

### **1단계: SSH 키 생성 (Windows 11)**

```powershell
# PowerShell 실행 (관리자 권한 불필요)

# SSH 키 생성
ssh-keygen -t ed25519 -C "your_email@example.com"

# 저장 위치: C:\Users\[사용자명]\.ssh\id_ed25519 (기본값 Enter)
# Passphrase: 원하는 암호 입력 또는 Enter (비워둠)
```

### **2단계: 공개키를 서버에 복사**

```powershell
# 공개키 내용 확인
type C:\Users\[사용자명]\.ssh\id_ed25519.pub

# 출력된 내용 복사 (ssh-ed25519로 시작하는 한 줄)
```

**서버에서 실행** (SSH로 접속 후):
```bash
# ~/.ssh/authorized_keys 파일에 공개키 추가
mkdir -p ~/.ssh
echo "여기에_복사한_공개키_붙여넣기" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### **3단계: DataGrip에서 Key pair 방식으로 설정**

```
SSH/SSL 탭:
  Authentication type: Key pair
  Private key file: C:\Users\[사용자명]\.ssh\id_ed25519
  Passphrase: [설정한 경우 입력, 없으면 비워둠]
```

---

## 📊 연결 성공 확인

DataGrip에서 연결 후 다음 쿼리 실행:

```sql
-- PostgreSQL 버전 확인
SELECT version();

-- 현재 데이터베이스 확인
SELECT current_database();

-- 테이블 목록 확인
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public';

-- n8n 워크플로우 개수 확인
SELECT COUNT(*) as workflow_count FROM workflow_entity;

-- n8n 실행 기록 개수 확인
SELECT COUNT(*) as execution_count FROM execution_entity;
```

---

## 💡 추가 팁

### **여러 환경 관리**

```
Production: n8n Production DB (SSH: krdn-n8n.duckdns.org)
Local Dev: n8n Local Dev (Direct: localhost:5432)
```

### **자동 재연결 설정**

DataGrip 설정:
1. `File` → `Settings` → `Database` → `General`
2. ☑ `Keep connections alive`
3. Interval: `300` seconds (5분)

### **SSH Keep-Alive 설정** (연결 끊김 방지)

Windows에서 `C:\Users\[사용자명]\.ssh\config` 파일 생성:

```
Host krdn-n8n.duckdns.org
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

---

## ✅ 체크리스트

DataGrip 연결 전 확인사항:

- [ ] SSH로 서버 접속 가능 확인 (`ssh gon@krdn-n8n.duckdns.org`)
- [ ] PostgreSQL 컨테이너 실행 중 (서버에서 `docker-compose ps`)
- [ ] 방화벽에서 SSH(22) 포트 허용
- [ ] DataGrip의 PostgreSQL 드라이버 설치됨
- [ ] General 탭에서 Host를 `localhost`로 설정
- [ ] SSH/SSL 탭에서 "Use SSH tunnel" 체크
- [ ] SSH 인증 정보 정확히 입력

---

## 📞 지원

문제가 계속되면 다음 정보와 함께 문의:
1. DataGrip 버전 (`Help` → `About`)
2. 정확한 오류 메시지 (스크린샷)
3. PowerShell에서 `ssh -v` 출력 결과

---

**작성일**: 2025-10-13
**서버**: krdn-n8n.duckdns.org
**PostgreSQL 버전**: 16-alpine
**n8n 버전**: 1.114.4
