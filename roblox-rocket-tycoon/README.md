# 🚀 로켓 타이쿤 스타터 키트 (Rocket Space Factory Tycoon)

Roblox Studio를 열고 **30분 안에 실행 가능한 타이쿤 게임**을 완성하는 스타터 키트입니다.
스크립트 3개를 정해진 위치에 붙여넣기만 하면 광석 생산 → 컨베이어 → 수거 → 업그레이드 → **로켓 발사**까지 전부 동작합니다.
UI(돈 표시, 게임패스 버튼, 카운트다운)는 코드가 자동으로 만들기 때문에 따로 배치할 필요가 없습니다.

---

## 0. 폴더 구성

| 파일 | 용도 |
|---|---|
| `README.md` | 지금 읽고 있는 설치·운영 가이드 |
| `scripts/01_PlayerDataAndPasses.server.lua` | `ServerScriptService` 에 넣는 **Script** — 돈/발사횟수, 자동 저장, 게임패스 확인 |
| `scripts/02_TycoonCore.server.lua` | `ServerScriptService` 에 넣는 **Script** — 기지·드로퍼·컨베이어·수거함·업그레이드·로켓 발사 |
| `scripts/03_TycoonHUD.client.lua` | `StarterGui` 에 넣는 **LocalScript** — 화면 UI 전체 |
| `build_layout.lua` | (선택) Studio Command Bar에 붙여넣으면 기지 3D 구조를 자동 생성 |
| `thumbnail.png` | 게임 아이콘/썸네일용 이미지 (원본 1254×1254) |
| `thumbnail_512.png` | Roblox 아이콘 권장 크기(512×512)로 줄인 파일 |
| `thumbnail_wide.png` | 16:9 썸네일용 이미지 (1920×1080) — 체험 썸네일 슬롯용 |
| `rocket-tycoon-safari.html` | **아이폰 사파리에서 바로 플레이하는 미니 테스트판** (단일 HTML 파일, PC·휴대폰 브라우저에서 열기만 하면 실행) |
| `preview-safari-1~3.png` | 위 미니 테스트판 화면 미리보기 (조립 완료 / 발사 중 / 발사 성공) |

### 완성 후 게임 흐름
1. 서버 접속 → 초록색 **ClaimPad** 터치 → 내 기지 획득
2. **Dropper1** 이 광석을 계속 생산 → **Conveyor** 를 따라 이동
3. **Collector(수거함)** 에 쌓임 → 수거함을 터치해 돈 받기 (자동 수거 게임패스가 있으면 자동)
4. 돈으로 **업그레이드 버튼** 구매 → 광석 가치·속도·드릴 개수 증가
5. **LaunchButton** 터치 → 5초 카운트다운 → 로켓 발사 → 보상 + 발사 횟수 +1

---

## 1. 준비물

- **Windows PC 또는 Mac** (Roblox Studio는 휴대폰/아이패드에서 실행되지 않습니다)
- Roblox 계정 (무료)
- **Roblox Studio 무료 설치**: <https://create.roblox.com/> → 오른쪽 위 `Start Creating` → Studio 다운로드
- 결제·구매는 전혀 필요 없습니다.

---

## 2. 새 프로젝트 만들기

1. Roblox Studio 실행 → 로그인
2. `New` 탭 → **Baseplate** 선택 (Template 목록의 첫 번째, 회색 바닥만 있는 빈 맵)
3. 열린 프로젝트에서 오른쪽 **Explorer** 창과 **Properties** 창이 보이는지 확인
   (안 보이면 상단 `View` 메뉴에서 Explorer / Properties 체크)

---

## 3. 기지 구조 만들기

### 방법 A — 자동 생성 (권장, 30초)

1. 상단 메뉴 **View → Command Bar** 를 켜서 하단 입력창을 엽니다.
2. `build_layout.lua` 파일 내용을 **전부 복사**해 Command Bar 입력창에 붙여넣고 **Enter**.
3. Explorer → Workspace 아래에 `TycoonPlot` 모델이 생기고, 그 안에 필요한 파트·버튼·로켓이 전부 만들어집니다.
4. 이미 `TycoonPlot` 이 있으면 아무것도 지우지 않고 종료하니, 다시 만들고 싶을 때는 기존 모델을 지우고 재실행하세요.

