# 🛸 네온 볼트 약탈자 (Neon Vault Heist) — Roblox 스타터 키트

Roblox Studio를 처음 켜는 분도 **순서대로 따라 하면 30~40분 안에 플레이 가능한 게임**이 되는 키트입니다.
900×900 스터드의 **3레인(미드·탑·봇) 전략 맵**에서 뽑기 → 내 금고 전시 → 초당 수익 →
남의 방어막이 꺼지면 침입해 훔치기 → 드론 해킹 → **은신 수풀 매복** → **중앙 황금 코어 쟁탈전**까지,
리그 오브 레전드 · 포켓몬 유나이트 감성의 전략 루프가 들어 있습니다.
기획한 4테마(💎보석·유물 / 🦖공룡 알 / 🐉전설 몬스터 / 🛸사이버 드론)도 그대로입니다.

UI(현금·방어막 타이머·해킹 버튼·도감·상점)는 **코드가 자동으로 만듭니다.** 화면에 따로 배치할 것이 없습니다.

---

## 0. 폴더 구성

| 파일 | 붙여넣는 곳 | 역할 |
|---|---|---|
| `README.md` | — | 지금 읽고 있는 설치·운영 가이드 |
| `build_layout.lua` | **Command Bar** (한 번만) | 900×900 전략 맵 자동 생성 — 기지 4개 · 미드/탑/봇 레인 · 테마 구역 4 · 은신 수풀 18 · 황금 코어 제단 · 가속/점프 패드 · 테마 3D 템플릿 |
| `scripts/01_DataAndMonetization.server.lua` | `ServerScriptService` (Script) | 데이터 저장/복원, 리더보드, Game Pass·Developer Product |
| `scripts/02_VaultStealCore.server.lua` | `ServerScriptService` (Script) | 기지 배정, 초당 수익, 뽑기, 방어막 타이머, 훔치기, 드론 해킹, 🐾펫 팔로우, 🌿은신 수풀, 💛황금 코어, 패드 |
| `scripts/03_NeonVaultHUD.client.lua` | `StarterPlayer > StarterPlayerScripts` (LocalScript) | 네온 HUD·도감·상점·해킹 버튼·**전략 미니맵**·은신 표시·토스트 |
| `thumbnail_512.png` | — | Roblox 게임 아이콘(512×512) 업로드용 |
| `thumbnail_wide.png` | — | 체험 썸네일(16:9) 업로드용 |
| `../neon-vault/neon-vault-safari.html` | — | **아이폰 사파리용 미니 테스트판** (Roblox 없이 게임 루프를 먼저 체험) |
| `../neon-vault/preview-neon-vault.png` | — | 미니 테스트판 화면 미리보기 |

> 이 키트만 필요하면 저장소의 `roblox-neon-vault/` 폴더 파일 5종(README·build_layout·scripts 3개)과 썸네일 2장을 받으면 됩니다.
> 사파리 미니 테스트판은 같은 저장소의 `neon-vault/` 폴더에 있습니다.

### 완성 후 게임 흐름
1. 접속 → 기지 1~4 중 하나가 자동 배정되고 내 금고로 이동
2. 중앙 **네온 뽑기 타워** 또는 4개 테마 구역의 **뽑기 패드**에서 테마별 뽑기 (💎$40 → 🦖$180 → 🐉$700 → 🛸$2,600)
3. 뽑은 전시품이 내 금고 전시대 8칸에 자동으로 올라가고 **초당 수익**이 쌓임.
   가장 강한 전시품/드론은 **3D 펫 모델로 캐릭터 옆을 따라다닙니다** (🐾)
4. 금색 **수금 패드**를 터치하면 쌓인 현금 회수 (+5% 직접 수금 보너스)
5. 내 방어막은 **60초 켜짐 → 30초 꺼짐** 반복. 꺼진 동안 남의 금고에 들어가 `E`(모바일은 프롬프트 터치)로 **훔치기**
6. 전리품을 들고 **15초 안에 내 금고**로 복귀 → 소유권 이전 + 훔친 횟수 +1
   (가는 길에 주인에게 잡히면 전리품은 원래 자리로 돌아갑니다)
7. 🛸 **드론 해킹**: 드론을 보유하면 HUD의 해킹 버튼으로 가까운 적 방어막 남은 시간을 깎거나 즉시 무력화
8. 🌿 **은신 수풀**: 수풀 존에 들어가면 캐릭터가 반투명해지고 이름표가 사라집니다. 매복·도주용
9. 💛 **황금 하이퍼 코어**: 45초마다 중앙 아레나에 등장. 먼저 닿으면 **+$1,500 + 상대 3기지 방어막 25초 무력화**

---

