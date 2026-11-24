> 💡 PC 자동 동기화 브릿지(Pickle Agent)를 켜 두시면 C:\PickleGames\roblox-turret-defense 폴더가 자동으로 최신 유지됩니다.

# 🍀 운빨·조합 터렛 디펜스 — Roblox 4인 협동 키트

스타 유즈맵 감성 그대로, **4명이 각자 라인을 맡아** 랜덤 뽑기·합성으로 터렛을 키우고
**중앙 넥서스**로 몰려오는 20웨이브를 함께 막는 협동 디펜스입니다.
5웨이브마다 **울트라리스크 보스**가 넥서스 광장까지 밀고 들어와 **공성전**을 벌이고,
보스를 잡으면 **유물 3지선다**로 파티 전체가 강해집니다.

> 이 폴더는 **Roblox Studio 복붙용 키트**입니다. 아이폰 사파리에서 먼저 해보려면
> `../turret-defense/index.html` 을 여세요. (같은 루프를 3D로 미리 체험)

---

## 1. 폴더 구성

| 파일 | 붙여넣는 곳 | 역할 |
|---|---|---|
| `01_MapAndTurrets.server.lua` | `ServerScriptService` (Script) | P1~P4 4레인 아레나 · 분리벽 · 스폰 게이트 · **중앙 넥서스**(회전 링·크리스탈·HP바) · 터렛 패드 20개(라인당 4 + VIP 1) · **터렛 모델 10종** · **적 모델 5종** |
| `02_WaveGachaMerge.server.lua` | `ServerScriptService` (Script) | 접속자를 P1~P4에 자동 배정 · 20웨이브 · 보스 공성 · **뽑기/합성/공용 가스 강화** · 터렛 360° 추적·반동 · 투사체/레이저/폭발 · 유물 3지선다 · HUD 상태 동기화 |
| `03_MonetizationPasses.server.lua` | `ServerScriptService` (Script) | 게임패스 3종(2배속·자동합성·VIP 슬롯) + 개발자 상품 3종(미네랄·전설 확정·부활권). **ID만 넣으면 판매 시작** |
| `04_ClientHUD.client.lua` | `StarterPlayer > StarterPlayerScripts` (**LocalScript**) | 고정 쿼터뷰 카메라 · 상단 HUD(웨이브·넥서스 HP·미네랄·가스) · **4인 파티 현황** · 하단 버튼(뽑기·합성·공격력·공속·지원) · 내 라인 4칸 표시 · 유물/결과 화면 |
| `../turret-defense/index.html` | — | 아이폰 사파리용 3D 미니 테스트판 (AI 아군 3명과 4인 팟 연출) |
| `../turret-defense/preview-turret-defense.png` | — | 미니 테스트판 미리보기 |

### 게임 흐름
1. 접속 → **P1~P4 라인 자동 배정** (최대 4인, 남는 라인은 AI가 방어)
2. 내 라인 패드에 **🔮 뽑기**(미네랄 18)로 터렛 소환 → 같은 등급·같은 종류 2개를 **⚡ 합성**해 일반→희귀→영웅→전설→신화로 진화
3. 웨이브 클리어 → **가스** 획득 → 파티 공용 **공격력·공속 강화**
4. 5·10·15·20 웨이브 **울트라리스크** → 넥서스 광장에서 공성(2.4초마다 넥서스 피해) → 처치 시 **유물 3지선다**
5. 적이 넥서스에 닿으면 HP 30이 깎이고, 0이 되면 패배. 20웨이브를 버티면 승리

---

## 2. 준비물

