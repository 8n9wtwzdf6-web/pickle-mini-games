--[[ ============================================================
  01_WorldAndUnits.server.lua  —  v3.0
  🌌 우주 공간 · 5개 팀 부유 아레나 · 자유 전략 건설 그리드 · 5종족 넥서스/유닛
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService  (일반 Script)
  먼저 필요한 것 : ReplicatedStorage 의 ModuleScript "TDShared"
  하는 일
    1) 우주 공간(별·성운·조명) + 정중앙 최종 보스 제단
    2) 정오각형으로 떠 있는 5개 팀 아레나 (휴먼·메카·아케인·바이오·드론)
       · 아레나마다 8×8 자유 건설 그리드 (기본 사용 6×6)
       · 종족별 고유 넥서스 + 스폰 게이트 + 팀 배너
       · 3대 맵 테마(우주 요새 / 판타지 성채 / 사이버펑크) 장식 3벌
    3) 터렛 모델 10종 (5종족 × 2모드) + 융합 유닛 5종 → ReplicatedStorage.TD_Units
    4) 적 모델 8종 + 최종 보스 → ReplicatedStorage.TD_Enemies
  ※ 좌표·밸런스는 ReplicatedStorage.TDShared 한 곳에서만 관리합니다.
  ============================================================ ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local U = Shared.UNIVERSE
local THEMES = Shared.THEMES

Players.CharacterAutoLoads = false