## 0-B. 🗺️ 맵 구조 (3레인 전략 맵)

```
                    💎 크리스탈 유적 (TOP)
                            │
        [기지 3] ───────────┼─────────── [기지 2]
             🛸 사이버 시티 │ 💛 중앙 아레나    (TOP)
                    (MID)   │         (MID)
             ┌──────────────◉──────────────┐
             │        ▲ 미드 대각선 = 최단·노출
        [기지 1] ───────────┼─────────── [기지 4]
                    🐉 용암 던전 (BOT)  🦖 원시 정글 (BOT)
```

| 루트 | 특징 |
|---|---|
| **미드(MID)** | 기지 ↔ 중앙 아레나를 잇는 대각선 최단로. 가장 빠르지만 사방에서 보입니다 |
| **탑(TOP)** | 💎크리스탈 유적 · 🛸사이버 시티를 지나는 북·서 외곽 우회로 (⚡가속 패드는 42 스터드/초 부스트) |
| **봇(BOT)** | 🐉용암 던전 · 🦖원시 정글을 지나는 남·동 외곽 우회로 |

- 🌿 **은신 수풀 18곳** — 기지 진입로·미드 양옆·구역 입구 요충지. 반경 34 스터드.
- 💛 **황금 코어 제단** — 아레나 정중앙. 45초마다 스폰, 28초 유지.
- 🟢 **점프 패드** — 아레나 좌우에서 95 파워로 튕겨 줍니다.
- 서버는 `Workspace` 속성(`NV_CoreActive` / `NV_CoreEndsAt` / `NV_CoreNextAt`)으로 코어 상태를 공유하고,
  HUD 미니맵이 그 값을 읽어 우측 상단에 표시합니다.

---

## 1. 준비물

- **Windows PC 또는 Mac** (Roblox Studio는 아이폰/아이패드에서 실행되지 않습니다)
- Roblox 계정 (무료)
- Roblox Studio 무료 설치: <https://create.roblox.com/> → 오른쪽 위 **Start Creating** → Studio 다운로드
- 결제는 전혀 필요 없습니다. (게임패스는 나중에 원할 때)

---

## 2. 새 프로젝트 열기

1. Roblox Studio 실행 → 로그인
2. `New` 탭 → **Baseplate** 선택 (회색 바닥만 있는 빈 맵)
3. 오른쪽 **Explorer**(계층) / **Properties**(속성) 창이 보이는지 확인
   안 보이면 상단 `View` 메뉴에서 Explorer · Properties 체크

---

## 3. 맵 자동 생성 (`build_layout.lua`)

### 방법 A — Command Bar (권장, 30초)
1. 상단 메뉴 **View → Command Bar** → 화면 아래 입력창이 열립니다.
2. `build_layout.lua` 내용을 **전부 복사**해 입력창에 붙여넣고 **Enter**
3. Explorer → `Workspace` 아래에 **NeonVaultWorld** 모델이 생깁니다
   - `Plots` 아래 `Plot1 ~ Plot4` (기지 4개 · 3D 금고 문 · 전시대 8칸 · 방어막 돔)
   - `Arena` (중앙 아레나 · `CoreDais` 황금 코어 제단)
   - `GachaTower` (거대 뽑기 타워 + 스테이션 4개)
   - `Lanes` (Mid / Top / Bot 레인 도로)
   - `Regions` (💎크리스탈 유적 · 🛸사이버 시티 · 🐉용암 던전 · 🦖원시 정글)
   - `Bushes` (은신 수풀 18 · `BushZone` 파트에 반경 속성)
   - `Pads` (가속 패드 · 점프 패드)
   - `MapInfo` (미니맵용 좌표 정보)
   - `ServerStorage` 아래 **NeonVaultTemplates** (테마 3D 모델 4종)

> **Command Bar에 붙여넣기가 안 되는 Studio 버전이라면 (방법 B)**
> Explorer → `ServerScriptService` 우클릭 → Insert Object → **Script** → 내용을 전부 붙여넣기 →
> 스크립트 편집기 위쪽의 **Run Script** 버튼을 누릅니다. (게임을 실행(F5)하지 않아도 맵이 생성되고,
> 그 Script는 생성 후 삭제해도 됩니다.)

이미 `NeonVaultWorld`가 있으면 아무것도 지우지 않고 종료합니다. 새로 만들려면 기존 모델을 지우고 다시 실행하세요.

---

## 4. 스크립트 3개 붙여넣기 (순서 중요)

### 4-1. 데이터·수익화
1. Explorer → `ServerScriptService` 우클릭 → Insert Object → **Script**
2. 이름을 `01_DataAndMonetization` 으로 바꿉니다 (이름은 자유, 순서만 중요)
3. 기본으로 들어있는 `print("Hello world!")` 를 지우고 `scripts/01_DataAndMonetization.server.lua` 내용을 전부 붙여넣기

