#!/bin/bash
#
# n8n 워크플로우 GitHub 내보내기 스크립트
# 각 워크플로우를 개별 JSON 파일로 저장하고 Git에 커밋
#
# 사용법:
#   ./scripts/export-workflows.sh              # 내보내기만
#   ./scripts/export-workflows.sh --commit     # 내보내기 + Git 커밋
#   ./scripts/export-workflows.sh --push       # 내보내기 + 커밋 + 푸시
#

set -e

# 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOWS_DIR="$PROJECT_DIR/workflows"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 워크플로우 디렉토리 생성
mkdir -p "$WORKFLOWS_DIR"

cd "$PROJECT_DIR"

# n8n 컨테이너 확인
if ! docker compose ps --status running | grep -q "n8n"; then
    log_error "n8n 컨테이너가 실행 중이지 않습니다."
    log_info "다음 명령으로 시작하세요: docker compose up -d"
    exit 1
fi

log_info "워크플로우 내보내기 시작..."

# 기존 워크플로우 파일 목록 저장 (삭제 감지용)
EXISTING_FILES=$(find "$WORKFLOWS_DIR" -name "*.json" -type f 2>/dev/null | sort)

# 모든 워크플로우를 개별 파일로 내보내기
# --separate 옵션으로 각 워크플로우를 개별 파일로 저장
docker compose exec -T n8n n8n export:workflow \
    --all \
    --separate \
    --pretty \
    --output=/home/node/.n8n/workflows/ 2>/dev/null

# 컨테이너에서 호스트로 파일 복사
docker compose cp n8n:/home/node/.n8n/workflows/. "$WORKFLOWS_DIR/" 2>/dev/null || true

# 컨테이너 내부 임시 파일 정리
docker compose exec -T n8n rm -rf /home/node/.n8n/workflows/*.json 2>/dev/null || true

# 내보낸 파일 이름 정리 (ID -> 이름 기반)
EXPORTED_COUNT=0
for file in "$WORKFLOWS_DIR"/*.json; do
    [ -f "$file" ] || continue

    # JSON에서 워크플로우 이름 추출
    WF_NAME=$(jq -r '.name // "unknown"' "$file" 2>/dev/null)
    WF_ID=$(jq -r '.id // "unknown"' "$file" 2>/dev/null)

    # 파일명에 사용할 수 없는 문자 제거 및 정리
    SAFE_NAME=$(echo "$WF_NAME" | sed 's/[^a-zA-Z0-9가-힣_-]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

    # 새 파일명: ID_이름.json (ID 포함으로 고유성 보장)
    NEW_NAME="${WF_ID}_${SAFE_NAME}.json"

    if [ "$(basename "$file")" != "$NEW_NAME" ]; then
        mv "$file" "$WORKFLOWS_DIR/$NEW_NAME"
    fi

    EXPORTED_COUNT=$((EXPORTED_COUNT + 1))
done

log_success "총 ${EXPORTED_COUNT}개 워크플로우 내보내기 완료"

# 현재 워크플로우 파일 목록
CURRENT_FILES=$(find "$WORKFLOWS_DIR" -name "*.json" -type f 2>/dev/null | sort)

# 변경 사항 확인
if [ -d "$PROJECT_DIR/.git" ]; then
    cd "$PROJECT_DIR"

    # Git 상태 확인
    ADDED=$(git status --porcelain "$WORKFLOWS_DIR" 2>/dev/null | grep "^??" | wc -l)
    MODIFIED=$(git status --porcelain "$WORKFLOWS_DIR" 2>/dev/null | grep "^ M\|^M " | wc -l)
    DELETED=$(git status --porcelain "$WORKFLOWS_DIR" 2>/dev/null | grep "^ D\|^D " | wc -l)

    if [ "$ADDED" -gt 0 ] || [ "$MODIFIED" -gt 0 ] || [ "$DELETED" -gt 0 ]; then
        log_info "변경 감지: 추가 ${ADDED}, 수정 ${MODIFIED}, 삭제 ${DELETED}"

        # --commit 또는 --push 옵션 처리
        if [ "$1" == "--commit" ] || [ "$1" == "--push" ]; then
            git add "$WORKFLOWS_DIR"

            # 커밋 메시지 생성
            COMMIT_MSG="chore(workflows): 워크플로우 동기화 - ${TIMESTAMP}"
            if [ "$ADDED" -gt 0 ]; then
                COMMIT_MSG="$COMMIT_MSG\n\n추가된 워크플로우: ${ADDED}개"
            fi
            if [ "$MODIFIED" -gt 0 ]; then
                COMMIT_MSG="$COMMIT_MSG\n수정된 워크플로우: ${MODIFIED}개"
            fi
            if [ "$DELETED" -gt 0 ]; then
                COMMIT_MSG="$COMMIT_MSG\n삭제된 워크플로우: ${DELETED}개"
            fi

            echo -e "$COMMIT_MSG" | git commit -F -
            log_success "Git 커밋 완료"

            # --push 옵션인 경우 원격 저장소에 푸시
            if [ "$1" == "--push" ]; then
                if git remote | grep -q "origin"; then
                    git push origin HEAD
                    log_success "원격 저장소에 푸시 완료"
                else
                    log_warn "원격 저장소(origin)가 설정되지 않았습니다."
                    log_info "다음 명령으로 설정하세요: git remote add origin <repository-url>"
                fi
            fi
        else
            log_info "변경 사항을 커밋하려면: ./scripts/export-workflows.sh --commit"
            log_info "커밋 후 푸시하려면: ./scripts/export-workflows.sh --push"
        fi
    else
        log_info "변경된 워크플로우가 없습니다."
    fi
else
    log_warn "Git 저장소가 초기화되지 않았습니다."
fi

# 내보낸 워크플로우 목록 출력
echo ""
log_info "내보낸 워크플로우 목록:"
for file in "$WORKFLOWS_DIR"/*.json; do
    [ -f "$file" ] || continue
    WF_NAME=$(jq -r '.name' "$file" 2>/dev/null)
    WF_ACTIVE=$(jq -r '.active' "$file" 2>/dev/null)
    STATUS="비활성"
    [ "$WF_ACTIVE" == "true" ] && STATUS="활성"
    echo "  - $WF_NAME ($STATUS)"
done
