# 🤖 HERMES_TASK — 터렛 디펜스 Round 2 (01 시각 결함 2건)

- 작성: 피클(다둥이보안관) · 2026-11-28 11:50 KST
- 기준 커밋: `36c761a` (Round 1 결과물, 2026-11-28 10:42 KST) — 그 위에 이 문서가 올라갑니다.
- Round 1 지시서 원문: 커밋 `329cfd5`의 `HERMES_TASK.md` (기록용 · 다시 실행하지 마세요)
- 이번 라운드 결과물: `ServerScriptService/01_WorldAndUnits.server.lua` **2곳** + `HERMES_REPORT.md`

---

## 0. 세 줄 요약

1. Round 1의 **H1~H6은 통과**했습니다. 피클이 `36c761a`의 01을 실제로 실행(헤드리스)해 5아레나·320타일·포탈/코어 좌표·테마 전환·02 부팅까지 확인했습니다. → **H1~H6는 다시 손대지 마세요.**
2. 다만 H5에서 **화면에 안 보이는 결함 2건**이 남았습니다.
   - **H8** 스폰 발판(`SpawnDock`) 윗면이 상판 윗면과 **정확히 같은 높이(0.000)** 라서 16×7 studs가 겹칩니다 → z-파이팅(지글거림).
   - **H9** 절벽 광맥(`Vein` 5개)이 **바위 속에 묻히거나 허공에 떠서** 보이지 않습니다.
3. 이 문서의 **H8·H9만** 고치고 끝내세요. Studio 화면 확인은 재권 님이 합니다.

---

## 1. 작업 규칙 (지킬 것)

- **수정 파일은 1개**: `ServerScriptService/01_WorldAndUnits.server.lua` (H8·H9). 나머지 8개 파일은 **읽기만**.
- **좌표 상수 불변**: `Shared.UNIVERSE`(SPAWN_LOCAL·NEXUS_LOCAL·CELL·GRID_N), `cellLocal`, BFS 경로, 타일 속성(`Col`·`Row`·`Free`·`Arena`·`Parity`)을 바꾸지 마세요. 시각물만 바꿉니다.
- **부품 이름 불변**: `WarnBeacon`·`AILight`·`Portal`·`Core`·`Cells`·`Cell_c_r`·`Nexus`·`TeamBanner`·`SpawnDock`·`PlateBar*`·`Cliff*`·`IslandTip`·`Shard*`·`Vein*`·`Rim*`·`RimLight*`·`CornerPillar*`. `02`~`07`이 이름으로 찾습니다.
- 탭 들여쓰기·UTF-8 유지. `C:\PickleGames`는 15초마다 `git pull --ff-only`로 갱신되니 **작업 전 `git status` 깨끗한지 확인**, 끝나면 **커밋·푸시**.
- `concepts/`(49MB PNG 19장)·`models/`(18종)는 **다시 커밋하지 마세요.**
- H7(메시 임포트)은 **이번 라운드 범위 밖**입니다. `TDModels` 참조·MeshPart 코드를 넣지 마세요.

---

## 2. Round 1 검증 결과 — 다시 하지 말 것 (근거 포함)

| ID | 판정 | 피클이 확인한 근거 |
|---|---|---|
| H1 | ✅ 통과 | `SetAttribute/GetAttribute("Home")` 0건. `decorFolders`가 `{folder, home}` 표로 바뀌었고, 테마 3종 전환(sf→fantasy→cyber→sf)에서 `Decor_*` 폴더가 5섬 모두 정확히 갈아 끼워졌습니다(자식 16/16/28개). |
| H2 | ✅ 통과 | 5섬 전부 로컬 좌표 일치 — `SpawnDock (-3.50,-1.00,-36.00)`, `Portal (-3.50,0.40,-38.00)`, `AILight (0,16.60,-40)`, `Rim ±36.30`, 넥서스 `Core (0,7.8,31)`(휴먼 기준). 원점(0,0,0)에 뭉친 파트는 중앙 제단 원판 3개(의도된 위치)뿐입니다. |
| H3 | ✅ 코드 / ❌ Studio 미확인 | `TDSky`·`TDAtmosphere`·`TDBloom`·`TDColorCorrection` 생성 확인. `applyTheme("sf")`가 파트 생성 **전(240행)** 과 **완료 후(1081행)** 두 번 실행됨. 테마별 별 수·색·Bloom·Tint가 표 값대로 전환됨. |
| H4 | ✅ 통과 | 상판 `PlateBar0`~`7`, 아포템 36 → 8각 변 29.8. 타일 320개(섬당 64) 중 **8각 바깥으로 나간 타일 0개**, 중심에서 가장 먼 타일 중심 34.65. |
| H5 | ⚠️ **미흡** | 절벽 24파트·`IslandTip`·파편 22·테두리 8변·`RimLight` 4개·기둥 4개·발판은 정상 생성·정상 좌표. **그러나 광맥 5개는 보이지 않습니다(H9).** |
| H6 | ✅ 통과 | 기존 `Plate`·`UnderPlate`·`Spike`·`Fin`·`Trim` 부품 0개(이름 히스토그램 확인). 기둥은 대각선 4곳으로 이동, 스폰 좌표는 그대로. |
| 02 연동 | ✅ | `02_ArenaBattle`을 이어서 실행 → 아레나 5·타일 64×5·`Nexus`/`Core`/`NexusHP`/`WarnBeacon`/`AILight` 모두 찾아 부팅 로그까지 정상. |

