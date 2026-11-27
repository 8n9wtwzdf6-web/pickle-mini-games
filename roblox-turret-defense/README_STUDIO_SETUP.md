# 🛠️ Studio 설치 체크리스트 (v3 — 우주 5아레나 완성판)

> 이 문서만 위에서 아래로 따라 하면 됩니다. 한 단계씩, 끝나면 체크 ✔.
> 총 **9개 파일** · 처음 하는 분 기준 **30~40분**.

---

## 0. 준비 (1분)

- [ ] **Roblox Studio** 실행 → 로그인
- [ ] `New` → **Baseplate** 선택 (v2 파일이 있으면 그 파일을 열어도 됩니다)
- [ ] 오른쪽 위 **Explorer** 창 보이게 (View → Explorer)
- [ ] **Properties** 창 보이게 (View → Properties)
- [ ] 상단 `Home` → **Game Settings** → `Security` → **Enable Studio Access to API Services** 켜기
      → 접속 데이터(보석·최고 스테이지·출석)가 저장됩니다.

> 01 스크립트가 기본 **Baseplate** 와 **SpawnLocation** 을 자동으로 지우고 우주 공간을 만듭니다. 그대로 두세요.

---

## 1. 예전 파일 정리 (중요)

v2 스크립트가 남아 있으면 HUD가 두 개 뜨거나 오류가 납니다. 아래를 **지웁니다**.

- [ ] `ServerScriptService` 의 `01_MapAndTurrets` **삭제**
- [ ] `ServerScriptService` 의 `02_WaveGachaMerge` **삭제**
- [ ] `ServerScriptService` 의 `03_MonetizationPasses` · `05_RetentionQuests` · `TDData` 는 **새 파일로 교체** (지우고 다시 넣기)
- [ ] `ReplicatedStorage` 의 `TDShared` **삭제** (새 v3로 교체)
- [ ] `StarterPlayer > StarterPlayerScripts` 의 `04_ClientHUD` · `06_ClientShop` · `07_ClientMeta` **삭제**

> 삭제 = Explorer에서 우클릭 → Delete. 잘못 지웠으면 Ctrl+Z.

---

## 2. 파일 9개 붙여넣기 (순서대로)

각 파일 맨 위 주석에 "붙여넣는 곳"이 적혀 있습니다. **이름은 표 그대로**.

| 순서 | 내 컴퓨터 파일 | Studio 위치 | 오브젝트 종류 | 이름(정확히) |
|---|---|---|---|---|
| ① | `ReplicatedStorage/TDShared.lua` | `ReplicatedStorage` | **ModuleScript** | `TDShared` |
| ② | `ServerScriptService/01_WorldAndUnits.server.lua` | `ServerScriptService` | **Script** | `01_WorldAndUnits` |
| ③ | `ServerScriptService/TDData.lua` | `ServerScriptService` | **ModuleScript** | `TDData` |
| ④ | `ServerScriptService/02_ArenaBattle.server.lua` | `ServerScriptService` | **Script** | `02_ArenaBattle` |
| ⑤ | `ServerScriptService/03_MonetizationPasses.server.lua` | `ServerScriptService` | **Script** | `03_MonetizationPasses` |
| ⑥ | `ServerScriptService/05_RetentionQuests.server.lua` | `ServerScriptService` | **Script** | `05_RetentionQuests` |
| ⑦ | `StarterPlayerScripts/04_ClientHUD.client.lua` | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `04_ClientHUD` |
| ⑧ | `StarterPlayerScripts/06_ClientShop.client.lua` | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `06_ClientShop` |
| ⑨ | `StarterPlayerScripts/07_ClientMeta.client.lua` | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `07_ClientMeta` |

### 붙여넣는 방법 (매 파일 동일)

