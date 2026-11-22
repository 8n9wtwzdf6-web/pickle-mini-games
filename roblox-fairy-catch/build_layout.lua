--[[
  build_layout.lua  ·  매직 하트핑: 요정 캐치 & 하우스
  ------------------------------------------------------------------
  붙여넣는 곳 : Roblox Studio 위쪽 [Command Bar] 한 줄 입력창
  하는 일     : 마법 마을(6구역) + 분수대 + 디저트 카페 + 구름 정원 +
                크리스탈 동굴 + 요정 하우스 4채 + 요정 3D 템플릿을
                한 번에 자동으로 만들어 줍니다. (약 10~20초)

  사용법
    1) Baseplate 새 프로젝트를 엽니다.
    2) View > Command Bar 를 켭니다.
    3) 이 파일 전체를 복사해서 Command Bar 에 붙여넣고 Enter.
    4) "매직 하트핑 월드 생성 완료!" 메시지가 뜨면 성공입니다.

  ※ 다시 실행하면 이전 FairyWorld 폴더를 지우고 새로 만듭니다.
  ※ 이 스크립트는 한 번만 실행하면 됩니다(게임 안에 남지 않습니다).
]]

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- ============================================================
-- 0. 기존 것 정리
-- ============================================================
local oldWorld = Workspace:FindFirstChild("FairyWorld")
if oldWorld ~= nil then
	oldWorld:Destroy()
end
local oldTemplates = ServerStorage:FindFirstChild("FairyTemplates")
if oldTemplates ~= nil then
	oldTemplates:Destroy()
end

local world = Instance.new("Folder")
world.Name = "FairyWorld"
world.Parent = Workspace

local zoneFolder = Instance.new("Folder")
zoneFolder.Name = "Zones"
zoneFolder.Parent = world

local propFolder = Instance.new("Folder")
propFolder.Name = "Props"
propFolder.Parent = world

local plotFolder = Instance.new("Folder")
plotFolder.Name = "FairyHousePlots"
plotFolder.Parent = world

local spawnFolder = Instance.new("Folder")
spawnFolder.Name = "FairySpawnPoints"
spawnFolder.Parent = world

