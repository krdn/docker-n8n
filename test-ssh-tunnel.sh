#!/bin/bash

##############################################
# PostgreSQL SSH Tunnel Connection Test
# 원격에서 이 명령어들을 사용하세요
##############################################

echo "========================================="
echo "PostgreSQL SSH Tunnel 연결 가이드"
echo "========================================="
echo ""

# 서버 정보
SERVER_IP="192.168.0.50"
SERVER_DOMAIN="n8n.krdn.kr"
SSH_USER="gon"
SSH_PORT="22"
PG_PORT="5432"
PG_USER="n8n"
PG_DB="n8n"
PG_PASSWORD="korea123"

echo "📋 서버 정보:"
echo "  - SSH 주소: $SSH_USER@$SERVER_DOMAIN (또는 $SERVER_IP)"
echo "  - SSH 포트: $SSH_PORT"
echo "  - PostgreSQL: localhost:$PG_PORT (서버 내부)"
echo "  - DB 사용자: $PG_USER"
echo "  - DB 이름: $PG_DB"
echo ""

echo "========================================="
echo "방법 1: psql 명령줄 도구"
echo "========================================="
echo ""
echo "1단계: SSH 터널 생성 (새 터미널에서 실행)"
echo "----------------------------------------"
echo "ssh -L $PG_PORT:localhost:$PG_PORT $SSH_USER@$SERVER_DOMAIN"
echo ""
echo "2단계: 다른 터미널에서 psql 접속"
echo "----------------------------------------"
echo "psql -h localhost -p $PG_PORT -U $PG_USER -d $PG_DB"
echo "# 비밀번호 입력: $PG_PASSWORD"
echo ""

echo "========================================="
echo "방법 2: 백그라운드 SSH 터널"
echo "========================================="
echo ""
echo "ssh -f -N -L $PG_PORT:localhost:$PG_PORT $SSH_USER@$SERVER_DOMAIN"
echo "psql -h localhost -p $PG_PORT -U $PG_USER -d $PG_DB"
echo ""
echo "# 터널 종료하려면:"
echo "ps aux | grep 'ssh.*$PG_PORT:localhost:$PG_PORT' | grep -v grep | awk '{print \$2}' | xargs kill"
echo ""

echo "========================================="
echo "방법 3: 한 줄 명령어"
echo "========================================="
echo ""
echo "PGPASSWORD='$PG_PASSWORD' psql -h localhost -p $PG_PORT -U $PG_USER -d $PG_DB -c 'SELECT version();'"
echo ""
echo "# SSH 터널이 먼저 열려있어야 합니다!"
echo ""

echo "========================================="
echo "방법 4: DBeaver / DataGrip (GUI)"
echo "========================================="
echo ""
echo "[Main 탭]"
echo "  Host: localhost"
echo "  Port: $PG_PORT"
echo "  Database: $PG_DB"
echo "  Username: $PG_USER"
echo "  Password: $PG_PASSWORD"
echo ""
echo "[SSH 탭]"
echo "  ✓ Use SSH Tunnel"
echo "  Host: $SERVER_DOMAIN"
echo "  Port: $SSH_PORT"
echo "  Username: $SSH_USER"
echo "  Auth Method: Password or Key"
echo ""

echo "========================================="
echo "방법 5: Python 스크립트"
echo "========================================="
echo ""
cat << 'PYTHON_CODE'
# install: pip install psycopg2-binary sshtunnel

from sshtunnel import SSHTunnelForwarder
import psycopg2

with SSHTunnelForwarder(
    ('n8n.krdn.kr', 22),
    ssh_username='gon',
    ssh_password='YOUR_SSH_PASSWORD',  # 또는 ssh_pkey='/path/to/key'
    remote_bind_address=('localhost', 5432)
) as tunnel:
    conn = psycopg2.connect(
        host='localhost',
        port=tunnel.local_bind_port,
        user='n8n',
        password='korea123',
        database='n8n'
    )
    cur = conn.cursor()
    cur.execute('SELECT version();')
    print(cur.fetchone())
    conn.close()
PYTHON_CODE
echo ""

echo "========================================="
echo "🔍 문제 해결 (Troubleshooting)"
echo "========================================="
echo ""
echo "1. 연결이 거부되는 경우:"
echo "   - SSH 접속이 되는지 먼저 확인: ssh $SSH_USER@$SERVER_DOMAIN"
echo "   - 방화벽에서 SSH(22) 포트가 열려있는지 확인"
echo ""
echo "2. 'Address already in use' 오류:"
echo "   - 로컬 5432 포트가 이미 사용중입니다"
echo "   - 다른 포트 사용: ssh -L 5433:localhost:5432 $SSH_USER@$SERVER_DOMAIN"
echo "   - 그 후: psql -h localhost -p 5433 -U $PG_USER -d $PG_DB"
echo ""
echo "3. PostgreSQL 인증 실패:"
echo "   - 비밀번호 확인: $PG_PASSWORD"
echo "   - 사용자 확인: $PG_USER"
echo ""
echo "4. SSH 키 인증 사용 (권장):"
echo "   # 클라이언트에서:"
echo "   ssh-keygen -t ed25519 -C 'your_email@example.com'"
echo "   ssh-copy-id $SSH_USER@$SERVER_DOMAIN"
echo ""

echo "========================================="
echo "✅ 서버 상태 확인"
echo "========================================="
echo ""
echo "SSH 서비스:"
systemctl is-active ssh && echo "  ✓ SSH 서비스 실행 중" || echo "  ✗ SSH 서비스 중지됨"
echo ""

echo "PostgreSQL 컨테이너:"
docker-compose ps postgres 2>/dev/null | grep "Up" > /dev/null && \
  echo "  ✓ PostgreSQL 컨테이너 실행 중" || \
  echo "  ✗ PostgreSQL 컨테이너 중지됨"
echo ""

echo "PostgreSQL 포트 바인딩:"
netstat -tln 2>/dev/null | grep "127.0.0.1:5432" > /dev/null && \
  echo "  ✓ PostgreSQL이 localhost:5432에서 리스닝 중" || \
  echo "  ✗ PostgreSQL이 리스닝하지 않음"
echo ""

echo "========================================="
echo "📞 연결 테스트 명령어"
echo "========================================="
echo ""
echo "원격 클라이언트에서 다음 명령어를 순서대로 실행하세요:"
echo ""
echo "# 1. SSH 연결 테스트"
echo "ssh -v $SSH_USER@$SERVER_DOMAIN 'echo SSH connection OK'"
echo ""
echo "# 2. SSH 터널 테스트 (verbose)"
echo "ssh -v -L $PG_PORT:localhost:$PG_PORT $SSH_USER@$SERVER_DOMAIN"
echo ""
echo "# 3. 터널이 열린 상태에서 다른 터미널에서:"
echo "nc -zv localhost $PG_PORT"
echo ""

echo "========================================="
echo "완료!"
echo "========================================="