- **Windows PC 또는 Mac** (Roblox Studio는 아이폰에서 실행되지 않습니다)
- Roblox 계정(무료), Roblox Studio (<https://create.roblox.com/> → Start Creating)
- 결제는 필요 없습니다. 게임패스는 나중에 원할 때.

---

## 3. 붙여넣기 순서 (그대로 따라 하세요)

1. Studio 실행 → 로그인 → `New` → **Baseplate** 선택
2. 오른쪽 **Explorer / Properties** 창이 보이게 (View 메뉴에서 체크)
3. **01 먼저**: Explorer에서 `ServerScriptService` 우클릭 → `Insert Object` → **Script**
   - 이름을 `01_MapAndTurrets` 로 바꾸고, 파일 내용 전체를 붙여넣기 (기존 `print("Hello world!")` 는 지우기)
4. **02**: 같은 방법으로 Script 추가 → 이름 `02_WaveGachaMerge` → 전체 붙여넣기
5. **03**: Script 추가 → 이름 `03_MonetizationPasses` → 붙여넣기 (지금은 ID가 0이라 구매만 비활성)
6. **04**: Explorer에서 `StarterPlayer` → `StarterPlayerScripts` 우클릭 → `Insert Object` → **LocalScript**
   - 이름 `04_ClientHUD` → 전체 붙여넣기
7. 상단 **Play** (F5) → 4레인 아레나와 넥서스가 세워지고 HUD가 뜨면 성공

> ⚠️ **01을 먼저 실행해야** 02가 아레나/터렛 모델을 찾습니다. 순서가 바뀌어 오류가 나면
> Studio를 다시 실행(Stop → Play)하면 01이 먼저 돕니다.
> ⚠️ 02는 `Players.CharacterAutoLoads = false` 로 아바타를 끄고 카메라를 고정합니다(디펜스 전용 시점).

### 4인 협동 테스트
- 상단 `Test` 탭 → **Clients and Servers** → Players **4** 로 설정 → Start
- 4개 창이 각각 P1~P4로 배정되고, 서로의 라인 터렛/넥서스 HP를 함께 봅니다.
- 혼자 테스트할 때는 빈 라인을 AI가 채우지 않습니다(사람 라인만 방어). 4인 테스트를 권장합니다.

---

## 4. 게임패스 · 개발자 상품 ID 넣기 (수익화)

1. Studio 상단 `Home` → **Game Passes** → `Create a Game Pass`
   | 이름 | 권장 가격 | 넣을 변수 |
   |---|---|---|
   | ⚡ 2배속 패스 | 149 R$ | `PASS_2X` |
   | 🧲 자동 합성 패스 | 199 R$ | `PASS_AUTO` |
   | 👑 VIP 추가 슬롯 | 399 R$ | `PASS_VIP` |
2. `Home` → **Developer Products** → 상품 3개 생성
   | 이름 | 권장 가격 | 넣을 변수 |
   |---|---|---|
   | 💎 긴급 미네랄 팩 (+250) | 49 R$ | `PRODUCT_MINERALS` |
   | 🍀 전설 확정 뽑기권 | 199 R$ | `PRODUCT_LEGEND` |
   | 💖 부활권 (넥서스 +10) | 99 R$ | `PRODUCT_REVIVE` |
3. `03_MonetizationPasses` 맨 위 변수에 발급된 **ID 숫자**를 넣습니다.
4. `File` → **Publish to Roblox** 로 저장하면 실제 결제가 연결됩니다.

- 2배속 패스: 내 터렛 공속 +25% + 웨이브 대기 30% 단축
- 자동 합성 패스: 합성 가능해지면 자동 진화
- VIP 슬롯: 라인당 5번째 패드 해금 (내 라인만)

---

## 5. 밸런스 조정 (02 파일 위쪽 숫자만 바꾸면 됨)

| 값 | 위치 | 기본 | 설명 |
|---|---|---|---|
| 웨이브 수 | `MAX_WAVE` | 20 | 늘리면 더 길게 |
| 넥서스 HP | `CORE_MAX` | 30 | 낮추면 어려움 |
| 뽑기 가격 | `GACHA_COST` | 18 | 미네랄 |
| 뽑기 확률 | `GACHA_W` | 62/27/8/2.5/0.5% | 신화 확률 |
| 적 체력 | `spawnEnemy` 의 `baseHp` | 60 × 1.262^(웨이브-1) | 전체 난이도 |
| 터렛 데미지 | `TURRETS` 표 | 등급별 | 한 방에 보스 잡히면 낮추기 |

> Studio에서 **Play** 후 HUD의 `공격력/공속` 을 올리며 5웨이브 보스 체력이
> 2~5초 안에 깎이는지 보면 감이 옵니다. (테스트 후 값을 조금씩 조정)

---

## 6. 자주 나는 문제

| 증상 | 원인 / 해결 |
|---|---|
| 아레나가 안 생김 | 01을 `ServerScriptService`에 넣었는지, Script(파란 아이콘)인지 확인 |
| `TD_Turrets` 를 찾을 수 없다 | 01이 먼저 실행되지 않음 → Stop 후 다시 Play |
| 버튼을 눌러도 반응 없음 | 04를 **LocalScript**로 넣었는지 확인 (일반 Script면 안 됨) |
| 카메라가 캐릭터를 따라감 | 다른 카메라 스크립트가 있으면 끄기 (04가 고정 카메라를 잡습니다) |
| 터렛이 안 쏨 | 그 라인에 적이 사거리 안에 있어야 함 · 패드가 비어 있으면 뽑기 필요 |
| 4인 정원 초과 | 서버당 4명 제한, 5번째 접속자는 안내 후 나감 |

---

## 7. 검증 상태 (정직하게)

- ✅ Luau **문법 검사 0오류** (4개 파일 전부, luaparser)
- ✅ **Roblox API 덤프 대조** — 사용한 클래스/Enum/속성 이름 0오류
- ✅ 01 → 02 → 03 → 04 실행 순서·의존 관계 점검
- ⚠️ **Studio 실제 플레이 테스트는 미검증** — Studio는 PC 전용이라 이 환경에서 실행할 수 없습니다.
  처음 Play 했을 때 (1) 아레나 4레인·넥서스 생성 (2) HUD 표시 (3) 뽑기/합성 버튼 동작
  세 가지를 확인하고, 어긋나면 알려 주시면 바로 고쳐 드립니다.

---

## 8. 다음 업데이트 후보

- 라인별 미네랄을 DataStore에 저장 (재접속 유지)
- 2인 협동 보스 레이드(넥서스 광장 확장)
- 터렛 도감 10종 수집 보상
- 무한 웨이브 랭킹(리더보드)
