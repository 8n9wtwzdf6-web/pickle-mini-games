# 🧚 매직 하트핑: 요정 캐치 & 하우스 — Roblox 스타터 키트

Roblox Studio를 처음 켜는 분도 **순서대로 따라 하면 30~40분 안에 플레이 가능한 게임**이 되는 키트입니다.
마법 마을 6구역을 돌아다니며 요정을 찾고 → 마법 콤팩트 타이밍 게임으로 포획 → **내 요정 하우스에 직접 걸어 들어가** 요정들이 소파·그네·트램펄린을 오가며 노는 모습을 보고, 밥·놀기·쓰다듬기로 키우는 루프가 그대로 들어 있습니다.

UI(코인·콤팩트 미니게임·도감·하우스·상점)는 **코드가 자동으로 만듭니다.** 화면에 따로 배치할 것이 없습니다.

---

## 0. 폴더 구성

| 파일 | 붙여넣는 곳 | 역할 |
|---|---|---|
| `README.md` | — | 지금 읽고 있는 설치·운영 가이드 |
| `build_layout.lua` | **Command Bar** (한 번만) | 마법 마을 6구역 · 분수대 · 카페 · 구름 정원 · 크리스탈 동굴 · **실내 가구까지 갖춘 요정 하우스 4채** · 요정 3D 템플릿 자동 생성 |
| `scripts/01_DataAndMonetization.server.lua` | `ServerScriptService` (Script) | 데이터 저장/복원, 리더보드, 도감 목록, Game Pass·Developer Product |
| `scripts/02_CatchAndHouseCore.server.lua` | `ServerScriptService` (Script) | 요정 랜덤 소환, 서버 판정 콤팩트 캐치, 하우스 육성, 따라다니는 요정 펫, **하우스 안 요정 자유 놀이 AI** |
| `scripts/03_FairyHUD.client.lua` | `StarterPlayer > StarterPlayerScripts` (LocalScript) | 파스텔 HUD · 캐치 미니게임 화면 · 도감 · 하우스 · 상점 |
| `thumbnail_512.png` | — | Roblox 게임 아이콘(512×512) 업로드용 |
| `thumbnail_wide.png` | — | 체험 썸네일(16:9) 업로드용 |
| `../fairy-catch/index.html` | — | **아이폰 사파리용 미니 테스트판** (Roblox 없이 게임 루프를 먼저 체험) |
| `../fairy-catch/preview-fairy-catch.png` | — | 미니 테스트판 화면 미리보기 |

### 완성 후 게임 흐름
1. 접속 → 마법 마을 광장에 스폰, 내 요정 하우스(1~4번)가 자동 배정
2. 마을 6구역(풀숲 · 꽃길 · 분수대 광장 · 디저트 카페 · 구름 정원 · 크리스탈 동굴)에 요정이 반짝이며 계속 소환됨
3. 요정에게 다가가 **E** (모바일은 프롬프트 버튼) → **마법 콤팩트** 화면이 열림
4. 회전하는 하트가 **분홍 반짝 구간**에 들어올 때 탭 → 3~4번 맞히면 포획 성공 (판정은 서버가 계산)
5. 포획하면 코인 + 도감 등록 + **따라다니는 요정 친구**가 생김
6. **내 하우스 문으로 걸어 들어가면** 잡은 요정들이 3D로 소파·침대·그네·점프 패드를 오가며 통통 튀고 빙글 돌고, 마주치면 머리 위에 💖·✨·🎵·🍓 말풍선을 띄웁니다
7. 하우스 패드의 **하우스 메뉴** → 밥(5코인)·놀아주기·쓰다듬기로 친밀도 상승 → 100이 되면 Lv.Up + 보너스 코인 (버튼을 누르면 그 요정이 하트·점프로 반응)
8. 하우스에 있는 요정들은 **초당 코인**을 모아 줌 → `코인 수확` 버튼으로 회수
9. 코인으로 상점에서 하우스 꾸미기(러그·스탠드·커튼·소파·샹들리에) 구매

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
1. 상단 메뉴 `View` → **Command Bar** 체크 (화면 아래 한 줄 입력창이 생깁니다)
2. `build_layout.lua` 파일을 메모장으로 열어 **전체 복사**
3. Command Bar 클릭 → 붙여넣기(Ctrl+V) → **Enter**
4. 10~20초 기다리면 아래쪽 Output 창에
   `매직 하트핑 월드 생성 완료!` 가 뜹니다
5. 카메라를 돌려 마법 마을이 생겼는지 확인

> 다시 실행해도 됩니다. 이전 `FairyWorld` 폴더를 지우고 새로 만듭니다.
> Command Bar는 **한 번만** 쓰는 도구입니다(게임에 저장되지 않습니다).

