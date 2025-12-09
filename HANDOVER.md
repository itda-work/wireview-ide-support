# wireview-ide-support 인수인계서

django-wireview IDE 플러그인 프로젝트 인수인계 문서입니다.

## 프로젝트 개요

**목적**: django-wireview 라이브러리를 위한 IDE 자동완성/Go-to-Definition/호버 지원

**관련 이슈**: [django-wireview#54](https://github.com/itda-work/django-wireview/issues/54)

**관련 저장소**:
- 이 저장소: `wireview-ide-support` (IDE 플러그인)
- 라이브러리: `../django-wireview` (wireview_lsp 명령어 포함)

---

## 현재 진행 상황

### Phase 1: VSCode 확장 ✅ 완료

| 항목 | 상태 | 설명 |
|------|------|------|
| Python 메타데이터 추출기 | ✅ | `django-wireview/wireview/management/commands/wireview_lsp.py` |
| VSCode 확장 구조 | ✅ | `vscode/` |
| 템플릿 파서 | ✅ | `vscode/server/src/parser/template.ts` |
| 컴포넌트 자동완성 | ✅ | simple, FQN, app prefix 3가지 형식 |
| 속성 자동완성 | ✅ | Pydantic 필드 + 타입 정보 |
| 이벤트 핸들러 자동완성 | ✅ | async 메서드 |
| 이벤트 수정자 자동완성 | ✅ | prevent, debounce 등 |
| Go to Definition | ✅ | 컴포넌트 → Python 클래스 |
| 호버 문서 | ✅ | docstring, 필드, 슬롯 정보 |
| 빌드 & 패키징 | ✅ | `.vsix` 파일 생성 |

### Phase 2: Neovim 플러그인 ✅ 완료

| 항목 | 상태 | 설명 |
|------|------|------|
| Lua 플러그인 기본 구조 | ✅ | `nvim/lua/wireview/` |
| 설정 시스템 | ✅ | `nvim/lua/wireview/config.lua` |
| 메타데이터 로딩 | ✅ | `nvim/lua/wireview/metadata.lua` |
| 템플릿 파서 | ✅ | `nvim/lua/wireview/parser.lua` |
| nvim-cmp 자동완성 | ✅ | `nvim/lua/wireview/completion.lua` |
| Go to Definition | ✅ | `nvim/lua/wireview/definition.lua` |
| 호버 문서 | ✅ | `nvim/lua/wireview/hover.lua` |
| Telescope 통합 | ✅ | `nvim/lua/wireview/telescope.lua` |
| Which-key 통합 | ✅ | `nvim/lua/wireview/whichkey.lua` |
| 문서화 | ✅ | `nvim/doc/wireview.txt`, `nvim/README.md` |

### Phase 3: PyCharm 플러그인 📋 계획

---

## 디렉토리 구조

```
wireview-ide-support/
├── .gitignore
├── .wireview/
│   └── metadata.json        # 생성된 메타데이터 (gitignore됨)
├── docs/
│   └── ide-support.md       # IDE 지원 문서
├── Makefile                 # 빌드/메타데이터 생성 명령
├── README.md
├── HANDOVER.md              # 이 문서
├── vscode/                  # VSCode 확장
│   ├── package.json
│   ├── tsconfig.json
│   ├── language-configuration.json
│   ├── django-wireview-0.1.0.vsix  # 패키징된 확장
│   ├── src/
│   │   └── extension.ts     # 확장 진입점
│   ├── server/
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── server.ts            # LSP 서버 메인
│   │       ├── metadata/
│   │       │   ├── types.ts         # 메타데이터 타입 정의
│   │       │   └── manager.ts       # Python 실행 & 캐시 관리
│   │       ├── parser/
│   │       │   └── template.ts      # Django 템플릿 파싱
│   │       └── handlers/
│   │           ├── completion.ts    # 자동완성
│   │           ├── definition.ts    # Go to Definition
│   │           └── hover.ts         # 호버 정보
│   └── out/                 # 컴파일된 클라이언트
└── nvim/                    # Neovim 플러그인
    ├── lua/
    │   └── wireview/
    │       ├── init.lua           # 플러그인 진입점
    │       ├── config.lua         # 설정 관리
    │       ├── metadata.lua       # Python 메타데이터 로더 & 캐시
    │       ├── parser.lua         # 템플릿 파싱
    │       ├── completion.lua     # nvim-cmp 소스
    │       ├── definition.lua     # Go-to-definition 핸들러
    │       ├── hover.lua          # Floating window hover
    │       ├── telescope.lua      # Telescope 확장
    │       ├── whichkey.lua       # Which-key 통합
    │       └── utils.lua          # 공유 유틸리티
    ├── plugin/
    │   └── wireview.lua           # 자동 로드
    ├── doc/
    │   └── wireview.txt           # Vim help 문서
    └── README.md
```

---

## 주요 명령어

```bash
# 의존성 설치
make install

# 빌드
make build

# 메타데이터 생성 (django-wireview 테스트 프로젝트 기준)
make lsp-save

# VSCode 확장 패키징
make package

# VSCode 확장 설치
code --install-extension vscode/django-wireview-0.1.0.vsix
```

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    IDE Plugins                          │
├──────────────────┬──────────────────┬──────────────────┤
│  VSCode (완료)   │  Neovim (완료)   │ PyCharm (계획)   │
│  TypeScript LSP  │  Lua Plugin      │ Kotlin Plugin    │
└────────┬─────────┴────────┬─────────┴────────┬─────────┘
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────┐
│              Python Metadata Extractor                  │
│    (django-wireview/wireview/management/commands/)      │
│                                                         │
│  명령어: python manage.py wireview_lsp                  │
│  출력: JSON 메타데이터 (컴포넌트, 필드, 메서드 등)      │
└─────────────────────────────────────────────────────────┘
```

---

## 메타데이터 스키마

`wireview_lsp` 명령어가 출력하는 JSON 구조:

```json
{
  "version": "1.0",
  "generated_at": "2024-01-15T10:00:00Z",
  "components": {
    "Counter": {
      "name": "Counter",
      "fqn": "myapp.live.Counter",
      "app_key": "myapp:Counter",
      "file_path": "/path/to/live.py",
      "line_number": 15,
      "docstring": "...",
      "template_name": "counter.html",
      "fields": {
        "count": {"type": "int", "default": 0, "required": false}
      },
      "methods": {
        "increment": {
          "is_async": true,
          "parameters": {"amount": {"type": "int", "default": 1}},
          "docstring": "...",
          "line_number": 25
        }
      },
      "slots": {},
      "subscriptions": [],
      "subscriptions_is_dynamic": false
    }
  },
  "modifiers": {
    "prevent": {"description": "...", "has_argument": false},
    "debounce": {"description": "...", "has_argument": true}
  }
}
```

---

## Phase 2: Neovim 플러그인 (완료)

### 설치

```lua
-- lazy.nvim
{
  "itda-work/wireview-ide-support",
  ft = { "htmldjango", "html" },
  dependencies = {
    "hrsh7th/nvim-cmp",
    "nvim-telescope/telescope.nvim", -- optional
    "folke/which-key.nvim", -- optional
  },
  opts = {
    python_path = "python",
    django_settings = "", -- e.g., "myproject.settings"
    auto_refresh = true,
  },
}
```

### 기능

- **자동완성**: 컴포넌트, 속성, 핸들러, 이벤트, 수정자
- **Go-to-Definition**: 컴포넌트 및 핸들러 정의로 이동
- **Hover**: Floating window로 문서 표시
- **Telescope**: 컴포넌트 검색 (`:Telescope wireview`)
- **Which-key**: 키바인딩 가이드 (`<leader>w` prefix)

### 명령어

- `:WireviewStatus` - 플러그인 상태 표시
- `:WireviewRefresh` - 메타데이터 새로고침
- `:WireviewGotoDefinition` - 정의로 이동
- `:WireviewHover` - 호버 문서 표시

### 키맵 (Django 템플릿 파일에서)

- `gd` - Go to definition
- `K` - Show hover

---

## 참고 자료

- [VSCode Language Server Extension Guide](https://code.visualstudio.com/api/language-extensions/language-server-extension-guide)
- [nvim-cmp Custom Sources](https://github.com/hrsh7th/nvim-cmp/wiki/List-of-sources)
- [django-wireview 문서](../django-wireview/CLAUDE.md)

---

## 알려진 이슈

1. **VSCode 확장 파일 크기**: `.vscodeignore` 설정 없이 패키징되어 5.6MB (최적화 필요)
2. **메타데이터 캐시**: 5분 TTL, 대규모 프로젝트에서 성능 테스트 필요

---

## 연락처

- GitHub Issue: [django-wireview#54](https://github.com/itda-work/django-wireview/issues/54)
