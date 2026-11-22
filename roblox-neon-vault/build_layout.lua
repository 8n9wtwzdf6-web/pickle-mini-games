--[[
  build_layout.lua  ·  네온 볼트 약탈자 (Neon Vault Heist) 3D 전략 맵 생성기
  --------------------------------------------------------------------------------
  사용법 (Studio 편집 모드에서 한 번만 실행):
    1) Roblox Studio 상단 메뉴 View > Command Bar 를 켭니다.
    2) 이 파일 내용을 전부 복사해 Command Bar 입력창에 붙여넣고 Enter.
       (Command Bar 붙여넣기가 안 되는 버전이면: Explorer > ServerScriptService 에
        Script 를 하나 만들고 내용을 붙여넣은 뒤, 스크립트 편집기 위쪽의
        'Run Script' 를 누르면 됩니다. 실행 후 그 Script 는 지워도 됩니다.)
    3) Explorer > Workspace 아래에 'NeonVaultWorld' 모델이,
       ServerStorage 아래에 'NeonVaultTemplates' 폴더가 생깁니다.

  만드는 맵 (LoL · 포켓몬 유나이트식 전략 구조, 900 × 900 스터드)
    · 중앙 아레나 (반경 120) + 거대 뽑기 타워 + 💛황금 코어 제단
    · 4개 기지 (대각선 코너) — 3D 금고 문 · 전시대 8칸 · 레이저 방어막 돔 · 상태 빌보드
    · 3개 레인
        미드(MID)  : 기지 ↔ 중앙 아레나를 잇는 대각선 최단로 (빠르지만 노출)
        탑(TOP)    : 💎크리스탈 유적 · 🛸사이버 시티를 지나는 외곽 우회로
        봇(BOT)    : 🐉용암 던전 · 🦖원시 정글을 지나는 외곽 우회로
    · 🌿 은신 수풀 18곳 (Bushes 폴더, 'BushZone' 파트) — 들어가면 은신
    · ⚡ 가속 패드 · 🟢 점프 패드
    · 테마별 뽑기 스테이션 (중앙 타워 4개 + 각 구역 1개)
    · ServerStorage > NeonVaultTemplates : 테마 대표 3D 모델 4종
    · 조명/블룸/대기 연출

  ※ 이 스크립트는 3D 구조만 만듭니다. 실제 게임 동작은 README 5장의
     스크립트 3개(01/02/03)를 붙여넣어야 동작합니다.
  ※ 이미 'NeonVaultWorld' 가 있으면 아무것도 지우지 않고 종료합니다.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

if Workspace:FindFirstChild("NeonVaultWorld") ~= nil then
	print("[NeonVault] 'NeonVaultWorld' 가 이미 있어서 아무것도 만들지 않았습니다. 새로 만들려면 기존 모델을 지우고 다시 실행하세요.")
	return
end

-- ==============================================================
-- 0. 팔레트 / 공통 헬퍼
-- ==============================================================
local NEON = {
	cyan = Color3.fromRGB(0, 232, 255),
	magenta = Color3.fromRGB(255, 46, 190),
	violet = Color3.fromRGB(146, 92, 255),
	lime = Color3.fromRGB(120, 255, 90),
	gold = Color3.fromRGB(255, 198, 58),
	red = Color3.fromRGB(255, 72, 92),
	white = Color3.fromRGB(236, 246, 255),
	dark = Color3.fromRGB(12, 14, 26),
	dark2 = Color3.fromRGB(20, 24, 42),
	steel = Color3.fromRGB(58, 66, 92),
	leaf = Color3.fromRGB(36, 150, 96),
}

local PLOT_COLORS = { NEON.cyan, NEON.magenta, NEON.lime, NEON.violet }

