# 🛠️ Studio 설치 체크리스트 (v2 — 수익화·저장·리텐션 풀버전)

> 이 문서만 위에서 아래로 따라 하면 됩니다. 한 단계씩, 끝나면 체크 ✔.
> 총 9개 파일 · 처음 하는 분 기준 25~35분.

---

## 0. 준비 (1분)

- [ ] **Roblox Studio** 실행 → 로그인
- [ ] `New` → **Baseplate** 선택 (v1에서 쓰던 파일이 있으면 그 파일을 열어도 됩니다)
- [ ] 오른쪽 위 **Explorer** 창이 보이게 (View 메뉴 → Explorer 체크)
- [ ] **Properties** 창도 보이게 (View 메뉴 → Properties 체크)
- [ ] 상단 `Home` → **Game Settings** → `Security` → **Enable Studio Access to API Services** 를 **켜기**
      → 이걸 켜야 접속 데이터(보석·출석·최고기록)가 저장됩니다. (안 켜면 플레이할 때만 저장되고 나가면 사라짐)

---

## 1. v1 파일 정리 (중요!)

v1에서 만든 스크립트가 남아 있으면 **HUD가 두 개 뜨거나 오류**가 납니다. 아래 4개를 **지우고** 새 파일로 바꿉니다.

- [ ] `ServerScriptService` 안의 `01_MapAndTurrets` **삭제**
- [ ] `ServerScriptService` 안의 `02_WaveGachaMerge` **삭제**
- [ ] `ServerScriptService` 안의 `03_MonetizationPasses` **삭제**
- [ ] `StarterPlayer > StarterPlayerScripts` 안의 `04_ClientHUD` **삭제**

> 삭제 = Explorer에서 우클릭 → Delete. 잘못 지웠으면 Ctrl+Z.

---

## 2. 파일 9개 붙여넣기 (순서대로)

각 파일 맨 위 주석에 "붙여넣는 곳"이 적혀 있습니다. **이름은 표에 적힌 그대로** 써야 합니다.

| 순서 | 내 컴퓨터 파일 | Studio 위치 | 오브젝트 종류 | 이름(정확히) |
|---|---|---|---|---|
| ① | `ReplicatedStorage/TDShared.lua` | `ReplicatedStorage` | **ModuleScript** | `TDShared` |
| ② | `ServerScriptService/01_MapAndTurrets.server.lua` | `ServerScriptService` | **Script** | `01_MapAndTurrets` |
| ③ | `ServerScriptService/TDData.lua` | `ServerScriptService` | **ModuleScript** | `TDData` |
| ④ | `ServerScriptService/02_WaveGachaMerge.server.lua` | `ServerScriptService` | **Script** | `02_WaveGachaMerge` |
| ⑤ | `ServerScriptService/03_MonetizationPasses.server.lua` | `ServerScriptService` | **Script** | `03_MonetizationPasses` |
| ⑥ | `ServerScriptService/05_RetentionQuests.server.lua` | `ServerScriptService` | **Script** | `05_RetentionQuests` |
| ⑦ | `StarterPlayerScripts/04_ClientHUD.client.lua` | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `04_ClientHUD` |
| ⑧ | `StarterPlayerScripts/06_ClientShop.client.lua` | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `06_ClientShop` |
| ⑨ | `StarterPlayerScripts/07_ClientMeta.client.lua` | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `07_ClientMeta` |

### 붙여넣는 방법 (매 파일 동일)

1. Explorer에서 대상 폴더(`ReplicatedStorage` 등) **우클릭** → `Insert Object`
2. 종류 선택 → 표의 **오브젝트 종류** (Script / LocalScript / ModuleScript)
3. 생긴 스크립트를 **더블클릭**해서 열고, 안에 있는 기본 글자(`print("Hello world!")` 등) **전부 지우기**
4. 파일 내용 **전체 복사 → 붙여넣기** (Ctrl+A, Ctrl+C, Ctrl+V)
5. Explorer에서 이름을 표의 **이름**으로 변경 (F2)

> ⚠️ `TDShared`와 `TDData`는 **ModuleScript**(보라색 아이콘)입니다. Script로 만들면 동작하지 않습니다.
> ⚠️ ①`TDShared`를 **가장 먼저** 넣어야 나머지가 찾습니다.

**StarterGui는 비워 두세요.** 화면(상점·미션·HUD)은 04·06·07 스크립트가 실행될 때 직접 만듭니다.

---

## 3. 실행해서 기본 동작 확인 (3분)