1. Explorer에서 대상 폴더(`ReplicatedStorage` 등) **우클릭** → `Insert Object`
2. 종류 선택 → 표의 **오브젝트 종류**
3. 생긴 스크립트를 **더블클릭**해서 열고 기본 글자(`print("Hello world!")`) **전부 지우기**
4. 파일 내용 **전체 복사 → 붙여넣기** (Ctrl+A, Ctrl+C, Ctrl+V)
5. Explorer에서 이름을 표의 **이름**으로 변경 (F2)

> ⚠️ `TDShared`·`TDData` 는 **ModuleScript**(보라 아이콘)입니다. Script로 만들면 동작하지 않습니다.
> ⚠️ ①`TDShared`를 **가장 먼저** 넣어야 나머지가 찾습니다.
> ⚠️ ③`TDData`는 ②보다 뒤에 넣어도 됩니다(02가 실행될 때 기다립니다).

**StarterGui는 비워 두세요.** 화면은 04·06·07이 실행될 때 직접 만듭니다.

---

## 3. 실행해서 확인 — ★ 여기가 제일 중요합니다 (1단계)

- [ ] 상단 **Play** (F5)
- [ ] **Output** 창 열기 (View → Output)

### 3-1. 이 8줄이 보이는가 (순서는 조금 달라도 됨)

```
[TD] TDData 준비 — DataStore(Studio) 프로필 v3 (5종족 · 보스딜량 · 테마)
[TD] 01_WorldAndUnits 완료 — 우주 5아레나 · 그리드 8×8×5 · 터렛 유닛 10종+융합 5종 · 적 8종+최종보스 (v3.0)
[TD] 02_ArenaBattle 시작 — 5아레나 · 40단계 × 100마리 · 중앙 보스 딜량 레이드 (v3.0)
[TD] 03_MonetizationPasses 로드 — 패스 6종 · 상품 11종 (ID 미입력 시 구매만 비활성) v3.0
[TD] 05_RetentionQuests 로드 — 출석 7일 · 체류 보상 5단계 · 일일 퀘스트 3개 (v3.0)
[TD] 04_ClientHUD 준비 완료 — 우주 5아레나 HUD v3.0
[TD] 06_ClientShop 준비 완료 — 패스 6종 · 상품 11종 (v3.0)
[TD] 07_ClientMeta 준비 완료 — 출석 · 체류 보상 · 미션 · 영구 강화 (v3.0)
```

### 3-2. ★ 딱 하나만 확인한다면 — "타일 건설"

1. 인트로 화면에서 **테마**(🌌/🏰/🏙️)와 **종족**(휴먼 등)을 고르고 **⚔ 전투 시작**
2. 화면 아래 **🔮 유닛 뽑기** 를 2~3번 누른다 → 아래 **손패 칸**에 `T1 👤휴먼` 같은 칸이 생긴다
3. 손패 칸을 누른 뒤, **아레나 바닥의 빈 타일을 터치**한다
4. 그 타일 위에 **터렛이 세워지면 성공** (등급 색 링 + 파티클)

이 4단계가 되면 01(월드)·02(서버)·04(클라이언트)·TDShared(데이터)가 모두 연결된 것입니다.

### 3-3. 이어서 확인