> Command Bar가 여러 줄 붙여넣기를 지원하지 않는 Studio 버전이라면 방법 B로 직접 만드세요. (아래 표의 이름·크기·위치를 그대로 쓰면 동일한 결과입니다.)

### 방법 B — 직접 만들기

`Instance.new` 로 만드는 대신 Explorer에서 `+` 버튼(Insert Object)으로 추가합니다.
**이름은 표와 정확히 같아야** 스크립트가 찾습니다.

**Workspace 아래**
| 오브젝트 | 타입 | 크기 (Size) | 위치 (Position) | 속성 |
|---|---|---|---|---|
| `TycoonPlot` | **Model** | – | – | 그 안에 아래 파트들을 넣습니다 |
| `TycoonPlot/Base` | Part | 70, 1, 70 | 0, 0.5, 0 | Anchored ✔, Material Concrete, 색 (52,58,76) |
| `TycoonPlot/ClaimPad` | Part | 10, 1, 10 | 10, 1.5, 6 | Anchored ✔, CanCollide ✔, Material Neon, 색 (60,220,120) |
| `TycoonPlot/Conveyor` | Part | 8, 1, 40 | -16, 1.6, -13 | Anchored ✔, CanCollide ✔, Material DiamondPlate |
| `TycoonPlot/Collector` | Part | 10, 8, 10 | -16, 5, 11 | Anchored ✔, CanCollide ✔, Material Metal, 색 (220,180,70) |
| `TycoonPlot/Dropper1` | Part | 5, 5, 5 | -16, 8, -33 | Anchored ✔, **CanCollide ✘**, 색 (255,138,60) |
| `TycoonPlot/LaunchButton` | Part | 8, 1, 8 | 18, 1.5, 3 | Anchored ✔, CanCollide ✔, Material Neon, 색 (230,70,70) |
| `TycoonPlot/Buttons` | **Folder** | – | – | 업그레이드 버튼 8개를 넣습니다 |
| `TycoonPlot/RocketModel` | **Model** | – | – | 로켓 (아래 참고) |

**`TycoonPlot/Buttons` 폴더 안** — 모두 Part, 크기 5×1×5, Position Y = 1.5

| 이름 | X 위치 (Z는 22) |
|---|---|
| `Button_Drill1` | -21 |
| `Button_Speed1` | -15 |
| `Button_Drill2` | -9 |
| `Button_Dropper2` | -3 |
| `Button_Speed2` | 3 |
| `Button_Drill3` | 9 |
| `Button_Dropper3` | 15 |
| `Button_LaunchUpgrade` | 21 |

**`TycoonPlot/RocketModel` 안** — 모두 Part, **Anchored ✔** 필수

| 이름 | 크기 | 위치 | 색 |
|---|---|---|---|
| `Body` (**PrimaryPart 로 지정**) | 6, 18, 6 | 18, 11, -13 | 흰색 (238,240,248) |
| `Nose` (Shape = Ball) | 5, 5, 5 | 18, 21.5, -13 | 빨강 (230,70,70) |
| `Window` | 2.6, 2.6, 0.6 | 18, 16, -16.2 | 파랑 (80,170,255), Neon |
| `FinLeft` | 1.2, 7, 4 | 14.6, 5, -13 | 빨강 |
| `FinRight` | 1.2, 7, 4 | 21.4, 5, -13 | 빨강 |
| `FinFront` | 4, 7, 1.2 | 18, 5, -16.4 | 빨강 |
| `FinBack` | 4, 7, 1.2 | 18, 5, -9.6 | 빨강 |

> `RocketModel` 선택 → Properties 창의 **PrimaryPart** 칸에 `Body` 를 지정하세요.
> 지정을 잊어도 02 스크립트가 첫 번째 파트를 자동으로 PrimaryPart로 잡고 경고만 남깁니다.
> 로켓 파트가 Anchored가 아니면 스크립트가 자동으로 Anchored로 바꿔 줍니다(중력에 떨어지는 현상 방지).

