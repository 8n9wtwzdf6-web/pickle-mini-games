--[[ ============================================================
  01_MapAndTurrets.server.lua
  🍀 운빨·조합 터렛 디펜스 — 4인 협동 아레나 + 터렛/적 3D 모델
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService  (일반 Script)
  먼저 필요한 것 : ReplicatedStorage 의 ModuleScript "TDShared"
  하는 일
    1) P1~P4 4개 라인 아레나 · 분리벽 · 스폰 게이트 · 중앙 넥서스 건설
    2) 라인당 터렛 패드 6칸(1~4 무료 / 5·6 = 추가 슬롯 패스)
    3) 터렛 모델 10종 → ReplicatedStorage.TD_Turrets
    4) 적 모델 5종   → ReplicatedStorage.TD_Enemies.Root : 적이 걸어오는 기준점
  ※ 좌표는 ReplicatedStorage.TDShared.GEO 한 곳에서만 관리합니다.
  ============================================================ ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local GEO = Shared.GEO

local LANE_X = GEO.LANE_X
local LANE_COLORS = GEO.LANE_COLORS
local LANE_NAMES = GEO.LANE_NAMES
local ARENA_W = GEO.ARENA_W
local ARENA_D = GEO.ARENA_D
local SLOT_Z = GEO.SLOT_Z
local SLOT_X_OFF = GEO.SLOT_X_OFF
local ENEMY_X_OFF = GEO.ENEMY_X_OFF
local NEXUS_POS = GEO.NEXUS_POS

local TIERS = Shared.TIER_COLORS