---

## 3. H8 (P1) — 스폰 발판 윗면이 상판과 같은 평면 (z-파이팅)

### 증상
8각 상판 `PlateBar`(k=0,2,4,6)의 **윗면 y = 0.000**, `SpawnDock`의 **윗면 y = -1.0 + 2/2 = 0.000**. 두 윗면이 같은 평면에서 x 16 × z 7 studs 만큼 겹칩니다. 첫 화면 카메라가 `arenaCF * (0, 66, -52)`에서 스폰 쪽을 내려다보므로, **화면 아래쪽에 지글거리는 사각 패치**로 보입니다.

### 수정 (605행 한 줄)
지금:
```lua
	local dock = place(arena, "SpawnDock", Vector3.new(16, 2, 14), rel(spawnPos.X, -1.0, spawnPos.Z + 2),
		shade(THEMES.sf.plate2, 0.85), Enum.Material.Slate, { shadow = true })
```
바꿀 것 (중심 y `-1.0` → `-0.95`, 윗면이 +0.05 = 약 1.5cm):
```lua
	-- 윗면을 상판(0.000)보다 0.05 위로 올려 z-파이팅을 없앱니다 (착륙 패드가 살짝 높은 느낌).
	local dock = place(arena, "SpawnDock", Vector3.new(16, 2, 14), rel(spawnPos.X, -0.95, spawnPos.Z + 2),
		shade(THEMES.sf.plate2, 0.85), Enum.Material.Slate, { shadow = true })
```
- `GatePillar`(아래끝 y=0)와 `Portal`(y=0.4)은 그대로 두세요. 발판이 0.05 올라가 기둥 아래끝이 살짝 파묻히는 쪽이, 틈이 생기는 쪽보다 안전합니다.
- 상판 `PlateBar`의 `-1.5 + (k % 2) * 0.01` 값은 건드리지 마세요(인접 바가 겹치는 구간의 z-파이팅 방지용입니다).

### 완료 판정 (H8)
- [ ] `SpawnDock` 윗면 y = **+0.05**, 상판 윗면(0.000/0.010)과 0.04 이상 차이
- [ ] 같은 높이(±0.005)에서 XZ로 1 stud 이상 겹치는 **위를 향한 면 쌍**이 발판 주변에 없음
- [ ] `SpawnDock` 이름·크기·재질·`reg(dock, "plate2")` 유지 → 테마 전환 시 색이 바뀜

---

## 4. H9 (P1) — 절벽 광맥 5개가 보이지 않음

### 증상
현재(545~551행) 광맥은 **반지름 29, y -12~-5**에 세워집니다. 그런데 절벽 단의 반지름(아포템)은 1단 34 / 2단 24 / 3단 13입니다.

| 광맥 y | 그 높이의 절벽 표면 | 반지름 29인 광맥 | 결과 |
|---|---|---|---|
| -3 ~ -8 (1단) | 34 | 안쪽 5 studs | **바위 속에 묻혀 안 보임** |
| -8 ~ -14 (2단) | 24 | 바깥 5 studs | **허공에 뜸** |
| -14 ~ -21 (3단) | 13 | 바깥 16 studs | **허공에 뜸** |

시드 고정이라 섬마다 1~2개만 떠 있고 나머지는 묻혀 있습니다(측정: 슬롯별 3~4개가 바위 속, 1~2개가 허공). 시안 `concepts/roblox-5-floating-islands.png`에서 섬 옆면에 보이는 종족색 세로 발광 띠가 바로 이 광맥인데, 지금 화면에는 없습니다.

