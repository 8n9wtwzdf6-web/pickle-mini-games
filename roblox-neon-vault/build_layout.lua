--[[
  build_layout.lua  ·  네온 볼트 약탈자 (Neon Vault Heist) 3D 맵 자동 생성기
  --------------------------------------------------------------------------------
  사용법 (Studio 편집 모드에서 한 번만 실행):
    1) Roblox Studio 상단 메뉴 View > Command Bar 를 켭니다.
    2) 이 파일 내용을 전부 복사해 Command Bar 입력창에 붙여넣고 Enter.
       (Command Bar 붙여넣기가 안 되는 버전이면: Explorer > ServerScriptService 에
        Script 를 하나 만들고 내용을 붙여넣은 뒤, 스크립트 편집기 위쪽의
        'Run Script' 를 누르면 됩니다. 실행 후 그 Script 는 지워도 됩니다.)
    3) Explorer > Workspace 아래에 'NeonVaultWorld' 모델이,
       ServerStorage 아래에 'NeonVaultTemplates' 폴더가 생깁니다.

  만들어지는 것
    - 바닥 네온 그라운드 + 4개 플레이어 기지(기지 1~4)
        · 금고 플랫폼, 전시대 8칸(ProximityPrompt 포함)
        · 레이저 방어막 벽 4장(투명 네온) + 상태 표시 빌보드
        · '기지 입장' 패드, '수금' 패드
    - 중앙 네온 뽑기 타워 + 테마별 뽑기 스테이션 4개
        (💎보석 / 🦖공룡알 / 🐉전설 몬스터 / 🛸사이버 드론)
    - ServerStorage > NeonVaultTemplates : 테마 대표 3D 모델 4종
        (게임 중 02_VaultStealCore 가 복제해서 전시대에 올립니다)
    - 조명/블룸/대기 연출

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
}

local PLOT_THEME_COLORS = {
	NEON.cyan,
	NEON.magenta,
	NEON.lime,
	NEON.violet,
}

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
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 260
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

local world = Instance.new("Model")
world.Name = "NeonVaultWorld"

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = world

local propsFolder = Instance.new("Folder")
propsFolder.Name = "Props"
propsFolder.Parent = world

-- ==============================================================
-- 1. 바닥 / 네온 길 / 외곽
-- ==============================================================
makePart(world, "GroundFloor", Vector3.new(760, 2, 760), CFrame.new(0, -1, 0), Color3.fromRGB(9, 10, 18), Enum.Material.Slate, 0, true)
makePart(world, "GroundGlowRing", Vector3.new(520, 0.4, 520), CFrame.new(0, 0.2, 0), Color3.fromRGB(16, 22, 44), Enum.Material.SmoothPlastic, 0.2, false)

for i = 1, 4 do
	local angle = math.rad(90 * (i - 1))
	local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local mid = dir * 70
	local strip = makePart(propsFolder, "Path" .. i, Vector3.new(10, 0.3, 110), CFrame.new(mid.X, 0.35, mid.Z), PLOT_THEME_COLORS[i], Enum.Material.Neon, 0.35, false)
	strip.CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.35, mid.Z), Vector3.new(0, 0.35, 0))
end

-- 외곽 네온 펜스
for i = 1, 4 do
	local angle = math.rad(90 * (i - 1))
	local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local pos = dir * 355
	local fence = makePart(propsFolder, "Border" .. i, Vector3.new(720, 16, 2), CFrame.new(pos.X, 8, pos.Z), NEON.violet, Enum.Material.Neon, 0.82, false)
	fence.CFrame = CFrame.lookAt(Vector3.new(pos.X, 8, pos.Z), Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.rad(90), 0)
end

-- ==============================================================
-- 2. 플레이어 기지 4개
-- ==============================================================
local PLOT_RADIUS = 122
local PEDESTAL_XS = { -22, -7.4, 7.4, 22 }
local PEDESTAL_ZS = { -9, 11 }

