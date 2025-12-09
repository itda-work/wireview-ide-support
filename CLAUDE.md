# wireview-ide-support

django-wireview를 위한 IDE 플러그인 프로젝트

## 프로젝트 구조

```
wireview-ide-support/
├── vscode/          # VSCode 확장 (완료)
├── nvim/            # Neovim 플러그인 (완료)
├── pycharm/         # PyCharm 플러그인 (개발중)
└── docs/            # 문서
```

## GitHub 이슈 관리 (gh CLI)

### 이슈 조회

```bash
# 전체 이슈 목록
gh issue list

# 열린 이슈만
gh issue list --state open

# 특정 이슈 상세 보기
gh issue view <번호>

# 라벨별 필터링
gh issue list --label enhancement
```

### 이슈 상태 변경

```bash
# 이슈 닫기 (완료 시)
gh issue close <번호> --comment "구현 완료"

# 이슈 다시 열기
gh issue reopen <번호>

# 이슈에 코멘트 추가
gh issue comment <번호> --body "작업 진행 중..."
```

### 작업 흐름

1. **작업 시작 전**: `gh issue view <번호>`로 요구사항 확인
2. **작업 중**: 필요시 `gh issue comment`로 진행 상황 기록
3. **작업 완료**: `gh issue close <번호> --comment "완료: <요약>"`

## Neovim 플러그인 이슈 목록

| 이슈 | 제목 | 상태 |
|------|------|------|
| #1 | 플러그인 기본 구조 및 설정 시스템 | 구현완료 |
| #2 | 유틸리티 함수 모듈 | 구현완료 |
| #3 | 메타데이터 로딩 모듈 | 구현완료 |
| #4 | Treesitter 기반 템플릿 파서 | 구현완료 |
| #5 | nvim-cmp 자동완성 소스 | 구현완료 |
| #6 | Go-to-Definition 핸들러 | 구현완료 |
| #7 | Hover 문서화 | 구현완료 |
| #8 | Python 서브프로세스 통합 | 구현완료 |
| #9 | 자동 새로고침 및 파일 감시 | 구현완료 |
| #10 | Telescope 통합 | 구현완료 |
| #11 | Which-key 통합 및 문서화 | 구현완료 |

## PyCharm 플러그인 이슈 목록

| 이슈 | 제목 | 상태 |
|------|------|------|
| #12 | 플러그인 프로젝트 구조 및 설정 | 진행중 |
| #13 | 메타데이터 서비스 | 진행중 |
| #14 | Django 템플릿 파서 | 진행중 |
| #15 | 자동완성 (Completion Contributor) | 진행중 |
| #16 | Go to Definition (Reference Contributor) | 진행중 |
| #17 | 호버 문서 (Documentation Provider) | 진행중 |
| #18 | 액션 및 UI | 대기 |
| #19 | 테스트 및 문서화 | 대기 |

## 개발 명령어

```bash
# 메타데이터 생성
make lsp-save

# VSCode 확장 빌드
make build

# VSCode 확장 설치
code --install-extension vscode/django-wireview-0.1.0.vsix

# PyCharm 플러그인 빌드
cd pycharm && ./gradlew buildPlugin

# PyCharm 플러그인 개발 실행
cd pycharm && ./gradlew runIde
```

## 참고

- [HANDOVER.md](./HANDOVER.md) - 상세 인수인계 문서
- [django-wireview#54](https://github.com/itda-work/django-wireview/issues/54) - 관련 이슈