### 방법 B — 손으로 만들기
자동 생성을 쓰지 않아도 됩니다. 다만 스크립트가 아래 이름을 찾으므로 **이름을 꼭 맞춰** 주세요.
- `Workspace > FairyWorld > Zones` 안에 `Zone_plaza`, `Zone_grass`, `Zone_flower`, `Zone_cafe`, `Zone_cloud`, `Zone_cave` 이름의 파트(속성 `ZoneId` = plaza/grass/...)
- 하우스 패드: 이름 `HousePad`, 속성 `HouseIndex` = 1~4
- `ServerStorage > FairyTemplates > Fairy_Common / Fairy_Rare / Fairy_Legend` (Model, PrimaryPart = `Root`)

---

## 4. 서버 스크립트 넣기

### 4-1. 데이터 + 수익화
1. Explorer 에서 `ServerScriptService` 위에 마우스 오른쪽 → **Insert Object** → **Script**
2. 새로 생긴 `Script` 이름을 `01_DataAndMonetization` 으로 바꿉니다 (이름은 자유, 순서만 중요)
3. `scripts/01_DataAndMonetization.server.lua` 내용 전체를 복사해 스크립트 편집창에 붙여넣기
4. 저장(Ctrl+S)

### 4-2. 캐치 & 하우스 코어
1. 같은 방법으로 `ServerScriptService` 에 **Script** 하나 더 추가 → 이름 `02_CatchAndHouseCore`
2. `scripts/02_CatchAndHouseCore.server.lua` 전체 붙여넣기

### 4-3. 화면(UI)
1. Explorer 에서 `StarterPlayer > StarterPlayerScripts` 위에 마우스 오른쪽 → **Insert Object** → **LocalScript**
2. 이름 `03_FairyHUD`
3. `scripts/03_FairyHUD.client.lua` 전체 붙여넣기

> 붙여넣은 뒤 Output 창에 빨간 오류가 없는지 확인하세요.
> 정상이면 `[FairyCatch] 데이터/수익화 스크립트 준비 완료`, `캐치 & 하우스 코어 준비 완료`, `HUD 준비 완료` 세 줄이 뜹니다.

---

## 5. 플레이 테스트

1. 위쪽 **Play** (▶) 버튼 → 5~10초 뒤 마을이 로드됩니다
2. 하늘색 요정들이 반짝이며 떠다니는지 확인
3. 요정에게 걸어가면 **E** 프롬프트가 뜹니다 → 눌러서 콤팩트 미니게임 시작
4. 하트가 분홍 구간에 올 때 화면을 탭(클릭) → 3번 맞히면 포획
5. 오른쪽 위 **도감 / 상점** 버튼, 내 하우스 패드의 **요정 하우스 열기** 확인

### 잘 안 될 때
| 증상 | 해결 |
|---|---|
| 요정이 안 보여요 | Output에 `FairyWorld 가 없습니다` 가 있으면 `build_layout.lua` 를 먼저 실행하세요 |
| 프롬프트가 안 떠요 | 요정 모델의 `Body` 파트에 ProximityPrompt 가 있는지 확인 (02 스크립트가 자동으로 붙입니다) |
| UI가 안 보여요 | 03번을 **LocalScript** 로 넣었는지 확인 (Script 로 넣으면 화면에 안 나옵니다) |
| 데이터가 저장 안 돼요 | Studio 에서는 저장되지 않는 것이 정상입니다. Publish 후 Game Settings → Security → **Enable Studio Access to API Services** 를 켜면 테스트 저장이 됩니다 |
| 오류 `01_... 먼저 넣어 주세요` | 01번 스크립트 이름/위치를 확인하고 다시 Play |

---

## 6. Publish (세상에 공개)

1. 상단 `File` → **Publish to Roblox**
2. Name: `매직 하트핑: 요정 캐치 & 하우스`
3. Description 예시:
   > 반짝이는 요정을 찾아 마법 콤팩트로 포획하고, 내 하우스에서 키워 보세요! 요정 12종 수집 · 육성 · 꾸미기.
4. Thumbnail: `thumbnail_512.png` 업로드
5. **Create** → 게임 주소가 만들어집니다
6. 체험 페이지에서 ⋯ → **Configure** → **Thumbnails** 에 `thumbnail_wide.png` 업로드

---

## 7. 수익화 (Game Pass / Developer Product)

먼저 게임을 Publish 한 뒤에 만들 수 있습니다.
<https://create.roblox.com> → **Creations** → 내 체험 → **Monetization**

### 7-1. Game Pass 3종 (한 번 사면 계속)
| 상품명 | 가격 예시 | 코드에서 하는 일 | CONFIG 이름 |
|---|---|---|---|
| 황금 콤팩트 (2x Catch) | 99 R$ | 포획 코인 2배 | `GAMEPASS_GOLDEN_COMPACT` |
| 요정 슬롯 +3 (Extra Fairy Slots) | 149 R$ | 하우스 자리 4 → 7 | `GAMEPASS_EXTRA_SLOTS` |
| 전설의 요정 알 (Legend Fairy Egg) | 299 R$ | 접속 시 갤럭시핑 1회 지급 | `GAMEPASS_LEGEND_EGG` |

만든 뒤 각 Pass 의 **ID**(숫자)를 `01_DataAndMonetization.server.lua` 맨 위 CONFIG 에 넣습니다.