local function buildPlot(index)
	local angle = math.rad(90 * (index - 1))
	local center = Vector3.new(math.sin(angle), 0, math.cos(angle)) * PLOT_RADIUS
	local toCenter = (Vector3.new(0, 0, 0) - center)
	toCenter = Vector3.new(toCenter.X, 0, toCenter.Z).Unit
	local right = Vector3.new(-toCenter.Z, 0, toCenter.X)
	local themeColor = PLOT_THEME_COLORS[index]

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("BasePosition", center)

	-- 기지 바닥
	makePart(plot, "Base", Vector3.new(78, 2, 78), CFrame.new(center + Vector3.new(0, 1, 0)), NEON.dark2, Enum.Material.Slate, 0, true)
	-- 네온 테두리 4줄
	for s = 1, 4 do
		local off, size
		if s == 1 then off = Vector3.new(0, 0, -39); size = Vector3.new(78, 0.6, 1.2)
		elseif s == 2 then off = Vector3.new(0, 0, 39); size = Vector3.new(78, 0.6, 1.2)
		elseif s == 3 then off = Vector3.new(-39, 0, 0); size = Vector3.new(1.2, 0.6, 78)
		else off = Vector3.new(39, 0, 0); size = Vector3.new(1.2, 0.6, 78) end
		makePart(plot, "Edge" .. s, size, CFrame.new(center + off + Vector3.new(0, 2.2, 0)), themeColor, Enum.Material.Neon, 0.15, false)
	end

	-- 금고 전시 플랫폼
	makePart(plot, "VaultFloor", Vector3.new(66, 1.4, 36), CFrame.new(center + Vector3.new(0, 2.6, 0)), Color3.fromRGB(26, 30, 52), Enum.Material.Marble, 0, true)
	makePart(plot, "VaultStripe", Vector3.new(66, 0.3, 1), CFrame.new(center + Vector3.new(0, 3.4, -18)), themeColor, Enum.Material.Neon, 0.2, false)
	makePart(plot, "VaultStripe2", Vector3.new(66, 0.3, 1), CFrame.new(center + Vector3.new(0, 3.4, 18)), themeColor, Enum.Material.Neon, 0.2, false)

	-- 전시대 8칸
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = plot

	local slot = 0
	for _, pz in ipairs(PEDESTAL_ZS) do
		for _, px in ipairs(PEDESTAL_XS) do
			slot = slot + 1
			local ppos = center + Vector3.new(px, 3.6, pz)
			local ped = makeDisc(pedestals, "Slot" .. slot, 5.6, 0.7, ppos, themeColor, Enum.Material.Neon, 0.25)
			ped:SetAttribute("Slot", slot)
			local glow = makeDisc(pedestals, "SlotGlow" .. slot, 4.2, 0.3, ppos + Vector3.new(0, 0.45, 0), NEON.white, Enum.Material.Neon, 0.6)
			glow.CanCollide = false
			local prompt = makePrompt(ped, "훔치기", "전시품", 0.35, 11)
			prompt.Name = "StealPrompt"
			prompt.Enabled = false
		end
	end

	-- 전시품 표시용 폴더 (02 스크립트가 여기에 모델을 넣습니다)
	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = plot

	-- 레이저 방어막
	local shield = Instance.new("Model")
	shield.Name = "Shield"
	shield.Parent = plot
	local wallColor = Color3.fromRGB(120, 230, 255)
	makePart(shield, "ShieldWall1", Vector3.new(68, 24, 0.6), CFrame.new(center + Vector3.new(0, 15, -19)), wallColor, Enum.Material.Neon, 0.7, false)
	makePart(shield, "ShieldWall2", Vector3.new(68, 24, 0.6), CFrame.new(center + Vector3.new(0, 15, 19)), wallColor, Enum.Material.Neon, 0.7, false)
	makePart(shield, "ShieldWall3", Vector3.new(0.6, 24, 38), CFrame.new(center + Vector3.new(-33, 15, 0)), wallColor, Enum.Material.Neon, 0.7, false)
	makePart(shield, "ShieldWall4", Vector3.new(0.6, 24, 38), CFrame.new(center + Vector3.new(33, 15, 0)), wallColor, Enum.Material.Neon, 0.7, false)
	for c = 1, 4 do
		local cx = 0
		local cz = 0
		if c == 1 then cx = -33; cz = -19
		elseif c == 2 then cx = 33; cz = -19
		elseif c == 3 then cx = -33; cz = 19
		else cx = 33; cz = 19 end
		makePart(shield, "ShieldPillar" .. c, Vector3.new(1.6, 26, 1.6), CFrame.new(center + Vector3.new(cx, 15, cz)), themeColor, Enum.Material.Neon, 0.1, false)
	end
	shield:SetAttribute("Active", true)

	-- 상태 표시 빌보드
	local anchor = makePart(plot, "StatusAnchor", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 32, 0)), NEON.white, Enum.Material.SmoothPlastic, 1, false)
	anchor.CanQuery = false
	local bb = makeBillboard(anchor, anchor, UDim2.fromOffset(260, 64), "기지 " .. index .. " · 빈 기지", themeColor, 0)
	bb.Name = "PlotStatusGui"

	-- 기지 입장 패드 (보라)
	local enterPad = makePart(plot, "EnterPad", Vector3.new(10, 1, 10), CFrame.new(center + toCenter * 31 + Vector3.new(0, 2.4, 0)), NEON.violet, Enum.Material.Neon, 0.15, false)
	makePrompt(enterPad, "기지 입장", "내 금고로 이동", 0.15, 12)

	-- 수금 패드 (금색)
	local collectPos = center + toCenter * 31 + right * 22
	local collectPad = makePart(plot, "CollectPad", Vector3.new(9, 1.2, 9), CFrame.new(collectPos + Vector3.new(0, 2.4, 0)), NEON.gold, Enum.Material.Neon, 0.1, false)
	makePrompt(collectPad, "수금", "대기 수익 회수", 0.15, 12)
	local collectBb = makeBillboard(collectPad, collectPad, UDim2.fromOffset(150, 40), "수금", NEON.gold, 3)
	collectBb.Name = "CollectGui"

	-- 기지 표지
	local signPos = center + (-toCenter) * 34
	makePart(plot, "VaultSign", Vector3.new(20, 8, 0.8), CFrame.new(signPos + Vector3.new(0, 12, 0)), NEON.dark, Enum.Material.Metal, 0, false)
	local signPart = plot:FindFirstChild("VaultSign")
	local signText = makeBillboard(plot, signPart, UDim2.fromOffset(240, 60), "VAULT " .. index, themeColor, 0)
	signText.Name = "SignGui"

	plot.Parent = plotsFolder
	return plot