- [ ] 상단 **Play** (F5) 눌러보기
- [ ] 4레인 아레나 · 중앙 넥서스 · 터렛 패드 6칸×4줄이 보이는가
- [ ] 상단 HUD(WAVE / NEXUS / 미네랄 / 가스 / 보석)가 뜨는가
- [ ] `Output` 창(Ctrl+F5 아님, View → Output)에 아래 4줄이 보이는가
      ```
      [TD] 01_MapAndTurrets 완료 — 아레나 · 패드 24개 · 터렛 10종 · 적 5종 (v2.0)
      [TD] TDData 준비 — DataStore(...) 프로필 v2
      [TD] 02_WaveGachaMerge 시작 — 4인 협동 · 20웨이브 ...
      [TD] 03_MonetizationPasses 로드 — 패스 6종 · 상품 14종 ...
      [TD] 04_ClientHUD 준비 완료 — 4인 협동 HUD v2.0
      [TD] 05_RetentionQuests 로드 — 출석 7일 · 체류 보상 5단계 · 일일 퀘스트 3개
      [TD] 06_ClientShop 준비 완료 — 패스 6종 · 상품 14종
      [TD] 07_ClientMeta 준비 완료 — 출석 · 체류 보상 · 미션 · 영구 강화
      ```
- [ ] 🔮 뽑기 버튼을 눌러 터렛이 생기는가 (미네랄 18 소모)
- [ ] ⚡ 합성 버튼 → 같은 터렛 2개가 합쳐지는가
- [ ] 🛍 상점 → 🎁 혜택 → ✕ 닫기 가 되는가
- [ ] 🎁 혜택 → 출석 탭에서 "오늘 출석 받기"를 눌러 보석이 오르는가
- [ ] 15초 뒤 WAVE 1이 시작되고 적이 걸어오는가

**4인 협동 테스트**: 상단 `Test` 탭 → `Clients and Servers` → Players **2~4** → Start

---

## 4. ID 넣기 — `TDShared` 한 곳만 (수익화 켜기)

`ReplicatedStorage > TDShared` 를 열면 맨 위에 `Shared.IDS = { ... }` 가 있습니다.
Studio에서 상품·패스를 만든 뒤 발급된 **숫자 ID**를 여기에 넣으면 즉시 판매가 연결됩니다.

### 4-1. 게임패스 6종 (`Home` → `Game Passes` → Create a Game Pass)

| ID 넣을 변수 | 표시 이름 | 권장 가격 | 효과 |
|---|---|---|---|
| `PASS_VIP` | 👑 VIP | **399 R$** | 모든 미네랄·보석 보상 +20%, VIP 태그 |
| `PASS_2X` | ⚡ 2배속 | **149 R$** | 내 터렛 공속 +25%, 웨이브 대기 -30% |
| `PASS_AUTO` | 🧲 자동 합성·자동 배치 | **199 R$** | 합성 자동 · 빈 패드 자동 배치 |
| `PASS_SLOTS` | 🎰 추가 덱 슬롯 | **249 R$** | 5·6번 패드 해금(터렛 +2기) |
| `PASS_LUCK` | 🍀 럭키 뽑기 | **299 R$** | 전설+ ×1.8 · 천장 8회 |
| `PASS_BONUS` | 💰 웨이브 보너스 | **349 R$** | 웨이브 보상 +30% · 유물 4지선다 |

> Studio에서 패스를 만들면 **가격은 나중에** `create.roblox.com` → 해당 게임 → Passes 에서 정합니다.
> 가격을 바꾸면 이 문서의 표는 참고값일 뿐, 실제 결제 금액은 로블록스에 등록한 가격입니다.

### 4-2. 개발자 상품 14종 (`Home` → `Developer Products` → Create)

| ID 넣을 변수 | 표시 이름 | 권장 가격 |
|---|---|---|
| `PRODUCT_REVIVE` | 💖 부활권 | **25 R$** |
| `PRODUCT_BOOST_DMG` | 🔥 2배 데미지 10분 | **35 R$** |
| `PRODUCT_BOOST_GOLD` | 💎 미네랄 2배 10분 | **35 R$** |
| `PRODUCT_REROLL` | 🎲 즉시 리롤 | **39 R$** |
| `PRODUCT_WAVE_SKIP` | ⏭ 웨이브 정리 | **49 R$** |
| `PRODUCT_TEAM_GOLD` | 🎁 팀 전체 미네랄 +150 | **49 R$** |
| `PRODUCT_TEAM_SPEED` | 🎁 팀 전체 공속 +50% 5분 | **79 R$** |
| `PRODUCT_STARTER` | 🚀 스타터팩(1회) | **79 R$** |
| `PRODUCT_GEMS_S` | 💠 보석 150 | **99 R$** |
| `PRODUCT_LUCK10` | 🎯 럭키 10연차 | **149 R$** |
| `PRODUCT_LEGEND` | 🌟 전설 확정 뽑기 | **199 R$** |
| `PRODUCT_GEMS_M` | 💠 보석 500 | **249 R$** |
| `PRODUCT_GEMS_L` | 💠 보석 1,200 | **449 R$** |
| `PRODUCT_GEMS_XL` | 💠 보석 3,000 | **799 R$** |