-- ---------------------------------------------------------------
-- 공통 헬퍼
-- ---------------------------------------------------------------
local function shade(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf or CFrame.new()
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Metal
	p.Color = color or Color3.fromRGB(90, 105, 120)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function neon(parent, name, size, cf, color, shape)
	return part(parent, name, size, cf, color, Enum.Material.Neon, shape)
end

local function newModel(folder, name, pos)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = folder
	local root = part(m, "Root", Vector3.new(1, 1, 1), CFrame.new(pos or Vector3.new()), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	m.PrimaryPart = root
	return m, root
end

local function place(model, name, size, relCF, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Metal
	p.Color = color or Color3.fromRGB(90, 105, 120)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.CFrame = model.PrimaryPart.CFrame * relCF
	p.Parent = model
	return p
end

local function rel(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

-- ===============================================================
-- 1. 아레나
-- ===============================================================
local oldArena = Workspace:FindFirstChild("TDArena")
if oldArena then oldArena:Destroy() end

local arena = Instance.new("Folder")
arena.Name = "TDArena"
arena.Parent = Workspace
arena:SetAttribute("Version", Shared.VERSION)

local ground = Instance.new("Folder")
ground.Name = "Ground"
ground.Parent = arena

part(ground, "Base", Vector3.new(ARENA_W + 4, 2, ARENA_D + 4), CFrame.new(0, -1.2, -1), Color3.fromRGB(36, 47, 57), Enum.Material.DiamondPlate)
part(ground, "Deck", Vector3.new(ARENA_W, 0.5, ARENA_D), CFrame.new(0, -0.1, -1), Color3.fromRGB(52, 66, 78), Enum.Material.Metal)
part(ground, "DeckLower", Vector3.new(ARENA_W - 2, 1.4, ARENA_D - 2), CFrame.new(0, -2.2, -1), Color3.fromRGB(24, 32, 40), Enum.Material.Metal)

neon(ground, "TrimN", Vector3.new(ARENA_W + 4, 0.2, 0.3), CFrame.new(0, 0.12, -1 - ARENA_D / 2 - 2), Color3.fromRGB(63, 208, 240))
neon(ground, "TrimS", Vector3.new(ARENA_W + 4, 0.2, 0.3), CFrame.new(0, 0.12, -1 + ARENA_D / 2 + 2), Color3.fromRGB(63, 208, 240))
neon(ground, "TrimW", Vector3.new(0.3, 0.2, ARENA_D + 4), CFrame.new(-ARENA_W / 2 - 2, 0.12, -1), Color3.fromRGB(63, 208, 240))
neon(ground, "TrimE", Vector3.new(0.3, 0.2, ARENA_D + 4), CFrame.new(ARENA_W / 2 + 2, 0.12, -1), Color3.fromRGB(63, 208, 240))

for i = 1, 4 do
	local lx = LANE_X[i]
	local col = LANE_COLORS[i]
	local laneFolder = Instance.new("Folder")
	laneFolder.Name = "Lane" .. i
	laneFolder.Parent = arena

	part(laneFolder, "Track", Vector3.new(6.4, 0.2, 58), CFrame.new(lx, 0.14, -3), Color3.fromRGB(26, 36, 44), Enum.Material.Metal)
	neon(laneFolder, "RailL", Vector3.new(0.18, 0.16, 58), CFrame.new(lx - 3.0, 0.28, -3), col)
	neon(laneFolder, "RailR", Vector3.new(0.18, 0.16, 58), CFrame.new(lx + 3.0, 0.28, -3), col)
	neon(laneFolder, "CenterLine", Vector3.new(0.10, 0.12, 58), CFrame.new(lx + ENEMY_X_OFF, 0.26, -3), shade(col, 0.8))

	for s = -1, 1, 2 do
		part(laneFolder, "GatePillar", Vector3.new(0.8, 8, 0.8), CFrame.new(lx + ENEMY_X_OFF + s * 2.6, 4, -33), Color3.fromRGB(58, 74, 88), Enum.Material.Metal)
		neon(laneFolder, "GateGlow", Vector3.new(0.9, 0.3, 0.9), CFrame.new(lx + ENEMY_X_OFF + s * 2.6, 8.2, -33), col)
	end
	neon(laneFolder, "GateBar", Vector3.new(5.6, 0.3, 0.4), CFrame.new(lx + ENEMY_X_OFF, 8.4, -33), col)

	local portal = neon(laneFolder, "Portal", Vector3.new(4.6, 0.25, 4.6), CFrame.new(lx + ENEMY_X_OFF, 0.3, -31), col)
	portal.Shape = Enum.PartType.Cylinder
	portal.CFrame = CFrame.new(lx + ENEMY_X_OFF, 0.3, -31) * CFrame.Angles(0, 0, math.rad(90))
	portal.Transparency = 0.35

	-- 보스 경고등 (02 가 색을 바꿔 깜빡입니다)
	local beacon = neon(laneFolder, "WarnBeacon", Vector3.new(2.2, 2.2, 2.2), CFrame.new(lx + ENEMY_X_OFF, 9.6, -33), shade(col, 0.6), Enum.PartType.Ball)
	beacon.Transparency = 0.85

	local plate = neon(laneFolder, "GatePlate", Vector3.new(3.4, 1.2, 0.2), CFrame.new(lx + ENEMY_X_OFF, 9.4, -32.7), col)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = LANE_NAMES[i]
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = sg
end

for _, wx in ipairs({ -18.2, -9, 0, 9, 18.2 }) do
	local outer = math.abs(wx) > 17
	local h = outer and 3.4 or 2.6
	local w = outer and 1.2 or 0.7
	part(arena, "Divider", Vector3.new(w, h, 58), CFrame.new(wx, h / 2, -3), Color3.fromRGB(44, 57, 68), Enum.Material.Metal)
	neon(arena, "DividerGlow", Vector3.new(w * 0.6, 0.16, 58), CFrame.new(wx, h + 0.06, -3), Color3.fromRGB(47, 159, 190))
	for z = -30, 26, 6 do
		part(arena, "DividerRib", Vector3.new(w + 0.35, h * 0.5, 0.6), CFrame.new(wx, h * 0.5, z), Color3.fromRGB(58, 74, 88), Enum.Material.Metal)
	end
end

-- 넥서스 광장 + 넥서스
part(arena, "Plaza", Vector3.new(ARENA_W - 4, 0.4, 10), CFrame.new(0, 0.2, 31), Color3.fromRGB(56, 71, 84), Enum.Material.Metal)
for i = 1, 4 do
	neon(arena, "PlazaLane", Vector3.new(0.2, 0.1, 9), CFrame.new(LANE_X[i], 0.45, 31), LANE_COLORS[i])
end

local nexus, nexusRoot = newModel(arena, "Nexus", NEXUS_POS)
part(nexus, "Base", Vector3.new(16, 1.2, 16), CFrame.new(NEXUS_POS), Color3.fromRGB(48, 62, 74), Enum.Material.Metal)
part(nexus, "Base2", Vector3.new(11, 1, 11), CFrame.new(NEXUS_POS + Vector3.new(0, 1, 0)), Color3.fromRGB(60, 78, 92), Enum.Material.Metal)
for i = 1, 4 do
	local a = math.rad((i - 1) * 90 + 45)
	local px = math.cos(a) * 5.6
	local pz = math.sin(a) * 5.6
	part(nexus, "Pylon" .. i, Vector3.new(1.4, 7, 1.4), CFrame.new(NEXUS_POS + Vector3.new(px, 3.6, pz)), Color3.fromRGB(70, 92, 108), Enum.Material.Metal)
	neon(nexus, "PylonGlow" .. i, Vector3.new(1.5, 0.4, 1.5), CFrame.new(NEXUS_POS + Vector3.new(px, 7.3, pz)), LANE_COLORS[i])
end

local crystal = part(nexus, "Crystal", Vector3.new(3.4, 5.2, 3.4), CFrame.new(NEXUS_POS + Vector3.new(0, 6.4, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(150, 245, 255), Enum.Material.Neon)
crystal.CastShadow = false
local shell = neon(nexus, "Shell", Vector3.new(5.4, 5.4, 5.4), CFrame.new(NEXUS_POS + Vector3.new(0, 6.4, 0)), Color3.fromRGB(60, 210, 255), Enum.PartType.Ball)
shell.Transparency = 0.78

for i = 1, 3 do
	local ring = neon(nexus, "Ring" .. i, Vector3.new(9 + i * 2.2, 0.18, 9 + i * 2.2), CFrame.new(NEXUS_POS + Vector3.new(0, 5.2 + i * 0.8, 0)), Color3.fromRGB(90, 230, 255))
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(NEXUS_POS + Vector3.new(0, 5.2 + i * 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring:SetAttribute("Spin", (i % 2 == 0) and -0.6 or 0.8)
	ring.CanCollide = false
end

local nLight = Instance.new("PointLight")
nLight.Color = Color3.fromRGB(110, 230, 255)
nLight.Range = 36
nLight.Brightness = 2.4
nLight.Parent = crystal

local hpGui = Instance.new("BillboardGui")
hpGui.Name = "NexusHP"
hpGui.Size = UDim2.fromScale(16, 2.2)
hpGui.StudsOffset = Vector3.new(0, 11, 0)
hpGui.AlwaysOnTop = true
hpGui.Parent = crystal
local hpBack = Instance.new("Frame")
hpBack.Size = UDim2.fromScale(1, 1)
hpBack.BackgroundColor3 = Color3.fromRGB(8, 12, 16)
hpBack.BorderSizePixel = 0
hpBack.Parent = hpGui
local hpFill = Instance.new("Frame")
hpFill.Name = "Fill"
hpFill.Size = UDim2.fromScale(1, 0.72)
hpFill.Position = UDim2.fromScale(0, 0.14)
hpFill.BackgroundColor3 = Color3.fromRGB(90, 255, 170)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpBack
local hpText = Instance.new("TextLabel")
hpText.Size = UDim2.fromScale(1, 1)
hpText.BackgroundTransparency = 1
hpText.Text = "NEXUS 30 / 30"
hpText.TextColor3 = Color3.new(1, 1, 1)
hpText.TextStrokeTransparency = 0.35
hpText.TextScaled = true
hpText.Font = Enum.Font.GothamBlack
hpText.Parent = hpBack

-- ---------------------------------------------------------------
-- 2. 터렛 패드 (라인당 6칸)
-- ---------------------------------------------------------------
local pads = Instance.new("Folder")
pads.Name = "Pads"
pads.Parent = arena

local function makePad(lane, slot, pos, locked)
	local pad = Instance.new("Model")
	pad.Name = "Pad_" .. lane .. "_" .. slot
	pad.Parent = pads
	local root = part(pad, "Root", Vector3.new(1, 1, 1), CFrame.new(pos), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	pad.PrimaryPart = root

	part(pad, "Base", Vector3.new(5.4, 0.5, 5.4), CFrame.new(pos), locked and Color3.fromRGB(30, 38, 46) or Color3.fromRGB(38, 50, 61), Enum.Material.Metal)
	local ring = neon(pad, "Ring", Vector3.new(5.0, 0.16, 5.0), CFrame.new(pos + Vector3.new(0, 0.32, 0)), locked and Color3.fromRGB(90, 90, 90) or LANE_COLORS[lane])
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.32, 0)) * CFrame.Angles(0, 0, math.rad(90))
	neon(pad, "RingInner", Vector3.new(3.4, 0.12, 3.4), CFrame.new(pos + Vector3.new(0, 0.36, 0)), Color3.fromRGB(26, 54, 68))

	pad:SetAttribute("Lane", lane)
	pad:SetAttribute("Slot", slot)
	pad:SetAttribute("Owner", 0)
	pad:SetAttribute("Tier", 0)
	pad:SetAttribute("Kind", 0)
	pad:SetAttribute("Star", 0)
	pad:SetAttribute("Locked", locked and true or false)
	pad:SetAttribute("Vip", locked and true or false)
	return pad
end

for lane = 1, 4 do
	for slot = 1, #SLOT_Z do
		local locked = slot > GEO.FREE_SLOTS
		makePad(lane, slot, Vector3.new(LANE_X[lane] + SLOT_X_OFF, 0.35, SLOT_Z[slot]), locked)
	end
end

-- ---------------------------------------------------------------
-- 3. 터렛 모델 10종 (받침대 고정 + Head* 부품이 360° 회전)
-- ---------------------------------------------------------------
local turretFolder = ReplicatedStorage:FindFirstChild("TD_Turrets")
if turretFolder then turretFolder:Destroy() end
turretFolder = Instance.new("Folder")
turretFolder.Name = "TD_Turrets"
turretFolder.Parent = ReplicatedStorage

local STEEL = Color3.fromRGB(84, 98, 112)
local DARK = Color3.fromRGB(40, 50, 60)
local TRIM = Color3.fromRGB(128, 146, 160)

local function buildTurret(tier, kind)
	local accent = TIERS[tier]
	local model = newModel(turretFolder, "T" .. tier .. "_" .. kind)

	-- 고정 받침대
	part(model, "Base", Vector3.new(4.4, 0.7, 4.4), CFrame.new(0, 0.35, 0), DARK, Enum.Material.Metal)
	local ring = neon(model, "BaseRing", Vector3.new(4.5, 0.2, 4.5), CFrame.new(0, 0.72, 0), accent)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(0, 0.72, 0) * CFrame.Angles(0, 0, math.rad(90))
	for i = 1, 4 do
		local a = math.rad((i - 1) * 90 + 45)
		part(model, "Bolt" .. i, Vector3.new(0.35, 0.25, 0.35), CFrame.new(math.cos(a) * 1.75, 0.78, math.sin(a) * 1.75), TRIM, Enum.Material.Metal)
	end

	-- 회전부 공통
	place(model, "HeadBody", Vector3.new(2.8, 1.4, 2.8), rel(0, 1.6, 0), STEEL, Enum.Material.Metal)
	neon(model, "HeadCore", Vector3.new(1.4, 0.45, 1.4), CFrame.new(0, 2.0, 0), accent)
	place(model, "HeadShoulderL", Vector3.new(0.45, 1.0, 1.9), rel(-1.6, 1.7, 0), shade(accent, 0.45), Enum.Material.Metal)
	place(model, "HeadShoulderR", Vector3.new(0.45, 1.0, 1.9), rel(1.6, 1.7, 0), shade(accent, 0.45), Enum.Material.Metal)

	-- 정면은 -Z
	if tier == 1 and kind == 1 then
		place(model, "HeadTorso", Vector3.new(2.0, 1.7, 1.8), rel(0, 2.5, 0), TRIM, Enum.Material.Metal)
		place(model, "HeadVisor", Vector3.new(1.2, 0.35, 0.2), rel(0, 2.9, -0.95), accent, Enum.Material.Neon)
		place(model, "HeadRifle", Vector3.new(0.24, 0.24, 2.8), rel(0.45, 2.5, -1.9), DARK, Enum.Material.Metal)
		neon(model, "HeadMuzzle", Vector3.new(0.34, 0.34, 0.3), CFrame.new(0.45, 2.5, -3.3), accent)
		place(model, "HeadPack", Vector3.new(0.9, 1.0, 0.6), rel(0, 2.5, 1.0), shade(accent, 0.5), Enum.Material.Metal)
	elseif tier == 1 and kind == 2 then
		place(model, "HeadGunBody", Vector3.new(2.4, 1.1, 2.6), rel(0, 2.0, -0.2), STEEL, Enum.Material.Metal)
		for s = -1, 1, 2 do
			place(model, "HeadBarrel" .. s, Vector3.new(0.28, 0.28, 3.4), rel(s * 0.4, 2.05, -2.2), DARK, Enum.Material.Metal)
			neon(model, "HeadTip" .. s, Vector3.new(0.4, 0.4, 0.25), CFrame.new(s * 0.4, 2.05, -4.0), accent)
		end
		place(model, "HeadAmmo", Vector3.new(0.8, 1.0, 1.2), rel(-1.4, 1.9, 0.3), Color3.fromRGB(92, 108, 76), Enum.Material.Metal)
		place(model, "HeadBipod", Vector3.new(2.6, 0.2, 0.2), rel(0, 1.2, -1.4), TRIM, Enum.Material.Metal)
	elseif tier == 2 and kind == 1 then
		for s = -1, 1, 2 do
			local tank = place(model, "HeadTank" .. s, Vector3.new(0.9, 2.0, 0.9), rel(s * 1.05, 2.2, 0.9), Color3.fromRGB(44, 98, 168), Enum.Material.Metal)
			tank.Shape = Enum.PartType.Cylinder
			tank.CFrame = model.PrimaryPart.CFrame * rel(s * 1.05, 2.2, 0.9, 0, 0, 90)
			neon(model, "HeadTankGlow" .. s, Vector3.new(1.0, 0.2, 1.0), CFrame.new(s * 1.05, 3.2, 0.9), accent)
		end
		place(model, "HeadNozzle", Vector3.new(0.9, 0.9, 2.2), rel(0, 2.0, -1.7), Color3.fromRGB(58, 80, 96), Enum.Material.Metal)
		neon(model, "HeadFlame", Vector3.new(0.7, 0.7, 1.0), CFrame.new(0, 2.0, -3.1), Color3.fromRGB(255, 150, 60))
	elseif tier == 2 and kind == 2 then
		place(model, "HeadArmor", Vector3.new(3.4, 1.9, 3.0), rel(0, 2.2, 0), shade(accent, 0.55), Enum.Material.Metal)
		place(model, "HeadShoulderPadL", Vector3.new(1.0, 1.2, 1.6), rel(-1.9, 2.5, 0), TRIM, Enum.Material.Metal)
		place(model, "HeadShoulderPadR", Vector3.new(1.0, 1.2, 1.6), rel(1.9, 2.5, 0), TRIM, Enum.Material.Metal)
		for s = -1, 1, 2 do
			place(model, "HeadNozzle" .. s, Vector3.new(0.55, 0.55, 2.2), rel(s * 0.55, 2.1, -2.0), DARK, Enum.Material.Metal)
			neon(model, "HeadFlame" .. s, Vector3.new(0.6, 0.6, 0.5), CFrame.new(s * 0.55, 2.1, -3.2), Color3.fromRGB(255, 130, 40))
		end
	elseif tier == 3 and kind == 1 then
		place(model, "HeadLauncher", Vector3.new(3.0, 1.9, 2.6), rel(0, 2.4, 0, -14, 0, 0), shade(accent, 0.5), Enum.Material.Metal)
		for ix = -1, 1, 2 do
			for iy = -1, 1, 2 do
				local tube = place(model, "HeadTube" .. ix .. iy, Vector3.new(0.6, 0.6, 2.4), rel(ix * 0.72, 2.4 + iy * 0.5, -1.1, -14, 0, 0), DARK, Enum.Material.Metal)
				tube.Shape = Enum.PartType.Cylinder
				tube.CFrame = model.PrimaryPart.CFrame * rel(ix * 0.72, 2.4 + iy * 0.5, -1.1, -104, 0, 0)
				neon(model, "HeadTubeGlow" .. ix .. iy, Vector3.new(0.5, 0.5, 0.12), CFrame.new(ix * 0.72, 2.4 + iy * 0.5 - 0.2, -2.25), accent)
			end
		end
		local dish = place(model, "HeadRadar", Vector3.new(0.9, 0.2, 0.9), rel(0, 3.2, 0.9), TRIM, Enum.Material.Metal)
		dish.Shape = Enum.PartType.Cylinder
		dish.CFrame = model.PrimaryPart.CFrame * rel(0, 3.2, 0.9, 10, 0, 0)
		neon(model, "HeadRadarTip", Vector3.new(0.2, 0.5, 0.2), CFrame.new(0, 3.5, 0.9), accent)
	elseif tier == 3 and kind == 2 then
		place(model, "HeadHull", Vector3.new(2.2, 0.8, 4.6), rel(0, 3.0, 0), TRIM, Enum.Material.Metal)
		place(model, "HeadNose", Vector3.new(1.4, 0.7, 1.2), rel(0, 3.0, -2.6), shade(accent, 0.6), Enum.Material.Metal)
		for s = -1, 1, 2 do
			place(model, "HeadWing" .. s, Vector3.new(2.2, 0.25, 1.8), rel(s * 1.9, 3.0, 0.4, 0, 0, s * 8), shade(accent, 0.5), Enum.Material.Metal)
			place(model, "HeadMissile" .. s, Vector3.new(0.3, 0.3, 1.6), rel(s * 1.9, 2.7, 0.4), DARK, Enum.Material.Metal)
		end
		place(model, "HeadRotor", Vector3.new(6.4, 0.12, 0.4), rel(0, 3.6, 0.2), TRIM, Enum.Material.Metal)
		neon(model, "HeadEngine", Vector3.new(1.2, 0.4, 0.4), CFrame.new(0, 3.0, 2.5), accent)
	elseif tier == 4 and kind == 1 then
		for s = -1, 1, 2 do
			place(model, "HeadTread" .. s, Vector3.new(1.1, 1.3, 5.2), rel(s * 1.7, 1.2, 0.2), Color3.fromRGB(28, 36, 44), Enum.Material.DiamondPlate)
		end
		place(model, "HeadTurret", Vector3.new(3.4, 1.6, 3.4), rel(0, 2.3, 0), shade(accent, 0.55), Enum.Material.Metal)
		local barrel = place(model, "HeadBarrel", Vector3.new(0.8, 0.8, 6.4), rel(0, 2.5, -3.4), DARK, Enum.Material.Metal)
		barrel.Shape = Enum.PartType.Cylinder
		barrel.CFrame = model.PrimaryPart.CFrame * rel(0, 2.5, -3.4, 90, 0, 0)
		neon(model, "HeadMuzzle", Vector3.new(1.05, 1.05, 0.5), CFrame.new(0, 2.5, -6.6), accent)
		neon(model, "HeadTrim", Vector3.new(3.5, 0.18, 0.5), CFrame.new(0, 2.95, 0.4), accent)
	elseif tier == 4 and kind == 2 then
		place(model, "HeadHull", Vector3.new(1.8, 0.9, 6.4), rel(0, 3.4, 0), TRIM, Enum.Material.Metal)
		place(model, "HeadNose", Vector3.new(1.2, 0.8, 1.4), rel(0, 3.4, -3.6), shade(accent, 0.65), Enum.Material.Metal)
		place(model, "HeadBridge", Vector3.new(1.2, 0.9, 1.8), rel(0, 4.1, 0.4), shade(accent, 0.5), Enum.Material.Metal)
		for s = -1, 1, 2 do
			place(model, "HeadEngine" .. s, Vector3.new(0.6, 0.6, 0.8), rel(s * 0.5, 3.4, 3.3), DARK, Enum.Material.Metal)
			neon(model, "HeadEngineGlow" .. s, Vector3.new(0.55, 0.55, 0.2), CFrame.new(s * 0.5, 3.4, 3.85), Color3.fromRGB(120, 235, 255))
			place(model, "HeadWing" .. s, Vector3.new(1.0, 0.2, 2.6), rel(s * 1.4, 3.3, 0.6), TRIM, Enum.Material.Metal)
		end
		place(model, "HeadLaser", Vector3.new(0.3, 0.3, 1.8), rel(0, 4.6, -0.6), DARK, Enum.Material.Metal)
		neon(model, "HeadLaserTip", Vector3.new(0.4, 0.4, 0.2), CFrame.new(0, 4.6, -1.6), accent)
	elseif tier == 5 and kind == 1 then
		part(model, "HeadObelisk", Vector3.new(1.8, 6.0, 1.8), CFrame.new(0, 3.7, 0), Color3.fromRGB(38, 30, 54), Enum.Material.Metal)
		neon(model, "HeadObeliskGlow", Vector3.new(0.35, 5.0, 0.35), CFrame.new(0, 3.8, -0.95), accent)
		local gem = neon(model, "HeadGem", Vector3.new(1.1, 1.6, 1.1), CFrame.new(0, 7.2, 0), accent)
		gem.Orientation = Vector3.new(0, 0, 45)
		for s = -1, 1, 2 do
			local blade = neon(model, "HeadBlade" .. s, Vector3.new(0.12, 3.2, 0.7), CFrame.new(s * 1.5, 4.2, 0.2) * CFrame.Angles(0, 0, math.rad(s * 16)), accent)
			blade.Transparency = 0.15
		end
	else
		part(model, "HeadPedestal", Vector3.new(1.8, 2.0, 1.8), CFrame.new(0, 1.7, 0), shade(accent, 0.4), Enum.Material.Metal)
		local orb = neon(model, "HeadOrb", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 4.2, 0), accent, Enum.PartType.Ball)
		orb.Transparency = 0.05
		local halo = neon(model, "HeadHalo", Vector3.new(3.6, 3.6, 3.6), CFrame.new(0, 4.2, 0), accent, Enum.PartType.Ball)
		halo.Transparency = 0.8
		for i = 1, 2 do
			local r = neon(model, "HeadRing" .. i, Vector3.new(4.2 + i * 0.8, 0.16, 4.2 + i * 0.8), CFrame.new(0, 4.2, 0) * CFrame.Angles(math.rad(i * 24), 0, math.rad(90)), shade(accent, 0.85))
			r.Shape = Enum.PartType.Cylinder
			r.Transparency = 0.1
		end
	end

	-- 등급 표시 별(작은 네온)
	for i = 1, tier do
		local a = math.rad(-40 + i * 26)
		neon(model, "TierPip" .. i, Vector3.new(0.28, 0.28, 0.28), CFrame.new(math.cos(a) * 2.0, 0.95, math.sin(a) * 2.0), accent, Enum.PartType.Ball)
	end

	model:SetAttribute("Tier", tier)
	model:SetAttribute("Kind", kind)
	return model
end

for tier = 1, 5 do
	for kind = 1, 2 do
		buildTurret(tier, kind)
	end
end

-- ---------------------------------------------------------------
-- 4. 적 모델 5종
-- ---------------------------------------------------------------
local enemyFolder = ReplicatedStorage:FindFirstChild("TD_Enemies")
if enemyFolder then enemyFolder:Destroy() end
enemyFolder = Instance.new("Folder")
enemyFolder.Name = "TD_Enemies"
enemyFolder.Parent = ReplicatedStorage

local function buildZergling()
	local m = newModel(enemyFolder, "zergling")
	place(m, "Body", Vector3.new(1.9, 1.5, 2.8), rel(0, 1.5, 0), Color3.fromRGB(138, 79, 30), Enum.Material.Metal)
	place(m, "Head", Vector3.new(1.3, 1.1, 1.4), rel(0, 1.9, -1.6), Color3.fromRGB(160, 96, 42), Enum.Material.Metal)
	neon(m, "Eye", Vector3.new(0.55, 0.25, 0.2), CFrame.new(0, 2.0, -2.3), Color3.fromRGB(255, 150, 60))
	for i = 1, 4 do
		local s = (i <= 2) and -1 or 1
		local z = ((i - 1) % 2 == 0) and -0.6 or 0.7
		place(m, "Leg" .. i, Vector3.new(0.35, 1.7, 0.35), rel(s * 1.1, 0.7, z), Color3.fromRGB(104, 60, 22), Enum.Material.Metal)
	end
	for s = -1, 1, 2 do
		place(m, "Scythe" .. s, Vector3.new(0.3, 2.4, 0.5), rel(s * 1.2, 1.8, -1.4, 24, 0, s * 18), Color3.fromRGB(206, 180, 140), Enum.Material.Metal)
	end
	m:SetAttribute("Speed", 9.5)
	m:SetAttribute("Reward", 2)
	m:SetAttribute("CoreDamage", 1)
	m:SetAttribute("Air", false)
	return m
end

local function buildHydra()
	local m = newModel(enemyFolder, "hydra")
	place(m, "Body", Vector3.new(2.4, 2.0, 3.0), rel(0, 1.8, 0), Color3.fromRGB(84, 168, 60), Enum.Material.Metal)
	place(m, "Neck", Vector3.new(0.9, 2.2, 0.9), rel(0, 3.0, -1.2, -24, 0, 0), Color3.fromRGB(96, 184, 70), Enum.Material.Metal)
	place(m, "Head", Vector3.new(1.5, 1.2, 2.0), rel(0, 4.0, -2.4), Color3.fromRGB(120, 205, 88), Enum.Material.Metal)
	neon(m, "Eye", Vector3.new(0.6, 0.25, 0.2), CFrame.new(0, 4.1, -3.4), Color3.fromRGB(255, 210, 90))
	place(m, "Spike", Vector3.new(0.4, 1.6, 0.4), rel(0, 3.0, 0.6, -20, 0, 0), Color3.fromRGB(60, 130, 44), Enum.Material.Metal)
	for i = 1, 6 do
		local s = (i <= 3) and -1 or 1
		local z = ((i - 1) % 3) - 1
		place(m, "Leg" .. i, Vector3.new(0.35, 1.8, 0.35), rel(s * 1.3, 0.8, z), Color3.fromRGB(70, 140, 50), Enum.Material.Metal)
	end
	m:SetAttribute("Speed", 7.6)
	m:SetAttribute("Reward", 3)
	m:SetAttribute("CoreDamage", 1)
	m:SetAttribute("Air", false)
	return m
end

local function buildRoach()
	local m = newModel(enemyFolder, "roach")
	place(m, "Body", Vector3.new(3.0, 2.0, 3.2), rel(0, 1.6, 0), Color3.fromRGB(112, 66, 176), Enum.Material.Metal)
	place(m, "Shell", Vector3.new(2.4, 1.2, 2.6), rel(0, 2.6, 0), Color3.fromRGB(140, 96, 208), Enum.Material.Metal)
	for i = 1, 5 do
		local a = math.rad(-50 + i * 25)
		place(m, "Plate" .. i, Vector3.new(0.7, 0.35, 1.6), CFrame.new(0, 3.0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.0), Color3.fromRGB(168, 126, 232), Enum.Material.Metal)
	end
	neon(m, "Eye", Vector3.new(0.7, 0.25, 0.25), CFrame.new(0, 2.0, -1.7), Color3.fromRGB(220, 150, 255))
	for i = 1, 6 do
		local s = (i % 2 == 0) and 1 or -1
		local z = (math.floor((i - 1) / 2) - 1) * 1.0
		place(m, "Leg" .. i, Vector3.new(0.4, 1.6, 0.4), rel(s * 1.5, 0.7, z), Color3.fromRGB(84, 48, 132), Enum.Material.Metal)
	end
	m:SetAttribute("Speed", 6.2)
	m:SetAttribute("Reward", 4)
	m:SetAttribute("CoreDamage", 1)
	m:SetAttribute("Armor", 0.15)
	m:SetAttribute("Air", false)
	return m
end

local function buildMutalisk()
	local m = newModel(enemyFolder, "mutalisk")
	place(m, "Body", Vector3.new(1.8, 1.4, 2.6), rel(0, 6, 0), Color3.fromRGB(199, 79, 199), Enum.Material.Metal)
	place(m, "Head", Vector3.new(1.1, 1.0, 1.4), rel(0, 6.3, -1.6), Color3.fromRGB(220, 110, 220), Enum.Material.Metal)
	neon(m, "Eye", Vector3.new(0.5, 0.22, 0.2), CFrame.new(0, 6.4, -2.3), Color3.fromRGB(255, 190, 255))
	for s = -1, 1, 2 do
		local w = place(m, "Wing" .. s, Vector3.new(3.4, 0.18, 2.2), rel(s * 1.9, 6.1, 0.2, 0, 0, s * 12), Color3.fromRGB(255, 182, 236), Enum.Material.Metal)
		w.Transparency = 0.15
	end
	place(m, "Tail", Vector3.new(0.5, 0.5, 2.4), rel(0, 5.9, 2.2, 18, 0, 0), Color3.fromRGB(156, 63, 156), Enum.Material.Metal)
	m:SetAttribute("Speed", 8.6)
	m:SetAttribute("Reward", 3)
	m:SetAttribute("CoreDamage", 1)
	m:SetAttribute("Air", true)
	return m
end

local function buildBoss()
	local m = newModel(enemyFolder, "boss")
	place(m, "Body", Vector3.new(5.4, 3.6, 7.0), rel(0, 3.6, 0), Color3.fromRGB(156, 48, 56), Enum.Material.Metal)
	place(m, "Head", Vector3.new(3.6, 2.8, 3.4), rel(0, 4.4, -4.2), Color3.fromRGB(176, 74, 80), Enum.Material.Metal)
	place(m, "Jaw", Vector3.new(3.0, 1.4, 2.0), rel(0, 3.2, -5.4), Color3.fromRGB(94, 28, 34), Enum.Material.Metal)
	for s = -1, 1, 2 do
		place(m, "Tusk" .. s, Vector3.new(0.7, 3.6, 0.7), rel(s * 1.6, 4.6, -6.0, 100, 0, s * 18), Color3.fromRGB(232, 214, 176), Enum.Material.Metal)
		neon(m, "Eye" .. s, Vector3.new(0.7, 0.35, 0.3), CFrame.new(s * 1.1, 5.0, -5.7), Color3.fromRGB(255, 130, 60))
	end
	for i = 1, 6 do
		local s = (i % 2 == 0) and 1 or -1
		local z = (math.floor((i - 1) / 2) - 1) * 1.8
		place(m, "Leg" .. i, Vector3.new(0.9, 3.2, 0.9), rel(s * 2.6, 1.4, z), Color3.fromRGB(110, 34, 40), Enum.Material.Metal)
	end
	for i = 1, 4 do
		place(m, "Spike" .. i, Vector3.new(0.8, 2.4, 0.8), rel(-1.8 + i * 1.2, 5.6, 1.6, -18, 0, 0), Color3.fromRGB(124, 33, 41), Enum.Material.Metal)
	end
	m:SetAttribute("Speed", 4.6)
	m:SetAttribute("Reward", 80)
	m:SetAttribute("CoreDamage", 4)
	m:SetAttribute("Armor", 0.12)
	m:SetAttribute("Boss", true)
	m:SetAttribute("Air", false)
	return m
end

buildZergling()
buildHydra()
buildRoach()
buildMutalisk()
buildBoss()

print("[TD] 01_MapAndTurrets 완료 — 아레나 · 패드 " .. (4 * #SLOT_Z) .. "개 · 터렛 10종 · 적 5종 (v" .. Shared.VERSION .. ")")