---

## 4. 스크립트 붙여넣기 (순서 중요)

Explorer에서 아래 위치에 스크립트 오브젝트를 만들고, **기존 내용을 모두 지운 뒤** 파일 내용을 붙여넣습니다.

| 순서 | 파일 | Explorer 위치 | 만들어야 하는 타입 | 권장 이름 |
|---|---|---|---|---|
| 1 | `scripts/01_PlayerDataAndPasses.server.lua` | `ServerScriptService` | **Script** (서버) | `01_PlayerDataAndPasses` |
| 2 | `scripts/02_TycoonCore.server.lua` | `ServerScriptService` | **Script** (서버) | `02_TycoonCore` |
| 3 | `scripts/03_TycoonHUD.client.lua` | `StarterGui` | **LocalScript** | `03_TycoonHUD` |

**만드는 방법**
1. Explorer에서 `ServerScriptService` 에 마우스 올리고 `+` → `Script` 선택 (기본 생성되는 `print("Hello world!")` 는 전부 지우기)
2. 스크립트 창에 01 파일 내용을 **전부** 붙여넣기 (Ctrl+A → Ctrl+V)
3. 같은 방법으로 `02_TycoonCore` Script 추가 → 02 파일 붙여넣기
4. `StarterGui` 에서 `+` → **`LocalScript`** 선택 (❌ `Script` 아님) → 03 파일 붙여넣기
5. 저장: Ctrl+S

> 서버 스크립트를 `StarterPlayerScripts` 나 `ReplicatedStorage` 에 넣으면 동작하지 않습니다. 위치를 꼭 지켜 주세요.
> `03` 은 반드시 **LocalScript** 여야 합니다. Script로 만들면 화면 UI가 만들어지지 않습니다.

---

## 5. 게임패스 만들기 + ID 넣기 + Publish

게임패스 ID를 넣지 않아도 게임은 정상 동작합니다(2배·자동 수거 기능만 꺼짐). 먼저 Publish 한 뒤 ID를 넣는 순서를 권장합니다.

### 5-1. Publish (체험 등록)
1. Studio 상단 **File → Publish to Roblox**
2. Name: 예) `Rocket Factory Tycoon`
3. Description: 예) `Build your rocket factory, upgrade the drills, and launch rockets into space!`
4. **Playability: Public** (공개. 테스트만 할 거면 Private도 가능)
5. `Create` → 업로드 완료

### 5-2. 게임패스 2개 만들기
1. 브라우저에서 <https://create.roblox.com/> → **Creations** → 방금 만든 체험 선택
2. 왼쪽 메뉴 **Monetization(또는 Associated Items) → Passes → Create a Pass**
3. 첫 번째 패스
   - Name: `2x Cash`
   - Description: `모든 광석 판매가 2배`
   - Icon: `thumbnail_512.png` 업로드
   - **Sales → Item for Sale 켜기**, Price 예) `99` Robux
   - 저장 후 **Pass ID** 확인 (패스 페이지 URL의 숫자, 예: `.../game-pass/1234567890/...` → `1234567890`)
4. 두 번째 패스
   - Name: `Auto Collect`, Description: `수거함을 자동으로 정산`, Price 예) `149` Robux
   - 같은 방법으로 Pass ID 복사

### 5-3. ID를 스크립트에 넣기
Studio에서 `01_PlayerDataAndPasses` 스크립트 **맨 위쪽 CONFIG** 만 수정합니다.

```lua
local CONFIG = {
    DOUBLE_CASH_PASS_ID = 1234567890,   -- 2배 수익 패스 ID
    AUTO_COLLECT_PASS_ID = 9876543210,  -- 자동 수거 패스 ID
    START_CASH = 100,
    ...
}
```