-- ============================================================
-- 1. 도우미 함수
-- ============================================================
local function newPart(name, size, position, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.CanCollide = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function newSphere(name, size, position, color, parent)
	local p = newPart(name, Vector3.new(size, size, size), position, color, Enum.Material.SmoothPlastic, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

local function newCylinder(name, size, position, color, parent)
	local p = newPart(name, size, position, color, Enum.Material.SmoothPlastic, parent)
	p.Shape = Enum.PartType.Cylinder
	p.Orientation = Vector3.new(0, 0, 90)
	return p
end

local function newWedge(name, size, position, color, parent)
	local p = newPart(name, size, position, color, Enum.Material.SmoothPlastic, parent)
	p.Parent = parent
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = p
	return p
end

local function label(part, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(500, 140)
	gui.LightInfluence = 0
	gui.Parent = part

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.Text = text
	tl.TextColor3 = color or Color3.fromRGB(120, 70, 110)
	tl.TextScaled = true
	tl.TextStrokeTransparency = 0.6
	tl.TextStrokeColor3 = Color3.new(1, 1, 1)
	tl.Parent = gui
	return gui
end

local function glow(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 14
	light.Brightness = brightness or 1.2
	light.Parent = part
	return light
end

local function sparkles(part, color, rate)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Rate = rate or 6
	pe.Lifetime = NumberRange.new(0.8, 1.6)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(20, 20)
	pe.Size = NumberSequence.new(0.35)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.LightEmission = 0.6
	pe.Parent = part
	return pe
end

-- ============================================================
-- 2. 바닥
-- ============================================================
local ground = newPart("Ground", Vector3.new(520, 6, 520), Vector3.new(0, -3, 0),
	Color3.fromRGB(196, 238, 186), Enum.Material.Grass, world)
ground.TopSurface = Enum.SurfaceType.Smooth

local pond = newPart("MagicPond", Vector3.new(46, 1, 34), Vector3.new(-118, 0.2, 96),
	Color3.fromRGB(170, 226, 255), Enum.Material.Glass, world)
pond.Transparency = 0.35
pond.CanCollide = false

-- ============================================================
-- 3. 6개 구역
-- ============================================================
local ZONES = {
	{ id = "plaza",   name = "분수대 광장", x = 0,    z = 0,    r = 34, color = Color3.fromRGB(233, 224, 255) },
	{ id = "grass",   name = "풀숲",        x = -95,  z = 62,   r = 36, color = Color3.fromRGB(174, 232, 165) },
	{ id = "flower",  name = "꽃길",        x = -78,  z = -92,  r = 32, color = Color3.fromRGB(255, 208, 232) },
	{ id = "cafe",    name = "디저트 카페", x = 98,   z = -58,  r = 34, color = Color3.fromRGB(255, 220, 196) },
	{ id = "cloud",   name = "구름 정원",   x = 96,   z = 88,   r = 34, color = Color3.fromRGB(230, 220, 255) },
	{ id = "cave",    name = "크리스탈 동굴", x = 0,  z = -136, r = 32, color = Color3.fromRGB(188, 216, 255) },
}

for _, zn in ipairs(ZONES) do
	local disc = newCylinder("Zone_" .. zn.id, Vector3.new(1.2, zn.r * 2, zn.r * 2),
		Vector3.new(zn.x, 0.4, zn.z), zn.color, zoneFolder)
	disc.CanCollide = false
	disc:SetAttribute("ZoneId", zn.id)
	disc:SetAttribute("ZoneName", zn.name)

	-- 구역 표지판
	local sign = newPart("Sign_" .. zn.id, Vector3.new(6, 4, 0.4),
		Vector3.new(zn.x, 5, zn.z + zn.r * 0.72), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, propFolder)
	label(sign, zn.name, Color3.fromRGB(150, 80, 130))

	-- 요정 스폰 지점 (스크립트가 여기 근처에 요정을 만듭니다)
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2
		local sp = newPart("Spawn_" .. zn.id .. "_" .. i, Vector3.new(2, 2, 2),
			Vector3.new(zn.x + math.cos(a) * zn.r * 0.55, 4, zn.z + math.sin(a) * zn.r * 0.55),
			Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, spawnFolder)
		sp.Transparency = 1
		sp.CanCollide = false
		sp:SetAttribute("ZoneId", zn.id)
	end
end

-- ============================================================
-- 4. 분수대
-- ============================================================
local fBase = newCylinder("FountainBase", Vector3.new(2, 30, 30), Vector3.new(0, 1, 0),
	Color3.fromRGB(238, 230, 255), propFolder)
fBase.CanCollide = false
local fWater = newCylinder("FountainWater", Vector3.new(1.6, 26, 26), Vector3.new(0, 1.6, 0),
	Color3.fromRGB(180, 236, 255), propFolder)
fWater.Material = Enum.Material.Glass
fWater.Transparency = 0.25
fWater.CanCollide = false
local fPillar = newCylinder("FountainPillar", Vector3.new(12, 3, 3), Vector3.new(0, 7, 0),
	Color3.fromRGB(250, 245, 255), propFolder)
fPillar.CanCollide = false
local fTop = newCylinder("FountainTop", Vector3.new(1.6, 14, 14), Vector3.new(0, 13, 0),
	Color3.fromRGB(214, 244, 255), propFolder)
fTop.Material = Enum.Material.Glass
fTop.Transparency = 0.3
fTop.CanCollide = false
local splash = newPart("Splash", Vector3.new(2, 2, 2), Vector3.new(0, 14, 0),
	Color3.fromRGB(200, 240, 255), Enum.Material.SmoothPlastic, propFolder)
splash.Transparency = 1
splash.CanCollide = false
local splashEmitter = Instance.new("ParticleEmitter")
splashEmitter.Color = ColorSequence.new(Color3.fromRGB(190, 238, 255))
splashEmitter.Rate = 60
splashEmitter.Lifetime = NumberRange.new(0.5, 1)
splashEmitter.Speed = NumberRange.new(6, 12)
splashEmitter.SpreadAngle = Vector2.new(25, 25)
splashEmitter.Size = NumberSequence.new(0.4)
splashEmitter.Transparency = NumberSequence.new(0.3)
splashEmitter.Parent = splash

-- ============================================================
-- 5. 디저트 카페
-- ============================================================
local cafeX, cafeZ = 98, -58
local cafeBody = newPart("CafeBody", Vector3.new(30, 16, 22), Vector3.new(cafeX, 8, cafeZ),
	Color3.fromRGB(255, 244, 250), Enum.Material.SmoothPlastic, propFolder)
local cafeRoof = newPart("CafeRoof", Vector3.new(34, 2, 26), Vector3.new(cafeX, 17, cafeZ),
	Color3.fromRGB(255, 150, 190), Enum.Material.SmoothPlastic, propFolder)
cafeRoof.CanCollide = false
for i = 1, 6 do
	local stripe = newPart("Awning" .. i, Vector3.new(5, 0.6, 6), Vector3.new(cafeX - 12.5 + (i - 1) * 5, 15, cafeZ + 12.5),
		(i % 2 == 0) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 154, 200),
		Enum.Material.SmoothPlastic, propFolder)
	stripe.CanCollide = false
end
local cafeDoor = newPart("CafeDoor", Vector3.new(6, 9, 0.6), Vector3.new(cafeX + 4, 4.5, cafeZ + 11.2),
	Color3.fromRGB(190, 160, 240), Enum.Material.SmoothPlastic, propFolder)
cafeDoor.CanCollide = false
local cafeWindow = newPart("CafeWindow", Vector3.new(8, 6, 0.4), Vector3.new(cafeX - 7, 9, cafeZ + 11.2),
	Color3.fromRGB(205, 240, 255), Enum.Material.Neon, propFolder)
cafeWindow.CanCollide = false
local cafeSign = newPart("CafeSign", Vector3.new(10, 3.4, 0.4), Vector3.new(cafeX, 12.6, cafeZ + 11.3),
	Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, propFolder)
cafeSign.CanCollide = false
label(cafeSign, "DESSERT", Color3.fromRGB(220, 70, 140))
local cupcake = newSphere("Cupcake", 4, Vector3.new(cafeX - 13, 19.5, cafeZ - 4),
	Color3.fromRGB(255, 210, 120), propFolder)
cupcake.CanCollide = false

-- ============================================================
-- 6. 구름 정원
-- ============================================================
local cloudX, cloudZ = 96, 88
for i = 1, 7 do
	local a = (i / 7) * math.pi * 2
	local c = newSphere("Cloud" .. i, 9 + (i % 3) * 2,
		Vector3.new(cloudX + math.cos(a) * 16, 4 + (i % 3) * 2, cloudZ + math.sin(a) * 12),
		Color3.fromRGB(255, 255, 255), propFolder)
	c.CanCollide = false
	c.Transparency = 0.15
end
local rainbowColors = {
	Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 214, 165), Color3.fromRGB(255, 243, 170),
	Color3.fromRGB(180, 240, 190), Color3.fromRGB(170, 226, 255), Color3.fromRGB(200, 170, 255),
}
for i, col in ipairs(rainbowColors) do
	local arc = newPart("RainbowArc" .. i, Vector3.new(2, 16 + i * 1.5, 2),
		Vector3.new(cloudX, 8 + (i - 1) * 0.6, cloudZ - 18 + i * 1.2), col, Enum.Material.Neon, propFolder)
	arc.CanCollide = false
	arc.Transparency = 0.35
end

-- ============================================================
-- 7. 크리스탈 동굴
-- ============================================================
local caveX, caveZ = 0, -136
for i = 1, 6 do
	local a = (i / 6) * math.pi * 2
	local rock = newSphere("CaveRock" .. i, 20 + (i % 3) * 6,
		Vector3.new(caveX + math.cos(a) * 20, 5, caveZ + math.sin(a) * 14),
		Color3.fromRGB(188, 198, 226), propFolder)
	rock.CanCollide = true
end
local caveMouth = newPart("CaveMouth", Vector3.new(12, 12, 4), Vector3.new(caveX, 6, caveZ + 14),
	Color3.fromRGB(90, 72, 140), Enum.Material.SmoothPlastic, propFolder)
caveMouth.CanCollide = false
for i = 1, 5 do
	local a = (i / 5) * math.pi * 2
	local crystal = newPart("Crystal" .. i, Vector3.new(1.6, 6 + i, 1.6),
		Vector3.new(caveX + math.cos(a) * 26, 3 + i * 0.3, caveZ + math.sin(a) * 18),
		Color3.fromRGB(150, 255, 250), Enum.Material.Neon, propFolder)
	crystal.CanCollide = false
	crystal.Orientation = Vector3.new(0, i * 30, 12)
	glow(crystal, Color3.fromRGB(170, 255, 250), 16, 1.4)
	sparkles(crystal, Color3.fromRGB(220, 255, 255), 4)
end

-- ============================================================
-- 8. 풀숲 · 꽃길 · 나무
-- ============================================================
local function makeTree(x, z, scale)
	local trunk = newCylinder("Trunk", Vector3.new(10 * scale, 2.4 * scale, 2.4 * scale),
		Vector3.new(x, 5 * scale, z), Color3.fromRGB(198, 152, 112), propFolder)
	trunk.Orientation = Vector3.new(0, 0, 0)
	local c1 = newSphere("Leaves", 12 * scale, Vector3.new(x, 13 * scale, z),
		Color3.fromRGB(150, 226, 160), propFolder)
	c1.CanCollide = false
	local c2 = newSphere("Leaves2", 8 * scale, Vector3.new(x + 4 * scale, 17 * scale, z - 2 * scale),
		Color3.fromRGB(180, 240, 180), propFolder)
	c2.CanCollide = false
end

local treeSpots = {
	{ -120, 30 }, { -70, 100 }, { -130, 78 }, { -55, 18 }, { -108, -30 }, { -40, -60 },
	{ 60, 30 }, { 40, -90 }, { 120, -20 }, { 130, 60 }, { 60, 120 }, { -30, 120 },
}
for _, t in ipairs(treeSpots) do
	makeTree(t[1], t[2], 1)
end

local flowerColors = {
	Color3.fromRGB(255, 160, 205), Color3.fromRGB(255, 214, 120),
	Color3.fromRGB(200, 170, 255), Color3.fromRGB(150, 240, 210),
}
for i = 1, 60 do
	local a = (i / 60) * math.pi * 2
	local rad = 20 + (i % 7) * 4
	local x = -78 + math.cos(a) * rad
	local z = -92 + math.sin(a) * rad * 0.8
	local f = newPart("Flower" .. i, Vector3.new(1.2, 1.2, 1.2), Vector3.new(x, 1, z),
		flowerColors[(i % #flowerColors) + 1], Enum.Material.SmoothPlastic, propFolder)
	f.Shape = Enum.PartType.Ball
	f.CanCollide = false
end

for i = 1, 8 do
	local a = (i / 8) * math.pi * 2
	local lamp = newPart("Lamp" .. i, Vector3.new(1, 10, 1),
		Vector3.new(math.cos(a) * 42, 5, math.sin(a) * 42), Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic, propFolder)
	lamp.CanCollide = false
	local bulb = newSphere("Bulb" .. i, 2.2, Vector3.new(math.cos(a) * 42, 10.5, math.sin(a) * 42),
		Color3.fromRGB(255, 236, 170), propFolder)
	bulb.Material = Enum.Material.Neon
	bulb.CanCollide = false
	glow(bulb, Color3.fromRGB(255, 226, 160), 18, 1.6)
end

-- ============================================================
-- 9. 요정 하우스 4채 (실내까지 만드는 파스텔 코티지)
-- ============================================================
local houseSpots = {
	{ 34, 40 }, { -34, 40 }, { 34, -40 }, { -34, -40 },
}
local wallColor = Color3.fromRGB(255, 248, 253)
local mintColor = Color3.fromRGB(127, 230, 205)
local lilacColor = Color3.fromRGB(201, 166, 255)
local pinkColor = Color3.fromRGB(255, 170, 210)
local creamColor = Color3.fromRGB(255, 238, 248)

for i, spot in ipairs(houseSpots) do
	local x, z = spot[1] * 2.2, spot[2] * 2.2
	local plot = Instance.new("Model")
	plot.Name = "FairyHouse_" .. i
	plot.Parent = plotFolder
	plot:SetAttribute("HouseIndex", i)
	plot:SetAttribute("RoomSize", Vector3.new(15, 9, 12))

	local base = newCylinder("PlotBase", Vector3.new(1, 26, 26), Vector3.new(x, 0.6, z),
		Color3.fromRGB(255, 236, 247), zoneFolder)
	base.CanCollide = false
	base:SetAttribute("ZoneId", "plaza")

	-- ---------- 바닥 / 벽 ----------
	local floor = newPart("Floor", Vector3.new(16, 0.6, 13), Vector3.new(x, 1.5, z),
		Color3.fromRGB(255, 226, 240), Enum.Material.SmoothPlastic, plot)
	floor.CanCollide = true

	newPart("WallBack", Vector3.new(16, 9, 0.6), Vector3.new(x, 6, z - 6.2),
		wallColor, Enum.Material.SmoothPlastic, plot)
	newPart("WallLeft", Vector3.new(0.6, 9, 13), Vector3.new(x - 7.7, 6, z),
		wallColor, Enum.Material.SmoothPlastic, plot)
	newPart("WallRight", Vector3.new(0.6, 9, 13), Vector3.new(x + 7.7, 6, z),
		wallColor, Enum.Material.SmoothPlastic, plot)
	-- 앞면은 크게 열어 둡니다 (밖에서도 요정이 노는 모습이 보이도록)
	newPart("WallFrontL", Vector3.new(1.6, 9, 0.6), Vector3.new(x - 7.2, 6, z + 6.2),
		wallColor, Enum.Material.SmoothPlastic, plot)
	newPart("WallFrontR", Vector3.new(1.6, 9, 0.6), Vector3.new(x + 7.2, 6, z + 6.2),
		wallColor, Enum.Material.SmoothPlastic, plot)
	local header = newPart("FrontHeader", Vector3.new(16, 1.4, 0.6), Vector3.new(x, 9.8, z + 6.2),
		wallColor, Enum.Material.SmoothPlastic, plot)
	header.CanCollide = true

	local roof = newWedge("Roof", Vector3.new(18, 5, 15), Vector3.new(x, 12.6, z),
		Color3.fromRGB(255, 160, 205), plot)
	roof.CanCollide = false

	-- 현관 매트
	local mat = newPart("DoorMat", Vector3.new(7, 0.3, 1.6), Vector3.new(x, 1.85, z + 6.7),
		Color3.fromRGB(255, 170, 210), Enum.Material.SmoothPlastic, plot)
	mat.CanCollide = false

	-- 앞면 창문 대신 안쪽 벽에 창문 2개 (밖에서도 보임)
	for _, wx in ipairs({ -4.4, 4.4 }) do
		local win = newPart("Window", Vector3.new(3.4, 3.2, 0.3), Vector3.new(x + wx, 6.6, z - 5.9),
			Color3.fromRGB(205, 244, 255), Enum.Material.Neon, plot)
		win.CanCollide = false
		local sill = newPart("WindowSill", Vector3.new(4, 0.4, 0.8), Vector3.new(x + wx, 4.9, z - 5.8),
			Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, plot)
		sill.CanCollide = false
	end

	-- 하우스 표지판 (앞면 상단에 매답게)
	local sign = newPart("HouseSign", Vector3.new(8, 1.9, 0.4), Vector3.new(x, 8.9, z + 6.45),
		Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, plot)
	sign.CanCollide = false
	label(sign, "요정 하우스 " .. i, Color3.fromRGB(200, 80, 150))
	for _, sx2 in ipairs({ -2.6, 2.6 }) do
		local string_ = newPart("SignString", Vector3.new(0.12, 0.9, 0.12), Vector3.new(x + sx2, 9.5, z + 6.45),
			Color3.fromRGB(224, 185, 117), Enum.Material.SmoothPlastic, plot)
		string_.CanCollide = false
	end

	-- 상호작용 패드 (스크립트가 ProximityPrompt 를 붙입니다)
	local pad = newCylinder("HousePad", Vector3.new(0.6, 7, 7), Vector3.new(x, 1.2, z + 9),
		Color3.fromRGB(255, 220, 240), zoneFolder)
	pad.Material = Enum.Material.Neon
	pad.CanCollide = false
	pad:SetAttribute("HouseIndex", i)
	glow(pad, Color3.fromRGB(255, 200, 235), 12, 0.9)

	-- ---------- 실내 가구 ----------
	local furniture = Instance.new("Folder")
	furniture.Name = "Furniture"
	furniture.Parent = plot

	local function fur(name, size, pos, color, material, collide)
		local p = newPart(name, size, pos, color, material or Enum.Material.SmoothPlastic, furniture)
		p.CanCollide = (collide == true)
		return p
	end
	local function furSphere(name, dia, pos, color, material, collide)
		local p = fur(name, Vector3.new(dia, dia, dia), pos, color, material, collide)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local function furCyl(name, size, pos, color, material, collide)
		local p = fur(name, size, pos, color, material, collide)
		p.Shape = Enum.PartType.Cylinder
		p.Orientation = Vector3.new(0, 0, 90)
		return p
	end

	-- 러그
	furCyl("Rug", Vector3.new(0.3, 9.5, 9.5), Vector3.new(x, 1.95, z), pinkColor)
	furCyl("RugInner", Vector3.new(0.34, 6.4, 6.4), Vector3.new(x, 1.98, z), Color3.fromRGB(255, 235, 245))

	-- 소파 (왼쪽 벽)
	fur("SofaBase", Vector3.new(2.4, 1.2, 5), Vector3.new(x - 5.4, 2.6, z + 1.6), creamColor, nil, true)
	fur("SofaBack", Vector3.new(0.8, 2.4, 5), Vector3.new(x - 6.5, 3.6, z + 1.6), creamColor, nil, true)
	fur("SofaArmA", Vector3.new(2.4, 1.5, 0.7), Vector3.new(x - 5.4, 3.3, z - 1.0), creamColor, nil, true)
	fur("SofaArmB", Vector3.new(2.4, 1.5, 0.7), Vector3.new(x - 5.4, 3.3, z + 4.2), creamColor, nil, true)
	fur("SofaCushionA", Vector3.new(2, 0.5, 2), Vector3.new(x - 5.3, 3.4, z + 0.3), mintColor)
	fur("SofaCushionB", Vector3.new(2, 0.5, 2), Vector3.new(x - 5.3, 3.4, z + 2.9), mintColor)
	local heartPillow = furSphere("HeartPillow", 1.1, Vector3.new(x - 5.2, 4.0, z + 1.2), Color3.fromRGB(255, 150, 200))
	heartPillow.Material = Enum.Material.SmoothPlastic

	-- 티테이블 + 티팟 + 컵
	furCyl("TeaTableTop", Vector3.new(0.4, 4.6, 4.6), Vector3.new(x, 3.4, z + 0.4), Color3.fromRGB(255, 255, 255), nil, true)
	furCyl("TeaTableLeg", Vector3.new(2.4, 0.9, 0.9), Vector3.new(x, 2.2, z + 0.4), Color3.fromRGB(233, 196, 220))
	furSphere("Teapot", 1.5, Vector3.new(x - 0.6, 4.3, z + 0.2), Color3.fromRGB(255, 208, 232))
	furCyl("CupA", Vector3.new(0.7, 0.8, 0.8), Vector3.new(x + 1.1, 3.9, z + 0.9), Color3.fromRGB(255, 255, 255))
	furCyl("CupB", Vector3.new(0.7, 0.8, 0.8), Vector3.new(x + 0.4, 3.9, z - 0.9), Color3.fromRGB(255, 255, 255))

	-- 요정 침대 / 쿠션
	fur("BedBase", Vector3.new(4.6, 0.5, 2.9), Vector3.new(x + 5.1, 2.0, z + 3.2), Color3.fromRGB(255, 255, 255), nil, true)
	fur("BedMattress", Vector3.new(4.3, 0.6, 2.6), Vector3.new(x + 5.1, 2.5, z + 3.2), Color3.fromRGB(255, 226, 244))
	fur("BedPillow", Vector3.new(1.1, 0.5, 1.9), Vector3.new(x + 3.5, 2.9, z + 3.2), Color3.fromRGB(255, 255, 255))
	fur("BedBlanket", Vector3.new(2.4, 0.3, 2.6), Vector3.new(x + 5.9, 2.9, z + 3.2), lilacColor)
	furSphere("BedCushionA", 0.9, Vector3.new(x + 6.6, 2.6, z + 4.0), Color3.fromRGB(255, 208, 232))
	furSphere("BedCushionB", 0.8, Vector3.new(x + 6.4, 2.6, z + 2.4), Color3.fromRGB(255, 240, 180))

	-- 실내 그네
	fur("SwingBeam", Vector3.new(3.4, 0.4, 0.4), Vector3.new(x + 4.6, 9.1, z - 3.8), Color3.fromRGB(233, 196, 220))
	fur("SwingRopeA", Vector3.new(0.16, 4.6, 0.16), Vector3.new(x + 3.4, 6.8, z - 3.8), Color3.fromRGB(224, 185, 117))
	fur("SwingRopeB", Vector3.new(0.16, 4.6, 0.16), Vector3.new(x + 5.8, 6.8, z - 3.8), Color3.fromRGB(224, 185, 117))
	fur("SwingSeat", Vector3.new(2.4, 0.3, 1.3), Vector3.new(x + 4.6, 4.5, z - 3.8), Color3.fromRGB(233, 196, 220), nil, true)
	fur("SwingCushion", Vector3.new(2.1, 0.25, 1.1), Vector3.new(x + 4.6, 4.7, z - 3.8), Color3.fromRGB(255, 208, 232))

	-- 점프 패드 (미니 트램펄린)
	furCyl("JumpPad", Vector3.new(0.5, 4.4, 4.4), Vector3.new(x - 4.4, 2.0, z - 3.9), mintColor, Enum.Material.Neon)
	local padRim = furCyl("JumpPadRim", Vector3.new(0.8, 5.0, 5.0), Vector3.new(x - 4.4, 1.8, z - 3.9), pinkColor)
	padRim.CanCollide = true
	glow(padRim, Color3.fromRGB(127, 230, 205), 14, 1.2)
	for k = 1, 8 do
		local a = (k / 8) * math.pi * 2
		furSphere("Spring" .. k, 0.5, Vector3.new(x - 4.4 + math.cos(a) * 2.4, 1.9, z - 3.9 + math.sin(a) * 2.4),
			Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	end

	-- 간식 테이블
	furCyl("SnackTable", Vector3.new(0.3, 3.2, 3.2), Vector3.new(x + 1.4, 3.3, z - 4.4), Color3.fromRGB(255, 255, 255), nil, true)
	furCyl("SnackLeg", Vector3.new(1.6, 0.9, 0.9), Vector3.new(x + 1.4, 2.2, z - 4.4), Color3.fromRGB(233, 196, 220))
	furCyl("Cake", Vector3.new(1.3, 1.7, 1.7), Vector3.new(x + 1.4, 4.0, z - 4.4), Color3.fromRGB(255, 226, 244))
	furSphere("Cherry", 0.5, Vector3.new(x + 1.4, 4.9, z - 4.4), Color3.fromRGB(255, 95, 150), Enum.Material.Neon)
	furSphere("Strawberry", 0.5, Vector3.new(x - 0.2, 3.7, z - 4.4), Color3.fromRGB(255, 107, 138))

	-- 책장 (앞 왼쪽 구석)
	fur("Bookshelf", Vector3.new(1, 4.4, 3), Vector3.new(x - 6.9, 4.4, z - 2.4), Color3.fromRGB(255, 255, 255), nil, true)
	for b = 1, 4 do
		fur("Book" .. b, Vector3.new(0.8, 0.6, 0.4), Vector3.new(x - 6.6, 3.3 + b * 0.9, z - 3.3 + (b % 3) * 0.5),
			Color3.fromRGB(255, 170, 210 + b * 10))
	end

	-- 반짝이 샹들리에
	fur("ChandelierRod", Vector3.new(0.2, 1.6, 0.2), Vector3.new(x, 9.7, z), Color3.fromRGB(255, 225, 150))
	local bulb = furSphere("ChandelierBulb", 1.4, Vector3.new(x, 8.8, z), Color3.fromRGB(255, 244, 196), Enum.Material.Neon)
	glow(bulb, Color3.fromRGB(255, 236, 170), 22, 2.2)
	for k = 1, 6 do
		local a = (k / 6) * math.pi * 2
		furSphere("Crystal" .. k, 0.45, Vector3.new(x + math.cos(a) * 1.9, 8.4, z + math.sin(a) * 1.9),
			Color3.fromRGB(191, 244, 255), Enum.Material.Neon)
	end

	-- 벽 액자 + 전구 줄
	fur("WallFrame", Vector3.new(4, 3, 0.2), Vector3.new(x, 6.6, z - 5.9), Color3.fromRGB(255, 255, 255))
	fur("WallFrameIn", Vector3.new(3.2, 2.2, 0.24), Vector3.new(x, 6.6, z - 5.85), Color3.fromRGB(255, 214, 236))
	local bulbColors2 = { Color3.fromRGB(255, 209, 102), Color3.fromRGB(255, 158, 203),
		Color3.fromRGB(167, 232, 255), Color3.fromRGB(184, 243, 198) }
	for k = 1, 8 do
		local bulbColor = bulbColors2[(k % 4) + 1]
		furSphere("StringLight" .. k, 0.42, Vector3.new(x - 6.5 + (k - 1) * 1.85, 8.3, z - 5.7), bulbColor, Enum.Material.Neon)
	end

	-- 화분
	furCyl("Pot", Vector3.new(1.2, 1.4, 1.4), Vector3.new(x - 6.6, 2.2, z + 5.2), Color3.fromRGB(224, 185, 117))
	furSphere("Plant", 1.5, Vector3.new(x - 6.6, 3.3, z + 5.2), Color3.fromRGB(142, 214, 135))

	-- 스크립트가 읽는 방 기준점 (보이지 않음)
	local mark = newPart("RoomCenter", Vector3.new(1, 1, 1), Vector3.new(x, 5.4, z),
		Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, plot)
	mark.Transparency = 1
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark:SetAttribute("HouseIndex", i)
end

-- ============================================================
-- 10. 서버 저장소: 요정 3D 템플릿
-- ============================================================
local templates = Instance.new("Folder")
templates.Name = "FairyTemplates"
templates.Parent = ServerStorage

local function makeFairyTemplate(name, rarity, bodyColor, glowColor)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Rarity", rarity)

	local body = newSphere("Body", 2, Vector3.new(0, 0, 0), bodyColor, model)
	body.CanCollide = false
	body.Massless = true

	local head = newSphere("Head", 1.6, Vector3.new(0, 1.4, 0), Color3.fromRGB(255, 232, 222), model)
	head.CanCollide = false
	head.Massless = true

	local wingL = newPart("WingL", Vector3.new(0.2, 2.2, 1.2), Vector3.new(-1.2, 0.6, -0.2), glowColor, Enum.Material.Neon, model)
	wingL.CanCollide = false
	wingL.Massless = true
	wingL.Transparency = 0.35

	local wingR = newPart("WingR", Vector3.new(0.2, 2.2, 1.2), Vector3.new(1.2, 0.6, -0.2), glowColor, Enum.Material.Neon, model)
	wingR.CanCollide = false
	wingR.Massless = true
	wingR.Transparency = 0.35

	local root = newPart("Root", Vector3.new(2, 2, 2), Vector3.new(0, 0, 0), bodyColor, Enum.Material.SmoothPlastic, model)
	root.CanCollide = false
	root.Transparency = 1
	root.Massless = true

	glow(head, glowColor, 16, 1.6)
	sparkles(head, glowColor, 12)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 160, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.Text = name
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0
	tl.TextStrokeColor3 = Color3.fromRGB(90, 40, 90)
	tl.TextScaled = true
	tl.Parent = billboard

	local primary = Instance.new("Attachment")
	primary.Name = "RootAttachment"
	primary.Position = Vector3.new(0, -1.2, 0)
	primary.Parent = root

	local align = Instance.new("BodyPosition")
	align.Name = "Hover"
	align.MaxForce = Vector3.new(0, 0, 0)
	align.Parent = root

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
		end
	end

	model.PrimaryPart = root
	model.Parent = templates
	return model
end

makeFairyTemplate("Fairy_Common", "common", Color3.fromRGB(255, 170, 205), Color3.fromRGB(255, 220, 240))
makeFairyTemplate("Fairy_Rare", "rare", Color3.fromRGB(196, 170, 255), Color3.fromRGB(230, 215, 255))
makeFairyTemplate("Fairy_Legend", "legendary", Color3.fromRGB(255, 214, 120), Color3.fromRGB(255, 245, 190))

-- ============================================================
-- 11. 조명 (파스텔 분위기)
-- ============================================================
Lighting.Ambient = Color3.fromRGB(120, 110, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(190, 180, 210)
Lighting.Brightness = 2.4
Lighting.ClockTime = 14.5
Lighting.GeographicLatitude = 35
Lighting.FogColor = Color3.fromRGB(255, 236, 247)
Lighting.FogEnd = 900
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.3

local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
if atmos == nil then
	atmos = Instance.new("Atmosphere")
	atmos.Parent = Lighting
end
atmos.Color = Color3.fromRGB(255, 236, 250)
atmos.Decay = Color3.fromRGB(200, 190, 235)
atmos.Density = 0.28
atmos.Glare = 0.2
atmos.Haze = 1.4

local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom == nil then
	bloom = Instance.new("BloomEffect")
	bloom.Parent = Lighting
end
bloom.Intensity = 0.6
bloom.Threshold = 1.1
bloom.Size = 24

print("==============================================")
print(" 매직 하트핑 월드 생성 완료!")
print("  · 구역 6개 · 분수대 · 카페 · 구름정원 · 동굴")
print("  · 요정 하우스 4채")
print("  · ServerStorage > FairyTemplates (요정 3D 3종)")
print("==============================================")
