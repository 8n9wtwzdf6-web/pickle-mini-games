# 🤖 HERMES_TASK — 터렛 디펜스 Round 1 (점검 → 보완 → Studio 확인)

- 작성: 피클(다둥이보안관) · 2026-11-28 10:25 KST
- 저장소: `8n9wtwzdf6-web/pickle-mini-games` · 작업 폴더: `C:\PickleGames\roblox-turret-defense\`
- 기준 커밋: `b6529bc` (2026-11-27 15:58 KST) — 이후 변동 없음. 이 문서가 그 위에 올라갑니다.
- 이번 라운드 결과물: 수정한 `01_WorldAndUnits.server.lua` (+ `TDShared.lua`의 THEMES 조명 값) + `HERMES_REPORT.md`

---

## 0. 세 줄 요약

1. **지금 `01`은 아레나 1을 만들다 에러로 죽습니다.** 그래서 하늘이 밝고, 섬이 1개뿐이고, 조명·유닛·적 모델이 아예 만들어지지 않습니다. (H1)
2. **`neon()`/`disc()`는 좌표를 월드 절대값으로 쓰는데, 호출부는 아레나 로컬값을 줍니다.** 그래서 5개 섬의 네온(테두리·코어·포탈·경고등)이 전부 맵 중앙 제단 위에 뭉쳐 있고, 섬에는 까만 판만 남습니다. (H2)
3. H1·H2를 고치고 **검은 우주(H3) + 8각 부유섬(H4~H6)** 을 적용하면 시안 `concepts/roblox-5-floating-islands.png`의 첫 화면이 됩니다.

> 재권 님이 Studio에서 본 **"밝은 낮 하늘 + 어두운 네모 판"** 은 ① 조명이 적용되기 전에 스크립트가 죽었고(H1) ② 네온이 전부 중앙으로 몰렸기(H2) 때문입니다. 화면 설정 문제가 아니라 코드 버그입니다.

---

## 1. 작업 규칙 (지킬 것)

- **이번 라운드에서 고치는 파일은 2개뿐**입니다.
  - `ServerScriptService/01_WorldAndUnits.server.lua` — H1~H6
  - `ReplicatedStorage/TDShared.lua` — **THEMES의 `lighting` 값만** (H3-4). 다른 숫자·가격·확률은 손대지 마세요.
- 나머지 7개 파일(`02`·`03`·`05`·`04`·`06`·`07`·`TDData`)은 **읽기만** 합니다. 게임 로직·밸런스 변경 금지.
- `C:\PickleGames`는 `Pickle Agent`가 15초마다 `git pull --ff-only`로 갱신합니다. 로컬에 커밋 안 한 수정이 있으면 자동 갱신을 건너뜁니다(파일을 지우지는 않음). **작업 시작 전 `git status`로 깨끗한지 확인**하고, 끝나면 반드시 커밋·푸시하세요(§10).
- 파일은 **UTF-8**, 들여쓰기는 기존 **탭** 유지. 줄바꿈은 CRLF/LF 어느 쪽이어도 되지만 파일 전체를 같은 방식으로.
- `concepts/`(49MB PNG 19장)와 `models/`(18종)는 **다시 커밋하지 마세요.** 새 이미지·바이너리 추가도 금지.
- 좌표계 불변 원칙: **타일 좌표(`Shared.cellLocal`)·BFS 경로·`SPAWN_LOCAL`·`NEXUS_LOCAL` 값은 절대 바꾸지 않습니다.** 시각물만 바꿉니다.

---

## 2. 먼저 볼 것 (10분)

1. `SPEC_V3.md` → **8.5 시안 표**와 **8.6 ①②③** (이번 라운드의 목표 정의)
2. 그림 2장을 직접 열어 보기: `concepts/roblox-5-floating-islands.png`, `concepts/roblox-engine-preview.png`
3. `AUDIT.md` (v2→v3 감사표) — 여기서 "됐다"고 한 항목도 실제로는 H1·H2 때문에 화면에 안 나왔습니다.

---

## 3. H1 (P0 · 치명) — `01`이 아레나 1에서 죽는다

### 증상
- Output에 빨간 에러가 뜨고 `[TD] 01_WorldAndUnits 완료 …` 줄이 **안 나옵니다**.
- `Workspace.TDWorld.Arenas`에 **`Arena_1`만** 있고 2~5가 없습니다.
- `ReplicatedStorage`에 **`TD_Units` / `TD_Enemies` 폴더가 없습니다** → `02`가 `WaitForChild("TD_Enemies")`에서 영원히 멈춥니다(플레이어 배정·HUD 없음).
- 조명이 기본값이라 **낮의 파란 하늘**이 그대로 보입니다(`applyTheme`은 976행, 즉 스크립트 맨 끝에서야 실행되므로).

### 원인 (근거)
`01_WorldAndUnits.server.lua:374`

```lua
folder:SetAttribute("Home", arena)   -- ❌ Instance 는 속성(attribute) 값으로 저장할 수 없음
```

Roblox 공식 문서: 속성에 저장 가능한 타입은 string·boolean·number·UDim·UDim2·BrickColor·Color3·Vector2·Vector3·CFrame·NumberSequence·ColorSequence·NumberRange·Rect·Font 뿐이고, **지원하지 않는 타입을 넣으면 에러가 납니다.** (`Instance is not a supported attribute type`). 이 줄은 `buildArena(1)` → `buildThemeDecor(1,"sf")` 안에서 pcall 없이 실행되므로 **스크립트 전체가 거기서 멈춥니다.**

### 수정 H1-A — `decorFolders`에 home을 표(table)로 보관

`01`의 `local decorFolders = {}`(102행) 근처는 그대로 두고, `buildThemeDecor`(370행 부근)를 이렇게 바꿉니다.

```lua
local function buildThemeDecor(arena, slot, themeKey)
	local cf = Shared.arenaCFrame(slot)
	local folder = Instance.new("Folder")
	folder.Name = "Decor_" .. themeKey
	folder.Parent = arena
	decorFolders[themeKey] = decorFolders[themeKey] or {}
	table.insert(decorFolders[themeKey], { folder = folder, home = arena })  -- ✅ Instance 는 표에 담아 둡니다
	folder.Parent = nil -- applyTheme 가 켭니다
	local t = THEMES[themeKey]
	-- ... 이하 기존 장식 코드 그대로 ...