> ID는 **01 스크립트에서만** 넣으면 됩니다. 화면(HUD)이 이 값을 자동으로 읽어서 우측 상단 구매 버튼에 가격을 표시합니다.
> 수정 후 다시 **File → Publish to Roblox** 로 업로드해야 실제 게임에 반영됩니다.
> 게임패스 구매 창은 **Publish 된 체험에서 플레이할 때만** 열립니다(Studio 테스트에서는 열리지 않는 것이 정상).

---

## 6. 테스트 체크리스트

### 6-1. Studio에서 혼자 테스트
1. 상단 **File → Game Settings → Security → Enable Studio Access to API Services** 를 켭니다.
   (이걸 켜야 Studio에서 저장/불러오기 테스트가 됩니다. 꺼져 있으면 경고 로그만 남기고 게임은 정상 진행)
2. **Play** (F5) → 초록색 ClaimPad 를 캐릭터로 걸어서 터치
3. 확인할 것
   - [ ] 좌측 상단에 `CASH`, `발사 0회`, `기지: 내 기지 운영 중` 표시
   - [ ] Dropper1 에서 광석이 떨어져 컨베이어를 따라 수거함으로 이동
   - [ ] 수거함 위에 `수거 대기 $…` 표시 → 수거함 터치 시 돈 증가 + 하단 알림
   - [ ] 업그레이드 버튼 터치 → 돈 차감, 버튼이 초록색 + `해금 완료`
   - [ ] `Button_Dropper2` 구매 시 드릴 2호기 생성, 광석 라인 증가
   - [ ] LaunchButton 터치 → 1,2,3,4,5 카운트다운 → 로켓 상승(불꽃·연기) → 보상 + `발사 1회`
   - [ ] 로켓이 1.5초 후 원래 자리로 돌아오고 다시 발사 가능
   - [ ] 정지 후 다시 Play → 돈/발사 횟수가 유지됨(DataStore)
4. Output 창(보기 → Output)에 빨간 에러가 없는지 확인

### 6-2. 2인 테스트 (소유권 확인)
상단 **Test → Clients and Servers → Players 2 → Start**
- 한 명이 기지를 차지하면 다른 한 명은 ClaimPad 에서 `○○ 님이 사용 중인 기지입니다` 안내를 받습니다.

---

## 7. 게임 규칙 (스크립트에 구현된 그대로)

### 수거와 돈
- 광석 1개 가치 = **기본 8** + 무작위 0~3 (+ 업그레이드 보너스)
- 광석이 수거함에 도착하면 `수거 대기` 금액이 쌓입니다. **수거함을 터치**하면 한 번에 입금됩니다.
- **2배 수익 게임패스** 보유 시 광석이 도착하는 순간 2배로 계산됩니다.
- **자동 수거 게임패스** 보유 시 2초마다 자동 정산됩니다.
- 기지 주인이 나가면 남은 대기 금액은 자동 정산 후 저장되고, 기지는 초기화되어 다른 사람이 사용할 수 있습니다.

### 업그레이드 (버튼 이름 = Explorer 파트 이름)
| 버튼 | 가격 | 효과 |
|---|---|---|
| `Button_Drill1` | $100 | 광석 가치 +6 |
| `Button_Speed1` | $250 | 컨베이어 속도 +5, 생산 간격 -0.2초 |
| `Button_Drill2` | $450 | 광석 가치 +12 |
| `Button_Dropper2` | $900 | 드릴 2호기(생산 라인 +1) |
| `Button_Speed2` | $1,500 | 컨베이어 속도 +6, 생산 간격 -0.25초 |
| `Button_Drill3` | $3,000 | 광석 가치 +20 |
| `Button_Dropper3` | $7,000 | 드릴 3호기(생산 라인 +1) |
| `Button_LaunchUpgrade` | $5,000 | 발사 보상 +$750 |

### 로켓 발사
- `LaunchButton` 터치(기지 주인만) → **5초 카운트다운** → **6초 동안 220 studs 상승** (불꽃·연기·조명 파티클 자동 생성)
- 성공 보상: **Cash +$250**, **Launches +1**, 1.5초 후 로켓이 원위치로 복귀