local function makePart(parent, name, size, cframe, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color or NEON.steel
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeDisc(parent, name, diameter, height, position, color, material, transparency)
	local part = makePart(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(position), color, material or Enum.Material.Neon, transparency, false)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

local function makePrompt(parent, actionText, objectText, holdTime, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.HoldDuration = holdTime or 0.2
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = true
	prompt.Parent = parent
	return prompt
end

local function makeBillboard(parent, adornee, size, text, color, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StatusGui"
	gui.Adornee = adornee
	gui.Size = size
	gui.StudsOffset = Vector3.new(0, offsetY or 0, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 420
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "StatusLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color or NEON.white
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = gui
	return gui
end

-- 레인 도로 (두 점을 잇는 네온 도로 + 중앙 점선)
local function laneSegment(parent, name, a, b, color, width, height)
	width = width or 46
	height = height or 1
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = delta.Magnitude
	if length < 1 then
		return nil
	end
	local mid = Vector3.new((a.X + b.X) / 2, a.Y, (a.Z + b.Z) / 2)
	local cframe = CFrame.lookAt(mid, mid + delta)
	local deck = makePart(parent, name, Vector3.new(width, height, length), cframe, Color3.fromRGB(18, 24, 44), Enum.Material.Slate, 0, true)
	local edgeL = makePart(parent, name .. "_EdgeL", Vector3.new(2, 1.4, length), cframe * CFrame.new(-width / 2, 1, 0), color, Enum.Material.Neon, 0.35, false)
	local edgeR = makePart(parent, name .. "_EdgeR", Vector3.new(2, 1.4, length), cframe * CFrame.new(width / 2, 1, 0), color, Enum.Material.Neon, 0.35, false)
	edgeL.CanCollide = false
	edgeR.CanCollide = false
	local dashes = math.floor(length / 34)
	local dir = Vector3.new(delta.X, 0, delta.Z).Unit
	for i = 1, dashes do
		local t = (i - 0.5) / dashes
		local pos = a:Lerp(b, t) + Vector3.new(0, 0.9, 0)
		makePart(parent, name .. "_Dash" .. i, Vector3.new(1.6, 0.5, 12), CFrame.lookAt(pos, pos + dir), color, Enum.Material.Neon, 0.45, false)
	end
	return deck
end

local function speedPad(parent, name, position, color, direction)
	local pad = makePart(parent, name, Vector3.new(26, 1.6, 26), CFrame.new(position + Vector3.new(0, 0.8, 0)), color, Enum.Material.Neon, 0.15, false)
	pad:SetAttribute("SpeedPad", true)
	pad:SetAttribute("BoostSpeed", 42)
	local arrow = makePart(parent, name .. "_Arrow", Vector3.new(12, 1.2, 12), CFrame.new(position + Vector3.new(0, 2.6, 0)), NEON.white, Enum.Material.Neon, 0.25, false)
	arrow.Shape = Enum.PartType.Cylinder
	arrow.CFrame = CFrame.new(position + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	if direction ~= nil then
		arrow.CFrame = CFrame.lookAt(position + Vector3.new(0, 2.6, 0), position + direction + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
	return pad
end

local function jumpPad(parent, name, position)
	local pad = makePart(parent, name, Vector3.new(24, 1.6, 24), CFrame.new(position + Vector3.new(0, 0.8, 0)), NEON.lime, Enum.Material.Neon, 0.15, false)
	pad:SetAttribute("JumpPad", true)
	pad:SetAttribute("JumpPower", 95)
	local ring = makeDisc(parent, name .. "_Ring", 28, 0.8, position + Vector3.new(0, 1.4, 0), NEON.white, Enum.Material.Neon, 0.5)
	ring.CanCollide = false
	return pad
end

-- ==============================================================
-- 1. 폴더
-- ==============================================================
local world = Instance.new("Model")
world.Name = "NeonVaultWorld"

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local plotsFolder = folder("Plots", world)
local propsFolder = folder("Props", world)
local lanesFolder = folder("Lanes", world)
local bushesFolder = folder("Bushes", world)
local regionsFolder = folder("Regions", world)
local padsFolder = folder("Pads", world)

-- ==============================================================
-- 2. 바닥 / 외곽
-- ==============================================================
makePart(world, "GroundFloor", Vector3.new(900, 4, 900), CFrame.new(0, -2, 0), Color3.fromRGB(9, 11, 20), Enum.Material.Slate, 0, true)
makePart(world, "GroundGlow", Vector3.new(880, 0.4, 880), CFrame.new(0, 0.2, 0), Color3.fromRGB(14, 20, 40), Enum.Material.SmoothPlastic, 0.35, false)

-- 외곽 네온 펜스
for i = 1, 4 do
	local angle = math.rad(90 * (i - 1))
	local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local pos = dir * 440
	local fence = makePart(propsFolder, "Border" .. i, Vector3.new(860, 18, 3), CFrame.new(pos.X, 9, pos.Z), NEON.violet, Enum.Material.Neon, 0.72, false)
	fence.CFrame = CFrame.lookAt(Vector3.new(pos.X, 9, pos.Z), Vector3.new(0, 9, 0)) * CFrame.Angles(0, math.rad(90), 0)
end

-- ==============================================================
-- 3. 레인 (미드 / 탑 / 봇)
-- ==============================================================
-- 기지 4곳: 1=남서(기본), 2=북동, 3=북서, 4=남동
local PLOT_CENTERS = {
	Vector3.new(-230, 0, 230),
	Vector3.new(230, 0, -230),
	Vector3.new(-230, 0, -230),
	Vector3.new(230, 0, 230),
}
local REGION_CENTERS = {
	crystal = Vector3.new(0, 0, -340),   -- 💎 북 (탑 레인)
	city = Vector3.new(-340, 0, 0),      -- 🛸 서 (탑 레인)
	lava = Vector3.new(0, 0, 340),       -- 🐉 남 (봇 레인)
	jungle = Vector3.new(340, 0, 0),     -- 🦖 동 (봇 레인)
}

local ARENA_R = 120
local ARENA_MARK = Vector3.new(0, 1, 0)

local midLane = folder("Mid", lanesFolder)
local topLane = folder("Top", lanesFolder)
local botLane = folder("Bot", lanesFolder)

-- 미드: SW ↔ NE, NW ↔ SE 대각선
laneSegment(midLane, "Mid_SW_1", PLOT_CENTERS[1] + Vector3.new(60, 0.2, -60), Vector3.new(-52, 0.2, 52), NEON.magenta, 48)
laneSegment(midLane, "Mid_NE_1", Vector3.new(52, 0.2, -52), PLOT_CENTERS[2] + Vector3.new(-60, 0.2, 60), NEON.magenta, 48)
laneSegment(midLane, "Mid_NW_1", PLOT_CENTERS[3] + Vector3.new(60, 0.2, 60), Vector3.new(-52, 0.2, -52), NEON.magenta, 48)
laneSegment(midLane, "Mid_SE_1", Vector3.new(52, 0.2, 52), PLOT_CENTERS[4] + Vector3.new(-60, 0.2, -60), NEON.magenta, 48)

-- 탑: NW ↔ 💎크리스탈 ↔ NE, NW ↔ 🛸시티 ↔ SW
laneSegment(topLane, "Top_NW_Crystal", PLOT_CENTERS[3] + Vector3.new(0, 0.2, 40), REGION_CENTERS.crystal + Vector3.new(-90, 0.2, 90), NEON.cyan, 44)
laneSegment(topLane, "Top_Crystal_NE", REGION_CENTERS.crystal + Vector3.new(90, 0.2, 90), PLOT_CENTERS[2] + Vector3.new(-40, 0.2, 0), NEON.cyan, 44)
laneSegment(topLane, "Top_NW_City", PLOT_CENTERS[3] + Vector3.new(40, 0.2, 0), REGION_CENTERS.city + Vector3.new(90, 0.2, -90), NEON.cyan, 44)
laneSegment(topLane, "Top_City_SW", REGION_CENTERS.city + Vector3.new(90, 0.2, 90), PLOT_CENTERS[1] + Vector3.new(0, 0.2, -40), NEON.cyan, 44)

-- 봇: SW ↔ 🐉용암 ↔ SE, SE ↔ 🦖정글 ↔ NE
laneSegment(botLane, "Bot_SW_Lava", PLOT_CENTERS[1] + Vector3.new(40, 0.2, 0), REGION_CENTERS.lava + Vector3.new(-90, 0.2, -90), NEON.lime, 44)
laneSegment(botLane, "Bot_Lava_SE", REGION_CENTERS.lava + Vector3.new(90, 0.2, -90), PLOT_CENTERS[4] + Vector3.new(0, 0.2, -40), NEON.lime, 44)
laneSegment(botLane, "Bot_SE_Jungle", PLOT_CENTERS[4] + Vector3.new(0, 0.2, 40), REGION_CENTERS.jungle + Vector3.new(-90, 0.2, -90), NEON.lime, 44)
laneSegment(botLane, "Bot_Jungle_NE", REGION_CENTERS.jungle + Vector3.new(-90, 0.2, 90), PLOT_CENTERS[2] + Vector3.new(40, 0.2, 0), NEON.lime, 44)

-- 레인 표지
local midSignAnchor = makePart(propsFolder, "MidSignAnchor", Vector3.new(2, 2, 2), CFrame.new(-90, 16, 90), NEON.white, Enum.Material.SmoothPlastic, 1, false)
midSignAnchor.CanQuery = false
makeBillboard(propsFolder, midSignAnchor, UDim2.fromOffset(240, 90), "MID", NEON.magenta, 0)
local topSignAnchor = makePart(propsFolder, "TopSignAnchor", Vector3.new(2, 2, 2), CFrame.new(-200, 16, -200), NEON.white, Enum.Material.SmoothPlastic, 1, false)
topSignAnchor.CanQuery = false
makeBillboard(propsFolder, topSignAnchor, UDim2.fromOffset(240, 90), "TOP", NEON.cyan, 0)
local botSignAnchor = makePart(propsFolder, "BotSignAnchor", Vector3.new(2, 2, 2), CFrame.new(200, 16, 200), NEON.white, Enum.Material.SmoothPlastic, 1, false)
botSignAnchor.CanQuery = false
makeBillboard(propsFolder, botSignAnchor, UDim2.fromOffset(240, 90), "BOT", NEON.lime, 0)

-- ⚡ 가속 패드 (각 구역 진입로 + 미드 교전 지점)
speedPad(padsFolder, "SpeedPad_Crystal", REGION_CENTERS.crystal + Vector3.new(0, 0, 120), NEON.cyan, Vector3.new(0, 0, -1))
speedPad(padsFolder, "SpeedPad_Lava", REGION_CENTERS.lava + Vector3.new(0, 0, -120), NEON.magenta, Vector3.new(0, 0, 1))
speedPad(padsFolder, "SpeedPad_Jungle", REGION_CENTERS.jungle + Vector3.new(-120, 0, 0), NEON.lime, Vector3.new(1, 0, 0))
speedPad(padsFolder, "SpeedPad_City", REGION_CENTERS.city + Vector3.new(120, 0, 0), NEON.violet, Vector3.new(-1, 0, 0))
speedPad(padsFolder, "SpeedPad_MidSW", Vector3.new(-150, 0.2, 150), NEON.magenta, Vector3.new(1, 0, -1))

-- 🟢 점프 패드 (아레나 좌우)
jumpPad(padsFolder, "JumpPad_A", Vector3.new(-168, 0, 20))
jumpPad(padsFolder, "JumpPad_B", Vector3.new(168, 0, -20))

-- ==============================================================
-- 4. 중앙 아레나 · 뽑기 타워 · 황금 코어 제단
-- ==============================================================
local arena = Instance.new("Model")
arena.Name = "Arena"
arena.Parent = world

makeDisc(arena, "ArenaFloor", ARENA_R * 2, 3, Vector3.new(0, 1.5, 0), Color3.fromRGB(12, 18, 32), Enum.Material.Slate)
makeDisc(arena, "ArenaGlowRing1", ARENA_R * 2 + 4, 0.8, Vector3.new(0, 3.2, 0), NEON.cyan, Enum.Material.Neon, 0.55)
makeDisc(arena, "ArenaGlowRing2", 168, 0.7, Vector3.new(0, 3.3, 0), NEON.magenta, Enum.Material.Neon, 0.65)

-- 황금 코어 제단
local coreDais = Instance.new("Model")
coreDais.Name = "CoreDais"
coreDais.Parent = arena
makeDisc(coreDais, "DaisBase", 78, 3, Vector3.new(0, 3, 0), Color3.fromRGB(30, 26, 18), Enum.Material.Marble)
makeDisc(coreDais, "DaisGlow", 66, 1, Vector3.new(0, 4.8, 0), NEON.gold, Enum.Material.Neon, 0.4)
local coreAnchor = makePart(coreDais, "CoreSpawn", Vector3.new(14, 14, 14), CFrame.new(0, 16, 0), NEON.gold, Enum.Material.Neon, 1, false)
coreAnchor.CanQuery = false
coreAnchor:SetAttribute("CoreSpawn", true)
for i = 1, 4 do
	local a = math.rad(90 * (i - 1) + 45)
	local post = makePart(coreDais, "DaisPost" .. i, Vector3.new(3, 26, 3), CFrame.new(math.sin(a) * 34, 13, math.cos(a) * 34), NEON.gold, Enum.Material.Neon, 0.25, false)
	post.CanCollide = false
end
makeBillboard(coreDais, coreAnchor, UDim2.fromOffset(340, 90), "💛 황금 하이퍼 코어", NEON.gold, 14)

-- 거대 뽑기 타워 (아레나 북쪽)
local tower = Instance.new("Model")
tower.Name = "GachaTower"
tower.Parent = world
local TOWER_POS = Vector3.new(0, 0, -95)

makeDisc(tower, "TowerBase", 150, 4, TOWER_POS + Vector3.new(0, 2, 0), Color3.fromRGB(18, 22, 38), Enum.Material.Slate)
makeDisc(tower, "TowerBaseGlow", 128, 1, TOWER_POS + Vector3.new(0, 4.4, 0), NEON.cyan, Enum.Material.Neon, 0.2)
makeDisc(tower, "TowerBaseGlow2", 140, 0.8, TOWER_POS + Vector3.new(0, 4.2, 0), NEON.magenta, Enum.Material.Neon, 0.55)
makePart(tower, "TowerColumn", Vector3.new(28, 96, 28), CFrame.new(TOWER_POS + Vector3.new(0, 50, 0)), Color3.fromRGB(24, 28, 48), Enum.Material.Metal, 0)
for i = 1, 5 do
	local ring = makeDisc(tower, "TowerRing" .. i, 40 + i * 4, 2, TOWER_POS + Vector3.new(0, 26 + i * 16, 0), NEON.cyan, Enum.Material.Neon, 0.35)
	ring.CanCollide = false
end
local core = makePart(tower, "TowerCore", Vector3.new(26, 26, 26), CFrame.new(TOWER_POS + Vector3.new(0, 112, 0)), NEON.white, Enum.Material.Neon, 0.05, false)
core.Shape = Enum.PartType.Ball
local coreGlow = makePart(tower, "TowerCoreGlow", Vector3.new(40, 40, 40), CFrame.new(TOWER_POS + Vector3.new(0, 112, 0)), NEON.cyan, Enum.Material.Neon, 0.82, false)
coreGlow.Shape = Enum.PartType.Ball
makeBillboard(tower, core, UDim2.fromOffset(380, 100), "NEON VAULT · 뽑기 타워", NEON.cyan, 16)

-- ==============================================================
-- 5. 테마 구역 (크리스탈 유적 / 사이버 시티 / 용암 던전 / 원시 정글)
-- ==============================================================
local THEMES = {
	{ id = "gem", label = "💎 보석 · 유물", color = NEON.cyan, region = "crystal" },
	{ id = "egg", label = "🦖 공룡 알", color = NEON.lime, region = "jungle" },
	{ id = "monster", label = "🐉 전설 몬스터", color = NEON.magenta, region = "lava" },
	{ id = "drone", label = "🛸 사이버 드론", color = NEON.violet, region = "city" },
}
local THEME_BY_ID = {}
for i, t in ipairs(THEMES) do
	THEME_BY_ID[t.id] = t
end

-- 중앙 타워 뽑기 스테이션 4개
local TOWER_DIRS = {
	gem = Vector3.new(0, 0, 1),
	egg = Vector3.new(1, 0, 0),
	monster = Vector3.new(0, 0, -1),
	drone = Vector3.new(-1, 0, 0),
}
for id, dir in pairs(TOWER_DIRS) do
	local theme = THEME_BY_ID[id]
	local pos = TOWER_POS + dir * 62 + Vector3.new(0, 5, 0)
	local station = makePart(tower, "Gacha_" .. id, Vector3.new(26, 12, 26), CFrame.new(pos), theme.color, Enum.Material.Neon, 0.22, true)
	station:SetAttribute("Theme", id)
	local top = makePart(tower, "GachaTop_" .. id, Vector3.new(14, 8, 14), CFrame.new(pos + Vector3.new(0, 9, 0)), NEON.white, Enum.Material.Neon, 0.05, false)
	top.CanCollide = false
	makePrompt(station, "뽑기", theme.label, 0.2, 18)
	local bb = makeBillboard(station, station, UDim2.fromOffset(300, 80), theme.label, theme.color, 12)
	bb.Name = "GachaGui"
end

-- 지역별 랜드마크 + 뽑기 패드
local function regionFloor(name, center, radius, color, topColor)
	local regionModel = Instance.new("Model")
	regionModel.Name = name
	regionModel.Parent = regionsFolder
	makeDisc(regionModel, "Floor", radius * 2, 3, center + Vector3.new(0, 1.5, 0), topColor, Enum.Material.Ground, 0)
	makeDisc(regionModel, "Rim", radius * 2 + 6, 1.2, center + Vector3.new(0, 3.2, 0), color, Enum.Material.Neon, 0.35)
	return regionModel
end

local function regionStation(regionModel, center, themeId)
	local theme = THEME_BY_ID[themeId]
	local pos = center + Vector3.new(0, 4, 70)
	local station = makePart(regionModel, "GachaPad_" .. themeId, Vector3.new(30, 10, 30), CFrame.new(pos + Vector3.new(0, 5, 0)), theme.color, Enum.Material.Neon, 0.15, true)
	station:SetAttribute("Theme", themeId)
	local glow = makeDisc(regionModel, "GachaPadGlow_" .. themeId, 40, 1, pos + Vector3.new(0, 6, 0), NEON.white, Enum.Material.Neon, 0.4)
	glow.CanCollide = false
	makePrompt(station, "뽑기", theme.label .. " · 구역 패드", 0.2, 18)
	makeBillboard(station, station, UDim2.fromOffset(320, 90), theme.label, theme.color, 14)
end

-- 💎 크리스탈 유적 (북, 탑 레인)
do
	local c = REGION_CENTERS.crystal
	local model = regionFloor("CrystalRuins", c, 170, NEON.cyan, Color3.fromRGB(18, 44, 58))
	for i = 1, 16 do
		local a = math.rad(i * 22.5 + 8)
		local rad = 46 + (i % 4) * 28
		local h = 30 + (i % 5) * 12
		local col = makePart(model, "CrystalPillar" .. i, Vector3.new(10, h, 10), CFrame.new(c + Vector3.new(math.cos(a) * rad, h / 2 + 3, math.sin(a) * rad)) * CFrame.Angles(0, a, math.rad(6)), NEON.cyan, Enum.Material.Neon, 0.18, true)
		col.CanCollide = true
		local tip = makePart(model, "CrystalTip" .. i, Vector3.new(8, 14, 8), CFrame.new(c + Vector3.new(math.cos(a) * rad, h + 9, math.sin(a) * rad)), NEON.white, Enum.Material.Neon, 0.1, false)
		tip.CFrame = CFrame.new(tip.Position) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(45))
		tip.Shape = Enum.PartType.Ball
	end
	for i = 1, 2 do
		local archZ = c.Z - 60 + (i - 1) * 120
		local p1 = makePart(model, "ArchPillarA" .. i, Vector3.new(10, 60, 10), CFrame.new(-34, 33, archZ), Color3.fromRGB(30, 70, 86), Enum.Material.Marble, 0, true)
		local p2 = makePart(model, "ArchPillarB" .. i, Vector3.new(10, 60, 10), CFrame.new(34, 33, archZ), Color3.fromRGB(30, 70, 86), Enum.Material.Marble, 0, true)
		local lintel = makePart(model, "ArchTop" .. i, Vector3.new(86, 10, 12), CFrame.new(0, 66, archZ), Color3.fromRGB(36, 84, 100), Enum.Material.Marble, 0, true)
		local rune = makePart(model, "ArchRune" .. i, Vector3.new(70, 2, 13), CFrame.new(0, 60, archZ), NEON.cyan, Enum.Material.Neon, 0.2, false)
		p1.CanCollide = true
		p2.CanCollide = true
		lintel.CanCollide = true
		rune.CanCollide = false
	end
	makeBillboard(model, model:FindFirstChild("Floor"), UDim2.fromOffset(340, 90), "💎 크리스탈 유적 · 탑", NEON.cyan, 26)
	regionStation(model, c, "gem")
end

-- 🛸 사이버 시티 (서, 탑 레인)
do
	local c = REGION_CENTERS.city
	local model = regionFloor("CyberCity", c, 170, NEON.violet, Color3.fromRGB(24, 20, 52))
	local spots = { { -40, -50 }, { -10, -70 }, { 30, -54 }, { 58, -20 }, { 52, 26 }, { 20, 60 }, { -20, 54 }, { -58, 18 } }
	for i, s in ipairs(spots) do
		local h = 50 + (i % 4) * 26
		local b = makePart(model, "Building" .. i, Vector3.new(30 + i, h, 30 + (i % 3) * 8), CFrame.new(c + Vector3.new(s[1], h / 2 + 3, s[2])), Color3.fromRGB(20, 26, 54), Enum.Material.Metal, 0, true)
		b.CanCollide = true
		local neonCol = (i % 2 == 0) and NEON.cyan or NEON.magenta
		local strip = makePart(model, "NeonStrip" .. i, Vector3.new(2, h * 0.9, 2), CFrame.new(b.Position + Vector3.new(-15, 0, 16)), neonCol, Enum.Material.Neon, 0.1, false)
		strip.CanCollide = false
	end
	for i = 1, 3 do
		local ring = makeDisc(model, "HoloRing" .. i, 70 + i * 20, 2, c + Vector3.new(0, 80 + i * 24, 0), NEON.violet, Enum.Material.Neon, 0.55)
		ring.CanCollide = false
	end
	makeBillboard(model, model:FindFirstChild("Floor"), UDim2.fromOffset(340, 90), "🛸 사이버 시티 · 탑", NEON.violet, 26)
	regionStation(model, c, "drone")
end

-- 🐉 용암 던전 (남, 봇 레인)
do
	local c = REGION_CENTERS.lava
	local model = regionFloor("LavaDungeon", c, 170, NEON.magenta, Color3.fromRGB(52, 18, 20))
	local lava = makeDisc(model, "LavaPool", 210, 2, c + Vector3.new(0, 3.6, 30), Color3.fromRGB(255, 96, 30), Enum.Material.Neon, 0.05)
	lava.CanCollide = false
	makeDisc(model, "LavaRim", 218, 1.2, c + Vector3.new(0, 4.6, 30), NEON.gold, Enum.Material.Neon, 0.4)
	for i = 1, 8 do
		local a = math.rad(i * 45)
		local wall = makePart(model, "DungeonWall" .. i, Vector3.new(40, 44, 6), CFrame.new(c + Vector3.new(math.sin(a) * 130, 25, math.cos(a) * 130)) * CFrame.Angles(0, a, 0), Color3.fromRGB(44, 22, 30), Enum.Material.Brick, 0, true)
		wall.CanCollide = true
		makePart(model, "DungeonSpike" .. i, Vector3.new(8, 12, 8), CFrame.new(wall.Position + Vector3.new(0, 26, 0)), NEON.magenta, Enum.Material.Neon, 0.4, false)
	end
	for i = 1, 4 do
		local a = math.rad(90 * (i - 1) + 45)
		local col = makePart(model, "DungeonColumn" .. i, Vector3.new(12, 56, 12), CFrame.new(c + Vector3.new(math.cos(a) * 92, 31, math.sin(a) * 92)), Color3.fromRGB(50, 26, 34), Enum.Material.Brick, 0, true)
		col.CanCollide = true
		local fire = makePart(model, "DungeonFire" .. i, Vector3.new(14, 14, 14), CFrame.new(c + Vector3.new(math.cos(a) * 92, 62, math.sin(a) * 92)), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, 0.2, false)
		fire.Shape = Enum.PartType.Ball
		fire.CanCollide = false
	end
	makeBillboard(model, model:FindFirstChild("Floor"), UDim2.fromOffset(340, 90), "🐉 용암 던전 · 봇", NEON.magenta, 26)
	regionStation(model, c, "monster")
end

-- 🦖 원시 정글 (동, 봇 레인)
do
	local c = REGION_CENTERS.jungle
	local model = regionFloor("PrimalJungle", c, 170, NEON.lime, Color3.fromRGB(18, 46, 26))
	for i = 1, 14 do
		local a = math.rad(i * 25.7)
		local rad = 48 + (i % 3) * 30
		local h = 34 + (i % 4) * 12
		local trunk = makePart(model, "TreeTrunk" .. i, Vector3.new(10, h, 10), CFrame.new(c + Vector3.new(math.cos(a) * rad, h / 2 + 3, math.sin(a) * rad)), Color3.fromRGB(62, 44, 28), Enum.Material.Wood, 0, true)
		trunk.CanCollide = true
		for k = 1, 3 do
			local canopy = makePart(model, "TreeCanopy" .. i .. "_" .. k, Vector3.new(46 - k * 8, 26, 46 - k * 8), CFrame.new(trunk.Position + Vector3.new(math.cos(k) * 8, h / 2 + k * 10, math.sin(k) * 8)), Color3.fromRGB(26, 120, 60), Enum.Material.Grass, 0, true)
			canopy.CanCollide = false
		end
	end
	-- 화석
	for i = 1, 5 do
		local bone = makePart(model, "FossilRib" .. i, Vector3.new(30, 4, 4), CFrame.new(c + Vector3.new(-60 + i * 12, 6, -60)) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(214, 206, 176), Enum.Material.Sand, 0, false)
		bone.CanCollide = false
	end
	-- 공룡알 둥지
	local nest = makeDisc(model, "Nest", 90, 4, c + Vector3.new(50, 4, 50), Color3.fromRGB(110, 86, 54), Enum.Material.Fabric, 0)
	for i = 1, 3 do
		local a = math.rad(i * 120)
		local egg = makePart(model, "DinoEgg" .. i, Vector3.new(22, 30, 22), CFrame.new(c + Vector3.new(50 + math.cos(a) * 20, 22, 50 + math.sin(a) * 20)), Color3.fromRGB(232, 228, 200), Enum.Material.SmoothPlastic, 0, false)
		egg.Shape = Enum.PartType.Ball
		egg.CanCollide = false
	end
	makeBillboard(model, model:FindFirstChild("Floor"), UDim2.fromOffset(340, 90), "🦖 원시 정글 · 봇", NEON.lime, 26)
	regionStation(model, c, "egg")
end

-- ==============================================================
-- 6. 🌿 은신 수풀
-- ==============================================================
local BUSH_SPOTS = {
	{ -150, 90 }, { -90, 150 },
	{ 150, -90 }, { 90, -150 },
	{ -150, -90 }, { -90, -150 },
	{ 150, 90 }, { 90, 150 },
	{ 0, -150 }, { 0, 150 }, { 150, 0 }, { -150, 0 },
	{ -40, -250 }, { 40, 250 }, { 250, -40 }, { -250, 40 },
	{ -320, 120 }, { 320, -120 },
}

local function buildBush(index, x, z, radius)
	local bush = Instance.new("Model")
	bush.Name = "Bush" .. index
	bush.Parent = bushesFolder

	local zone = makePart(bush, "BushZone", Vector3.new(radius * 2, 16, radius * 2), CFrame.new(x, 8, z), NEON.leaf, Enum.Material.Grass, 1, false)
	zone.CanCollide = false
	zone.CanQuery = false
	zone:SetAttribute("StealthZone", true)
	zone:SetAttribute("Radius", radius)

	local leaves = { NEON.leaf, Color3.fromRGB(24, 116, 74), Color3.fromRGB(46, 176, 116) }
	local count = 7
	for i = 1, count do
		local a = math.rad(i * (360 / count))
		local rr = radius * 0.55
		local blob = makePart(bush, "Leaf" .. i, Vector3.new(radius * 0.9, radius * 0.8, radius * 0.9), CFrame.new(x + math.cos(a) * rr, 8 + (i % 3) * 3, z + math.sin(a) * rr) * CFrame.Angles(0, a, 0), leaves[(i % 3) + 1], Enum.Material.Grass, 0.35, false)
		blob.Shape = Enum.PartType.Ball
		blob.CanCollide = false
	end
	local core = makePart(bush, "LeafCore", Vector3.new(radius * 1.2, radius, radius * 1.2), CFrame.new(x, 11, z), NEON.leaf, Enum.Material.Grass, 0.35, false)
	core.Shape = Enum.PartType.Ball
	core.CanCollide = false

	local ring = makeDisc(bush, "StealthRing", radius * 2.2, 0.6, Vector3.new(x, 3.4, z), NEON.lime, Enum.Material.Neon, 0.45)
	ring.CanCollide = false

	local bb = makeBillboard(bush, core, UDim2.fromOffset(200, 60), "🌿 은신 수풀", NEON.lime, radius + 6)
	bb.Name = "BushGui"
	bush:SetAttribute("BushIndex", index)
	return bush
end

for i, spot in ipairs(BUSH_SPOTS) do
	buildBush(i, spot[1], spot[2], 34)
end

-- ==============================================================
-- 7. 플레이어 기지 4개
-- ==============================================================
local BASE_W = 120
local BASE_D = 96
local PEDESTAL_XS = { -42, -14, 14, 42 }
local PEDESTAL_ZS = { -20, 20 }

local function buildPlot(index)
	local center = PLOT_CENTERS[index]
	local toCenter = Vector3.new(-center.X, 0, -center.Z)
	toCenter = Vector3.new(toCenter.X, 0, toCenter.Z).Unit
	local right = Vector3.new(-toCenter.Z, 0, toCenter.X)
	local themeColor = PLOT_COLORS[index]

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("BasePosition", center)

	-- 기지 바닥
	makePart(plot, "Base", Vector3.new(BASE_W, 3, BASE_D), CFrame.new(center + Vector3.new(0, 1.5, 0)), NEON.dark2, Enum.Material.Slate, 0, true)
	for s = 1, 4 do
		local off, size
		if s == 1 then off = Vector3.new(0, 0, -BASE_D / 2); size = Vector3.new(BASE_W, 1.2, 2)
		elseif s == 2 then off = Vector3.new(0, 0, BASE_D / 2); size = Vector3.new(BASE_W, 1.2, 2)
		elseif s == 3 then off = Vector3.new(-BASE_W / 2, 0, 0); size = Vector3.new(2, 1.2, BASE_D)
		else off = Vector3.new(BASE_W / 2, 0, 0); size = Vector3.new(2, 1.2, BASE_D) end
		makePart(plot, "Edge" .. s, size, CFrame.new(center + off + Vector3.new(0, 3.4, 0)), themeColor, Enum.Material.Neon, 0.15, false)
	end

	-- 3D 금고 문
	local door = makePart(plot, "VaultDoor", Vector3.new(34, 30, 3), CFrame.new(center + toCenter * (BASE_D / 2 - 1) + Vector3.new(0, 17, 0)), Color3.fromRGB(28, 34, 58), Enum.Material.Metal, 0, false)
	door.CFrame = CFrame.lookAt(door.Position, door.Position + toCenter)
	local dial = makeDisc(plot, "VaultDial", 22, 2, door.Position + toCenter * 2 + Vector3.new(0, 0, 0), themeColor, Enum.Material.Neon, 0.2)
	dial.CFrame = CFrame.lookAt(door.Position + toCenter * 2, door.Position + toCenter * 3)

	-- 전시 플랫폼 + 전시대 8칸
	makePart(plot, "VaultFloor", Vector3.new(BASE_W - 16, 1.6, BASE_D - 30), CFrame.new(center + Vector3.new(0, 3.6, 0)), Color3.fromRGB(26, 30, 52), Enum.Material.Marble, 0, true)
	local pedestals = folder("Pedestals", plot)
	local slot = 0
	for _, pz in ipairs(PEDESTAL_ZS) do
		for _, px in ipairs(PEDESTAL_XS) do
			slot = slot + 1
			local ppos = center + Vector3.new(px, 4.8, pz)
			local ped = makeDisc(pedestals, "Slot" .. slot, 15, 1.4, ppos, themeColor, Enum.Material.Neon, 0.25)
			ped:SetAttribute("Slot", slot)
			local glow = makeDisc(pedestals, "SlotGlow" .. slot, 11, 0.6, ppos + Vector3.new(0, 1.2, 0), NEON.white, Enum.Material.Neon, 0.6)
			glow.CanCollide = false
			local prompt = makePrompt(ped, "훔치기", "전시품", 0.35, 16)
			prompt.Name = "StealPrompt"
			prompt.Enabled = false
		end
	end

	local displays = folder("Displays", plot)

	-- 레이저 방어막 돔
	local shield = Instance.new("Model")
	shield.Name = "Shield"
	shield.Parent = plot
	local wallColor = Color3.fromRGB(120, 230, 255)
	local dome = makePart(shield, "ShieldDome", Vector3.new(BASE_W + 26, BASE_D + 26, BASE_D + 26), CFrame.new(center + Vector3.new(0, 16, 0)), wallColor, Enum.Material.ForceField, 0.55, false)
	dome.Shape = Enum.PartType.Ball
	dome.CanCollide = false
	-- 기존 02 스크립트 호환용 4면 벽
	makePart(shield, "ShieldWall1", Vector3.new(BASE_W, 26, 1), CFrame.new(center + Vector3.new(0, 15, -BASE_D / 2 - 6)), wallColor, Enum.Material.Neon, 0.7, false)
	makePart(shield, "ShieldWall2", Vector3.new(BASE_W, 26, 1), CFrame.new(center + Vector3.new(0, 15, BASE_D / 2 + 6)), wallColor, Enum.Material.Neon, 0.7, false)
	makePart(shield, "ShieldWall3", Vector3.new(1, 26, BASE_D), CFrame.new(center + Vector3.new(-BASE_W / 2 - 6, 15, 0)), wallColor, Enum.Material.Neon, 0.7, false)
	makePart(shield, "ShieldWall4", Vector3.new(1, 26, BASE_D), CFrame.new(center + Vector3.new(BASE_W / 2 + 6, 15, 0)), wallColor, Enum.Material.Neon, 0.7, false)
	for c = 1, 4 do
		local cx = (c == 1 or c == 3) and -BASE_W / 2 or BASE_W / 2
		local cz = (c <= 2) and -BASE_D / 2 or BASE_D / 2
		makePart(shield, "ShieldPillar" .. c, Vector3.new(3, 30, 3), CFrame.new(center + Vector3.new(cx, 16, cz)), themeColor, Enum.Material.Neon, 0.1, false)
	end
	shield:SetAttribute("Active", true)

	-- 상태 표시
	local anchor = makePart(plot, "StatusAnchor", Vector3.new(2, 2, 2), CFrame.new(center + Vector3.new(0, 52, 0)), NEON.white, Enum.Material.SmoothPlastic, 1, false)
	anchor.CanQuery = false
	local bb = makeBillboard(anchor, anchor, UDim2.fromOffset(320, 80), "기지 " .. index .. " · 빈 기지", themeColor, 0)
	bb.Name = "PlotStatusGui"

	-- 기지 입장 패드 / 수금 패드
	local enterPad = makePart(plot, "EnterPad", Vector3.new(20, 1.6, 20), CFrame.new(center + toCenter * 40 + Vector3.new(0, 3.6, 0)), NEON.violet, Enum.Material.Neon, 0.15, false)
	makePrompt(enterPad, "기지 입장", "내 금고로 이동", 0.15, 16)
	local collectPos = center + toCenter * 40 + right * 34
	local collectPad = makePart(plot, "CollectPad", Vector3.new(18, 2, 18), CFrame.new(collectPos + Vector3.new(0, 3.6, 0)), NEON.gold, Enum.Material.Neon, 0.1, false)
	makePrompt(collectPad, "수금", "대기 수익 회수", 0.15, 16)
	local collectBb = makeBillboard(collectPad, collectPad, UDim2.fromOffset(180, 50), "수금", NEON.gold, 8)
	collectBb.Name = "CollectGui"

	-- 기지 표지
	local signPart = makePart(plot, "VaultSign", Vector3.new(34, 14, 2), CFrame.new(center + (-toCenter) * (BASE_D / 2 + 2) + Vector3.new(0, 20, 0)), NEON.dark, Enum.Material.Metal, 0, false)
	makeBillboard(plot, signPart, UDim2.fromOffset(320, 80), "VAULT " .. index, themeColor, 0)

	plot.Parent = plotsFolder
	return plot
end

for i = 1, 4 do
	buildPlot(i)
end

-- 중앙 스폰 (아레나 남쪽)
local existingSpawn = Workspace:FindFirstChildOfClass("SpawnLocation")
if existingSpawn == nil then
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "NeonVaultSpawn"
	spawn.Size = Vector3.new(24, 2, 24)
	spawn.CFrame = CFrame.new(0, 3, 60)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = NEON.cyan
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.2
	spawn.Parent = world
end

-- 맵 좌표 정보 (03 HUD 미니맵이 읽습니다)
local mapInfo = Instance.new("Folder")
mapInfo.Name = "MapInfo"
mapInfo.Parent = world
local function numValue(parent, name, value)
	local v = Instance.new("NumberValue")
	v.Name = name
	v.Value = value
	v.Parent = parent
end
numValue(mapInfo, "WorldHalf", 440)
numValue(mapInfo, "ArenaRadius", ARENA_R)
local regionsFolderInfo = folder("RegionPoints", mapInfo)
for key, pos in pairs(REGION_CENTERS) do
	local part = makePart(regionsFolderInfo, key, Vector3.new(2, 2, 2), CFrame.new(pos + Vector3.new(0, 4, 0)), NEON.white, Enum.Material.SmoothPlastic, 1, false)
	part.CanQuery = false
	part.CanCollide = false
end

world.Parent = Workspace

-- ==============================================================
-- 8. 테마 3D 모델 템플릿 (ServerStorage)
-- ==============================================================
local templatesFolder = ServerStorage:FindFirstChild("NeonVaultTemplates")
if templatesFolder == nil then
	templatesFolder = Instance.new("Folder")
	templatesFolder.Name = "NeonVaultTemplates"
	templatesFolder.Parent = ServerStorage
end

local function newTemplate(name, color)
	local model = Instance.new("Model")
	model.Name = name
	local primary = makePart(model, "Core", Vector3.new(2, 2, 2), CFrame.new(0, 0, 0), color, Enum.Material.Neon, 0.05, false)
	primary.Shape = Enum.PartType.Ball
	model.PrimaryPart = primary
	return model, primary
end

-- 💎 보석
do
	local model, corePart = newTemplate("Template_Gem", NEON.cyan)
	corePart.Size = Vector3.new(2.4, 3.4, 2.4)
	for i = 1, 4 do
		local a = math.rad(90 * (i - 1))
		local shard = makePart(model, "Shard" .. i, Vector3.new(0.5, 2.2, 0.5), CFrame.new(math.sin(a) * 1.6, -0.2, math.cos(a) * 1.6), NEON.white, Enum.Material.Neon, 0.25, false)
		shard.CFrame = CFrame.new(math.sin(a) * 1.6, -0.2, math.cos(a) * 1.6) * CFrame.Angles(math.rad(18), a, math.rad(12))
	end
	local ring = makeDisc(model, "Ring", 5.4, 0.15, Vector3.new(0, -1.5, 0), NEON.cyan, Enum.Material.Neon, 0.45)
	ring.CanCollide = false
	model.Parent = templatesFolder
end

-- 🦖 공룡알
do
	local model, corePart = newTemplate("Template_Egg", Color3.fromRGB(214, 236, 190))
	corePart.Size = Vector3.new(3.2, 4.2, 3.2)
	corePart.Material = Enum.Material.SmoothPlastic
	corePart.Transparency = 0
	for i = 1, 5 do
		local a = math.rad(72 * i)
		local spot = makePart(model, "Spot" .. i, Vector3.new(0.9, 0.9, 0.9), CFrame.new(math.sin(a) * 1.5, -0.4 + i * 0.35, math.cos(a) * 1.5), Color3.fromRGB(110, 168, 92), Enum.Material.SmoothPlastic, 0, false)
		spot.Shape = Enum.PartType.Ball
	end
	local nest = makeDisc(model, "Nest", 6, 0.5, Vector3.new(0, -2.2, 0), Color3.fromRGB(120, 96, 62), Enum.Material.Grass, 0)
	nest.CanCollide = false
	model.Parent = templatesFolder
end

-- 🐉 전설 몬스터
do
	local model, corePart = newTemplate("Template_Monster", Color3.fromRGB(196, 84, 255))
	corePart.Size = Vector3.new(4.2, 4.4, 4.2)
	corePart.Transparency = 0.05
	local head = makePart(model, "Head", Vector3.new(2.8, 2.6, 2.8), CFrame.new(0, 2.8, 0.4), Color3.fromRGB(226, 132, 255), Enum.Material.Neon, 0.05, false)
	head.Shape = Enum.PartType.Ball
	for i = 1, 2 do
		local sx = (i == 1) and -0.9 or 0.9
		local horn = makePart(model, "Horn" .. i, Vector3.new(0.4, 1.6, 0.4), CFrame.new(sx, 4.1, 0.3), NEON.white, Enum.Material.Neon, 0, false)
		horn.CFrame = CFrame.new(sx, 4.1, 0.3) * CFrame.Angles(0, 0, math.rad(sx * 20))
		local eye = makePart(model, "Eye" .. i, Vector3.new(0.5, 0.5, 0.5), CFrame.new(sx * 0.7, 2.9, 1.6), NEON.gold, Enum.Material.Neon, 0, false)
		eye.Shape = Enum.PartType.Ball
		local wing = makePart(model, "Wing" .. i, Vector3.new(0.3, 2.6, 3.4), CFrame.new(sx * 2.3, 0.6, -0.2), Color3.fromRGB(140, 50, 190), Enum.Material.Neon, 0.35, false)
		wing.CFrame = CFrame.new(sx * 2.3, 0.6, -0.2) * CFrame.Angles(0, math.rad(sx * 25), math.rad(sx * 15))
	end
	local tail = makePart(model, "Tail", Vector3.new(0.6, 0.6, 3.6), CFrame.new(0, -1.4, -2.2), Color3.fromRGB(160, 66, 220), Enum.Material.Neon, 0.1, false)
	tail.CFrame = CFrame.new(0, -1.4, -2.2) * CFrame.Angles(math.rad(-25), 0, 0)
	model.Parent = templatesFolder
end

-- 🛸 사이버 드론
do
	local model, corePart = newTemplate("Template_Drone", Color3.fromRGB(150, 170, 255))
	corePart.Size = Vector3.new(2.4, 2.4, 2.4)
	for i = 1, 4 do
		local a = math.rad(90 * (i - 1) + 45)
		local arm = makePart(model, "Arm" .. i, Vector3.new(3.2, 0.35, 0.55), CFrame.new(math.sin(a) * 2.1, 0.2, math.cos(a) * 2.1), NEON.steel, Enum.Material.Metal, 0, false)
		arm.CFrame = CFrame.new(math.sin(a) * 2.1, 0.2, math.cos(a) * 2.1) * CFrame.Angles(0, a, 0)
		local rotor = makeDisc(model, "Rotor" .. i, 2.6, 0.18, Vector3.new(math.sin(a) * 3.6, 0.45, math.cos(a) * 3.6), NEON.cyan, Enum.Material.Neon, 0.35)
		rotor.CanCollide = false
	end
	local light = makePart(model, "CoreLight", Vector3.new(1, 1, 1), CFrame.new(0, 0, 0), NEON.magenta, Enum.Material.Neon, 0, false)
	light.Shape = Enum.PartType.Ball
	model.Parent = templatesFolder
end

-- ==============================================================
-- 9. 조명 연출
-- ==============================================================
Lighting.ClockTime = 0
Lighting.Brightness = 1.6
Lighting.Ambient = Color3.fromRGB(34, 26, 64)
Lighting.OutdoorAmbient = Color3.fromRGB(22, 18, 46)
Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.5
Lighting.GlobalShadows = true

local function ensureEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing ~= nil then
		return existing
	end
	local effect = Instance.new(className)
	effect.Name = name
	if className == "BloomEffect" then
		effect.Intensity = 1.4
		effect.Size = 44
		effect.Threshold = 0.85
	elseif className == "ColorCorrectionEffect" then
		effect.Brightness = 0.02
		effect.Contrast = 0.16
		effect.Saturation = 0.22
		effect.TintColor = Color3.fromRGB(226, 238, 255)
	elseif className == "Atmosphere" then
		effect.Density = 0.32
		effect.Offset = 0.15
		effect.Color = Color3.fromRGB(120, 140, 220)
		effect.Decay = Color3.fromRGB(60, 40, 110)
		effect.Glare = 0.15
		effect.Haze = 1.2
	end
	effect.Parent = Lighting
	return effect
end

ensureEffect("BloomEffect", "NV_Bloom")
ensureEffect("ColorCorrectionEffect", "NV_ColorCorrection")
ensureEffect("Atmosphere", "NV_Atmosphere")

print("[NeonVault] 전략 맵 생성 완료: 900×900 오픈 월드 · 기지 4 · 미드/탑/봇 레인 · 테마 구역 4 · 은신 수풀 18 · 황금 코어 제단")
print("[NeonVault] 다음: README 5장 순서대로 스크립트 01 → 02 → 03 을 붙여넣으세요.")