```

### 수정 H1-B — `applyTheme`의 재부모화 루프 (141~149행)

```lua
	for themeKey, list in pairs(decorFolders) do
		for _, rec in ipairs(list) do
			if themeKey == t.key then
				rec.folder.Parent = rec.home
			else
				rec.folder.Parent = nil
			end
		end
	end
```

> `decorFolders`를 쓰는 곳은 `applyTheme` 한 곳뿐이라 이 교체로 충분합니다. `GetAttribute("Home")` / `SetAttribute("Home", …)`는 코드에서 **완전히 사라져야** 합니다.

### 완료 판정 (H1)
- [ ] `01` 안에 `SetAttribute("Home"` / `GetAttribute("Home"` 문자열이 0건
- [ ] Output에 `[TD] 01_WorldAndUnits 완료 …`가 뜸, 빨간 에러 0건
- [ ] `Workspace.TDWorld.Arenas` 자식 5개(`Arena_1`~`Arena_5`)
- [ ] `ReplicatedStorage.TD_Units` 자식 **15개**(유닛 10 + 융합 5), `TD_Enemies` 자식 **9개**(적 8 + 최종보스)

---

## 4. H2 (P0 · 치명) — 네온이 전부 맵 중앙에 뭉치는 좌표 버그

### 증상
- 5개 섬 위에 **종족색 네온 테두리·넥서스 코어 빛·스폰 포탈·경고등이 하나도 없습니다.**
- 대신 맵 정중앙(제단 근처)에 **네온 덩어리**가 뭉쳐 있습니다. (전체뷰로 보면 확실)
- 섬은 "어두운 네모 판"처럼 보입니다 — 재권 님이 지적한 그 화면입니다.

### 원인 (근거)
`01`의 두 헬퍼가 좌표를 다르게 다룹니다.

| 헬퍼 | CFrame 처리 | 결과 |
|---|---|---|
| `place(model, …)` (84행 부근) | `model.PrimaryPart.CFrame * relCF` | ✅ 로컬 좌표로 해석 |
| `neon(parent, …)` (58행) | 받은 CFrame을 **그대로** `p.CFrame`에 | ❌ 월드 절대 좌표로 해석 |
| `disc(parent, …)` (87행) | 받은 CFrame을 **그대로** | ❌ 월드 절대 좌표로 해석 |

그런데 `buildArena`/`buildNexus`는 `neon(arena, "Trim"..i, … rel(…))`, `disc(nexus, "BaseRing", …, rel(0,1.8,0), …)`, `neon(arena,"Portal", …, rel(spawnPos.X, 0.4, spawnPos.Z))` 처럼 **로컬값 `rel(…)`을 넘깁니다.** → 아레나가 (0,0,−150)·(143,0,−46) 등에 있어도 네온은 원점(보스 제단)에 그려집니다. 5개 아레나 × (테두리 4 + 모서리 4 + 게이트 3 + 경고등 + 넥서스 코어·링·라이트)가 전부 중앙에 겹칩니다.

### 수정 H2-A — 헬퍼가 Model의 pivot을 곱하도록 (권장)

`neon`(58행) 바로 위에 헬퍼를 추가하고, `neon`·`disc`만 고칩니다. `place`는 이미 올바르므로 **그대로 둡니다.**

```lua
-- Model 이면 PrimaryPart 기준 로컬 좌표로, Folder/Part 면 지금처럼 월드 좌표로 해석합니다.
local function pivotOf(parent)
	if parent and parent:IsA("Model") and parent.PrimaryPart then
		return parent.PrimaryPart.CFrame
	end
	return CFrame.new()
end

local function neon(parent, name, size, cf, color, opts)
	opts = opts or {}
	opts.shape = opts.shape
	opts.transparency = opts.transparency or 0
	return makePart(parent, name, size, pivotOf(parent) * cf, color, Enum.Material.Neon, opts)
end
```

`disc`도 첫 `makePart` 호출에 같은 pivot을 곱합니다.

```lua
local function disc(parent, name, radius, thickness, cf, color, material, opts)
	opts = opts or {}
	local size = Vector3.new(thickness, radius * 2, radius * 2)
	local p = makePart(parent, name, size, pivotOf(parent) * cf * CFrame.Angles(0, 0, math.rad(90)), color, material, opts)
	p.Shape = Enum.PartType.Cylinder
	return p
end
```

> 유닛·적 모델은 pivot이 원점(`rootPart(m, CFrame.new())`)이고, `spaceFolder`·장식 폴더는 Folder라 `pivotOf`가 항등행렬을 돌려줍니다 → **기존 유닛·적·장식은 결과가 똑같습니다.** 아레나·넥서스만 제자리를 찾습니다.

### 수정 H2-B — 이미 월드 좌표를 넘기던 호출 3곳만 로컬로 바꿉니다

이 3곳은 위 수정으로 **두 번 변환**되므로 반드시 같이 고쳐야 합니다.

| 줄 | 지금 | 바꿀 것 |
|---|---|---|
| 286 | `neon(nexus, "CannonTip" .. i, Vector3.new(1,1,0.5), barrel.CFrame * CFrame.new(0,0,-3.2), coreColor)` | `neon(nexus, "CannonTip" .. i, Vector3.new(1,1,0.5), rel(px, 6.2, pz, 0, i * 90, 0) * CFrame.new(0, 0, -3.2), coreColor)` |
| 508 | `portal.CFrame = cf * rel(spawnPos.X, 0.4, spawnPos.Z) * CFrame.Angles(0, 0, math.rad(90))` | `portal.CFrame = arena.PrimaryPart.CFrame * rel(spawnPos.X, 0.4, spawnPos.Z) * CFrame.Angles(0, 0, math.rad(90))` (또는 이 줄 삭제 후 507행의 `neon(...)`에 `rel(...) * CFrame.Angles(0,0,math.rad(90))`를 넘김) |
| 523 | `neon(arena, "AILight", Vector3.new(2,2,2), cf * rel(0, 16.6, -40), …)` | `neon(arena, "AILight", Vector3.new(2,2,2), rel(0, 16.6, -40), …)` |

> 388·404·422·428행(`neon(folder, …, cf * rel(…))`)과 731행(`neon(model, …, drone.CFrame * …)`)은 **부모가 Folder이거나 pivot이 원점**이라 그대로 두면 됩니다.

### 완료 판정 (H2)
- [ ] 아레나 바닥 가장자리에 **종족색 네온 테두리**가 보임(5개 섬 모두)
- [ ] 넥서스 위에 **발광 코어**가 보임(중앙에 몰려 있지 않음)
- [ ] 스폰 쪽에 **원형 포탈**과 경고등이 보임
- [ ] 맵 중앙 제단 근처에 **네온 덩어리가 없음**

---

## 5. H3 (P0) — 검은 우주 · 별 · Bloom (SPEC 8.6①)

### H3-1. 조명을 월드 생성 **전에** 한 번 적용
지금은 976행(맨 끝)에서만 `applyTheme("sf")`를 부릅니다. 중간에 무슨 일이 생겨도 하늘은 검게 유지되도록, `world` 폴더를 만든 직후(약 190행, `spaceFolder` 생성 다음)에 **`applyTheme("sf")`를 한 번 더** 넣으세요. (맨 끝 호출은 그대로 둡니다.)

### H3-2. Lighting 오브젝트 생성 (스크립트로 가능 · 서버에서 만들면 전원에게 적용)

`01`의 `local THEMES = Shared.THEMES` 아래, `applyTheme` **위**에 넣습니다.

```lua
-- ── 우주 조명 오브젝트 (SPEC 8.6①) ─────────────────────────
local function ensureFx(class, name)
	local o = Lighting:FindFirstChild(name)
	if not o then
		o = Instance.new(class)
		o.Name = name
		o.Parent = Lighting
	end
	return o
end

local TDSky = ensureFx("Sky", "TDSky")
TDSky.SkyboxBk = ""
TDSky.SkyboxDn = ""
TDSky.SkyboxFt = ""
TDSky.SkyboxLf = ""
TDSky.SkyboxRt = ""
TDSky.SkyboxUp = ""
TDSky.CelestialBodiesShown = false   -- 해·달 제거 (낮 하늘 금지)
TDSky.StarCount = 5000

local TDAtmosphere = ensureFx("Atmosphere", "TDAtmosphere")
TDAtmosphere.Density = 0.35
TDAtmosphere.Offset = 0.1
TDAtmosphere.Glare = 0.15
TDAtmosphere.Haze = 1.2
TDAtmosphere.Decay = Color3.fromRGB(106, 112, 125)

local TDBloom = ensureFx("BloomEffect", "TDBloom")
TDBloom.Size = 32
TDBloom.Threshold = 0.9

local TDColor = ensureFx("ColorCorrectionEffect", "TDColorCorrection")
TDColor.Saturation = 0.15
TDColor.Contrast = 0.12
```

> `Sky`의 6면을 빈 문자열로 두면 **검은 배경 + 별**만 그려집니다. 마켓플레이스 텍스처는 이번 라운드에서 쓰지 않습니다(외부 에셋 없이 확실하게).

### H3-3. `applyTheme`의 조명 블록 교체 (152~160행)

```lua
	-- 조명 (SPEC 8.6① — 어떤 테마에도 낮 하늘 금지)
	local L = t.lighting
	Lighting.Ambient = L.ambient
	Lighting.OutdoorAmbient = L.outdoor
	Lighting.FogColor = L.fog
	Lighting.FogEnd = L.fogEnd or 1600
	Lighting.FogStart = 400            -- 120 은 너무 가까워 섬이 안개에 먹힘
	Lighting.Brightness = L.brightness or 0.6
	Lighting.ClockTime = 0             -- 자정 고정
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.15
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ExposureCompensation = 0.3 -- 너무 어두우면 0.5까지

	TDSky.StarCount = L.stars or 3000
	TDAtmosphere.Color = L.atmo or Color3.fromRGB(18, 20, 40)
	TDBloom.Intensity = L.bloom or 1.2
	TDColor.TintColor = L.tint or Color3.fromRGB(255, 255, 255)
```

### H3-4. `TDShared.lua`의 `THEMES[key].lighting` 값 교체 (표 그대로)

| 테마 | ambient | outdoor | fog | fogEnd | brightness | atmo | bloom | tint | stars |
|---|---|---|---|---|---|---|---|---|---|
| `sf` | `(22,24,38)` | `(10,12,22)` | `(8,10,22)` | `1600` | `0.6` | `(18,20,40)` | `1.2` | `(255,255,255)` | `5200` |
| `fantasy` | `(34,22,26)` | `(18,12,16)` | `(20,12,20)` | `1500` | `0.9` | `(40,26,50)` | `0.9` | `(255,236,214)` | `2600` |
| `cyber` | `(26,18,36)` | `(12,8,20)` | `(11,7,20)` | `1500` | `0.5` | `(30,10,50)` | `1.8` | `(238,224,255)` | `3200` |

```lua
	sf = {
		...
		lighting = {
			ambient = Color3.fromRGB(22, 24, 38),
			outdoor = Color3.fromRGB(10, 12, 22),
			fog = Color3.fromRGB(8, 10, 22),
			fogEnd = 1600,
			brightness = 0.6,
			atmo = Color3.fromRGB(18, 20, 40),
			bloom = 1.2,
			tint = Color3.fromRGB(255, 255, 255),
			stars = 5200,
		},
	},
```

### H3-5. 재권 님 손이 필요한 단계 1개 (스크립트로 불가)
`Lighting.Technology`는 **스크립트로 바꿀 수 없습니다.** Studio에서 `Lighting` 선택 → Properties → `Technology` = **Future** 로 직접 지정해야 그림자·발광이 시안처럼 나옵니다.
→ 헤르메스는 이 항목을 **HERMES_REPORT.md의 "재권 님 확인 필요"에 적고 넘어갑니다.** (Bloom·Atmosphere·Sky는 기술 설정과 무관하게 동작합니다.)

### 완료 판정 (H3)
- [ ] 하늘이 **검정/남색**, 별이 보임, 파란 낮 하늘이 아님 (전체뷰에서도)
- [ ] 네온 파츠 주변에 빛 번짐(Bloom)
- [ ] 테마를 바꿔도 하늘은 계속 어두움

---

## 6. H4~H6 (P1) — 8각 부유섬 (SPEC 8.6②)

`buildArena`의 판·아래 구조 부분(**443~457행**)을 아래 블록으로 **교체**합니다. `U.PLATE=68`, `U.CELL=7`, `U.GRID_N=8` 은 그대로 씁니다.

### H4. 8각 상판 (정사각 → 8각)

```lua
	-- ── 8각 상판 (SPEC 8.6②) ──────────────────────────────────
	-- AP=중심~변 거리. 64칸(±24.5)을 모두 덮도록 68 정사각보다 조금 크게 둡니다.
	local AP = 36
	local SIDE = 2 * AP * math.tan(math.rad(22.5))   -- ≈ 29.8 (8각 한 변 길이)

	for k = 0, 7 do
		local a = math.rad(45 * k)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = Vector3.new(dir.X * AP * 0.5, -1.5 + (k % 2) * 0.01, dir.Z * AP * 0.5)
		local bar = place(arena, "PlateBar" .. k, Vector3.new(SIDE, 3, AP),
			CFrame.lookAt(c, c - dir), THEMES.sf.plate, Enum.Material.Slate, { shadow = true })
		reg(bar, "plate")
	end
```

- `k % 2`로 위아래 0.01 studs씩 어긋나게 해서 **8장이 겹치는 면의 깜빡임(z-fighting)** 을 막습니다.
- 위에서 보면 **모서리가 깎인 8각 실루엣**이어야 합니다. 4각이면 `SIDE`가 틀린 것입니다(`2*AP*tan(22.5°)`).

### H5. 절벽 3단 + 뾰족한 바닥 + 파편 + 종족색 테두리

```lua
	-- 절벽 3단 (아래로 좁아지는 바위 덩어리)
	local RINGS = {
		{ ap = 34, top = -3, h = 5 },
		{ ap = 24, top = -8, h = 6 },
		{ ap = 13, top = -14, h = 7 },
	}
	for r, ring in ipairs(RINGS) do
		local side = 2 * ring.ap * math.tan(math.rad(22.5))
		for k = 0, 7 do
			local a = math.rad(45 * k)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local c = Vector3.new(dir.X * ring.ap * 0.5, ring.top - ring.h * 0.5, dir.Z * ring.ap * 0.5)
			local p = place(arena, "Cliff" .. r .. "_" .. k, Vector3.new(side, ring.h, ring.ap),
				CFrame.lookAt(c, c - dir), shade(THEMES.sf.plate2, 0.8), Enum.Material.Slate, { shadow = true })
			reg(p, "plate2")
		end
	end

	-- 맨 아래 뾰족한 바위 끝
	local tip = place(arena, "IslandTip", Vector3.new(9, 9, 9), rel(0, -21.5, 0, 0, 22.5, 0),
		shade(THEMES.sf.plate2, 0.55), Enum.Material.Slate, { shadow = true })
	reg(tip, "plate2")

	-- 절벽 파편 22개 (시드 고정 → 다시 켜도 같은 모양)
	local rng = Random.new(slot * 7919)
	for i = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local ap = rng:NextNumber(18, 33)
		local y = rng:NextNumber(-15, -2)
		local s = rng:NextNumber(0.7, 2.4)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = place(arena, "Shard" .. i, Vector3.new(s, s * 1.4, s),
			CFrame.new(dir.X * ap, y, dir.Z * ap) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
			shade(THEMES.sf.plate2, 0.9), Enum.Material.Slate)
		reg(p, "plate2")
	end

	-- 절벽의 종족색 발광 광맥 5개
	for i = 1, 5 do
		local a = math.rad(i * 72)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local y = rng:NextNumber(-12, -5)
		neon(arena, "Vein" .. i, Vector3.new(0.4, rng:NextNumber(3, 6), 0.4),
			rel(dir.X * 29, y, dir.Z * 29), faction.accent, { transparency = 0.15 })
	end

	-- 8변 종족색 네온 테두리 + 가장자리 빛
	for k = 0, 7 do
		local a = math.rad(45 * k)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = Vector3.new(dir.X * (AP + 0.3), 0.15, dir.Z * (AP + 0.3))
		neon(arena, "Rim" .. k, Vector3.new(SIDE + 0.6, 0.5, 0.6), CFrame.lookAt(c, c + dir), faction.accent)
	end
	for k = 0, 3 do
		local a = math.rad(90 * k + 45)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local anchor = neon(arena, "RimLight" .. k, Vector3.new(0.6, 0.6, 0.6),
			rel(dir.X * (AP - 1), 0.4, dir.Z * (AP - 1)), faction.accent, { shape = Enum.PartType.Ball })
		local pl = Instance.new("PointLight")
		pl.Color = faction.accent
		pl.Range = 45
		pl.Brightness = 1.5
		pl.Parent = anchor
	end
```

> `faction`은 `buildArena(slot, faction)` 인자로 이미 들어옵니다. 5개 섬이 각자 종족색으로 빛나야 합니다(휴먼 파랑 / 메카 주황 / 아케인 보라 / 바이오 초록 / 드론 청록).

### H6. 기존 상판·테두리 정리 (같은 함수 안)

1. **삭제**: `Plate`·`UnderPlate`·`Spike`·`Fin` 4개(`443~457행`) → 위 H4·H5가 대체합니다.
2. **삭제**: `Trim` 4개 네온 띠(`462~467행`) → `Rim` 8변이 대체합니다.
3. **수정**: `CornerPillar` 4개(`469~476행`)는 8각 밖(모서리 ±33,±33)으로 튀어나옵니다. 대각선 4방향(45°·135°·225°·315°) **반지름 `AP - 4`** 위치로 옮기세요.

```lua
	for i = 1, 4 do
		local a = math.rad(45 + (i - 1) * 90)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pillar = place(arena, "CornerPillar" .. i, Vector3.new(2.2, 9, 2.2),
			rel(dir.X * (AP - 4), 4.2, dir.Z * (AP - 4)), THEMES.sf.decor, Enum.Material.Metal)
		reg(pillar, "decor")
		neon(arena, "CornerGlow" .. i, Vector3.new(2.4, 0.4, 2.4),
			rel(dir.X * (AP - 4), 8.9, dir.Z * (AP - 4)), faction.color)
	end
```

4. (선택) 스폰 포탈이 섬 밖 허공(z≈−38)에 뜹니다. 좌표는 그대로 두고 **작은 스폰 발판**을 하나 추가하면 자연스럽습니다.

```lua
	local dock = place(arena, "SpawnDock", Vector3.new(16, 2, 14), rel(spawnPos.X, -1.0, spawnPos.Z + 2),
		shade(THEMES.sf.plate2, 0.85), Enum.Material.Slate, { shadow = true })
	reg(dock, "plate2")
```

### 완료 판정 (H4~H6)
- [ ] 위에서 봤을 때 **8각** 실루엣 (정사각이면 실패)
- [ ] 아래에서 봤을 때 **바위 절벽 + 뾰족한 바닥**, 회색 파편
- [ ] 가장자리가 **종족색으로 빛나고**, 주변 바닥에 빛이 번짐
- [ ] 섬 아래로 **하늘색이 비치지 않음**(절벽이 외곽을 감쌈)
- [ ] 타일 64칸이 모두 섬 위에 올라가 있음(모서리 칸이 허공에 뜨지 않음)

---

## 7. H7 (P2) — `models/` 3D 메시 (SPEC 8.6③) · 이번 라운드는 "연결 준비"만

- 지금 `models/*.obj` 18종은 저장소에만 있고 **Studio에 임포트되지 않았습니다**. 코드에도 `MeshPart`·`TDModels` 참조가 **0건**입니다.
- **임포트(Blender→FBX→Studio `File → Import 3D`)는 재권 님 Studio 작업**이라 이번 라운드에서 하지 않습니다. 대신 **있으면 쓰고 없으면 기존 파트를 그대로 쓰는 가드**만 넣어 두면, 나중에 임포트하는 순간 자동으로 메시가 뜹니다.

`buildNexus` 맨 앞(넥서스 Model을 만든 직후)에 넣습니다.

```lua
	-- TDModels 가 임포트되어 있으면 그 메시를 쓰고, 없으면 아래 파트 조립을 그대로 씁니다.
	local tdModels = ReplicatedStorage:FindFirstChild("TDModels")
	local nexusMesh = tdModels and tdModels:FindFirstChild("nexus_" .. faction.key)
	if nexusMesh then
		local mesh = nexusMesh:Clone()
		mesh.Name = "NexusMesh"
		for _, d in ipairs(mesh:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		mesh:PivotTo(cf * rel(0, 0, 31))
		mesh.Parent = arena
		return nexus  -- 파트 조립은 건너뜁니다
	end
```

- 넥서스 메시 이름 규칙: `nexus_human`·`nexus_mecha`·`nexus_arcane`·`nexus_bio`·`nexus_drone` (SPEC 8.6③ 표 그대로).
- 메시로 바꾸면 그 아레나의 **NEXUS HP 바가 안 보입니다**(현재 HP 바는 파트 코어에 붙어 있음). 이번 라운드는 메시가 없으므로 문제없고, 임포트 후 HP 바를 메시에 붙이는 일은 Round 2로 넘깁니다. H7을 적용했으면 HERMES_REPORT.md에 이 점을 적어 주세요.
- 유닛·적 메시 교체는 `02_ArenaBattle`의 `refreshUnitVisual`을 건드려야 하므로 **Round 2**로 넘깁니다.
- **임포트 전에는 이 블록이 아무 일도 하지 않아야 합니다**(`TDModels`가 없으므로). 게임이 깨지면 실패로 기록하세요.

---

## 8. 문법·연동 재점검 — 피클 1차 결과 (다시 하지 말 것 / 확인만 할 것)

피클이 `b6529bc` 기준 9개 파일 전수로 확인한 결과입니다. **아래는 이미 통과**이니 같은 검사를 반복하지 말고, H1~H6 수정 **뒤에 한 번만 다시** 돌리세요.

| 점검 | 결과 | 근거 |
|---|---|---|
| Luau 문법(9파일) | ✅ 0오류 | `luaparser` 4.2.0 파싱 성공 |
| `Shared.*` 참조 | ✅ 미정의 0건 | 60여 개 참조 전부 `TDShared`에 존재 |
| RemoteEvent 11종 이름 | ✅ 일치 | `TDShared.REMOTE_NAMES` ↔ 서버 `RD.*` ↔ 클라 `WaitForChild` |
| 상태 이벤트 이름 | ✅ 일치 | 서버 `assigned/banner/toast/state/theme/drawn/relic/relicDone/reviveOffer/win/lose/restart/metaDirty` ↔ 클라 분기 |
| FX kind 10종 | ✅ 일치 | `dmg/flash/shake/coreHit/bossWarn/heroWarn/stageStart/modeSwitch/skill/restart` |
| 서버 버스 | ✅ 일치 | 02 `Bus.Call`: `product`·`reward`·`refresh` ↔ 03/05 호출부 |
| 유닛 모델 이름 | ✅ 일치 | 01 `faction .. "_" .. form.key`, `FUSION_<key>` ↔ 02 `unitModelName` |
| 아레나 구조 참조 | ✅ 일치 | 02/04가 찾는 `Cells`·`Nexus`·`WarnBeacon`·`AILight`·`TeamBanner`·`EnergyLink_n`·`BossAltar` 모두 01이 생성 |
| `TD_Build`·`TD_Prompt`의 `OnServerEvent` 2개 연결 | ⚠️ **의도된 것 — 합치지 말 것** | `TD_Build`는 인자 4개(`move4`)를 따로, `TD_Prompt`는 `faction`을 따로 받습니다. 하나로 합치면 이동/종족변경이 깨집니다 |

**헤르메스가 새로 확인할 것**
- [ ] 수정 후 9개 파일 문법 재검사(가능하면 `luaparser`, 없으면 Studio Output의 컴파일 에러 0)
- [ ] Output에 `[TD] 01_WorldAndUnits 완료 …` 1줄 정상 출력
- [ ] 새로 넣은 코드에서 `Instance`를 `SetAttribute`에 넣은 곳이 없는지 (`Home`과 같은 실수)

**이번 라운드에서 고치지 않는(정상 동작인) 것**
- 상품·패스 ID가 전부 `0` → 상점이 "준비 중"으로 뜨고 결제가 꺼져 있음. **정상**입니다(게시 후 ID 입력).
- Studio에서 DataStore 저장이 안 될 수 있음 → `Game Settings → Security → Enable Studio Access to API Services` 필요.
- 캐릭터가 스폰되지 않음(`CharacterAutoLoads=false`) → 탑다운 카메라 게임이라 **정상**.

---

## 9. Studio 테스트 체크리스트 (수정 후, 순서대로)

1. Studio → `Play` → **Output** 창 비우고 다시 Play.
2. `[TD]` 로그 8줄이 뜨는지 (특히 `01_WorldAndUnits 완료`). **빨간 에러 0건.**
3. 하늘: **검정/남색 + 별**, 파란 낮 하늘 아님.
4. 내 아레나: **8각** 섬, 모서리가 깎임, 아래로 절벽, 가장자리 **종족색 빛**.
5. 전체뷰(👥 두 번): **5개 섬 + 중앙 제단**, 섬마다 다른 색, 중앙에 네온 덩어리 없음.
6. 인트로에서 종족 선택 → **🔮 유닛 뽑기** 2~3회 → 손패 → **빈 타일 터치** → 터렛이 서면 01/02/04/TDShared 연결 정상.
7. 14초 뒤 **STAGE 1 / 100기** 배너, 몬스터가 게이트에서 들어와 넥서스 HP가 줄어듦.
8. 🌌 테마 버튼 → 바닥·장식·조명·**하늘 밝기**는 그대로 어둡게, 색만 바뀜.
9. `Lighting.Technology`를 `Future`로 바꾼 뒤(재권 님) 그림자·발광이 더 좋아지는지.

각 항목의 결과를 HERMES_REPORT.md에 **✅/❌와 한 줄 근거**로 적어 주세요. Studio를 실행할 수 없으면 그 사실을 그대로 적고, 대신 코드 검사 결과(문법·참조)를 적습니다.

---

## 10. 완료 후 — `HERMES_REPORT.md` 작성 + 커밋·푸시

`C:\PickleGames\roblox-turret-defense\HERMES_REPORT.md`를 아래 형식으로 새로 만드세요. 피클이 다음 라운드에서 이 파일만 읽고 이어서 작업합니다.

```markdown
# 🧾 HERMES_REPORT — Round 1

- 작업 시각: 2026-11-28
- 기준 커밋: b6529bc
- 수정한 파일: (예) ServerScriptService/01_WorldAndUnits.server.lua, ReplicatedStorage/TDShared.lua

## 적용한 항목
| ID | 항목 | 결과 | 근거(줄/확인 방법) |
|---|---|---|---|
| H1 | Instance 속성 제거 | ✅ | 374행 삭제, decorFolders 표 교체 |
| H2 | neon/disc pivot | ✅ | … |
| H3 | 우주 조명 | ⚠️ | 코드 적용, Studio 미확인 |
| H4 | 8각 상판 | … | |
| H5 | 절벽·테두리 | … | |
| H6 | 기존 상판 정리 | … | |
| H7 | TDModels 가드 | … | |

## 확인된 것
- (Output 로그, 문법 검사 결과 등 실제로 본 것만)

## 확인하지 못한 것 / 남은 위험
- (Studio 실행 여부, Lighting.Technology 수동 설정 등)

## 재권 님이 직접 해야 할 일
- [ ] Studio → Lighting → Technology = Future
- [ ] (있으면) 메시 임포트

## 다음 라운드 제안
- (피클이 이어서 할 일 후보 2~3개)
```

### 커밋·푸시

```powershell
cd C:\PickleGames
git status                                  # 수정 파일이 01·TDShared·HERMES_REPORT.md 뿐인지 확인
git add roblox-turret-defense/ServerScriptService/01_WorldAndUnits.server.lua roblox-turret-defense/ReplicatedStorage/TDShared.lua roblox-turret-defense/HERMES_REPORT.md
git commit -m "🔧 터렛 디펜스 Round 1: 01 치명버그(속성 Instance) 수정 · 네온 좌표 버그 수정 · 우주 조명(8.6①) · 8각 부유섬(8.6②)"
git push origin main
```

- **push에 실패하면**(인증·권한) 커밋은 남겨 두고 `git format-patch -1 --output=round1.patch`로 패치 파일을 만든 뒤, `HERMES_REPORT.md`에 "push 실패: <에러 문구>"를 적어 주세요. 피클이 그 패치를 적용합니다.
- 다른 사람의 커밋과 충돌하면 **절대 강제 푸시하지 말고**, `git pull --rebase origin main` 후 다시 시도하고 결과를 보고하세요.

---

## 11. 하지 말 것 (경계)

- ❌ `02_ArenaBattle`·`03`·`05`·`04`·`06`·`07`·`TDData`의 로직·밸런스 수정
- ❌ `Shared.UNIVERSE`(좌표·그리드·`SPAWN_LOCAL`·`NEXUS_LOCAL`)·가격·확률·스테이지 숫자 변경
- ❌ `concepts/`·`models/` 재커밋, 새 바이너리 추가
- ❌ 2026-11-27에 재권 님이 받은 클로드 시각화 파일을 **통째로 덮어쓰기** — 그 파일은 `WorldFolder`·`Island_`·`TDRemotes`·`Race` 등 **다른 구조**를 씁니다(지금 `TDWorld`·`Arena_`·`TD_Remotes`·`Faction`과 불일치). **기법만 참고**(Sky/Atmosphere/Bloom 생성, 8각 판, 테두리)하고 구조는 지금 것을 유지하세요.
- ❌ 확인하지 않은 것을 "확인했다"고 보고하기