-- ---------------------------------------------------------------
-- 공통 헬퍼
-- ---------------------------------------------------------------
local function shade(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function makePart(parent, name, size, cf, color, material, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf or CFrame.new()
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = opts.query and true or false
	p.CastShadow = opts.shadow and true or false
	p.Material = material or Enum.Material.Metal
	p.Color = color or Color3.fromRGB(90, 105, 120)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then p.Shape = opts.shape end
	if opts.transparency then p.Transparency = opts.transparency end
	p.Parent = parent
	return p
end

local function pivotOf(parent)
	if parent and parent:IsA("Model") and parent.PrimaryPart then
		return parent.PrimaryPart.CFrame
	end
	return CFrame.new()
end

local function neon(parent, name, size, cf, color, opts)
	if typeof(opts) == "EnumItem" then opts = { shape = opts } end
	return makePart(parent, name, size, pivotOf(parent) * cf, color, Enum.Material.Neon, opts)
end

local function newModel(folder, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = folder
	return m
end

local function rootPart(m, cf)
	local r = makePart(m, "Root", Vector3.new(1, 1, 1), cf or CFrame.new(), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, { transparency = 1 })
	m.PrimaryPart = r
	return r
end

local function place(m, name, size, relCF, color, material, opts)
	local p = makePart(m, name, size, m.PrimaryPart.CFrame * relCF, color, material, opts)
	return p
end

local function rel(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function disc(parent, name, radius, thickness, cf, color, material, opts)
	-- 실린더를 눕혀서 원판으로 사용
	opts = opts or {}
	local size = Vector3.new(thickness, radius * 2, radius * 2)
	local p = makePart(parent, name, size, pivotOf(parent) * cf * CFrame.Angles(0, 0, math.rad(90)), color, material, opts)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ---------------------------------------------------------------
-- 0. 테마 등록기
--   role : plate / plate2 / trim / glow / decor / cellA / cellB / cellLock
-- ---------------------------------------------------------------
local themeParts = {}
local themeCells = {}
local decorFolders = {}

local function reg(part, role)
	table.insert(themeParts, { part = part, role = role })
	return part
end

local currentTheme = "sf"

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

local function applyTheme(key)
	local t = THEMES[key] or THEMES.sf
	currentTheme = t.key
	for _, rec in ipairs(themeParts) do
		local p = rec.part
		if p and p.Parent then
			if rec.role == "plate" then
				p.Color = t.plate
			elseif rec.role == "plate2" then
				p.Color = t.plate2
			elseif rec.role == "trim" then
				p.Color = t.trim
			elseif rec.role == "glow" then
				p.Color = t.glow
			elseif rec.role == "decor" then
				p.Color = t.decor
			end
		end
	end
	for _, rec in ipairs(themeCells) do
		local p = rec.part
		if p and p.Parent then
			local locked = p:GetAttribute("Free") ~= true
			if locked then
				p.Color = shade(t.plate2, 1.25)
			else
				p.Color = rec.parity and shade(t.plate, 1.22) or shade(t.plate, 0.95)
			end
		end
	end
	for themeKey, list in pairs(decorFolders) do
		for _, rec in ipairs(list) do
			if themeKey == t.key then
				rec.folder.Parent = rec.home
			else
				rec.folder.Parent = nil
			end
		end
	end

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

	Workspace:SetAttribute("TDTheme", t.key)
end

-- ---------------------------------------------------------------
-- 1. 기존 월드 정리
-- ---------------------------------------------------------------
local old = Workspace:FindFirstChild("TDWorld")
if old then old:Destroy() end
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then baseplate:Destroy() end
local spawnLoc = Workspace:FindFirstChildOfClass("SpawnLocation")
if spawnLoc then spawnLoc:Destroy() end

local world = Instance.new("Folder")
world.Name = "TDWorld"
world.Parent = Workspace
world:SetAttribute("Version", Shared.VERSION)

local arenasFolder = Instance.new("Folder")
arenasFolder.Name = "Arenas"
arenasFolder.Parent = world

local centerFolder = Instance.new("Folder")
centerFolder.Name = "Center"
centerFolder.Parent = world

local spaceFolder = Instance.new("Folder")
spaceFolder.Name = "Space"
spaceFolder.Parent = world
applyTheme("sf")

-- ---------------------------------------------------------------
-- 2. 우주 공간 (별 · 성운)
-- ---------------------------------------------------------------
local starColors = {
	Color3.fromRGB(210, 235, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(180, 210, 255),
	Color3.fromRGB(255, 225, 190),
	Color3.fromRGB(200, 170, 255),
}
for i = 1, 190 do
	local a = math.rad(math.random() * 360)
	local r = math.random(520, 1000)
	local y = math.random(-160, 320)
	local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	local s = math.random(4, 15) / 10
	neon(spaceFolder, "Star" .. i, Vector3.new(s, s, s), CFrame.new(pos), starColors[math.random(1, #starColors)], { shape = Enum.PartType.Ball })
end
for i = 1, 3 do
	local a = math.rad(i * 120 + 30)
	local pos = Vector3.new(math.cos(a) * 760, 120 + i * 40, math.sin(a) * 760)
	local neb = neon(spaceFolder, "Nebula" .. i, Vector3.new(1, 1, 1), CFrame.new(pos), (i == 1 and Color3.fromRGB(90, 60, 190)) or (i == 2 and Color3.fromRGB(30, 110, 160) or Color3.fromRGB(150, 50, 120)), { shape = Enum.PartType.Ball, transparency = 0.93 })
	neb.Size = Vector3.new(420, 220, 420)
end

-- ---------------------------------------------------------------
-- 3. 아레나 1개 만들기
-- ---------------------------------------------------------------
local function buildBanner(arena, faction, slot)
	local board = makePart(arena, "TeamBanner", Vector3.new(30, 7, 0.6), Shared.arenaCFrame(slot) * rel(0, 13, -40), shade(faction.hull, 1.4), Enum.Material.Metal)
	reg(board, "decor")
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 14, 20)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.Position = UDim2.fromScale(0, 0.04)
	title.BackgroundTransparency = 1
	title.Text = faction.icon .. " TEAM " .. slot .. " · " .. faction.name
	title.TextColor3 = faction.color
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = bg
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(1, 0.3)
	sub.Position = UDim2.fromScale(0, 0.66)
	sub.BackgroundTransparency = 1
	sub.Text = faction.tag .. "  ·  AI SLOT"
	sub.TextColor3 = Color3.fromRGB(180, 200, 215)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.Parent = bg
	board:SetAttribute("TeamSlot", slot)
	return board
end

local function buildNexus(arena, faction, slot)
	local cf = Shared.arenaCFrame(slot)
	local nexus = newModel(arena, "Nexus")
	rootPart(nexus, cf * rel(0, 0.2, 31))
	local base = place(nexus, "Base", Vector3.new(17, 1.2, 17), rel(0, 0.6, 0), shade(faction.hull, 1.1), Enum.Material.Metal, { shadow = true })
	reg(base, "decor")
	place(nexus, "Base2", Vector3.new(12, 1.0, 12), rel(0, 1.5, 0), shade(faction.hull, 1.4), Enum.Material.Metal)
	local ring = disc(nexus, "BaseRing", 8.6, 0.3, rel(0, 1.8, 0), faction.accent, Enum.Material.Neon)
	reg(ring, "glow")

	local coreColor = faction.accent
	local style = faction.nexus

	if style == "command" then
		-- 휴먼 : 지휘 본부 · 사각 타워 + 청색 결정
		place(nexus, "Tower", Vector3.new(7.2, 7.5, 7.2), rel(0, 5.6, 0), shade(faction.hull, 1.2), Enum.Material.Metal, { shadow = true })
		for i = 1, 4 do
			local a = math.rad((i - 1) * 90 + 45)
			place(nexus, "Pylon" .. i, Vector3.new(1.1, 9, 1.1), rel(math.cos(a) * 5.6, 5.6, math.sin(a) * 5.6), shade(faction.hull, 1.5), Enum.Material.Metal)
			neon(nexus, "PylonLight" .. i, Vector3.new(1.2, 0.5, 1.2), rel(math.cos(a) * 5.6, 10.3, math.sin(a) * 5.6), coreColor)
		end
		neon(nexus, "Core", Vector3.new(3.0, 4.6, 3.0), rel(0, 7.6, 0), coreColor, { shape = Enum.PartType.Ball, transparency = 0.1 })
		neon(nexus, "CoreHalo", Vector3.new(5.6, 5.6, 5.6), rel(0, 7.6, 0), shade(coreColor, 1.1), { shape = Enum.PartType.Ball, transparency = 0.82 })
	elseif style == "bunker" then
		-- 메카 : 중장갑 벙커 · 8각 방패 + 주황 노심
		place(nexus, "Hull", Vector3.new(11, 5.5, 11), rel(0, 4.6, 0), shade(faction.hull, 1.35), Enum.Material.Metal, { shadow = true })
		for i = 1, 4 do
			local a = math.rad((i - 1) * 90)
			local px, pz = math.cos(a) * 4.4, math.sin(a) * 4.4
			local barrel = place(nexus, "Cannon" .. i, Vector3.new(1.5, 1.5, 6.2), rel(px, 6.2, pz), shade(faction.hull, 0.8), Enum.Material.Metal)
			barrel.CFrame = nexus.PrimaryPart.CFrame * rel(px, 6.2, pz, 0, i * 90, 0)
			neon(nexus, "CannonTip" .. i, Vector3.new(1.0, 1.0, 0.5), rel(px, 6.2, pz, 0, i * 90, 0) * CFrame.new(0, 0, -3.2), coreColor)
		end
		neon(nexus, "Core", Vector3.new(4.2, 4.2, 4.2), rel(0, 6.8, 0), coreColor, { shape = Enum.PartType.Ball, transparency = 0.05 })
		neon(nexus, "CoreHalo", Vector3.new(7, 7, 7), rel(0, 6.8, 0), shade(coreColor, 1.1), { shape = Enum.PartType.Ball, transparency = 0.86 })
	elseif style == "crystal" then
		-- 아케인 : 부유 수정 첨탑 + 마법 링
		place(nexus, "Pedestal", Vector3.new(6, 3, 6), rel(0, 3.2, 0), shade(faction.hull, 1.2), Enum.Material.Metal)
		local crystal = neon(nexus, "Core", Vector3.new(4.2, 8.2, 4.2), rel(0, 9.2, 0), coreColor, { transparency = 0.05 })
		crystal.CFrame = nexus.PrimaryPart.CFrame * rel(0, 9.2, 0, 0, 45, 45)
		for i = 1, 3 do
			local r = disc(nexus, "SpellRing" .. i, 5 + i * 1.8, 0.22, rel(0, 6.5 + i * 1.4, 0), shade(coreColor, 0.9), Enum.Material.Neon)
			r:SetAttribute("Spin", (i % 2 == 0) and -0.8 or 0.6)
		end
		for i = 1, 4 do
			local a = math.rad((i - 1) * 90 + 20)
			local sp = neon(nexus, "Spire" .. i, Vector3.new(0.9, 6.5, 0.9), rel(math.cos(a) * 5, 6, math.sin(a) * 5), shade(coreColor, 0.85), { transparency = 0.15 })
			sp.CFrame = nexus.PrimaryPart.CFrame * rel(math.cos(a) * 5, 6, math.sin(a) * 5, 0, 0, math.deg(math.cos(a) * 12))
		end
	elseif style == "hive" then
		-- 바이오 : 살아있는 군체 · 구체 알집 + 촉수
		for i = 1, 5 do
			local a = math.rad((i - 1) * 72)
			neon(nexus, "Pod" .. i, Vector3.new(3.2, 3.2, 3.2), rel(math.cos(a) * 4.2, 3.4 + (i % 2), math.sin(a) * 4.2), shade(coreColor, 0.8 + 0.08 * i), { shape = Enum.PartType.Ball, transparency = 0.32 })
			place(nexus, "Tendril" .. i, Vector3.new(0.7, 4.5, 0.7), rel(math.cos(a) * 6.4, 2.2, math.sin(a) * 6.4), shade(faction.hull, 1.2), Enum.Material.SmoothPlastic)
		end
		neon(nexus, "Core", Vector3.new(5.4, 5.4, 5.4), rel(0, 6.4, 0), coreColor, { shape = Enum.PartType.Ball, transparency = 0.12 })
		neon(nexus, "CoreHalo", Vector3.new(8, 8, 8), rel(0, 6.4, 0), shade(coreColor, 1.1), { shape = Enum.PartType.Ball, transparency = 0.88 })
		place(nexus, "Crown", Vector3.new(8.6, 0.6, 8.6), rel(0, 4.4, 0), shade(faction.hull, 1.5), Enum.Material.Metal)
	else
		-- 드론 : 항공모함 · 착륙 갑판 + 회전 링 + 청록 구체
		place(nexus, "Deck", Vector3.new(12, 1.6, 12), rel(0, 3.4, 0), shade(faction.hull, 1.3), Enum.Material.Metal, { shadow = true })
		place(nexus, "Deck2", Vector3.new(8.4, 1.1, 8.4), rel(0, 4.8, 0), shade(faction.hull, 1.6), Enum.Material.Metal)
		for i = 1, 3 do
			local ring = disc(nexus, "DroneRing" .. i, 5.4 + i * 1.4, 0.18, rel(0, 5.4 + i * 0.5, 0), coreColor, Enum.Material.Neon)
			ring:SetAttribute("Spin", (i % 2 == 0) and -1.2 or 0.9)
		end
		neon(nexus, "Core", Vector3.new(3.6, 3.6, 3.6), rel(0, 7.4, 0), coreColor, { shape = Enum.PartType.Ball, transparency = 0.05 })
		for i = 1, 4 do
			local a = math.rad((i - 1) * 90 + 45)
			place(nexus, "DronePod" .. i, Vector3.new(1.2, 0.7, 2.2), rel(math.cos(a) * 4.6, 6.4, math.sin(a) * 4.6), shade(faction.hull, 0.9), Enum.Material.Metal)
		end
	end

	local core = nexus:FindFirstChild("Core") or nexus:FindFirstChild("Hull")
	local light = Instance.new("PointLight")
	light.Color = coreColor
	light.Range = 42
	light.Brightness = 2.6
	light.Parent = core

	-- 넥서스 HP (02 가 갱신)
	local hpGui = Instance.new("BillboardGui")
	hpGui.Name = "NexusHP"
	hpGui.Size = UDim2.fromScale(17, 2.4)
	hpGui.StudsOffset = Vector3.new(0, 13, 0)
	hpGui.AlwaysOnTop = true
	hpGui.Parent = core
	local hpBack = Instance.new("Frame")
	hpBack.Size = UDim2.fromScale(1, 1)
	hpBack.BackgroundColor3 = Color3.fromRGB(8, 12, 16)
	hpBack.BorderSizePixel = 0
	hpBack.Parent = hpGui
	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.Size = UDim2.fromScale(1, 0.7)
	hpFill.Position = UDim2.fromScale(0, 0.15)
	hpFill.BackgroundColor3 = Color3.fromRGB(90, 255, 170)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBack
	local hpText = Instance.new("TextLabel")
	hpText.Name = "Label"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Text = "NEXUS 30 / 30"
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextStrokeTransparency = 0.35
	hpText.TextScaled = true
	hpText.Font = Enum.Font.GothamBlack
	hpText.Parent = hpBack
	nexus:SetAttribute("MaxHp", U.CORE_MAX)
	return nexus, core
end

local function buildThemeDecor(arena, slot, themeKey)
	local cf = Shared.arenaCFrame(slot)
	local folder = Instance.new("Folder")
	folder.Name = "Decor_" .. themeKey
	folder.Parent = arena
	decorFolders[themeKey] = decorFolders[themeKey] or {}
	table.insert(decorFolders[themeKey], { folder = folder, home = arena })
	folder.Parent = nil -- applyTheme 가 켭니다
	local t = THEMES[themeKey]

	if themeKey == "sf" then
		for i = 1, 6 do
			local a = math.rad((i - 1) * 60 + 15)
			local rr = 37
			local px, pz = math.cos(a) * rr, math.sin(a) * rr
			local h = 4 + (i % 3) * 2.4
			local p = makePart(folder, "Strut" .. i, Vector3.new(1.8, h, 1.8), cf * rel(px, h / 2, pz), shade(t.plate, 1.5), Enum.Material.Metal)
			reg(p, "decor")
			neon(folder, "StrutLight" .. i, Vector3.new(2.0, 0.35, 2.0), cf * rel(px, h + 0.2, pz), t.trim)
		end
		for i = 1, 4 do
			local px = (i <= 2) and -33 or 33
			local pz = ((i % 2 == 0) and 32 or -32)
			local holo = makePart(folder, "Holo" .. i, Vector3.new(6, 3.2, 0.2), cf * rel(px, 6, pz), t.glow, Enum.Material.Neon, { transparency = 0.35 })
			holo.CFrame = cf * rel(px, 6, pz, 0, (i <= 2) and 40 or -40, 0)
		end
	elseif themeKey == "fantasy" then
		for i = 1, 6 do
			local a = math.rad((i - 1) * 60)
			local rr = 36
			local px, pz = math.cos(a) * rr, math.sin(a) * rr
			local h = 7 + (i % 2) * 3
			local col = makePart(folder, "Pillar" .. i, Vector3.new(2.6, h, 2.6), cf * rel(px, h / 2, pz), shade(t.decor, 1.15), Enum.Material.Slate)
			reg(col, "decor")
			neon(folder, "Brazier" .. i, Vector3.new(1.4, 1.4, 1.4), cf * rel(px, h + 0.8, pz), t.glow, { shape = Enum.PartType.Ball, transparency = 0.2 })
		end
		for i = 1, 4 do
			local px = (i <= 2) and -34 or 34
			local pz = ((i % 2 == 0) and 33 or -33)
			local flag = makePart(folder, "Banner" .. i, Vector3.new(4.4, 9, 0.2), cf * rel(px, 8, pz), shade(t.trim, 0.8), Enum.Material.Fabric)
			flag.CFrame = cf * rel(px, 8, pz, 0, (i <= 2) and 30 or -30, 0)
			reg(flag, "decor")
		end
	else
		for i = 1, 6 do
			local a = math.rad((i - 1) * 60 + 30)
			local rr = 37
			local px, pz = math.cos(a) * rr, math.sin(a) * rr
			local h = 9 + (i % 3) * 5
			local tower = makePart(folder, "Tower" .. i, Vector3.new(4.2, h, 4.2), cf * rel(px, h / 2, pz), shade(t.plate, 1.9), Enum.Material.Concrete)
			reg(tower, "decor")
			for k = 1, 3 do
				neon(folder, "Window" .. i .. "_" .. k, Vector3.new(2.6, 0.35, 0.2), cf * rel(px, 2 + k * (h / 4), pz + 2.15), (k % 2 == 0) and t.trim or t.glow, { transparency = 0.15 })
			end
		end
		for i = 1, 4 do
			local px = (i <= 2) and -33 or 33
			local pz = ((i % 2 == 0) and 32 or -32)
			local sign = neon(folder, "Sign" .. i, Vector3.new(7, 2.6, 0.2), cf * rel(px, 7, pz), t.trim, { transparency = 0.15 })
			sign.CFrame = cf * rel(px, 7, pz, 0, (i <= 2) and 45 or -45, 0)
		end
	end
end

local function buildArena(slot, faction)
	local cf = Shared.arenaCFrame(slot)
	local arena = newModel(arenasFolder, "Arena_" .. slot)
	arena:SetAttribute("TeamSlot", slot)
	arena:SetAttribute("Faction", faction.key)
	arena:SetAttribute("TeamName", faction.name)
	rootPart(arena, cf)
	arena.PrimaryPart.CFrame = cf

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

	for i = 1, 4 do
		local a = math.rad(45 + (i - 1) * 90)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pillar = place(arena, "CornerPillar" .. i, Vector3.new(2.2, 9, 2.2),
			rel(dir.X * (AP - 4), 4.2, dir.Z * (AP - 4)), THEMES.sf.decor, Enum.Material.Metal)
		reg(pillar, "decor")
		neon(arena, "CornerGlow" .. i, Vector3.new(2.4, 0.4, 2.4),
			rel(dir.X * (AP - 4), 8.9, dir.Z * (AP - 4)), faction.color)
	end

	-- 자유 건설 그리드 (8×8)
	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = arena
	local N = U.GRID_N
	for col = 1, N do
		for row = 1, N do
			local localPos = Shared.cellLocal(col, row, N)
			local free = Shared.isFreeCell(col, row)
			local parity = ((col + row) % 2 == 0)
			local cell = makePart(cells, "Cell_" .. col .. "_" .. row, Vector3.new(U.CELL - 0.5, 0.4, U.CELL - 0.5),
				cf * rel(localPos.X, 0.2, localPos.Z), free and shade(THEMES.sf.plate, 1.22) or shade(THEMES.sf.plate2, 1.25),
				Enum.Material.SmoothPlastic, { query = true })
			cell:SetAttribute("Col", col)
			cell:SetAttribute("Row", row)
			cell:SetAttribute("Free", free)
			cell:SetAttribute("Arena", slot)
			cell:SetAttribute("Parity", parity)
			table.insert(themeCells, { part = cell, parity = parity })
		end
	end

	-- 스폰 게이트 (바깥쪽)
	local spawnPos = U.SPAWN_LOCAL
	local dock = place(arena, "SpawnDock", Vector3.new(16, 2, 14), rel(spawnPos.X, -1.0, spawnPos.Z + 2),
		shade(THEMES.sf.plate2, 0.85), Enum.Material.Slate, { shadow = true })
	reg(dock, "plate2")
	for s = -1, 1, 2 do
		place(arena, "GatePillar" .. s, Vector3.new(1.6, 11, 1.6), rel(spawnPos.X + s * 5.4, 5.5, spawnPos.Z + 2), THEMES.sf.decor, Enum.Material.Metal)
		neon(arena, "GateGlow" .. s, Vector3.new(1.7, 0.6, 1.7), rel(spawnPos.X + s * 5.4, 11.3, spawnPos.Z + 2), faction.color)
	end
	neon(arena, "GateBar", Vector3.new(11.6, 0.6, 0.5), rel(spawnPos.X, 11.6, spawnPos.Z + 2), faction.color)
	local portal = neon(arena, "Portal", Vector3.new(7.6, 0.3, 7.6), rel(spawnPos.X, 0.4, spawnPos.Z) * CFrame.Angles(0, 0, math.rad(90)), faction.color, { shape = Enum.PartType.Cylinder, transparency = 0.35 })
	portal:SetAttribute("Spin", 0.5)
	-- 보스 경고등 (02 가 색을 바꿉니다)
	local beacon = neon(arena, "WarnBeacon", Vector3.new(3, 3, 3), rel(spawnPos.X, 13.4, spawnPos.Z + 2), shade(faction.color, 0.6), { shape = Enum.PartType.Ball, transparency = 0.85 })
	beacon:SetAttribute("Beacon", true)

	buildNexus(arena, faction, slot)
	buildBanner(arena, faction, slot)

	-- 테마 장식 3벌
	for _, key in ipairs(Shared.THEME_ORDER) do
		buildThemeDecor(arena, slot, key)
	end

	-- AI 표시등 (사람이 들어오면 02 가 끕니다)
	neon(arena, "AILight", Vector3.new(2, 2, 2), rel(0, 16.6, -40), Color3.fromRGB(255, 190, 80), { shape = Enum.PartType.Ball, transparency = 0.2 })

	return arena
end

for slot = 1, 5 do
	buildArena(slot, Shared.factionOfSlot(slot))
end

-- ---------------------------------------------------------------
-- 4. 우주 정중앙 — 최종 보스 제단
-- ---------------------------------------------------------------
do
	local cf = CFrame.new(U.BOSS_CENTER)
	local altar = newModel(centerFolder, "BossAltar")
	rootPart(altar, cf)
	local dais = disc(altar, "Dais", 34, 3, rel(0, -1.6, 0), THEMES.sf.plate2, Enum.Material.Slate, { shadow = true })
	reg(dais, "plate2")
	local dais2 = disc(altar, "DaisRing", 30, 0.4, rel(0, 0.2, 0), THEMES.sf.trim, Enum.Material.Neon)
	reg(dais2, "trim")
	local dais3 = disc(altar, "DaisCore", 18, 0.5, rel(0, 0.5, 0), Color3.fromRGB(60, 20, 30), Enum.Material.Metal)
	dais3.Transparency = 0.25
	for i = 1, 3 do
		local ring = disc(altar, "RitualRing" .. i, 12 + i * 5, 0.2, rel(0, 0.9 + i * 0.15, 0), (i == 2) and Color3.fromRGB(255, 80, 90) or Color3.fromRGB(180, 60, 200), Enum.Material.Neon, { transparency = 0.35 })
		ring:SetAttribute("Spin", (i % 2 == 0) and -0.4 or 0.3)
	end
	for i = 1, 6 do
		local a = math.rad((i - 1) * 60)
		local px, pz = math.cos(a) * 26, math.sin(a) * 26
		local spike = neon(altar, "AltarSpike" .. i, Vector3.new(1.6, 9, 1.6), rel(px, 4.5, pz), Color3.fromRGB(120, 40, 160), { transparency = 0.25 })
		spike.CFrame = cf * rel(px, 4.5, pz, 0, math.deg(a), -12)
	end
	-- 5개 아레나 → 중앙으로 흐르는 에너지 링크
	for slot = 1, 5 do
		local from = Shared.arenaCFrame(slot).Position + Shared.arenaCFrame(slot):VectorToWorldSpace(Vector3.new(0, 0.5, 30))
		local to = Vector3.new(0, 0.5, 0)
		local mid = (from + to) / 2
		local len = (to - from).Magnitude
		local beam = makePart(world, "Link_" .. slot, Vector3.new(0.5, 0.2, len), CFrame.lookAt(mid, to) * CFrame.new(0, 0, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, { transparency = 0.55 })
		beam.Name = "EnergyLink_" .. slot
		beam:SetAttribute("TeamSlot", slot)
	end
	local warning = Instance.new("PointLight")
	warning.Color = Color3.fromRGB(255, 90, 100)
	warning.Range = 120
	warning.Brightness = 0.6
	warning.Parent = dais3
	dais3.Name = "BossCore"
end

-- ---------------------------------------------------------------
-- 5. 터렛 · 융합 유닛 모델
-- ---------------------------------------------------------------
local unitFolder = ReplicatedStorage:FindFirstChild("TD_Units")
if unitFolder then unitFolder:Destroy() end
unitFolder = Instance.new("Folder")
unitFolder.Name = "TD_Units"
unitFolder.Parent = ReplicatedStorage

local STEEL = Color3.fromRGB(112, 126, 142)
local DARK = Color3.fromRGB(46, 55, 66)
local TRIMC = Color3.fromRGB(150, 168, 184)

local function unitBase(model, faction)
	local base = place(model, "Base", Vector3.new(5.2, 0.7, 5.2), rel(0, 0.35, 0), DARK, Enum.Material.Metal)
	base:SetAttribute("UnitBase", true)
	local ring = disc(model, "BaseRing", 2.55, 0.22, rel(0, 0.72, 0), faction.accent, Enum.Material.Neon)
	ring.Name = "AccentRing"
	for i = 1, 4 do
		local a = math.rad((i - 1) * 90 + 45)
		place(model, "Bolt" .. i, Vector3.new(0.35, 0.26, 0.35), rel(math.cos(a) * 2.1, 0.8, math.sin(a) * 2.1), TRIMC, Enum.Material.Metal)
	end
	place(model, "BasePlate", Vector3.new(3.4, 0.3, 3.4), rel(0, 0.82, 0), shade(faction.hull, 1.3), Enum.Material.Metal)
end

local function accent(model, name, size, cf, color)
	local p = neon(model, name, size, cf, color)
	p.Name = "Accent"
	return p
end

local function buildHuman(faction, form)
	local model = newModel(unitFolder, faction.key .. "_" .. form.key)
	rootPart(model, CFrame.new())
	unitBase(model, faction)
	accent(model, "Core", Vector3.new(1.3, 0.5, 1.3), CFrame.new(0, 2.1, 0), faction.accent)
	if form.key == "troops" then
		place(model, "HeadTorso", Vector3.new(2.1, 1.8, 1.9), rel(0, 2.5, 0), STEEL, Enum.Material.Metal)
		place(model, "HeadVisor", Vector3.new(1.3, 0.36, 0.2), rel(0, 3.0, -0.98), faction.color, Enum.Material.Neon)
		place(model, "HeadRifle", Vector3.new(0.26, 0.26, 3.0), rel(0.5, 2.6, -1.9), DARK, Enum.Material.Metal)
		neon(model, "HeadMuzzle", Vector3.new(0.36, 0.36, 0.3), CFrame.new(0.5, 2.6, -3.4), faction.accent)
		place(model, "HeadPack", Vector3.new(0.9, 1.1, 0.6), rel(0, 2.6, 1.0), shade(faction.hull, 1.4), Enum.Material.Metal)
		place(model, "HeadShoulderL", Vector3.new(0.5, 0.5, 0.9), rel(-1.3, 2.8, 0), shade(faction.accent, 0.8), Enum.Material.Metal)
		place(model, "HeadShoulderR", Vector3.new(0.5, 0.5, 0.9), rel(1.3, 2.8, 0), shade(faction.accent, 0.8), Enum.Material.Metal)
	else
		place(model, "HeadWall", Vector3.new(4.2, 2.0, 3.4), rel(0, 2.3, 0.2), shade(faction.hull, 1.5), Enum.Material.Concrete)
		place(model, "HeadHatch", Vector3.new(2.4, 0.4, 1.6), rel(0, 3.4, 0.2), DARK, Enum.Material.Metal)
		for s = -1, 1, 2 do
			place(model, "HeadMortar" .. s, Vector3.new(0.75, 0.75, 2.6), rel(s * 1.1, 2.9, -1.6), DARK, Enum.Material.Metal)
			neon(model, "HeadMuzzle" .. s, Vector3.new(0.9, 0.9, 0.4), CFrame.new(s * 1.1, 2.9, -3.0), faction.accent)
		end
		place(model, "HeadSandbag", Vector3.new(5.0, 0.7, 0.8), rel(0, 1.2, -1.9), Color3.fromRGB(120, 110, 84), Enum.Material.Fabric)
	end
	return model
end

local function buildMecha(faction, form)
	local model = newModel(unitFolder, faction.key .. "_" .. form.key)
	rootPart(model, CFrame.new())
	unitBase(model, faction)
	accent(model, "Core", Vector3.new(1.5, 0.6, 1.5), CFrame.new(0, 2.0, 0), faction.accent)
	if form.key == "walker" then
		place(model, "HeadHip", Vector3.new(2.6, 0.8, 2.0), rel(0, 1.7, 0), DARK, Enum.Material.Metal)
		place(model, "HeadChest", Vector3.new(2.6, 1.7, 2.0), rel(0, 2.9, 0), STEEL, Enum.Material.Metal)
		for s = -1, 1, 2 do
			place(model, "HeadLeg" .. s, Vector3.new(0.7, 1.4, 0.7), rel(s * 0.9, 1.0, 0), DARK, Enum.Material.Metal)
			place(model, "HeadPod" .. s, Vector3.new(1.1, 1.2, 1.8), rel(s * 1.6, 3.4, 0.2), shade(faction.hull, 1.6), Enum.Material.Metal)
			neon(model, "HeadPodGlow" .. s, Vector3.new(0.9, 0.2, 1.2), CFrame.new(s * 1.6, 4.0, 0.2), faction.accent)
		end
		place(model, "HeadSensor", Vector3.new(0.9, 0.5, 0.3), rel(0, 3.3, -1.0), faction.color, Enum.Material.Neon)
	else
		for s = -1, 1, 2 do
			place(model, "HeadTread" .. s, Vector3.new(1.2, 1.3, 5.0), rel(s * 1.8, 1.3, 0), DARK, Enum.Material.DiamondPlate)
		end
		place(model, "HeadTurret", Vector3.new(3.4, 1.7, 3.2), rel(0, 2.5, 0), shade(faction.hull, 1.5), Enum.Material.Metal)
		local barrel = place(model, "HeadBarrel", Vector3.new(0.9, 0.9, 6.6), rel(0, 2.7, -3.4), DARK, Enum.Material.Metal)
		barrel.CFrame = model.PrimaryPart.CFrame * rel(0, 2.7, -3.4, 90, 0, 0)
		neon(model, "HeadMuzzle", Vector3.new(1.15, 1.15, 0.5), CFrame.new(0, 2.7, -6.7), faction.accent)
		place(model, "HeadExhaust", Vector3.new(0.5, 1.4, 0.5), rel(1.2, 3.4, 0.9), TRIMC, Enum.Material.Metal)
	end
	return model
end

local function buildArcane(faction, form)
	local model = newModel(unitFolder, faction.key .. "_" .. form.key)
	rootPart(model, CFrame.new())
	unitBase(model, faction)
	accent(model, "Core", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 2.6, 0), faction.accent)
	if form.key == "tower" then
		place(model, "HeadPillar", Vector3.new(1.4, 4.2, 1.4), rel(0, 3.4, 0), shade(faction.hull, 1.5), Enum.Material.Slate)
		local gem = neon(model, "HeadGem", Vector3.new(1.4, 2.0, 1.4), CFrame.new(0, 6.0, 0), faction.accent)
		gem.CFrame = model.PrimaryPart.CFrame * rel(0, 6.0, 0, 0, 45, 45)
		for i = 1, 3 do
			local r = disc(model, "HeadOrbit" .. i, 1.9 + i * 0.4, 0.12, rel(0, 4.4 + i * 0.5, 0), faction.color, Enum.Material.Neon)
			r:SetAttribute("Spin", (i % 2 == 0) and -1.4 or 1.1)
		end
	else
		local shield = place(model, "HeadShield", Vector3.new(3.6, 3.6, 0.5), rel(0, 3.2, -0.8), shade(faction.hull, 1.7), Enum.Material.Metal)
		shield.CFrame = model.PrimaryPart.CFrame * rel(0, 3.2, -0.8, 8, 0, 45)
		local blade = neon(model, "HeadBlade", Vector3.new(0.3, 3.6, 0.6), rel(1.6, 3.4, -1.0), faction.accent)
		blade.CFrame = model.PrimaryPart.CFrame * rel(1.6, 3.4, -1.0, 0, 0, 18)
		neon(model, "HeadEye", Vector3.new(1.0, 0.4, 0.3), CFrame.new(0, 3.4, -1.15), faction.color)
		place(model, "HeadHalo", Vector3.new(2.8, 0.2, 2.8), rel(0, 5.0, 0), faction.accent, Enum.Material.Neon)
	end
	return model
end

local function buildBio(faction, form)
	local model = newModel(unitFolder, faction.key .. "_" .. form.key)
	rootPart(model, CFrame.new())
	unitBase(model, faction)
	accent(model, "Core", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 2.2, 0), faction.accent)
	if form.key == "spire" then
		for i = 1, 5 do
			local a = math.rad((i - 1) * 72)
			local h = 3.2 + (i % 3) * 1.2
			local p = place(model, "HeadSpike" .. i, Vector3.new(0.8, h, 0.8), rel(math.cos(a) * 0.9, 1.6 + h / 2, math.sin(a) * 0.9), shade(faction.hull, 1.4), Enum.Material.SmoothPlastic)
			p.CFrame = model.PrimaryPart.CFrame * rel(math.cos(a) * 0.9, 1.6 + h / 2, math.sin(a) * 0.9, math.cos(a) * 14, 0, math.sin(a) * 14)
		end
		local sac = neon(model, "HeadSac", Vector3.new(2.2, 2.8, 2.2), CFrame.new(0, 4.4, 0), faction.accent, Enum.PartType.Ball)
		sac.Transparency = 0.28
	else
		local body = place(model, "HeadBody", Vector3.new(2.6, 1.8, 3.4), rel(0, 2.4, 0), shade(faction.hull, 1.3), Enum.Material.SmoothPlastic)
		place(model, "HeadJaw", Vector3.new(1.8, 0.8, 1.6), rel(0, 2.0, -1.9), shade(faction.hull, 0.8), Enum.Material.SmoothPlastic)
		neon(model, "HeadMaw", Vector3.new(1.2, 0.4, 0.6), CFrame.new(0, 2.1, -2.7), faction.accent)
		for s = -1, 1, 2 do
			place(model, "HeadClaw" .. s, Vector3.new(0.6, 2.2, 0.6), rel(s * 1.4, 1.6, -0.6), shade(faction.hull, 1.1), Enum.Material.SmoothPlastic)
		end
		for i = 1, 5 do
			accent(model, "HeadSpine" .. i, Vector3.new(0.45, 0.9, 0.45), CFrame.new(0, 3.4 + (i % 2) * 0.2, -0.8 + i * 0.45), faction.accent)
		end
	end
	return model
end

local function buildDrone(faction, form)
	local model = newModel(unitFolder, faction.key .. "_" .. form.key)
	rootPart(model, CFrame.new())
	unitBase(model, faction)
	accent(model, "Core", Vector3.new(1.3, 0.5, 1.3), CFrame.new(0, 2.1, 0), faction.accent)
	if form.key == "robot" then
		place(model, "HeadTorso", Vector3.new(2.0, 2.0, 1.8), rel(0, 2.9, 0), shade(faction.hull, 1.5), Enum.Material.Metal)
		place(model, "HeadVisor", Vector3.new(1.1, 0.3, 0.2), rel(0, 3.5, -0.92), faction.color, Enum.Material.Neon)
		for s = -1, 1, 2 do
			place(model, "HeadArm" .. s, Vector3.new(0.6, 1.8, 0.6), rel(s * 1.3, 2.6, 0), DARK, Enum.Material.Metal)
		end
		local cannon = place(model, "HeadCannon", Vector3.new(0.9, 0.9, 3.4), rel(0, 3.0, -1.9), STEEL, Enum.Material.Metal)
		cannon.CFrame = model.PrimaryPart.CFrame * rel(0, 3.0, -1.9, 90, 0, 0)
		neon(model, "HeadMuzzle", Vector3.new(1.1, 1.1, 0.4), CFrame.new(0, 3.0, -3.6), faction.accent)
		place(model, "HeadAntenna", Vector3.new(0.15, 1.4, 0.15), rel(0.7, 4.4, 0.4), TRIMC, Enum.Material.Metal)
	else
		place(model, "HeadCarrier", Vector3.new(3.2, 0.7, 2.4), rel(0, 3.4, 0), shade(faction.hull, 1.6), Enum.Material.Metal)
		neon(model, "HeadDeck", Vector3.new(2.4, 0.16, 1.6), CFrame.new(0, 3.8, 0), faction.accent)
		for i = 1, 3 do
			local a = math.rad((i - 1) * 120)
			local px, pz = math.cos(a) * 2.2, math.sin(a) * 2.2
			local drone = place(model, "HeadDrone" .. i, Vector3.new(0.7, 0.4, 0.9), rel(px, 3.9 + i * 0.22, pz), TRIMC, Enum.Material.Metal)
			drone.CFrame = model.PrimaryPart.CFrame * rel(px, 3.9 + i * 0.22, pz)
			neon(model, "HeadDroneGlow" .. i, Vector3.new(0.24, 0.16, 0.24), drone.CFrame * CFrame.new(0, -0.3, 0), faction.accent)
		end
		place(model, "HeadRotor", Vector3.new(4.6, 0.12, 0.4), rel(0, 4.2, 0), TRIMC, Enum.Material.Metal)
	end
	return model
end

local UNIT_BUILDERS = {
	human = buildHuman,
	mecha = buildMecha,
	arcane = buildArcane,
	bio = buildBio,
	drone = buildDrone,
}

for _, faction in ipairs(Shared.FACTIONS) do
	for _, form in ipairs(faction.forms) do
		local model = UNIT_BUILDERS[faction.key](faction, form)
		model:SetAttribute("Faction", faction.key)
		model:SetAttribute("Form", form.key)
		model:SetAttribute("FormIndex", (form.key == faction.forms[1].key) and 1 or 2)
	end
end

-- 융합 유닛 5종 (두 종족의 부품이 섞인 실루엣)
local function buildFusionModel(def)
	local factionA = Shared.FACTION_BY_KEY[def.a]
	local factionB = Shared.FACTION_BY_KEY[def.b]
	local model = newModel(unitFolder, "FUSION_" .. def.key)
	rootPart(model, CFrame.new())
	unitBase(model, factionA)
	-- 좌우로 두 종족 색을 나눠 칠합니다
	place(model, "FuseHullL", Vector3.new(2.2, 2.2, 3.2), rel(-1.2, 2.6, 0), shade(factionA.hull, 1.5), Enum.Material.Metal)
	place(model, "FuseHullR", Vector3.new(2.2, 2.2, 3.2), rel(1.2, 2.6, 0), shade(factionB.hull, 1.5), Enum.Material.Metal)
	neon(model, "AccentL", Vector3.new(0.4, 1.6, 3.0), CFrame.new(-2.25, 2.7, 0), factionA.accent)
	neon(model, "AccentR", Vector3.new(0.4, 1.6, 3.0), CFrame.new(2.25, 2.7, 0), factionB.accent)
	place(model, "FuseSpine", Vector3.new(0.8, 2.6, 0.8), rel(0, 4.2, 0.4), DARK, Enum.Material.Metal)
	neon(model, "AccentCore", Vector3.new(2.0, 2.0, 2.0), CFrame.new(0, 4.6, -0.4), factionA.color, Enum.PartType.Ball)
	for i = 1, 4 do
		local a = math.rad((i - 1) * 90 + 45)
		local p = neon(model, "AccentRing" .. i, Vector3.new(0.3, 1.2, 0.3), CFrame.new(math.cos(a) * 2.8, 2.4, math.sin(a) * 2.8), factionB.accent)
		p.CFrame = model.PrimaryPart.CFrame * rel(math.cos(a) * 2.8, 2.4, math.sin(a) * 2.8, 0, math.deg(a), 20)
	end
	for s = -1, 1, 2 do
		place(model, "FuseBarrel" .. s, Vector3.new(0.7, 0.7, 4.6), rel(s * 1.0, 3.2, -2.4), DARK, Enum.Material.Metal)
		neon(model, "FuseMuzzle" .. s, Vector3.new(0.85, 0.85, 0.3), CFrame.new(s * 1.0, 3.2, -4.7), factionA.accent)
	end
	-- 날개
	for s = -1, 1, 2 do
		local wing = neon(model, "FuseWing" .. s, Vector3.new(2.6, 0.25, 1.4), rel(s * 3.2, 4.0, 0.6), factionB.accent)
		wing.CFrame = model.PrimaryPart.CFrame * rel(s * 3.2, 4.0, 0.6, 0, 0, s * 18)
		wing.Transparency = 0.25
	end
	model:SetAttribute("Fusion", def.key)
	return model
end

for _, def in ipairs(Shared.FUSIONS) do
	buildFusionModel(def)
end

-- ---------------------------------------------------------------
-- 6. 적 모델
-- ---------------------------------------------------------------
local enemyFolder = ReplicatedStorage:FindFirstChild("TD_Enemies")
if enemyFolder then enemyFolder:Destroy() end
enemyFolder = Instance.new("Folder")
enemyFolder.Name = "TD_Enemies"
enemyFolder.Parent = ReplicatedStorage

local function enemyModel(key, name)
	local m = newModel(enemyFolder, key)
	rootPart(m, CFrame.new())
	m:SetAttribute("EnemyKey", key)
	m:SetAttribute("DisplayName", name)
	return m
end

-- 1) 슬라임
do
	local m = enemyModel("slime", "스카우트 슬라임")
	local body = neon(m, "Body", Vector3.new(1.9, 1.5, 1.9), CFrame.new(0, 0.9, 0), Color3.fromRGB(95, 208, 106), Enum.PartType.Ball)
	body.Transparency = 0.05
	neon(m, "Eye", Vector3.new(0.34, 0.3, 0.24), CFrame.new(0, 1.05, -0.85), Color3.fromRGB(190, 255, 200))
	place(m, "Core", Vector3.new(0.7, 0.7, 0.7), rel(0, 1.0, 0.2), Color3.fromRGB(60, 160, 70), Enum.Material.Neon)
end
-- 2) 고블린
do
	local m = enemyModel("goblin", "고블린 약탈자")
	place(m, "Body", Vector3.new(1.1, 1.4, 0.9), rel(0, 1.0, 0), Color3.fromRGB(122, 142, 58), Enum.Material.SmoothPlastic)
	place(m, "Head", Vector3.new(0.9, 0.8, 0.8), rel(0, 1.9, -0.1), Color3.fromRGB(150, 168, 76), Enum.Material.SmoothPlastic)
	neon(m, "Eye", Vector3.new(0.3, 0.14, 0.12), CFrame.new(0, 1.95, -0.5), Color3.fromRGB(255, 220, 90))
	for s = -1, 1, 2 do
		local ear = place(m, "Ear" .. s, Vector3.new(0.3, 0.7, 0.16), rel(s * 0.6, 1.95, 0), Color3.fromRGB(140, 160, 70), Enum.Material.SmoothPlastic)
		ear.CFrame = m.PrimaryPart.CFrame * rel(s * 0.6, 1.95, 0, 0, 0, s * 30)
		place(m, "Leg" .. s, Vector3.new(0.3, 0.8, 0.3), rel(s * 0.3, 0.4, 0), Color3.fromRGB(96, 112, 44), Enum.Material.SmoothPlastic)
	end
	place(m, "Club", Vector3.new(0.22, 1.5, 0.22), rel(0.7, 1.1, -0.2), Color3.fromRGB(110, 84, 50), Enum.Material.Wood)
end
-- 3) 골렘
do
	local m = enemyModel("golem", "아머 골렘")
	place(m, "Body", Vector3.new(2.4, 2.4, 2.0), rel(0, 1.9, 0), Color3.fromRGB(95, 125, 146), Enum.Material.Metal)
	place(m, "Head", Vector3.new(1.2, 0.8, 1.0), rel(0, 3.3, -0.2), Color3.fromRGB(120, 150, 170), Enum.Material.Metal)
	neon(m, "Eye", Vector3.new(0.6, 0.16, 0.1), CFrame.new(0, 3.35, -0.72), Color3.fromRGB(120, 240, 255))
	for s = -1, 1, 2 do
		place(m, "Arm" .. s, Vector3.new(0.7, 2.0, 0.7), rel(s * 1.6, 1.9, 0), Color3.fromRGB(76, 100, 118), Enum.Material.Metal)
		place(m, "Leg" .. s, Vector3.new(0.8, 1.0, 0.9), rel(s * 0.7, 0.5, 0), Color3.fromRGB(60, 80, 96), Enum.Material.Metal)
	end
	neon(m, "Core", Vector3.new(0.6, 0.6, 0.2), CFrame.new(0, 2.3, -1.02), Color3.fromRGB(120, 240, 255))
end
-- 4) 하운드
do
	local m = enemyModel("hound", "사이버 하운드")
	place(m, "Body", Vector3.new(0.9, 0.8, 2.2), rel(0, 1.0, 0), Color3.fromRGB(178, 69, 47), Enum.Material.Metal)
	place(m, "Head", Vector3.new(0.8, 0.6, 0.9), rel(0, 1.2, -1.3), Color3.fromRGB(200, 90, 70), Enum.Material.Metal)
	neon(m, "Eye", Vector3.new(0.5, 0.12, 0.1), CFrame.new(0, 1.25, -1.75), Color3.fromRGB(110, 240, 255))
	for i = 1, 4 do
		local s = (i % 2 == 0) and 1 or -1
		local f = (i <= 2) and 0.6 or -0.6
		place(m, "Leg" .. i, Vector3.new(0.2, 0.8, 0.2), rel(s * 0.4, 0.45, f), Color3.fromRGB(110, 42, 28), Enum.Material.Metal)
	end
	place(m, "Tail", Vector3.new(0.18, 0.18, 1.2), rel(0, 1.2, 1.5), Color3.fromRGB(140, 52, 34), Enum.Material.Metal)
end
-- 5) 공허 레이스
do
	local m = enemyModel("voidling", "공허 레이스")
	local body = neon(m, "Body", Vector3.new(1.7, 1.9, 1.7), CFrame.new(0, 2.2, 0), Color3.fromRGB(90, 50, 150), Enum.PartType.Ball)
	body.Transparency = 0.2
	neon(m, "Eye", Vector3.new(0.6, 0.16, 0.1), CFrame.new(0, 2.4, -0.8), Color3.fromRGB(220, 140, 255))
	for i = 1, 6 do
		local a = math.rad((i - 1) * 60)
		local p = place(m, "Spike" .. i, Vector3.new(0.18, 0.7, 0.18), rel(math.cos(a) * 0.95, 2.2 + math.sin(a) * 0.5, math.sin(a) * 0.95), Color3.fromRGB(180, 120, 255), Enum.Material.Neon)
		p.CFrame = m.PrimaryPart.CFrame * rel(math.cos(a) * 0.95, 2.2 + math.sin(a) * 0.5, math.sin(a) * 0.95, 0, 0, math.deg(math.cos(a)) * 30)
	end
	local ring = disc(m, "Halo", 1.3, 0.1, rel(0, 2.2, 0), Color3.fromRGB(200, 140, 255), Enum.Material.Neon)
	ring:SetAttribute("Spin", 1.6)
end
-- 6) 마력 야수
do
	local m = enemyModel("beast", "마력 야수")
	place(m, "Body", Vector3.new(1.9, 1.5, 2.6), rel(0, 1.3, 0), Color3.fromRGB(192, 90, 216), Enum.Material.SmoothPlastic)
	place(m, "Head", Vector3.new(1.3, 1.0, 1.2), rel(0, 1.6, -1.7), Color3.fromRGB(220, 122, 240), Enum.Material.SmoothPlastic)
	neon(m, "Eye", Vector3.new(0.4, 0.18, 0.1), CFrame.new(0, 1.7, -2.3), Color3.fromRGB(255, 150, 230))
	for s = -1, 1, 2 do
		local horn = place(m, "Horn" .. s, Vector3.new(0.22, 0.9, 0.22), rel(s * 0.4, 2.2, -1.7), Color3.fromRGB(240, 200, 255), Enum.Material.SmoothPlastic)
		horn.CFrame = m.PrimaryPart.CFrame * rel(s * 0.4, 2.2, -1.7, 0, 0, s * 20)
		for k = 1, 2 do
			place(m, "Leg" .. s .. k, Vector3.new(0.28, 1.1, 0.28), rel(s * 0.8, 0.6, -0.6 + k * 1.1), Color3.fromRGB(140, 60, 160), Enum.Material.SmoothPlastic)
		end
	end
	neon(m, "Mane", Vector3.new(0.5, 1.2, 0.5), CFrame.new(0, 2.4, 0.4), Color3.fromRGB(255, 140, 230))