### 수정 (545~551행 블록 교체)
**1단 절벽(ap 34)의 바깥면에 0.2 studs 튀어나오게** 붙입니다. 각도는 반드시 **면 중심(45°×k)** 을 써야 합니다. 72° 간격으로 두면 8각 모서리(반지름 36.8)에 걸려 다시 바위 속으로 들어갑니다.

지금:
```lua
	-- 절벽의 종족색 발광 광맥 5개
	for i = 1, 5 do
		local a = math.rad(i * 72)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local y = rng:NextNumber(-12, -5)
		neon(arena, "Vein" .. i, Vector3.new(0.4, rng:NextNumber(3, 6), 0.4),
			rel(dir.X * 29, y, dir.Z * 29), faction.accent, { transparency = 0.15 })
	end
```
바꿀 것:
```lua
	-- 절벽의 종족색 발광 광맥 5개 — 1단 절벽(ap 34) 바깥면에 붙입니다.
	-- 45°×k 는 8각의 '면 중심' 방향이라 반지름 34.2가 항상 벽면 밖 0.2 입니다.
	-- (72° 간격이면 모서리(반지름 36.8)에 걸려 바위 속으로 들어갑니다.)
	local VEIN_FACES = { 0, 2, 4, 6, 1 }
	for i = 1, 5 do
		local a = math.rad(45 * VEIN_FACES[i])
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local h = rng:NextNumber(2.4, 3.4)
		local cy = rng:NextNumber(-6.1, -4.8)   -- 1단 띠(-3 ~ -8) 안쪽, 위아래로 삐져나오지 않게
		neon(arena, "Vein" .. i, Vector3.new(0.5, h, 0.5),
			rel(dir.X * 34.2, cy, dir.Z * 34.2), faction.accent, { transparency = 0.15 })
	end
```

### 완료 판정 (H9)
- [ ] `Vein1`~`Vein5` 5개, 섬 로컬 반지름 **34.0 ~ 34.5** (1단 외벽 34 바로 밖)
- [ ] y 범위가 **-8.0 ~ -3.0** (1단 절벽 띠) 안
- [ ] 각도가 0°·90°·180°·270°·45° (면 중심)
- [ ] 5섬 모두 동일. 화면에서 섬 옆면에 종족색 세로 발광 띠가 보임
- [ ] `rng` 호출 순서는 파편(22개) 뒤 · 테두리 앞 그대로 (파편 모양이 바뀌지 않아야 함)

---

## 5. 끝내기 전 재검증

1. `luau-compile`로 9개 Luau 파일 전부 컴파일 (Round 1과 동일).
2. 헤드리스 실행(01만): `[TD] 01_WorldAndUnits 완료` 로그, 아레나 5 / 섬당 타일 64, `SpawnDock` 윗면 y, `Vein` 5개의 반지름·y 출력.
3. `02_ArenaBattle`까지 이어서 실행해 부팅 로그가 나오는지(이름으로 찾는 부품이 그대로인지) 확인.
4. Studio 화면은 재권 님이 확인합니다. 헤드리스에서 "화면됐다"고 쓰지 말고, **`HERMES_REPORT.md`의 Round 2 표에 ✅ 코드 / ❌ Studio 미확인을 구분해** 적으세요.

---

## 6. 재권 님이 Studio에서 할 일 (3단계 · Hermes는 안내만)

1. Studio에서 `ServerScriptService/01_WorldAndUnits`, `ReplicatedStorage/TDShared`를 저장소 파일 내용으로 교체 → **Play**.
2. Output에 빨간 에러 0건 · `[TD] 01_WorldAndUnits 완료` · `[TD] 02_ArenaBattle 시작` 두 줄 확인.
3. 첫 화면에서 ① 검은 우주+별 ② 8각 부유섬 5개 ③ 섬 옆면 종족색 발광 띠(광맥) ④ 스폰 발판에 지글거림 없음 — 이 4개만 보고 화면 캡처.

---

## 7. 하지 말 것

- H1~H6 재작업 금지(이미 검증됨). H7 메시·`TDModels` 코드 금지.
- `02`~`07`·`TDShared`·`TDData` 수정 금지. 밸런스·가격·확률·상품 ID 변경 금지.
- 부품 이름·계층 변경 금지(02~07이 이름으로 찾습니다).
- 새 이미지·바이너리·`models/`·`concepts/` 커밋 금지.