- [ ] 14초 뒤 **STAGE 1 / 100기 (영웅 1)** 배너 → 몬스터가 게이트에서 걸어온다
- [ ] 몬스터가 넥서스에 닿으면 **NEXUS HP**가 줄어든다
- [ ] 터렛을 누르면 아래 **유닛 패널**이 뜨고 `🔄 모드` `✨ 스킬` `↔ 이동` `💎 판매` 가 동작한다
- [ ] `↔ 이동` → 다른 타일을 누르면 유닛이 옮겨진다 (길이 막히면 거부 메시지)
- [ ] 같은 종족·같은 모드·같은 등급 2기를 배치하고 **⚡ 합성** → 등급이 한 단계 오른다
- [ ] **🧬 융합** → 융합 목록이 뜨고, 타 종족 유닛이 3+2 모이면 `융합` 버튼이 켜진다
- [ ] 우측 **5팀 순위표**에 5개 팀(내 팀 + AI 4팀)이 스테이지 순으로 표시된다
- [ ] **🌌 테마** 버튼 → 테마를 바꾸면 바닥·장식·조명·넥서스 색이 바뀐다
- [ ] **👥 전체뷰** 버튼을 두 번 누르면 우주 전체(5개 부유 아레나 + 중앙 제단)가 보인다
- [ ] 🛍 상점 → 🎁 혜택 → ✕ 닫기가 된다. 혜택 → 출석 탭에서 "오늘 출석 받기"로 보석이 오른다
- [ ] **5분 이상** 두면 AI 팀들이 스테이지를 올리고, 40단계 뒤 **중앙 보스**가 뜬다
      (빠르게 보려면 Studio에서 `02_ArenaBattle` 의 `team.aiStageT = 18` 을 `2` 로 임시 변경)

**여러 명 테스트**: 상단 `Test` → `Clients and Servers` → Players **2~4** → Start

---

## 4. ID 넣기 — `TDShared` 한 곳만 (수익화 켜기)

`ReplicatedStorage > TDShared` 맨 위 `Shared.IDS = { ... }` 에 발급받은 **숫자 ID**를 넣으면 즉시 판매가 연결됩니다.

### 4-1. 게임패스 6종 (`Home` → `Game Passes`)

| 변수 | 표시 이름 | 권장 가격 | 효과 |
|---|---|---|---|
| `PASS_VIP` | 👑 VIP | **399 R$** | 5대 종족 전체 해금 · 보상 +25% · 순위표 황금 왕관 |
| `PASS_FUSION` | 🧬 융합 마스터 | **249 R$** | 이종족 융합 3+2 → **2+1** · 융합 유닛 공격력 +20% |
| `PASS_ARENA` | 🏗️ 아레나 확장 | **199 R$** | 건설 그리드 6×6 → **8×8** (테두리 28칸 추가) |
| `PASS_2X` | ⚡ 2배속 | **149 R$** | 몬스터 스폰 2배 · 스테이지 대기 -30% |
| `PASS_AUTO` | 🤖 자동합치기 | **199 R$** | 자동 합성 · 자동 배치 |
| `PASS_LUCK` | 🍀 러키 뽑기 | **299 R$** | 전설·신화 ×1.8 · 천장 8회 |

### 4-2. 개발자 상품 11종 (`Home` → `Developer Products`)

| 변수 | 표시 이름 | 권장 가격 |
|---|---|---|
| `PRODUCT_OVERCHARGE` | ⚡ 딜량 2배 과충전 (3분) | **29 R$** |
| `PRODUCT_REVIVE` | 💖 12초 긴급 부활 | **25 R$** |
| `PRODUCT_MODE_RESET` | 🔄 모드전환 쿨초기화 | **25 R$** |
| `PRODUCT_SUMMON` | 🌀 타 종족 지원 소환권 | **39 R$** |
| `PRODUCT_SABOTAGE` | ☠ 경쟁 1위 팀 방해 투하 | **49 R$** |
| `PRODUCT_TEAM_BOOST` | 🎁 팀 전체 과충전 선물 | **79 R$** |
| `PRODUCT_STARTER` | 🚀 스타터팩 (1회 한정) | **79 R$** |
| `PRODUCT_GEMS_S` | 💠 보석 150 | **99 R$** |
| `PRODUCT_GEMS_M` | 💠 보석 540 | **199 R$** |
| `PRODUCT_GEMS_L` | 💠 보석 1,320 | **399 R$** |
| `PRODUCT_GEMS_XL` | 💠 보석 3,450 | **799 R$** |

> ID가 0이면 상점에 **"준비 중"** 으로 표시되고 결제는 일어나지 않습니다. 게임은 정상 동작합니다.
> **실제 결제 테스트는 게시(Publish) 후** 실제 서버에서만 가능합니다. Studio에서는 창이 뜨지 않거나 체험용입니다.