end
-- 7) 지옥 타이탄
do
	local m = enemyModel("titan", "지옥 타이탄")
	place(m, "Body", Vector3.new(2.6, 2.8, 2.2), rel(0, 2.4, 0), Color3.fromRGB(122, 31, 31), Enum.Material.Metal)
	place(m, "Head", Vector3.new(1.4, 1.1, 1.2), rel(0, 4.2, -0.2), Color3.fromRGB(158, 44, 44), Enum.Material.Metal)
	neon(m, "Eye", Vector3.new(0.8, 0.2, 0.12), CFrame.new(0, 4.25, -0.85), Color3.fromRGB(255, 140, 60))
	for s = -1, 1, 2 do
		place(m, "Shoulder" .. s, Vector3.new(1.0, 1.0, 1.2), rel(s * 1.8, 3.4, 0), Color3.fromRGB(160, 60, 50), Enum.Material.Metal)
		place(m, "Arm" .. s, Vector3.new(0.9, 2.2, 0.9), rel(s * 1.9, 2.0, 0), Color3.fromRGB(96, 26, 26), Enum.Material.Metal)
		local horn = place(m, "Horn" .. s, Vector3.new(0.3, 1.2, 0.3), rel(s * 0.5, 4.9, -0.2), Color3.fromRGB(230, 210, 180), Enum.Material.Metal)
		horn.CFrame = m.PrimaryPart.CFrame * rel(s * 0.5, 4.9, -0.2, 0, 0, s * 24)
	end
	place(m, "Cloak", Vector3.new(3.4, 3.0, 0.3), rel(0, 2.4, 1.2), Color3.fromRGB(60, 12, 12), Enum.Material.Fabric)