### 4-2. 금고·약탈 코어
1. `ServerScriptService` 우클릭 → Insert Object → **Script** → 이름 `02_VaultStealCore`
2. `scripts/02_VaultStealCore.server.lua` 내용을 전부 붙여넣기

### 4-3. HUD (화면)
1. Explorer → `StarterPlayer` → **StarterPlayerScripts** 우클릭 → Insert Object → **LocalScript**
2. 이름 `03_NeonVaultHUD`
3. `scripts/03_NeonVaultHUD.client.lua` 내용을 전부 붙여넣기

> ⚠️ 4-3은 반드시 **LocalScript** 여야 합니다. (Script로 만들면 화면이 안 뜹니다)
> ⚠️ 4-1, 4-2는 반드시 **Script**(서버) 여야 합니다.

---

## 5. 테스트

1. 상단 **Play** (또는 F5) → 2~3초 뒤 화면 왼쪽 위에 `$500` 패널이 뜹니다
2. 자동으로 기지 하나가 배정되고 그 위로 이동합니다
3. 중앙 타워의 💎 스테이션에 다가가 `E` → 뽑기 → 전시품이 금고에 올라가고 `+$2/초` 표시
4. 금색 수금 패드에서 `E` → 현금이 늘어납니다
5. **Test 탭 → Clients and Servers → 2 players** 로 실행하면 두 명이 서로의 금고를 털 수 있습니다
   (혼자 테스트할 때는 상대 금고가 없으니, 뒤에 설명하는 `PLAYERS` 대신 NPC 기지가 필요하면 알려 주세요)

테스트 중 데이터는 저장되지 않습니다(정상). Publish 후
**Game Settings → Security → Enable Studio Access to API Services** 를 켜면 Studio에서도 저장 테스트가 됩니다.

---

## 6. Game Pass · Developer Product 연결 (선택, 수익화)

1. <https://create.roblox.com/> → 본인 체험(Creation) → **Monetization**
2. **Passes** → Create a Pass 로 3개를 만들고 각각 ID를 확인
   - `2x Cash` (2배 수익)
   - `Instant Lock` (즉시 잠금)
   - `Hacker Drone Pack` (해킹 드론 팩)
3. **Developer Products** → 현금 팩 3종 생성 (`$2,500` / `$15,000` / `$100,000` 상당)
4. `01_DataAndMonetization` 스크립트 맨 위 **CONFIG 표**에 ID를 숫자로 입력

```lua
local CONFIG = {
	GAMEPASS_2X_CASH = 123456789,     -- 본인 ID
	GAMEPASS_INSTANT_LOCK = 123456790,
	GAMEPASS_DRONE_PACK = 123456791,
	PRODUCT_CASH_SMALL = 123456792,
	PRODUCT_CASH_BIG = 123456793,
	PRODUCT_CASH_MEGA = 123456794,
	...
```

ID가 `0`이면 "아직 판매 등록 전" 안내만 뜨고 결제는 일어나지 않습니다. (안전한 기본값)

> 로블록스 정책상 **현금성 보상은 Developer Product**, 영구 기능은 **Game Pass**가 맞습니다.
> 이 키트는 그 구조로 짜여 있습니다.

---

## 7. Publish (세상에 공개)

1. 상단 **File → Publish to Roblox**
2. Name: `Neon Vault Heist` / Description 예시:
   `뽑기로 금고를 채우고, 남의 방어막이 꺼지면 훔쳐 오세요. 4테마 수집 + 드론 해킹.`
3. **Creator Dashboard → Places → 본인 게임 → Thumbnails / Icon**
   - 아이콘: `thumbnail_512.png`
   - 썸네일: `thumbnail_wide.png`
4. 공개 범위를 **Public** 으로 바꾸면 친구들이 들어올 수 있습니다
5. Play 버튼 옆 **⋯ → Copy Experience Link** 로 링크를 복사해 공유

---

## 8. 밸런스 조절 (원하는 대로)

`02_VaultStealCore` 맨 위 숫자만 바꾸면 됩니다.