### 저장
- 저장 항목: `Cash`, `Launches`
- 저장 시점: 60초마다 / 나갈 때 / 서버 종료 시
- 저장소 이름: `RocketTycoon_Save_v1` (이름을 바꾸면 기존 데이터와 분리됩니다)

---

## 8. 밸런스 조정 (숫자만 바꾸면 됨)

`02_TycoonCore` 스크립트 맨 위 `CONFIG`:

| 변수 | 기본값 | 의미 |
|---|---|---|
| `ORE_BASE_VALUE` | 8 | 광석 1개 기본 가치 |
| `ORE_VALUE_VARIANCE` | 3 | 광석마다 +0~3 랜덤 |
| `SPAWN_INTERVAL` | 2.2 | 광석 생성 간격(초) |
| `CONVEYOR_SPEED` | 12 | 컨베이어 이동 속도(studs/초) |
| `MAX_ORES` | 90 | 동시 존재 광석 수 제한(렉 방지) |
| `AUTO_COLLECT_SECONDS` | 2 | 자동 수거 주기 |
| `LAUNCH_REWARD` | 250 | 발사 1회 보상 |
| `LAUNCH_COUNTDOWN` | 5 | 카운트다운 길이 |
| `LAUNCH_RISE_SECONDS` / `LAUNCH_RISE_HEIGHT` | 6 / 220 | 로켓 상승 시간·높이 |

`01_PlayerDataAndPasses` 의 `CONFIG`:

| 변수 | 기본값 | 의미 |
|---|---|---|
| `START_CASH` | 100 | 신규 플레이어 시작 돈 |
| `AUTOSAVE_SECONDS` | 60 | 자동 저장 주기 |

업그레이드 가격과 효과는 `02` 스크립트의 `UPGRADES` 표에서 바로 고칠 수 있습니다 (`Cost`, `Info`, `Apply`).

---

## 9. 다인용으로 확장하기 (선택)

이 키트는 **기지 1개** 기준입니다(1인 또는 친구와 번갈아 플레이). 여러 명이 각자 기지를 가지려면:

1. Workspace의 `TycoonPlot` 을 복제(`Ctrl+D`)해서 이름을 `TycoonPlot2` 로 변경 → Base 등 파트를 X축으로 80 studs 정도 옮겨 겹치지 않게 배치
2. `02_TycoonCore` 스크립트를 복제해 이름을 `02_TycoonCore_Plot2` 로 변경
3. 복제한 스크립트의 `CONFIG` 첫 줄을 수정

```lua
PLOT_NAME = "TycoonPlot2",
```

4. 같은 방법으로 `TycoonPlot3` … 을 추가 (서버당 플레이어 8명이면 기지 8개 권장)

각 기지는 자기 돈(Cash)은 공유하지만 업그레이드·수거 대기 금액은 기지별로 따로 관리됩니다.
(좌측 상단 `기지:` 표시는 기본 기지 `TycoonPlot` 기준입니다.)

---

## 10. 문제 해결

| 증상 | 원인 / 해결 |
|---|---|
| Output에 `'TycoonPlot' 모델이 없어 스크립트를 시작하지 않습니다` | Workspace에 `TycoonPlot` 모델이 없거나 이름이 다름. 3장 구조 확인 |
| `'ClaimPad' 파트를 찾지 못했습니다` 등 | 파트 이름 오타. **대소문자까지** 정확히 (예: `claimpad` ❌) |
| ClaimPad를 터치해도 반응 없음 | 캐릭터가 실제로 파트에 닿아야 합니다. 파트가 Anchored인지, `CanTouch` 가 꺼져 있지 않은지 확인 |
| 광석이 안 나옴 | 기지를 Claim 했는지 확인(`기지: 내 기지 운영 중`). `Dropper1` 이 `TycoonPlot` 안에 있는지 확인 |
| 광석이 컨베이어에 안 붙고 사라짐 | 정상 동작입니다(광석은 앵커드 파트를 스크립트가 직접 이동). `Conveyor` 가 너무 짧으면 경로가 짧아 금방 도착합니다 |
| 로켓이 안 움직임 | `RocketModel` 이 Model인지, 안에 파트가 있는지, `LaunchButton` 이 `TycoonPlot` 안에 있는지 확인 |
| 로켓이 중력으로 떨어짐 | 파트 Anchored 해제 상태 → 스크립트가 자동으로 Anchored 처리하지만, 새 파트를 추가했다면 직접 켜 주세요 |
| 돈이 저장되지 않음 | Studio: Game Settings → Security → **Enable Studio Access to API Services** 켜기. 실제 게임에서는 Publish 여부 확인 |
| 게임패스 구매 창이 안 열림 | Studio에서는 열리지 않습니다. Publish 후 Roblox 앱/웹에서 플레이. ID가 0이면 버튼에 `게임패스 미설정` 표시 |
| 화면 UI가 안 보임 | `03_TycoonHUD` 가 **LocalScript** 이고 `StarterGui` 에 있는지 확인 |
| 2배/자동 수거가 적용 안 됨 | 01 스크립트 CONFIG의 ID 확인 → 수정 후 **다시 Publish** |