end
-- 8) 크리스탈 드래곤
do
	local m = enemyModel("dragon", "크리스탈 드래곤")
	local body = place(m, "Body", Vector3.new(1.9, 1.6, 3.0), rel(0, 2.6, 0), Color3.fromRGB(210, 64, 92), Enum.Material.Metal)
	place(m, "Neck", Vector3.new(0.6, 1.6, 0.6), rel(0, 3.4, -1.4, 40, 0, 0), Color3.fromRGB(230, 90, 118), Enum.Material.Metal)
	place(m, "Head", Vector3.new(0.9, 0.7, 1.4), rel(0, 4.1, -2.2), Color3.fromRGB(245, 120, 145), Enum.Material.Metal)
	neon(m, "Eye", Vector3.new(0.4, 0.14, 0.1), CFrame.new(0, 4.15, -2.85), Color3.fromRGB(255, 220, 140))
	for s = -1, 1, 2 do
		local wing = neon(m, "Wing" .. s, Vector3.new(2.8, 0.16, 1.8), rel(s * 2.2, 3.2, 0.2), Color3.fromRGB(255, 150, 180))
		wing.CFrame = m.PrimaryPart.CFrame * rel(s * 2.2, 3.2, 0.2, 0, 0, s * 16)
		wing.Transparency = 0.25
		place(m, "Leg" .. s, Vector3.new(0.3, 1.1, 0.3), rel(s * 0.7, 1.6, 0.4), Color3.fromRGB(150, 40, 60), Enum.Material.Metal)
	end
	place(m, "Tail", Vector3.new(0.4, 0.4, 2.2), rel(0, 2.5, 2.2), Color3.fromRGB(170, 50, 70), Enum.Material.Metal)
	for i = 1, 3 do
		neon(m, "Crystal" .. i, Vector3.new(0.4, 0.9, 0.4), CFrame.new(0, 3.5 + i * 0.15, 0.6 - i * 0.5), Color3.fromRGB(255, 170, 220))
	end