end

for i = 1, 4 do
	buildPlot(i)
end

-- ==============================================================
-- 3. 중앙 네온 뽑기 타워
-- ==============================================================
local tower = Instance.new("Model")
tower.Name = "GachaTower"
tower.Parent = world

makeDisc(tower, "TowerBase", 74, 2.4, Vector3.new(0, 1.2, 0), NEON.dark2, Enum.Material.Slate)
makeDisc(tower, "TowerBaseGlow", 60, 0.4, Vector3.new(0, 2.6, 0), NEON.cyan, Enum.Material.Neon, 0.2)
makeDisc(tower, "TowerBaseGlow2", 66, 0.3, Vector3.new(0, 2.5, 0), NEON.magenta, Enum.Material.Neon, 0.55)
makePart(tower, "TowerColumn", Vector3.new(12, 34, 12), CFrame.new(0, 17, 0), Color3.fromRGB(24, 28, 48), Enum.Material.Metal, 0)
makePart(tower, "TowerColumnGlow", Vector3.new(12.6, 1.2, 12.6), CFrame.new(0, 30, 0), NEON.cyan, Enum.Material.Neon, 0.1, false)
local core = makePart(tower, "TowerCore", Vector3.new(9, 9, 9), CFrame.new(0, 38, 0), NEON.white, Enum.Material.Neon, 0.1, false)
core.Shape = Enum.PartType.Ball
local coreGlow = makePart(tower, "TowerCoreGlow", Vector3.new(14, 14, 14), CFrame.new(0, 38, 0), NEON.cyan, Enum.Material.Neon, 0.8, false)
coreGlow.Shape = Enum.PartType.Ball
local towerSign = makeBillboard(core, core, UDim2.fromOffset(320, 90), "NEON VAULT · 뽑기 타워", NEON.cyan, 6)
towerSign.Name = "TowerGui"

local THEMES = {
	{ id = "gem", label = "💎 보석 · 유물", color = NEON.cyan, dir = Vector3.new(0, 0, -1) },
	{ id = "egg", label = "🦖 공룡 알", color = NEON.lime, dir = Vector3.new(1, 0, 0) },
	{ id = "monster", label = "🐉 전설 몬스터", color = NEON.magenta, dir = Vector3.new(0, 0, 1) },
	{ id = "drone", label = "🛸 사이버 드론", color = NEON.violet, dir = Vector3.new(-1, 0, 0) },
}

for i, theme in ipairs(THEMES) do
	local pos = theme.dir * 34 + Vector3.new(0, 4, 0)
	local station = makePart(tower, "Gacha_" .. theme.id, Vector3.new(12, 8, 12), CFrame.new(pos), theme.color, Enum.Material.Neon, 0.25, true)
	station:SetAttribute("Theme", theme.id)
	makePart(tower, "GachaTop_" .. theme.id, Vector3.new(6, 3, 6), CFrame.new(pos + Vector3.new(0, 5.4, 0)), NEON.white, Enum.Material.Neon, 0.05, false)
	makePrompt(station, "뽑기", theme.label, 0.2, 14)
	local bb = makeBillboard(station, station, UDim2.fromOffset(240, 70), theme.label, theme.color, 7)
	bb.Name = "GachaGui"
end

-- 중앙 스폰
local existingSpawn = Workspace:FindFirstChildOfClass("SpawnLocation")
if existingSpawn == nil then
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "NeonVaultSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 3.2, 62)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = NEON.cyan
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.2
	spawn.Parent = world
end

world.Parent = Workspace

-- ==============================================================
-- 4. 테마 3D 모델 템플릿 (ServerStorage)
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

-- 💎 보석 : 뾰족한 결정 + 위성 조각
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

-- 🦖 공룡 알 : 둥근 알 + 무늬 + 둥지
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

-- 🐉 전설 몬스터 : 몸통 + 머리 + 뿔 + 날개 + 눈
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

-- 🛸 사이버 드론 : 중심 구 + 4개 암 + 로터 + 코어 라이트
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
-- 5. 조명 연출
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

print("[NeonVault] 맵 생성 완료: Workspace.NeonVaultWorld (기지 4개 + 뽑기 타워), ServerStorage.NeonVaultTemplates (템플릿 4종)")
print("[NeonVault] 다음: README 5장 순서대로 스크립트 01 → 02 → 03 을 붙여넣으세요.")