### 4-3. 가격을 바꾸고 싶으면
- 실제 결제 금액: `create.roblox.com` → 해당 게임 → Monetization (여기 가격이 진짜)
- 상점에 보이는 숫자: `TDShared` 의 `price = ...` (표시용)

---

## 5. 게시해서 실제로 돌리기

- [ ] `File` → **Publish to Roblox** → 이름/설명 → Create
- [ ] `Game Settings` → `Permissions` → Public 확인
- [ ] `create.roblox.com` → Monetization 에서 상품·패스 가격 최종 확인
- [ ] 휴대폰 Roblox 앱에서 내 게임 검색 → 가장 싼 **25 R$ 부활권**으로 실결제 1건 테스트
- [ ] 결제 후 `보관 부활권` 숫자가 올라가는지 확인

---

## 6. 자주 나는 문제

| 증상 | 원인 / 해결 |
|---|---|
| 아레나가 안 생김 | ②가 `ServerScriptService`의 **Script**(파란 아이콘)이고 이름이 `01_WorldAndUnits` 인지 확인 |
| `TDShared` 를 찾을 수 없다 | `ReplicatedStorage` 에 **ModuleScript** 이름 `TDShared` (대소문자) |
| `TDData` 를 찾을 수 없다 | `ServerScriptService` 에 **ModuleScript** 이름 `TDData` |
| HUD가 두 개 뜸 | v2 `04_ClientHUD` 가 남아 있음 → 삭제 |
| 버튼을 눌러도 반응 없음 | ⑦~⑨가 **LocalScript** 인지 확인 |
| 타일을 눌러도 건설이 안 됨 | ① 손패에 유닛이 있는지 ② 잠긴 타일(테두리)인지 ③ "몬스터 길이 막힙니다" 메시지인지 확인 |
| 보석/출석이 저장 안 됨 | Game Settings → Security → **Enable Studio Access to API Services** |
| 상점이 전부 "준비 중" | `TDShared.Shared.IDS` 가 0 → 4단계에서 ID 입력 |
| 결제했는데 지급이 안 됨 | ①게시 여부 ②`03_MonetizationPasses` 가 서버에 있는지 ③Output의 `[TD][Shop]` 경고 |
| 몬스터가 안 나옴 | Play 후 **14초** 대기 (첫 스테이지 준비) |
| 5명이 접속 | 5팀 정원 · 6번째는 안내 후 나감 |
| 보스가 안 뜸 | 40단계를 끝내야 합니다 (AI 최속 13분) 또는 3-3의 임시 값 사용 |

---

## 7. 검증 상태 (정직하게)

- ✅ **Luau 문법 검사 0오류** — 9개 파일 전부 (`luaparser` 4.2.0)
- ✅ **정적 점검** — 미선언 전역 0건 · 선언 전 호출 0건 · 전역 쓰기 0건
- ✅ **Roblox API 덤프 대조** — 사용한 클래스/Enum/속성/메서드 0오류
- ✅ **데이터 런타임 검사** — TDShared를 Lua로 실제 실행해 종족 5×2모드 · 등급 5단계 밸런스 · 확률 합 100% · 상품 11종 확인
- ✅ **길찾기(BFS) 런타임 검사** — 빈 그리드/벽/미로에서 경로 생성·차단 판정 확인
- ⚠️ **Studio 실제 플레이 테스트는 미검증** — 이 작업 환경에서는 Studio를 실행할 수 없습니다.
  Play 했을 때 3-2의 "타일 건설" 4단계가 안 되면 그 화면을 알려 주시면 바로 고칩니다.
- ⚠️ **실제 결제 흐름(ProcessReceipt)은 게시 후에만 확인 가능** — 코드는 중복 지급 방지·미처리 재시도까지 구현되어 있습니다.