```lua
local SHIELD_ON_TIME = 60       -- 방어막 켜짐 시간(초)
local SHIELD_OFF_TIME = 30      -- 꺼짐(=털릴 수 있는) 시간(초)
local CARRY_TIME = 15           -- 전리품 운반 제한 시간(초)
local HACK_COOLDOWN = 18        -- 드론 해킹 재사용 대기(초)
local COLLECT_BONUS = 0.05      -- 직접 수금 보너스(5%)
local CORE_INTERVAL = 45        -- 💛 황금 코어 스폰 주기(초)
local CORE_LIFETIME = 28        -- 코어가 남아 있는 시간(초)
local CORE_RADIUS = 15          -- 코어 획득 판정 반경(스터드)
local CORE_REWARD = 1500        -- 코어 획득 현금
local CORE_SHIELD_CUT = 25      -- 코어 획득 시 상대 방어막 무력화(초)
local PET_SIDE_OFFSET = 6       -- 펫이 캐릭터 옆에 떠 있는 거리
local PET_HEIGHT = 9            -- 펫 높이
```

뽑기 가격·수익은 `THEMES` 표에서, 등급 확률은 `RARITY` 의 `weight`(62/25/10/3)에서 조절합니다.

---

## 9. 사파리 3D 미니 테스트판 (`neon-vault/index.html`)

Roblox Studio 없이 **아이폰 사파리에서 3D 오픈 월드를 먼저 체험**하는 WebGL(Three.js) 버전입니다.
`three.min.js` 를 같은 폴더에 함께 올려 두어 CDN이 없어도 100% 로드됩니다.

- **3인칭 3D 캐릭터**(로블록스 아바타 스타일, 걷기 애니메이션·이름표) + **동반 펫/드론 3D 모델**
- 좌하단 조이스틱 드래그 · 바닥 탭 이동 · 우하단 액션 버튼(뽑기·해킹·도감·잠금)
- 4구역 3D 오픈 월드: 💎크리스탈 유적(북) · 🦖원시 정글(동) · 🐉용암 던전(남) · 🛸사이버 시티(서)
- 같은 **3레인 전략 구조**: 미드 대각선 · 탑/봇 외곽로 · ⚡가속 패드 · 🟢점프 패드
- 🌿 은신 수풀: 들어가면 캐릭터가 반투명해지고 경비 드론 추격이 끊깁니다
- 💛 황금 코어: 40여 초마다 아레나 중앙 스폰, 먼저 차지하면 현금 + 적 3기지 방어막 무력화
- 🗺️ 좌상단 **전략 미니맵**: 4기지 방어막 ON/OFF · 내 위치 · 코어 스폰 카운트

PC에서는 파일을 더블클릭, 아이폰에서는 파일 앱 → 공유 → Safari로 열기로 실행합니다.
(깃허브 Pages → `https://8n9wtwzdf6-web.github.io/pickle-mini-games/neon-vault/`)

---

## 10. 자주 막히는 곳

| 증상 | 원인 / 해결 |
|---|---|
| 기지·타워가 안 보임 | `build_layout.lua` 를 실행하지 않음 → 3장 다시 |
| HUD가 안 뜸 | 03을 Script로 만듦 → LocalScript로 다시 만들기 |
| `NeonVaultWorld 를 찾지 못했습니다` 경고 | 맵 생성 전에 Play → 맵 먼저 생성 |
| 뽑기가 안 됨(`데이터를 불러오는 중`) | 01 스크립트가 없거나 오류 → Output 창 확인 |
| 데이터가 저장 안 됨 | Publish 전이거나 API Services 꺼짐 → 6장 참고 |
| 방어막이 안 꺼짐 | 서버 스크립트가 아니라 LocalScript에 02를 넣은 경우 |
| 두 명 테스트에서 한 명이 "빈 기지 없음" | 기지가 4개뿐입니다. `build_layout.lua` 의 `PLOT_RADIUS`/`for i = 1, 4` 를 늘리면 확장 가능 |

오류 메시지는 Studio 하단 **Output** 창에 뜹니다. 빨간 글씨가 있으면 그 줄을 그대로 알려 주세요.

---

## 11. 검증 상태 (2026-11-22 갱신)

- Luau 문법 검사: **오류 0건** (`build_layout.lua` + 스크립트 3개 파싱 통과, 총 3,100여 줄)
- Roblox API 이름 대조: 공식 API 덤프 기준 **클래스·속성·메서드·Enum 불일치 0건**
- 사파리 3D 버전: 헤드리스 Chromium(390×844 · 375×667, WebGL)에서 **콘솔 오류 0건**,
  3D 씬 렌더 · 조이스틱 이동 · 뽑기 · 약탈/운반/반납 · 해킹 · 잠금 · 은신 수풀 · 황금 코어 · 미니맵 동작 확인
- 실제 Studio 실행·플레이 테스트: **미검증** (Studio는 PC 전용이라 제작 환경에서 실행할 수 없습니다)
  → 5장 순서대로 Play 하면서 확인해 주세요. 막히면 Output 창의 빨간 줄을 알려 주시면 바로 고칩니다.