> ID를 0으로 두면 상점에 **"준비 중"** 으로 표시되고 결제는 일어나지 않습니다. 게임은 정상 동작합니다.
> **결제는 게시(Publish) 후 실제 서버에서만** 테스트할 수 있습니다. Studio에서는 창이 뜨지 않거나 "체험용"으로 표시됩니다.

### 4-3. 가격을 바꾸고 싶으면
- 로블록스 실제 가격: `create.roblox.com` 에서 수정 (이것이 진짜 결제 금액)
- 상점 화면에 보이는 숫자: `TDShared` 의 `price = ...` 값 (표시용)

---

## 5. 게시해서 실제로 돌리기

- [ ] `File` → **Publish to Roblox** → 게임 이름/설명 입력 → Create
- [ ] `Game Settings` → `Permissions` / `Playability` 확인 (Public)
- [ ] `create.roblox.com` → 해당 게임 → **Monetization** 에서 위 상품·패스 가격 최종 확인
- [ ] 휴대폰 Roblox 앱에서 내 게임 검색 → 실제 결제 1건 테스트(가장 싼 25 R$ 부활권)
- [ ] 결제 후 `보관 부활권` 숫자가 올라가는지 확인 (안 오르면 6번 문제 해결 참고)

---

## 6. 자주 나는 문제

| 증상 | 원인 / 해결 |
|---|---|
| 아레나가 안 생김 | ①이 `ServerScriptService`의 **Script**(파란 아이콘)인지, 이름이 `01_MapAndTurrets`인지 확인 |
| `TDShared` 를 찾을 수 없다 | `ReplicatedStorage`에 **ModuleScript** 이름 `TDShared` 로 넣었는지 확인 (대소문자) |
| `TDData` 를 찾을 수 없다 | `ServerScriptService`에 **ModuleScript** 이름 `TDData` |
| HUD가 두 개 뜸 | v1 `04_ClientHUD`가 남아 있음 → 지우기 |
| 버튼을 눌러도 반응 없음 | ④~⑦이 **LocalScript**인지 확인 |
| 보석/출석이 저장 안 됨 | Game Settings → Security → **Enable Studio Access to API Services** 켜기 |
| 상점에 전부 "준비 중" | `TDShared` 의 `Shared.IDS` 가 0 → ID 입력 |
| 결제했는데 지급이 안 됨 | ①게임이 Publish 되었는지 ②`03_MonetizationPasses`가 서버에 있는지 ③Output의 `[TD][Shop]` 경고 확인 |
| 부활권을 사도 안 써짐 | 넥서스가 붕괴된 12초 안에 💖 부활 버튼을 눌러야 함 |
| 4인 정원 초과 | 서버당 4명 · 5번째는 안내 후 나감 (재접속) |
| 적이 안 나옴 | 상단 Play 후 15초 대기 (첫 웨이브 준비 시간) |

---

## 7. 검증 상태 (정직하게)

- ✅ **Luau 문법 검사 0오류** — 9개 파일 전부 (`luaparser` 4.2.0)
- ✅ **정적 점검** — 미선언 전역 호출 0건, 선언 전 사용 0건
- ✅ **Roblox API 덤프 대조** — 사용한 클래스/Enum/속성 이름 0오류
- ⚠️ **Studio 실제 플레이 테스트는 미검증** — 이 작업 환경에서는 Studio를 실행할 수 없습니다.
  처음 Play 했을 때 위 3번 체크리스트에서 어긋나는 곳을 알려 주시면 바로 고칩니다.
- ⚠️ **실제 결제 흐름(ProcessReceipt)은 게시 후에만 확인 가능** — 코드는 중복 지급 방지·미처리 재시도까지 구현되어 있으나, 실결제 1건 테스트로 최종 확인이 필요합니다.