```lua
local CONFIG = {
    GAMEPASS_GOLDEN_COMPACT = 123456789,  -- ← 본인 Pass ID
    GAMEPASS_EXTRA_SLOTS = 123456790,
    GAMEPASS_LEGEND_EGG = 123456791,
    ...
}
```

### 7-2. Developer Product 3종 (반복 구매)
| 상품명 | 지급 코인 | CONFIG 이름 |
|---|---|---|
| 코인 500 | 500 | `PRODUCT_COINS_SMALL` |
| 코인 2,000 | 2,000 | `PRODUCT_COINS_MEDIUM` |
| 코인 8,000 | 8,000 | `PRODUCT_COINS_LARGE` |

ID를 넣으면 결제 즉시 코인이 지급되고 `ProcessReceipt` 가 정상 처리합니다.

> ID가 `0` 인 동안에는 구매 버튼이 아무 일도 하지 않습니다(안전). 게임은 그대로 플레이할 수 있습니다.

### 7-3. 수익을 내려면 알아 둘 것
- Roblox 는 결제 금액의 약 30%를 가져가고, 남은 금액이 개발자 수익(DevEx 대상)이 됩니다.
- 처음에는 **아이들이 좋아할 만한 것**: ① 코인 2배 패스 ② 하우스 꾸미기 아이템 ③ 새 요정 알(뽑기형 상품)
- 가격은 처음에 낮게(49~99 R$) 잡고, 하루 방문자 수를 보면서 올리는 편이 안전합니다.
- **광고·뽑기 문구**는 Roblox 정책상 "확률"을 표시해야 합니다. Developer Product 설명에 확률을 적어 두세요.

---

## 8. 12종 요정 목록 (저작권 안전 오리지널)

| 요정 | 등급 | 주 서식지 | 특징 |
|---|---|---|---|
| 루비하트핑 | 일반 | 풀숲 | 하트 마법 |
| 슈가핑 | 일반 | 디저트 카페 | 달콤한 향기 |
| 플라워핑 | 일반 | 꽃길 | 꽃잎 피우기 |
| 스타벨핑 | 일반 | 광장 | 별 종소리 |
| 클라우드핑 | 고급 | 구름 정원 | 구름 타기 |
| 젤리팝핑 | 고급 | 디저트 카페 | 젤리 만들기 |
| 선샤인핑 | 고급 | 구름 정원 | 햇살 모으기 |
| 레인보우핑 | 희귀 | 꽃길 | 무지개 그리기 |
| 문라이트핑 | 희귀 | 크리스탈 동굴 | 달빛 |
| 크리스탈핑 | 영웅 | 크리스탈 동굴 | 수정 마법 |
| 드림핑 | 영웅 | 구름 정원 | 꿈 배달 |
| 갤럭시핑 | 전설 | 크리스탈 동굴 | 별자리 |

> 이름·색·설정은 전부 이 프로젝트를 위해 새로 만든 것입니다. 특정 방송/완구의 캐릭터를 복제하지 않았으니 안심하고 써도 됩니다.
> 나중에 이름을 바꾸고 싶으면 **01 스크립트의 `FAIRY_LIST`** 한 곳만 고치면 도감·UI·소환에 모두 반영됩니다.

---

## 9. 게임을 더 키우는 팁

1. **요정 추가**: `FAIRY_LIST` 에 한 줄 추가 + `ServerStorage > FairyTemplates` 에 모델 추가
2. **구역 추가**: `build_layout.lua` 의 `ZONES` 표에 추가하고, 그 구역에 살 요정의 `zone` 값을 맞추기
3. **이벤트**: 저녁 7~9시에 전설 요정 등장 확률을 올리려면 02 스크립트의 `weights` 값을 시간에 따라 바꾸면 됩니다
4. **친구 시스템**: 요정을 친구에게 선물하는 기능은 `HouseData` 에 `Gift` 항목을 추가해 확장

---

## 10. 파일 검증 상태 (제작 시 확인한 것)

- Luau 문법 검사: 4개 파일 모두 **0 오류**
- Roblox API 이름 대조: 사용한 클래스/속성/Enum 을 Roblox API 덤프와 대조 확인 (0건 불일치)
- 하우스 구조 대조: `build_layout.lua` 가 만드는 `FairyHousePlots > FairyHouse_1~4 > RoomCenter` 위치·`RoomSize` 를 `02` 스크립트가 그대로 읽어 요정을 방 안(가로 ±5.9, 세로 ±4.9)에만 머물게 함
- 실제 Studio 실행: **미검증** (제작 환경에서 Studio를 실행할 수 없습니다)
  → 위 5번 "플레이 테스트" 를 먼저 해 보시고, 오류가 나오면 Output 창의 빨간 줄을 그대로 알려 주세요.
  → 하우스 앞면이 크게 열려 있어(폭 12.8스터드) 밖에서도 가구와 요정이 보입니다. 안으로 걸어 들어가 소파·침대·그네·점프 패드를 확인해 보세요.