---

## 11. 출시 전 체크리스트 (수익화)

- [ ] **아이콘 등록**: Creator Dashboard → 체험 → Thumbnails/Icon → `thumbnail_512.png`(512×512) 업로드
- [ ] **썸네일 등록**: 같은 화면에서 `thumbnail_wide.png`(16:9)를 Thumbnails 에 업로드, `thumbnail_512.png` 는 Icon 슬롯에 업로드
- [ ] **제목/설명에 검색 키워드**: `tycoon`, `rocket`, `factory`, `simulator` 등 영문 키워드가 검색 노출에 유리
- [ ] **게임패스 가격**: 2배 수익 49~99 R$, 자동 수거 99~199 R$ 구간이 초기 체험에서 무난합니다
- [ ] **Playability: Public** 인지 확인 (Private이면 아무도 입장 불가)
- [ ] **모바일 확인**: Studio의 `Test → Device` 로 Phone 화면에서 버튼이 잘 보이고 터치가 되는지 확인
- [ ] **수익 구조 이해**
  - 게임패스 판매 금액의 **30%는 Roblox 수수료**, 개발자에게 70% 지급
  - **Premium Payouts**: 프리미엄 구독자의 플레이 시간에 비례해 추가 지급(체험 공개 + 참여도 기준)
  - **DevEx(현금 환전)**: 최소 30,000 Robux, 만 13세 이상·인증 계정 등 조건 충족 시 신청 가능(환율은 정책에 따라 변동)
- [ ] **재방문 요소**: 다음 업데이트 예고, 리더보드(발사 횟수) 추가 등

---

## 12. 다음 확장 아이디어

1. **리더보드**: `leaderstats.Launches` 를 그대로 쓰는 `leaderboard` 파트 추가 → "우주 발사왕" 랭킹
2. **로켓 종류 해금**: 발사 횟수에 따라 로켓 색/크기 변경(발사 보상 배수 증가)
3. **부품 공장 라인 추가**: `Dropper` → `Conveyor` → `Collector` 를 두 번째 라인으로 복제 + 새 버튼 추가
4. **희귀 광석**: 5% 확률로 보라 광석(가치 10배) → 수집 욕구 자극
5. **일일 보상**: 24시간마다 무료 캐시 지급 (`os.time()` 기반, DataStore에 `LastDaily` 저장)
6. **사운드**: 발사 시 `SoundService` 로 로켓 굉음, 수거 시 동전 소리
7. **친구 초대**: `SocialService:PromptGameInvite` 로 초대 버튼 추가

---

### 동작 확인 범위 안내
- 이 키트의 3개 스크립트는 Roblox Studio에서 **에러 없이 로드되도록 방어 코드**(파트 누락 시 경고 후 대기, DataStore/게임패스 실패 시 기본값 유지)를 포함합니다.
- 다만 실제 물리·네트워크 동작은 Roblox 런타임에서만 확인되므로, **6장 체크리스트를 한 번 실행**해 보고 화면과 Output을 확인하는 것이 마지막 단계입니다.