end

-- 9) 최종 보스 — 오메가 파괴신 (3배 이상 스케일)
do
	local m = newModel(enemyFolder, "omegaboss")
	rootPart(m, CFrame.new())
	m:SetAttribute("FinalBoss", true)
	local scale = Shared.FINAL_BOSS.scale
	local function bs(x, y, z)
		return Vector3.new(x * scale, y * scale, z * scale)
	end
	local core = neon(m, "Body", bs(5.2, 5.2, 5.2), CFrame.new(0, 13 * scale / 2, 0), Color3.fromRGB(70, 20, 90), Enum.PartType.Ball)
	core.Transparency = 0.05
	neon(m, "CoreGlow", bs(3.2, 3.2, 3.2), CFrame.new(0, 13 * scale / 2, -2.4 * scale), Color3.fromRGB(255, 70, 120), Enum.PartType.Ball)
	neon(m, "Eye", bs(2.0, 1.0, 0.7), CFrame.new(0, 14 * scale / 2, -5.0 * scale), Color3.fromRGB(255, 230, 120), Enum.PartType.Ball)
	-- 왕관
	for i = 1, 7 do
		local a = math.rad((i - 1) * (360 / 7))
		local px, pz = math.cos(a) * 3.2 * scale, math.sin(a) * 3.2 * scale
		local spike = neon(m, "Crown" .. i, bs(0.5, 2.6, 0.5), CFrame.new(px, 17 * scale / 2 + 1.2 * scale, pz), Color3.fromRGB(255, 190, 90))
		spike.CFrame = m.PrimaryPart.CFrame * CFrame.new(px, 17 * scale / 2 + 1.2 * scale, pz) * CFrame.Angles(0, 0, math.rad(math.cos(a) * 16))
	end
	-- 날개
	for s = -1, 1, 2 do
		local wing = neon(m, "Wing" .. s, bs(4.0, 8.0, 1.2), CFrame.new(s * 7 * scale, 12 * scale / 2, 1.0 * scale), Color3.fromRGB(200, 40, 90))
		wing.CFrame = m.PrimaryPart.CFrame * CFrame.new(s * 7 * scale, 12 * scale / 2, 1.0 * scale) * CFrame.Angles(0, 0, math.rad(s * 26))
		wing.Transparency = 0.25
		for k = 1, 3 do
			local claw = neon(m, "Claw" .. s .. k, bs(0.4, 3.4 - k * 0.6, 0.4), CFrame.new(s * (9 + k) * scale * 0.9, (7 - k) * scale, 2.6 * scale), Color3.fromRGB(255, 120, 160))
			claw.CFrame = m.PrimaryPart.CFrame * CFrame.new(s * (9 + k) * scale * 0.9, (7 - k) * scale, 2.6 * scale) * CFrame.Angles(0, 0, math.rad(s * (30 + k * 14)))
		end
	end
	-- 바닥 오라 링
	for i = 1, 3 do
		local ring = disc(m, "AuraRing" .. i, (9 + i * 3) * scale / 2, 0.2, CFrame.new(0, 0.6 + i * 0.2, 0), (i == 2) and Color3.fromRGB(255, 80, 90) or Color3.fromRGB(190, 60, 220), Enum.Material.Neon)
		ring.Transparency = 0.35
		ring:SetAttribute("Spin", (i % 2 == 0) and -0.6 or 0.45)
	end
	neon(m, "Pillar", bs(1.4, 10, 1.4), CFrame.new(0, -6, 0), Color3.fromRGB(120, 40, 160))
end

-- ---------------------------------------------------------------
-- 7. 테마 API (02 가 호출) + 초기 테마
-- ---------------------------------------------------------------
local apiFolder = ServerScriptService:FindFirstChild("TD_WorldAPI")
if not apiFolder then
	apiFolder = Instance.new("Folder")
	apiFolder.Name = "TD_WorldAPI"
	apiFolder.Parent = ServerScriptService
end
local themeFn = apiFolder:FindFirstChild("Theme")
if not themeFn then
	themeFn = Instance.new("BindableFunction")
	themeFn.Name = "Theme"
	themeFn.Parent = apiFolder
end
themeFn.OnInvoke = function(key)
	applyTheme(key)
	return true
end

applyTheme("sf")

print("[TD] 01_WorldAndUnits 완료 — 우주 5아레나 · 그리드 8×8×5 · 터렛 유닛 10종+융합 5종 · 적 8종+최종보스 (v" .. Shared.VERSION .. ")")
