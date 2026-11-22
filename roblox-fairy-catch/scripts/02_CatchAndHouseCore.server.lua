--[[
  02_CatchAndHouseCore.server.lua
  ------------------------------------------------------------------
  붙여넣는 위치 : ServerScriptService  (일반 Script)
  하는 일
    · 마을 6구역에 요정을 랜덤으로 소환 (반짝이며 떠다님)
    · 요정 앞에서 E / 모바일 프롬프트를 누르면 콤팩트 미니게임 시작
      (타이밍 판정은 서버가 계산 → 치트 방지)
    · 포획 성공 시 코인 + 도감 등록 + 따라다니는 요정 친구 소환
    · 내 요정 하우스 상호작용 (밥 5코인 / 놀기 / 쓰다듬기, 친밀도·레벨업)
    · 하우스에 있는 요정들이 초당 코인을 모아 줌 (수확 버튼)

  ※ 01_DataAndMonetization.server.lua 가 먼저 실행되어야 합니다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- 01 스크립트가 준비될 때까지 대기
local waitTime = 0
while shared.FairyData == nil and waitTime < 20 do
	task.wait(0.5)
	waitTime = waitTime + 0.5
end
if shared.FairyData == nil then
	warn("[FairyCatch] 01_DataAndMonetization.server.lua 를 먼저 넣어 주세요!")
	return
end

local PlayerData = shared.FairyData
local remotes = shared.FairyRemotes
local FAIRY_LIST = shared.FairyConfig.FAIRY_LIST
local RARITY = shared.FairyConfig.RARITY
local CONFIG = shared.FairyConfig.CONFIG
local addCoins = shared.FairyAddCoins
local pushHouse = shared.FairyPush
local savePlayer = shared.FairySave

local WORLD = workspace:FindFirstChild("FairyWorld")
if WORLD == nil then
	warn("[FairyCatch] FairyWorld 가 없습니다. build_layout.lua 를 Command Bar 에서 먼저 실행하세요!")
	return
end

local templates = ServerStorage:FindFirstChild("FairyTemplates")
if templates == nil then
	warn("[FairyCatch] ServerStorage > FairyTemplates 가 없습니다. build_layout.lua 를 실행하세요!")
	return
end

-- ==============================================================
-- 0. 공용 테이블
-- ==============================================================
local FAIRY = {}
for _, info in ipairs(FAIRY_LIST) do
	FAIRY[info.id] = info
end

local DECOR = {
	{ id = "rug", name = "하트 러그", price = 120 },
	{ id = "lamp", name = "별빛 스탠드", price = 260 },
	{ id = "curtain", name = "무지개 커튼", price = 420 },
	{ id = "sofa", name = "젤리 소파", price = 680 },
	{ id = "chandelier", name = "크리스탈 샹들리에", price = 1200 },
	{ id = "dessert", name = "디저트 진열장", price = 590 },
	{ id = "horse", name = "유니콘 목마", price = 640 },
	{ id = "shelf", name = "마법 책장", price = 720 },
	{ id = "vanity", name = "공주 화장대", price = 780 },
	{ id = "tub", name = "구름 욕조", price = 860 },
	{ id = "piano", name = "마법 피아노", price = 980 },
	{ id = "tent", name = "별빛 텐트", price = 1120 },
}

-- ==============================================================
-- 0.5 옷 / 악세사리 카탈로그 (01 이 shared 로 넘겨 준 목록을 사용)
-- ==============================================================
local WEAR = {}            -- [id] = { id, name, price, color, trim, kind }
local WEAR_BY_KIND = { dress = {}, head = {}, acc = {} }
do
	local cfgWear = shared.FairyConfig or {}
	local groups = {
		{ kind = "dress", list = cfgWear.DRESSES or {} },
		{ kind = "head", list = cfgWear.HEADS or {} },
		{ kind = "acc", list = cfgWear.ACCS or {} },
	}
	for _, group in ipairs(groups) do
		for _, item in ipairs(group.list) do
			local info = {
				id = item.id, name = item.name, price = item.price,
				color = item.color, trim = item.trim, kind = group.kind,
			}
			WEAR[item.id] = info
			table.insert(WEAR_BY_KIND[group.kind], info)
		end
	end
end

local function findWear(itemId)
	if type(itemId) ~= "string" then
		return nil
	end
	return WEAR[itemId]
end

local wildFairies = {}      -- [model] = { id, rarity, baseCFrame, phase, zone }
local spawnFairyCooldown = 0
local sessions = {}         -- [player] = { ... 미니게임 상태 }
local pets = {}             -- [player] = model
local usedHouses = {}       -- [index] = player

-- ==============================================================
-- 1. 요정 소환
-- ==============================================================
local spawnPoints = {}
local zoneFolder = WORLD:FindFirstChild("Zones")
if zoneFolder ~= nil then
	for _, obj in ipairs(zoneFolder:GetChildren()) do
		if obj:GetAttribute("ZoneId") ~= nil then
			table.insert(spawnPoints, { zone = obj:GetAttribute("ZoneId"), position = obj.Position })
		end
	end
end

local function pickFairyForZone(zoneId)
	local pool = {}
	for _, info in ipairs(FAIRY_LIST) do
		if info.zone == zoneId then
			table.insert(pool, info)
		end
	end
	if #pool == 0 then
		pool = FAIRY_LIST
	end
	-- 희귀도 가중치
	local weights = { common = 42, uncommon = 26, rare = 13, epic = 6, legendary = 2 }
	local total = 0
	for _, info in ipairs(pool) do
		total = total + (weights[info.rarity] or 10)
	end
	local roll = math.random() * total
	for _, info in ipairs(pool) do
		roll = roll - (weights[info.rarity] or 10)
		if roll <= 0 then
			return info
		end
	end
	return pool[1]
end

local function makePrompt(part, fairyName)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "마법 콤팩트!"
	prompt.ObjectText = fairyName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	return prompt
end

local function spawnFairy(zoneId)
	local spot = nil
	if zoneId ~= nil then
		local candidates = {}
		for _, s in ipairs(spawnPoints) do
			if s.zone == zoneId then
				table.insert(candidates, s)
			end
		end
		spot = candidates[math.random(#candidates)]
	else
		spot = spawnPoints[math.random(#spawnPoints)]
	end
	if spot == nil then
		return nil
	end

	local info = pickFairyForZone(spot.zone)
	local rarityInfo = RARITY[info.rarity]
	local template = templates:FindFirstChild(rarityInfo.template) or templates:FindFirstChild("Fairy_Common")
	if template == nil then
		return nil
	end

	local model = template:Clone()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * 14
	local basePos = spot.position + Vector3.new(math.cos(angle) * radius, 4, math.sin(angle) * radius)

	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if root == nil then
		model:Destroy()
		return nil
	end

	model:PivotTo(CFrame.new(basePos))
	model.Name = "Wild_" .. info.id
	model:SetAttribute("FairyId", info.id)
	model:SetAttribute("Rarity", info.rarity)

	local body = model:FindFirstChild("Body")
	if body ~= nil then
		body.Color = info.color
		local prompt = makePrompt(body, info.name)
		prompt.Triggered:Connect(function(player)
			startCatch(player, model)
		end)
	end

	local head = model:FindFirstChild("Head")
	if head ~= nil then
		local tag = head:FindFirstChild("NameTag")
		if tag ~= nil then
			local tl = tag:FindFirstChildOfClass("TextLabel")
			if tl ~= nil then
				tl.Text = info.name
			end
		end
	end

	model.Parent = WORLD
	wildFairies[model] = {
		id = info.id,
		rarity = info.rarity,
		base = basePos,
		phase = math.random() * math.pi * 2,
		zone = spot.zone,
	}

	return model
end

-- ==============================================================
-- 2. 콤팩트 캐치 미니게임 (서버 판정)
-- ==============================================================
local CATCH_TIME = 12

function startCatch(player, model)
	if sessions[player] ~= nil then
		return
	end
	local info = wildFairies[model]
	if info == nil then
		return
	end
	if (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) == nil then
		return
	end

	local rarityInfo = RARITY[info.rarity]
	sessions[player] = {
		model = model,
		fairyId = info.id,
		rarity = info.rarity,
		t0 = workspace:GetServerTimeNow(),
		angle0 = math.random() * 360,
		speed = rarityInfo.speed,
		arcStart = math.random() * 360,
		arcLen = rarityInfo.arc,
		hits = 0,
		need = rarityInfo.hits,
		miss = 0,
		deadline = workspace:GetServerTimeNow() + CATCH_TIME,
	}

	remotes.CatchStart:FireClient(player, {
		fairyId = info.id,
		name = FAIRY[info.id].name,
		rarity = info.rarity,
		rarityLabel = rarityInfo.label,
		color = FAIRY[info.id].color,
		angle0 = sessions[player].angle0,
		arcStart = sessions[player].arcStart,
		arcLen = sessions[player].arcLen,
		speed = sessions[player].speed,
		t0 = sessions[player].t0,
		need = sessions[player].need,
		time = CATCH_TIME,
	})
end

local function currentAngle(session)
	local now = workspace:GetServerTimeNow()
	return (session.angle0 + session.speed * (now - session.t0)) % 360
end

remotes.CatchTap.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if session == nil then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now > session.deadline then
		sessions[player] = nil
		remotes.CatchResult:FireClient(player, { result = "fail" })
		return
	end

	local angle = currentAngle(session)
	local diff = (angle - session.arcStart) % 360
	if diff <= session.arcLen then
		session.hits = session.hits + 1
		session.arcStart = math.random() * 360
		session.arcLen = math.max(20, session.arcLen * 0.93)
		session.speed = session.speed * 1.06
		-- 새 기준 시각/각도로 갱신해야 클라이언트와 어긋나지 않습니다
		session.angle0 = angle
		session.t0 = now

		if session.hits >= session.need then
			local model = session.model
			local fairyId = session.fairyId
			local rarity = session.rarity
			sessions[player] = nil
			-- 정리
			if model ~= nil and model.Parent ~= nil then
				wildFairies[model] = nil
				model:Destroy()
			end
			giveFairy(player, fairyId, rarity)
			return
		end

		remotes.CatchResult:FireClient(player, {
			result = "hit",
			hits = session.hits,
			need = session.need,
			arcStart = session.arcStart,
			arcLen = session.arcLen,
			speed = session.speed,
			angle0 = session.angle0,
			t0 = session.t0,
		})
	else
		session.miss = session.miss + 1
		session.deadline = session.deadline - 1.6
		if session.miss >= 4 or workspace:GetServerTimeNow() > session.deadline then
			sessions[player] = nil
			remotes.CatchResult:FireClient(player, { result = "fail" })
			return
		end
		remotes.CatchResult:FireClient(player, {
			result = "miss",
			miss = session.miss,
			hits = session.hits,
			need = session.need,
			arcStart = session.arcStart,
			arcLen = session.arcLen,
			speed = session.speed,
			angle0 = session.angle0,
			t0 = session.t0,
		})
	end
end)

-- ==============================================================
-- 3. 포획 성공 처리
-- ==============================================================
function giveFairy(player, fairyId, rarityKey)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	local rarityInfo = RARITY[rarityKey] or RARITY.common
	local isNew = data.Fairies[fairyId] == nil
	if isNew then
		data.Fairies[fairyId] = { count = 1, aff = 0, level = 1 }
	else
		data.Fairies[fairyId].count = (data.Fairies[fairyId].count or 1) + 1
	end
	data.Total = (data.Total or 0) + 1

	local gain = rarityInfo.coins
	if data.HasGoldenCompact then
		gain = gain * 2
	end
	if isNew then
		gain = gain + math.floor(rarityInfo.coins * 0.5)
	end
	addCoins(player, gain)

	local stats = player:FindFirstChild("leaderstats")
	if stats ~= nil then
		local fairiesValue = stats:FindFirstChild("Fairies")
		if fairiesValue ~= nil then
			fairiesValue.Value = 0
			for _, _ in pairs(data.Fairies) do
				fairiesValue.Value = fairiesValue.Value + 1
			end
		end
	end

	-- 하우스가 비어 있으면 자동으로 입주
	if #data.House < data.Slots then
		local already = false
		for _, id in ipairs(data.House) do
			if id == fairyId then
				already = true
			end
		end
		if not already then
			table.insert(data.House, fairyId)
		end
	end

	savePlayer(player)
	pushHouse(player)

	remotes.CatchResult:FireClient(player, {
		result = "win",
		fairyId = fairyId,
		name = FAIRY[fairyId].name,
		rarity = rarityKey,
		isNew = isNew,
		coins = gain,
	})

	shared.FairyNotify(player, "✨ " .. FAIRY[fairyId].name .. " 포획 성공! +" .. tostring(gain) .. " 코인")
	startPet(player, fairyId)
end

-- ==============================================================
-- 3.5 요정 코디 (3D 옷 · 머리장식 · 소품 파트 부착)
-- ==============================================================
local WEAR_PREFIX = "Wear_"

local function weldWearPart(root, part)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
end

local function clearWear(model)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and string.sub(child.Name, 1, #WEAR_PREFIX) == WEAR_PREFIX then
			child:Destroy()
		end
	end
end

-- 모델 기준(루트) 좌표로 파트를 붙입니다.  Body 반지름 2 · Head 중심 y=1.4 / 반지름 1.6
local function makeWearPart(model, root, name, size, offset, color, material, shape, transparency, rot)
	local p = Instance.new("Part")
	p.Name = WEAR_PREFIX .. name
	p.Size = size
	p.Color = color or Color3.fromRGB(255, 255, 255)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape ~= nil then
		p.Shape = shape
	end
	local cf = root.CFrame * CFrame.new(offset)
	if rot ~= nil then
		cf = cf * CFrame.Angles(math.rad(rot.X or 0), math.rad(rot.Y or 0), math.rad(rot.Z or 0))
	end
	p.CFrame = cf
	p.Parent = model
	weldWearPart(root, p)
	return p
end

local function buildWear(model, wear)
	local root = model:FindFirstChild("Root")
	if root == nil then
		return
	end
	clearWear(model)
	wear = wear or {}
	local body = model:FindFirstChild("Body")
	local dress = findWear(wear.dress)
	local headItem = findWear(wear.head)
	local acc = findWear(wear.acc)

	-- 원래 몸 색으로 되돌린 뒤 옷 색을 입힙니다
	if body ~= nil then
		local baseColor = model:GetAttribute("BaseColor")
		body.Color = dress and dress.color or baseColor or body.Color
	end
	-- 천사 날개를 달면 원래 날개는 살짝 숨깁니다 (벗으면 원래대로)
	local wingL = model:FindFirstChild("WingL")
	local wingR = model:FindFirstChild("WingR")
	if wingL ~= nil then wingL.Transparency = 0.35 end
	if wingR ~= nil then wingR.Transparency = 0.35 end

	if dress ~= nil then
		local trimColor = dress.trim or dress.color
		local skirt = makeWearPart(model, root, "Skirt", Vector3.new(3.4, 2.2, 3.4), Vector3.new(0, -1.5, 0),
			dress.color, Enum.Material.Fabric, Enum.PartType.Ball)
		skirt:SetAttribute("Kind", "dress")
		makeWearPart(model, root, "SkirtTrim", Vector3.new(3.5, 0.32, 3.5), Vector3.new(0, -2.55, 0),
			trimColor, Enum.Material.Neon, Enum.PartType.Ball)
		if dress.id == "princess" then
			makeWearPart(model, root, "FrillA", Vector3.new(3.6, 0.4, 3.6), Vector3.new(0, -2.1, 0),
				Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			makeWearPart(model, root, "SleeveL", Vector3.new(1.1, 0.9, 1.1), Vector3.new(-1.5, 0.35, 0),
				dress.color, Enum.Material.Fabric, Enum.PartType.Ball)
			makeWearPart(model, root, "SleeveR", Vector3.new(1.1, 0.9, 1.1), Vector3.new(1.5, 0.35, 0),
				dress.color, Enum.Material.Fabric, Enum.PartType.Ball)
		elseif dress.id == "cloak" then
			makeWearPart(model, root, "Cape", Vector3.new(3.9, 3.0, 0.28), Vector3.new(0, -0.35, -1.55),
				Color3.fromRGB(43, 42, 99), Enum.Material.Fabric)
			for i = 1, 5 do
				local sx = -1.4 + (i - 1) * 0.7
				makeWearPart(model, root, "Star" .. i, Vector3.new(0.2, 0.2, 0.2),
					Vector3.new(sx, 0.5 - (i % 3) * 0.5, -1.7),
					Color3.fromRGB(255, 246, 201), Enum.Material.Neon, Enum.PartType.Ball)
			end
		elseif dress.id == "apron" then
			makeWearPart(model, root, "Apron", Vector3.new(1.7, 1.7, 0.2), Vector3.new(0, -1.1, 1.55),
				Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
			makeWearPart(model, root, "ApronHeart", Vector3.new(0.45, 0.45, 0.2), Vector3.new(0, -1.1, 1.68),
				dress.trim or Color3.fromRGB(255, 143, 194), Enum.Material.Neon, Enum.PartType.Ball)
		elseif dress.id == "tutu" then
			for i = 1, 3 do
				makeWearPart(model, root, "Tulle" .. i, Vector3.new(0.22, 4.2 + i * 0.25, 4.2 + i * 0.25),
					Vector3.new(0, -1.2 - i * 0.28, 0),
					(i % 2 == 0) and Color3.fromRGB(255, 255, 255) or dress.color,
					Enum.Material.Fabric, Enum.PartType.Cylinder, 0, Vector3.new(0, 0, 90))
			end
		elseif dress.id == "pajama" then
			for i = 1, 3 do
				makeWearPart(model, root, "Cloud" .. i, Vector3.new(0.55, 0.4, 0.3),
					Vector3.new(-0.8 + i * 0.7, -1.2 - (i % 2) * 0.5, 1.55),
					Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		elseif dress.id == "galaxy" then
			makeWearPart(model, root, "Belt", Vector3.new(0.22, 3.3, 3.3), Vector3.new(0, -0.55, 0),
				dress.trim or Color3.fromRGB(143, 240, 255), Enum.Material.Neon, Enum.PartType.Cylinder, 0, Vector3.new(0, 0, 90))
			for i = 1, 4 do
				local a = (i / 4) * math.pi * 2
				makeWearPart(model, root, "GalaxyStar" .. i, Vector3.new(0.22, 0.22, 0.22),
					Vector3.new(math.cos(a) * 1.35, -0.2 + math.sin(a) * 0.5, math.sin(a) * 1.35),
					Color3.fromRGB(255, 246, 201), Enum.Material.Neon, Enum.PartType.Ball)
			end
		elseif dress.id == "ladybug" then
			for i = 1, 5 do
				local a = (i / 5) * math.pi * 2
				makeWearPart(model, root, "Spot" .. i, Vector3.new(0.4, 0.4, 0.4),
					Vector3.new(math.cos(a) * 1.1, -1.4 + math.sin(a) * 0.45, 1.35 + math.sin(a) * 0.3),
					Color3.fromRGB(30, 20, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end

	if headItem ~= nil then
		local gold = Color3.fromRGB(255, 209, 102)
		if headItem.id == "tiara" then
			makeWearPart(model, root, "TiaraBand", Vector3.new(1.9, 0.22, 0.4), Vector3.new(0, 3.0, 0.25), gold)
			for i, dx in ipairs({ -0.6, 0, 0.6 }) do
				makeWearPart(model, root, "TiaraSpike" .. i, Vector3.new(0.3, 0.55, 0.3),
					Vector3.new(dx, 3.3 + (i == 2 and 0.14 or 0), 0.27), gold, Enum.Material.SmoothPlastic, nil, 0, Vector3.new(0, 45, 0))
			end
			makeWearPart(model, root, "TiaraGem", Vector3.new(0.34, 0.34, 0.34), Vector3.new(0, 3.02, 0.52),
				Color3.fromRGB(255, 95, 168), Enum.Material.Neon, Enum.PartType.Ball)
			makeWearPart(model, root, "TiaraGemB", Vector3.new(0.26, 0.26, 0.26), Vector3.new(-0.6, 3.02, 0.5),
				Color3.fromRGB(143, 240, 255), Enum.Material.Neon, Enum.PartType.Ball)
		elseif headItem.id == "ribbon" then
			for i, dx in ipairs({ -1.05, 1.05 }) do
				makeWearPart(model, root, "RibbonBow" .. i, Vector3.new(1.35, 1.0, 0.5), Vector3.new(dx, 2.95, 0.1),
					Color3.fromRGB(255, 95, 168), Enum.Material.Fabric, Enum.PartType.Ball, 0, Vector3.new(0, 0, (i == 1 and 18 or -18)))
			end
			makeWearPart(model, root, "RibbonKnot", Vector3.new(0.55, 0.55, 0.55), Vector3.new(0, 2.85, 0.2),
				Color3.fromRGB(255, 143, 194), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		elseif headItem.id == "beret" then
			makeWearPart(model, root, "Beret", Vector3.new(2.1, 0.85, 2.1), Vector3.new(0, 3.05, -0.1),
				Color3.fromRGB(183, 156, 255), Enum.Material.Fabric, Enum.PartType.Ball, 0, Vector3.new(0, 0, 6))
			makeWearPart(model, root, "BeretStem", Vector3.new(0.18, 0.35, 0.18), Vector3.new(0, 3.55, -0.1),
				Color3.fromRGB(143, 107, 240))
			makeWearPart(model, root, "BeretDot", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.75, 3.2, 0.55),
				Color3.fromRGB(255, 158, 203), Enum.Material.Neon, Enum.PartType.Ball)
		elseif headItem.id == "flowercrown" then
			local flowerColors = {
				Color3.fromRGB(255, 158, 203), Color3.fromRGB(255, 209, 102),
				Color3.fromRGB(201, 166, 255), Color3.fromRGB(143, 240, 216), Color3.fromRGB(255, 158, 203),
			}
			for i = 1, 5 do
				local a = -1.1 + (i - 1) * 0.55
				makeWearPart(model, root, "Flower" .. i, Vector3.new(0.5, 0.5, 0.5),
					Vector3.new(math.sin(a) * 1.35, 2.55 + math.cos(a) * 0.55, 0.2 + math.cos(a) * 0.2),
					flowerColors[i], Enum.Material.Neon, Enum.PartType.Ball)
			end
			makeWearPart(model, root, "FlowerBand", Vector3.new(0.16, 2.9, 2.9), Vector3.new(0, 2.7, 0),
				Color3.fromRGB(142, 214, 135), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, 0, Vector3.new(0, 0, 90))
		end
	end

	if acc ~= nil then
		if acc.id == "sunglasses" then
			for i, dx in ipairs({ -0.55, 0.55 }) do
				makeWearPart(model, root, "Lens" .. i, Vector3.new(0.78, 0.62, 0.16), Vector3.new(dx, 1.72, 1.55),
					Color3.fromRGB(38, 18, 48), Enum.Material.SmoothPlastic)
			end
			makeWearPart(model, root, "LensBridge", Vector3.new(0.36, 0.12, 0.12), Vector3.new(0, 1.8, 1.55),
				Color3.fromRGB(38, 18, 48))
			makeWearPart(model, root, "LensArmL", Vector3.new(0.5, 0.1, 0.1), Vector3.new(-1.15, 1.82, 1.3),
				Color3.fromRGB(38, 18, 48), Enum.Material.SmoothPlastic, nil, 0, Vector3.new(0, 20, 0))
			makeWearPart(model, root, "LensArmR", Vector3.new(0.5, 0.1, 0.1), Vector3.new(1.15, 1.82, 1.3),
				Color3.fromRGB(38, 18, 48), Enum.Material.SmoothPlastic, nil, 0, Vector3.new(0, -20, 0))
			makeWearPart(model, root, "LensShine", Vector3.new(0.2, 0.12, 0.1), Vector3.new(-0.7, 1.9, 1.63),
				Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		elseif acc.id == "wand" then
			makeWearPart(model, root, "WandRod", Vector3.new(0.14, 2.4, 0.14), Vector3.new(1.9, 1.1, 0.7),
				Color3.fromRGB(255, 209, 102), Enum.Material.SmoothPlastic, nil, 0, Vector3.new(0, 0, 22))
			makeWearPart(model, root, "WandStar", Vector3.new(0.62, 0.62, 0.62), Vector3.new(2.42, 2.35, 0.7),
				Color3.fromRGB(255, 224, 138), Enum.Material.Neon, Enum.PartType.Ball)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 246, 201)
			light.Range = 6
			light.Brightness = 1.2
			light.Parent = model:FindFirstChild("Wear_WandStar")
		elseif acc.id == "angelwing" then
			if wingL ~= nil then wingL.Transparency = 0.88 end
			if wingR ~= nil then wingR.Transparency = 0.88 end
			makeWearPart(model, root, "AngelWingL", Vector3.new(0.24, 3.0, 1.5), Vector3.new(-1.9, 0.9, -1.15),
				Color3.fromRGB(255, 255, 255), Enum.Material.Neon, nil, 0.12, Vector3.new(0, 0, 12))
			makeWearPart(model, root, "AngelWingR", Vector3.new(0.24, 3.0, 1.5), Vector3.new(1.9, 0.9, -1.15),
				Color3.fromRGB(255, 255, 255), Enum.Material.Neon, nil, 0.12, Vector3.new(0, 0, -12))
			makeWearPart(model, root, "AngelCore", Vector3.new(1.0, 1.0, 0.4), Vector3.new(0, 0.9, -1.15),
				Color3.fromRGB(255, 246, 201), Enum.Material.Neon, Enum.PartType.Ball)
		elseif acc.id == "bell" then
			makeWearPart(model, root, "BellCord", Vector3.new(1.5, 0.12, 0.12), Vector3.new(0, -0.05, 1.45),
				Color3.fromRGB(255, 209, 102))
			makeWearPart(model, root, "Bell", Vector3.new(0.55, 0.55, 0.55), Vector3.new(0, -0.35, 1.6),
				Color3.fromRGB(255, 209, 102), Enum.Material.Neon, Enum.PartType.Ball)
		elseif acc.id == "umbrella" then
			makeWearPart(model, root, "UmbrellaRod", Vector3.new(0.12, 3.2, 0.12), Vector3.new(2.0, 1.6, 0.7),
				Color3.fromRGB(201, 166, 255))
			makeWearPart(model, root, "UmbrellaCanopy", Vector3.new(3.0, 1.2, 3.0), Vector3.new(2.0, 3.2, 0.7),
				Color3.fromRGB(255, 158, 203), Enum.Material.Fabric, Enum.PartType.Ball)
			makeWearPart(model, root, "UmbrellaTip", Vector3.new(0.2, 0.4, 0.2), Vector3.new(2.0, 4.0, 0.7),
				Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		end
	end
end
shared.FairyBuildWear = buildWear

-- 착용 순간 머리 위로 반짝 파티클
local function celebrate(model, color)
	local head = model:FindFirstChild("Head")
	local base = head and head.Position or model:GetPivot().Position
	local palette = {
		Color3.fromRGB(255, 255, 255),
		color or Color3.fromRGB(255, 158, 203),
		Color3.fromRGB(255, 224, 138),
		Color3.fromRGB(201, 166, 255),
	}
	for i = 1, 10 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.3, 0.3, 0.3)
		p.Color = palette[(i % #palette) + 1]
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CFrame = CFrame.new(base + Vector3.new(math.random() * 2 - 1, 0.6 + math.random() * 1.4, math.random() * 2 - 1))
		p.Parent = workspace
		local dir = Vector3.new(math.random() * 1.6 - 0.8, 1.4 + math.random(), math.random() * 1.6 - 0.8)
		local tween = TweenService:Create(p, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = p.Position + dir,
			Transparency = 1,
			Size = Vector3.new(0.06, 0.06, 0.06),
		})
		tween:Play()
		Debris:AddItem(p, 0.9)
	end
end
shared.FairyCelebrate = celebrate

-- ==============================================================
-- 4. 따라다니는 요정 친구
-- ==============================================================
function startPet(player, fairyId)
	local old = pets[player]
	if old ~= nil and old.Parent ~= nil then
		old:Destroy()
	end
	local info = FAIRY[fairyId]
	if info == nil then
		return
	end
	local template = templates:FindFirstChild("Fairy_Common")
	local rarityInfo = RARITY[info.rarity]
	if rarityInfo ~= nil then
		template = templates:FindFirstChild(rarityInfo.template) or template
	end
	if template == nil then
		return
	end
	local model = template:Clone()
	model.Name = "Pet_" .. fairyId
	local body = model:FindFirstChild("Body")
	if body ~= nil then
		body.Color = info.color
		local prompt = body:FindFirstChildOfClass("ProximityPrompt")
		if prompt ~= nil then
			prompt:Destroy()
		end
	end
	local head = model:FindFirstChild("Head")
	if head ~= nil then
		local tag = head:FindFirstChild("NameTag")
		if tag ~= nil then
			tag.Enabled = false
		end
	end
	model:SetAttribute("BaseColor", info.color)
	model.Parent = workspace
	if model.PrimaryPart ~= nil then
		model:PivotTo(CFrame.new(player.Character and player.Character:GetPivot().Position or Vector3.new(0, 20, 0)))
	end
	local data = PlayerData[player]
	if data ~= nil and data.Wear ~= nil then
		buildWear(model, data.Wear[fairyId])
	end
	pets[player] = model
end

-- ==============================================================
-- 4.5 하우스 안에서 노는 요정들 (3D 자유 놀이 AI)
-- ==============================================================
local PLOT_FOLDER = WORLD:FindFirstChild("FairyHousePlots")
local houseFolder = WORLD:FindFirstChild("HouseFairies")
if houseFolder == nil then
	houseFolder = Instance.new("Folder")
	houseFolder.Name = "HouseFairies"
	houseFolder.Parent = WORLD
end

local houseGroups = {}      -- [player] = { fairies = {...}, sig = "...", center = Vector3 }
local HOUSE_EMOJI = { "💖", "✨", "🎵", "🍓", "🌸", "☁️" }
-- ==============================================================
-- 4.4 하우스 가구 12종 — 구매하면 실내에 나타납니다
-- ==============================================================
local decorFolders = {}   -- [houseIndex] = Folder

local function buildDecorPieces(plot, houseIndex)
	local mark = plot:FindFirstChild("RoomCenter")
	if mark == nil then
		return nil
	end
	local bx, bz = mark.Position.X, mark.Position.Z
	local fy = 1.8

	local folder = Instance.new("Folder")
	folder.Name = "DecorFurniture"
	folder.Parent = plot

	local function piece(decorId)
		local itemFolder = Instance.new("Folder")
		itemFolder.Name = decorId
		itemFolder.Parent = folder
		return itemFolder
	end
	local function part(parent, name, size, pos, color, material, transparency, rot)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = Vector3.new(bx + pos.X, fy + pos.Y, bz + pos.Z)
		if rot ~= nil then
			p.Orientation = rot
		end
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("Alpha", transparency or 0)
		if parent ~= nil then
			p.Parent = parent
		end
		return p
	end
	local function ball(parent, name, size, pos, color, material, transparency)
		local p = part(parent, name, size, pos, color, material, transparency)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local function disc(parent, name, size, pos, color, material, transparency)
		local p = part(parent, name, size, pos, color, material, transparency, Vector3.new(0, 0, 90))
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	local white = Color3.fromRGB(255, 255, 255)
	local pink = Color3.fromRGB(255, 170, 210)
	local pinkDeep = Color3.fromRGB(255, 95, 168)
	local lilac = Color3.fromRGB(201, 166, 255)
	local purple = Color3.fromRGB(107, 79, 184)
	local deepPurple = Color3.fromRGB(61, 42, 114)
	local mint = Color3.fromRGB(127, 230, 205)
	local cream = Color3.fromRGB(255, 240, 248)
	local wood = Color3.fromRGB(224, 185, 117)
	local gold = Color3.fromRGB(255, 209, 102)

	-- ---------- 마법 피아노 ----------
	local piano = piece("piano")
	part(piano, "Body", Vector3.new(3.0, 0.9, 1.7), Vector3.new(-1.2, 1.25, 4.4), deepPurple)
	part(piano, "Lid", Vector3.new(3.1, 0.16, 1.9), Vector3.new(-1.2, 1.8, 4.35), purple, nil, 0, Vector3.new(-9, 0, 0))
	part(piano, "Keys", Vector3.new(2.4, 0.16, 0.34), Vector3.new(-1.2, 1.76, 5.02), white)
	for k = 1, 5 do
		part(piano, "BlackKey" .. k, Vector3.new(0.13, 0.1, 0.2),
			Vector3.new(-2.1 + (k - 1) * 0.5, 1.82, 5.0), Color3.fromRGB(45, 36, 64))
	end
	for k, lx in ipairs({ -2.45, 0.0, 2.45 }) do
		part(piano, "Leg" .. k, Vector3.new(0.16, 1.1, 0.16), Vector3.new(-1.2 + lx, 0.55, 4.6), purple)
	end
	part(piano, "MusicBook", Vector3.new(0.9, 0.7, 0.08), Vector3.new(-1.2, 2.2, 4.0), cream, nil, 0, Vector3.new(-16, 0, 0))
	ball(piano, "NoteGlow", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-2.4, 2.5, 4.6), Color3.fromRGB(255, 224, 138), Enum.Material.Neon)
	ball(piano, "NoteGlow2", Vector3.new(0.24, 0.24, 0.24), Vector3.new(-2.9, 3.0, 4.4), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)

	-- ---------- 공주 화장대 ----------
	local vanity = piece("vanity")
	part(vanity, "Desk", Vector3.new(2.2, 0.16, 1.0), Vector3.new(-3.6, 1.0, 5.6), white)
	part(vanity, "Drawer", Vector3.new(2.0, 0.7, 0.85), Vector3.new(-3.6, 0.55, 5.55), Color3.fromRGB(255, 226, 240))
	part(vanity, "DrawerLine", Vector3.new(1.8, 0.1, 0.9), Vector3.new(-3.6, 0.6, 5.55), pink)
	part(vanity, "KnobA", Vector3.new(0.14, 0.14, 0.14), Vector3.new(-3.95, 0.6, 5.98), gold)
	part(vanity, "KnobB", Vector3.new(0.14, 0.14, 0.14), Vector3.new(-3.25, 0.6, 5.98), gold)
	part(vanity, "MirrorFrame", Vector3.new(1.8, 1.8, 0.14), Vector3.new(-3.6, 2.05, 5.25), white)
	part(vanity, "MirrorGlass", Vector3.new(1.5, 1.5, 0.16), Vector3.new(-3.6, 2.05, 5.2),
		Color3.fromRGB(214, 240, 255), Enum.Material.Glass, 0.25)
	ball(vanity, "MirrorHeart", Vector3.new(0.45, 0.45, 0.2), Vector3.new(-3.6, 2.05, 5.28), Color3.fromRGB(255, 236, 246), Enum.Material.Neon)
	ball(vanity, "PerfumeA", Vector3.new(0.3, 0.45, 0.3), Vector3.new(-4.2, 1.32, 5.6), lilac)
	ball(vanity, "PerfumeB", Vector3.new(0.26, 0.36, 0.26), Vector3.new(-3.9, 1.28, 5.75), mint)
	ball(vanity, "PerfumeC", Vector3.new(0.34, 0.34, 0.34), Vector3.new(-3.0, 1.28, 5.55), pink)
	part(vanity, "Stool", Vector3.new(0.9, 0.35, 0.9), Vector3.new(-3.6, 0.18, 6.25), Color3.fromRGB(255, 214, 236))

	-- ---------- 마법 책장 ----------
	local shelf = piece("shelf")
	part(shelf, "Back", Vector3.new(1.0, 3.4, 0.18), Vector3.new(7.0, 1.7, -5.5), Color3.fromRGB(255, 233, 246))
	part(shelf, "SideA", Vector3.new(0.18, 3.4, 1.4), Vector3.new(6.55, 1.7, -4.9), cream)
	part(shelf, "SideB", Vector3.new(0.18, 3.4, 1.4), Vector3.new(7.45, 1.7, -4.9), cream)
	for i = 1, 4 do
		part(shelf, "Board" .. i, Vector3.new(1.0, 0.12, 1.3), Vector3.new(7.0, 0.3 + i * 0.75, -4.9), pink)
	end
	local bookColors = { pinkDeep, mint, lilac, gold, Color3.fromRGB(142, 203, 255) }
	for i = 1, 8 do
		part(shelf, "Book" .. i, Vector3.new(0.18, 0.55, 0.5),
			Vector3.new(6.75 + (i % 4) * 0.16, 0.95 + math.floor((i - 1) / 4) * 0.75, -5.05 + (i % 3) * 0.25),
			bookColors[(i % #bookColors) + 1])
	end
	ball(shelf, "ShelfStar", Vector3.new(0.42, 0.42, 0.42), Vector3.new(7.0, 4.5, -4.9), gold, Enum.Material.Neon)

	-- ---------- 디저트 진열장 ----------
	local dessert = piece("dessert")
	part(dessert, "Base", Vector3.new(1.3, 1.1, 1.3), Vector3.new(2.0, 0.55, 5.2), Color3.fromRGB(255, 226, 240))
	part(dessert, "Case", Vector3.new(1.2, 1.5, 1.2), Vector3.new(2.0, 1.9, 5.2),
		Color3.fromRGB(214, 240, 255), Enum.Material.Glass, 0.55)
	part(dessert, "CaseShelf", Vector3.new(1.1, 0.08, 1.1), Vector3.new(2.0, 1.75, 5.2), white)
	ball(dessert, "Cake", Vector3.new(0.6, 0.45, 0.6), Vector3.new(2.0, 1.35, 5.2), Color3.fromRGB(255, 246, 249))
	ball(dessert, "MacaronA", Vector3.new(0.34, 0.22, 0.34), Vector3.new(1.75, 2.15, 5.2), pink)
	ball(dessert, "MacaronB", Vector3.new(0.34, 0.22, 0.34), Vector3.new(2.25, 2.15, 5.2), lilac)
	ball(dessert, "Cupcake", Vector3.new(0.4, 0.5, 0.4), Vector3.new(2.0, 2.75, 5.2), Color3.fromRGB(255, 158, 203))

	-- ---------- 구름 욕조 ----------
	local tub = piece("tub")
	ball(tub, "Basin", Vector3.new(2.4, 1.1, 1.9), Vector3.new(4.2, 0.75, -1.4), Color3.fromRGB(207, 230, 255), Enum.Material.SmoothPlastic)
	disc(tub, "Rim", Vector3.new(0.16, 2.5, 2.5), Vector3.new(4.2, 1.25, -1.4), white)
	ball(tub, "BubbleA", Vector3.new(0.6, 0.5, 0.6), Vector3.new(3.6, 1.35, -1.1), white)
	ball(tub, "BubbleB", Vector3.new(0.5, 0.45, 0.5), Vector3.new(4.3, 1.4, -1.6), white)
	ball(tub, "BubbleC", Vector3.new(0.55, 0.48, 0.55), Vector3.new(4.8, 1.35, -1.0), white)
	ball(tub, "Duck", Vector3.new(0.42, 0.4, 0.42), Vector3.new(4.0, 1.5, -1.2), gold, Enum.Material.SmoothPlastic)
	part(tub, "Faucet", Vector3.new(0.16, 0.8, 0.16), Vector3.new(5.2, 1.6, -1.4), lilac)
	part(tub, "FaucetHead", Vector3.new(0.36, 0.18, 0.36), Vector3.new(5.2, 2.0, -1.4), mint, Enum.Material.Neon)

	-- ---------- 별빛 텐트 ----------
	local tent = piece("tent")
	part(tent, "Mat", Vector3.new(2.6, 0.1, 2.6), Vector3.new(6.4, 0.05, -1.6), Color3.fromRGB(255, 226, 246))
	part(tent, "TentL", Vector3.new(0.16, 2.8, 2.6), Vector3.new(5.3, 1.4, -1.6),
		Color3.fromRGB(91, 75, 158), nil, 0, Vector3.new(0, 0, 16))
	part(tent, "TentR", Vector3.new(0.16, 2.8, 2.6), Vector3.new(7.5, 1.4, -1.6),
		Color3.fromRGB(91, 75, 158), nil, 0, Vector3.new(0, 0, -16))
	part(tent, "TentBack", Vector3.new(2.4, 2.6, 0.16), Vector3.new(6.4, 1.3, -2.8), Color3.fromRGB(47, 42, 99))
	part(tent, "Pole", Vector3.new(0.12, 3.4, 0.12), Vector3.new(6.4, 1.7, -1.6), wood)
	part(tent, "Flag", Vector3.new(0.9, 0.5, 0.08), Vector3.new(6.85, 3.2, -1.6), pinkDeep, Enum.Material.Neon)
	ball(tent, "CushionA", Vector3.new(0.8, 0.3, 0.8), Vector3.new(6.0, 0.25, -1.4), Color3.fromRGB(255, 194, 226))
	ball(tent, "CushionB", Vector3.new(0.7, 0.28, 0.7), Vector3.new(6.9, 0.25, -1.9), lilac)
	for i = 1, 4 do
		ball(tent, "Light" .. i, Vector3.new(0.22, 0.22, 0.22),
			Vector3.new(5.55 + (i - 1) * 0.58, 2.2 + (i % 2) * 0.2, -0.6),
			(i % 2 == 0) and gold or pinkDeep, Enum.Material.Neon)
	end

	-- ---------- 유니콘 목마 ----------
	local horse = piece("horse")
	part(horse, "RockA", Vector3.new(2.2, 0.14, 0.3), Vector3.new(-5.2, 0.12, 4.65), Color3.fromRGB(216, 168, 208), nil, 0, Vector3.new(0, 0, 4))
	part(horse, "RockB", Vector3.new(2.2, 0.14, 0.3), Vector3.new(-5.2, 0.12, 5.35), Color3.fromRGB(216, 168, 208), nil, 0, Vector3.new(0, 0, -4))
	for i, lx in ipairs({ -5.75, -4.65 }) do
		part(horse, "Leg" .. i, Vector3.new(0.16, 1.1, 0.16), Vector3.new(lx, 0.65, 5.0), white)
	end
	ball(horse, "Body", Vector3.new(1.9, 1.3, 1.3), Vector3.new(-5.2, 1.5, 5.0), white, Enum.Material.SmoothPlastic)
	ball(horse, "Head", Vector3.new(0.85, 0.85, 0.85), Vector3.new(-4.35, 2.15, 5.0), white, Enum.Material.SmoothPlastic)
	part(horse, "Horn", Vector3.new(0.16, 0.6, 0.16), Vector3.new(-4.2, 2.75, 5.0), gold, Enum.Material.Neon, 0, Vector3.new(0, 0, 18))
	part(horse, "Mane", Vector3.new(0.3, 0.9, 0.9), Vector3.new(-4.9, 2.25, 5.0), pink)
	part(horse, "Saddle", Vector3.new(0.9, 0.2, 1.0), Vector3.new(-5.2, 2.2, 5.0), lilac)
	part(horse, "Tail", Vector3.new(0.3, 0.8, 0.3), Vector3.new(-6.1, 1.65, 5.0), pink)
	ball(horse, "Eye", Vector3.new(0.14, 0.14, 0.14), Vector3.new(-4.2, 2.2, 5.35), Color3.fromRGB(58, 33, 64))

	decorFolders[houseIndex] = folder
	return folder
end

local function ensureDecor(plot, houseIndex)
	local cached = decorFolders[houseIndex]
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	return buildDecorPieces(plot, houseIndex)
end

local function refreshDecorFor(player)
	local houseIndex = player:GetAttribute("HouseIndex")
	if houseIndex == nil then
		return
	end
	local plot = PLOT_FOLDER and PLOT_FOLDER:FindFirstChild("FairyHouse_" .. tostring(houseIndex))
	if plot == nil then
		return
	end
	local folder = ensureDecor(plot, houseIndex)
	if folder == nil then
		return
	end
	local data = PlayerData[player]
	local owned = (data and data.Decor) or {}
	for _, item in ipairs(folder:GetChildren()) do
		local on = owned[item.Name] == true
		for _, obj in ipairs(item:GetDescendants()) do
			if obj:IsA("BasePart") then
				local alpha = obj:GetAttribute("Alpha") or 0
				obj.Transparency = on and alpha or 1
			end
		end
	end
end
shared.FairyRefreshDecor = refreshDecorFor

local HOUSE_SPOTS = {
	{ off = Vector3.new(-5.0, 0, 2.0), bubble = "🛋️" },                              -- 소파
	{ off = Vector3.new(5.0, 0, 3.0), bubble = "😴" },                                -- 침대
	{ off = Vector3.new(4.6, 0, -3.8), bubble = "✨" },                               -- 그네
	{ off = Vector3.new(-4.4, 0, -3.8), bubble = "🎪" },                              -- 점프 패드
	{ off = Vector3.new(1.4, 0, -4.4), bubble = "🍰" },                               -- 간식 테이블
	{ off = Vector3.new(-1.2, 0, 3.2), bubble = "🎵", decor = "piano" },              -- 마법 피아노
	{ off = Vector3.new(4.2, 0, 0.2), bubble = "🛁", decor = "tub" },                 -- 구름 욕조
	{ off = Vector3.new(-3.6, 0, 4.2), bubble = "💄", decor = "vanity" },             -- 공주 화장대
	{ off = Vector3.new(-5.2, 0, 3.6), bubble = "🦄", decor = "horse" },              -- 유니콘 목마
	{ off = Vector3.new(2.0, 0, 4.0), bubble = "🍰", decor = "dessert" },             -- 디저트 진열장
	{ off = Vector3.new(6.2, 0, 0.4), bubble = "✨", decor = "tent" },               -- 별빛 텐트
}

-- 구매한 가구에만 놀러 가도록 거르기
local function houseSpotsFor(data)
	local list = {}
	local owned = (data and data.Decor) or {}
	for _, spot in ipairs(HOUSE_SPOTS) do
		if spot.decor == nil or owned[spot.decor] == true then
			table.insert(list, spot)
		end
	end
	if #list == 0 then
		return HOUSE_SPOTS
	end
	return list
end

local function plotMark(houseIndex)
	if PLOT_FOLDER == nil or houseIndex == nil then
		return nil
	end
	local plot = PLOT_FOLDER:FindFirstChild("FairyHouse_" .. tostring(houseIndex))
	if plot == nil then
		return nil
	end
	return plot:FindFirstChild("RoomCenter")
end

local function pickEmoji()
	return HOUSE_EMOJI[math.random(#HOUSE_EMOJI)]
end

local function makeHouseFairyModel(fairyId, wear)
	local info = FAIRY[fairyId]
	if info == nil then
		return nil
	end
	local rarityInfo = RARITY[info.rarity] or RARITY.common
	local template = templates:FindFirstChild(rarityInfo.template) or templates:FindFirstChild("Fairy_Common")
	if template == nil then
		return nil
	end
	local model = template:Clone()
	model.Name = "HouseFairy_" .. fairyId
	model:SetAttribute("FairyId", fairyId)
	model:SetAttribute("Rarity", info.rarity)

	model:SetAttribute("BaseColor", info.color)

	local body = model:FindFirstChild("Body")
	if body ~= nil then
		body.Color = info.color
		local oldPrompt = body:FindFirstChildOfClass("ProximityPrompt")
		if oldPrompt ~= nil then
			oldPrompt:Destroy()
		end
		body.CanCollide = false
	end
	-- 코디한 옷·악세사리를 3D 파트로 붙입니다
	buildWear(model, wear)

	local head = model:FindFirstChild("Head")
	if head ~= nil then
		local tag = head:FindFirstChild("NameTag")
		if tag ~= nil then
			tag.Size = UDim2.new(0, 120, 0, 30)
			tag.StudsOffset = Vector3.new(0, 2.0, 0)
		end
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "SpeechBubble"
		bubble.Size = UDim2.new(0, 54, 0, 54)
		bubble.StudsOffset = Vector3.new(0, 3.2, 0)
		bubble.AlwaysOnTop = true
		bubble.Enabled = false
		bubble.Parent = head

		local lbl = Instance.new("TextLabel")
		lbl.Name = "BubbleText"
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		lbl.BackgroundTransparency = 0.05
		lbl.Text = ""
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = Color3.fromRGB(180, 60, 120)
		lbl.Parent = bubble

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 18)
		corner.Parent = lbl
	end

	model.Parent = houseFolder
	return model
end

local function houseSignature(data)
	local parts = {}
	for _, id in ipairs(data.House) do
		local wear = data.Wear and data.Wear[id]
		if wear ~= nil then
			table.insert(parts, id .. ":" .. tostring(wear.dress) .. "/" .. tostring(wear.head) .. "/" .. tostring(wear.acc))
		else
			table.insert(parts, id)
		end
	end
	return table.concat(parts, ",")
end

local function showBubble(f, text)
	f.bubbleText = text
	f.bubbleT = 1.9
	local head = f.model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("SpeechBubble")
	if gui ~= nil then
		local lbl = gui:FindFirstChild("BubbleText")
		if lbl ~= nil then
			lbl.Text = text
		end
		gui.Enabled = true
	end
end

local function chooseHouseAction(f, center, data)
	local r = math.random()
	if r < 0.48 then
		f.target = center + Vector3.new(math.random() * 10 - 5, 0, math.random() * 8 - 4)
		f.mode = "wander"
		f.timer = 1.4 + math.random() * 2.2
	elseif r < 0.68 then
		f.target = center + Vector3.new(math.random() * 9 - 4.5, 0, math.random() * 7 - 3.5)
		f.mode = "wander"
		f.jumpV = 11 + math.random() * 5
		f.jump = 0.05
		f.timer = 1.2 + math.random() * 1.4
	elseif r < 0.82 then
		f.target = center + Vector3.new(math.random() * 8 - 4, 0, math.random() * 6 - 3)
		f.mode = "wander"
		f.spinT = 0.8 + math.random() * 0.7
		f.timer = 0.9 + math.random() * 0.8
	else
		local list = houseSpotsFor(data)
		local spot = list[math.random(#list)]
		f.target = center + spot.off
		f.mode = "goto"
		f.timer = 7
		f.spot = spot
	end
end

local function refreshHouseFairies(player)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	local mark = plotMark(player:GetAttribute("HouseIndex"))
	if mark == nil then
		return
	end
	local center = mark.Position
	refreshDecorFor(player)
	local sig = houseSignature(data) .. "|" .. tostring(player:GetAttribute("HouseIndex"))
	local group = houseGroups[player]
	if group ~= nil and group.sig == sig then
		group.center = center
		return
	end
	if group ~= nil then
		for _, f in ipairs(group.fairies) do
			if f.model.Parent ~= nil then
				f.model:Destroy()
			end
		end
	end

	group = { fairies = {}, sig = sig, center = center }
	houseGroups[player] = group

	local total = math.max(1, #data.House)
	for index, fairyId in ipairs(data.House) do
		local model = makeHouseFairyModel(fairyId, data.Wear and data.Wear[fairyId])
		if model ~= nil then
			local a = ((index - 1) / total) * math.pi * 2
			local pos = center + Vector3.new(math.cos(a) * 3.2, 0, math.sin(a) * 2.6)
			local f = {
				id = fairyId,
				model = model,
				pos = pos,
				target = pos,
				speed = 2.0 + math.random() * 1.0,
				mode = "wander",
				timer = 1.5 + math.random() * 2,
				jump = 0,
				jumpV = 0,
				yaw = math.random() * math.pi * 2,
				spinT = 0,
				bubbleT = 0,
				bubbleText = "",
				meet = 0,
				phase = math.random() * math.pi * 2,
				spot = nil,
			}
			model:PivotTo(CFrame.new(pos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, f.yaw, 0))
			table.insert(group.fairies, f)
		end
	end
end
shared.FairyRefreshHouse = refreshHouseFairies

local function updateHouseFairies(dt, now)
	for player, group in pairs(houseGroups) do
		local center = group.center
		local data = PlayerData[player]
		for _, f in ipairs(group.fairies) do
			if f.model.Parent ~= nil then
			-- 점프
			if f.jumpV ~= 0 or f.jump > 0 then
				f.jump = f.jump + f.jumpV * dt
				f.jumpV = f.jumpV - 22 * dt
				if f.jump <= 0 then
					f.jump = 0
					f.jumpV = 0
				end
			end
			-- 빙글 회전
			if f.spinT > 0 then
				f.spinT = f.spinT - dt
				f.yaw = f.yaw + dt * 8
			end
			f.timer = f.timer - dt
			f.bubbleT = math.max(0, f.bubbleT - dt)
			f.meet = math.max(0, f.meet - dt)

			local flat = Vector3.new(f.target.X - f.pos.X, 0, f.target.Z - f.pos.Z)
			local dist = flat.Magnitude
			if f.mode == "rest" then
				if f.timer <= 0 then
					chooseHouseAction(f, center, data)
				end
			else
				if dist > 0.35 then
					local step = math.min(dist, f.speed * dt)
					local dir = flat.Unit
					f.pos = f.pos + dir * step
					f.yaw = math.atan2(dir.X, dir.Z)
					if f.spinT <= 0 then
						f.yaw = f.yaw + math.sin(now * 3 + f.phase) * 0.25
					end
				else
					if f.mode == "goto" then
						f.mode = "rest"
						f.timer = 2.4 + math.random() * 2.6
						showBubble(f, (f.spot and f.spot.bubble) or pickEmoji())
					else
						chooseHouseAction(f, center, data)
					end
				end
			end

			-- 벽 밖으로 나가지 않게
			f.pos = Vector3.new(
				math.clamp(f.pos.X, center.X - 6.6, center.X + 6.6),
				f.pos.Y,
				math.clamp(f.pos.Z, center.Z - 4.9, center.Z + 4.9)
			)

			local hover = center.Y - 2.2 + math.sin(now * 2 + f.phase) * 0.22 + f.jump
			f.model:PivotTo(CFrame.new(Vector3.new(f.pos.X, hover, f.pos.Z)) * CFrame.Angles(0, f.yaw, 0))

			if f.bubbleT <= 0 then
				local head = f.model:FindFirstChild("Head")
				local gui = head and head:FindFirstChild("SpeechBubble")
				if gui ~= nil and gui.Enabled then
					gui.Enabled = false
				end
			end
			end
		end

		-- 요정끼리 마주치면 말풍선으로 교감
		local list = group.fairies
		for i = 1, #list do
			for j = i + 1, #list do
				local a = list[i]
				local b = list[j]
				if a.meet <= 0 and b.meet <= 0 then
					local d = (a.pos - b.pos).Magnitude
					if d < 3.2 then
						a.meet = 4.2
						b.meet = 4.2
						showBubble(a, pickEmoji())
						showBubble(b, pickEmoji())
						a.spinT = 0.7
						b.spinT = 0.7
					end
				end
			end
		end
	end
end

-- ==============================================================
-- 5. 하우스 상호작용
-- ==============================================================
local ACTION_CONFIG = {
	feed = { cooldown = 45, aff = 12, cost = 5 },
	play = { cooldown = 75, aff = 18, cost = 0 },
	pet = { cooldown = 20, aff = 7, cost = 0 },
}

local function assignHouse(player)
	for index, owner in pairs(usedHouses) do
		if owner == player then
			return index
		end
	end
	for index = 1, 4 do
		if usedHouses[index] == nil then
			usedHouses[index] = player
			return index
		end
	end
	return 1
end

local zonePartsFolder = WORLD:FindFirstChild("Zones")
local housePads = {}
if zonePartsFolder ~= nil then
	for _, obj in ipairs(zonePartsFolder:GetChildren()) do
		if obj.Name == "HousePad" and obj:GetAttribute("HouseIndex") ~= nil then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "하우스 메뉴"
			prompt.ObjectText = "내 요정 하우스 · 문으로 직접 들어가도 돼요"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.Parent = obj

			local houseIndex = obj:GetAttribute("HouseIndex")
			prompt.Triggered:Connect(function(player)
				local myHouse = player:GetAttribute("HouseIndex") or 1
				if myHouse ~= houseIndex then
					shared.FairyNotify(player, "여기는 " .. tostring(houseIndex) .. "번 하우스예요! 내 하우스는 " .. tostring(myHouse) .. "번이에요")
					return
				end
				pushHouse(player)
				remotes.RequestHouse:FireClient(player, true)
			end)
		end
	end
end

-- ==============================================================
-- 6. 액션 / 수확 / 꾸미기
-- ==============================================================
remotes.FairyAction.OnServerEvent:Connect(function(player, fairyId, action)
	local data = PlayerData[player]
	if data == nil or data.Fairies[fairyId] == nil then
		return
	end
	local cfg = ACTION_CONFIG[action]
	if cfg == nil then
		return
	end

	data.Cool = data.Cool or {}
	data.Cool[fairyId] = data.Cool[fairyId] or {}
	local now = os.time()
	local ready = data.Cool[fairyId][action] or 0
	if now < ready then
		shared.FairyNotify(player, "아직 쉬는 중이에요! " .. tostring(ready - now) .. "초")
		return
	end
	if cfg.cost > 0 and data.Coins < cfg.cost then
		shared.FairyNotify(player, "코인이 모자라요 🪙")
		return
	end
	if cfg.cost > 0 then
		addCoins(player, -cfg.cost)
	end

	data.Cool[fairyId][action] = now + cfg.cooldown
	local fairyData = data.Fairies[fairyId]
	fairyData.aff = math.min(100, (fairyData.aff or 0) + cfg.aff)

	if fairyData.aff >= 100 then
		fairyData.level = (fairyData.level or 1) + 1
		fairyData.aff = 12
		local bonus = 12 * fairyData.level
		addCoins(player, bonus)
		shared.FairyNotify(player, "🎉 " .. FAIRY[fairyId].name .. " Lv." .. tostring(fairyData.level) .. " 달성! +" .. tostring(bonus) .. "코인")
	else
		shared.FairyNotify(player, "💗 " .. FAIRY[fairyId].name .. " 친밀도 +" .. tostring(cfg.aff))
	end

	-- 하우스 안 요정이 반응 (하트·점프·빙글)
	local group = houseGroups[player]
	if group ~= nil then
		for _, f in ipairs(group.fairies) do
			if f.id == fairyId then
				if action == "play" then
					f.jumpV = 15
					f.spinT = 1.1
					showBubble(f, "🎈")
				elseif action == "feed" then
					f.jumpV = 12
					showBubble(f, "🍰")
				else
					f.jumpV = 9
					showBubble(f, "💗")
				end
				f.jump = math.max(f.jump, 0.05)
			end
		end
	end

	savePlayer(player)
	pushHouse(player)
end)

remotes.Harvest.OnServerEvent:Connect(function(player)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	local amount = math.floor(data.Pending or 0)
	if amount < 5 then
		shared.FairyNotify(player, "코인이 조금만 더 모이면 받을 수 있어요")
		return
	end
	data.Pending = data.Pending - amount
	addCoins(player, amount)
	savePlayer(player)
	pushHouse(player)
	shared.FairyNotify(player, "🪙 " .. tostring(amount) .. " 코인 수확!")
end)

remotes.BuyDecor.OnServerEvent:Connect(function(player, decorId)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	local item = nil
	for _, d in ipairs(DECOR) do
		if d.id == decorId then
			item = d
		end
	end
	if item == nil then
		return
	end
	data.Decor = data.Decor or {}
	if data.Decor[decorId] then
		shared.FairyNotify(player, "이미 가지고 있어요")
		return
	end
	if data.Coins < item.price then
		shared.FairyNotify(player, "코인이 모자라요 🪙")
		return
	end
	addCoins(player, -item.price)
	data.Decor[decorId] = true
	savePlayer(player)
	pushHouse(player)
	refreshDecorFor(player)
	shared.FairyNotify(player, "🎀 " .. item.name .. " 설치 완료! 하우스 안에 나타났어요")
end)

remotes.BuyWear.OnServerEvent:Connect(function(player, itemId)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	local item = findWear(itemId)
	if item == nil then
		return
	end
	data.Owned = data.Owned or {}
	if data.Owned[itemId] then
		shared.FairyNotify(player, "이미 가지고 있어요 · 하우스 코디에서 입힐 수 있어요")
		return
	end
	if data.Coins < item.price then
		shared.FairyNotify(player, "코인이 모자라요 🪙")
		return
	end
	addCoins(player, -item.price)
	data.Owned[itemId] = true
	savePlayer(player)
	pushHouse(player)
	shared.FairyNotify(player, "🛍️ " .. item.name .. " 구매! 하우스 코디 창에서 바로 입혀 보세요")
end)

remotes.SetWear.OnServerEvent:Connect(function(player, fairyId, slot, itemId)
	local data = PlayerData[player]
	if data == nil or type(fairyId) ~= "string" then
		return
	end
	if slot ~= "dress" and slot ~= "head" and slot ~= "acc" then
		return
	end
	local inHouse = false
	for _, id in ipairs(data.House) do
		if id == fairyId then
			inHouse = true
		end
	end
	if not inHouse then
		return
	end
	data.Owned = data.Owned or {}
	local item = nil
	if itemId ~= nil and itemId ~= "" then
		item = findWear(itemId)
		if item == nil or item.kind ~= slot or not data.Owned[itemId] then
			return
		end
	end
	data.Wear = data.Wear or {}
	local wear = data.Wear[fairyId] or {}
	wear[slot] = item and item.id or nil
	data.Wear[fairyId] = wear
	savePlayer(player)
	pushHouse(player)
	refreshHouseFairies(player)

	local group = houseGroups[player]
	if group ~= nil then
		for _, f in ipairs(group.fairies) do
			if f.id == fairyId and f.model.Parent ~= nil then
				celebrate(f.model, item and item.color or nil)
			end
		end
	end
	local pet = pets[player]
	if pet ~= nil and pet.Parent ~= nil and pet.Name == "Pet_" .. fairyId then
		buildWear(pet, wear)
		celebrate(pet, item and item.color or nil)
	end
	local fairyName = FAIRY[fairyId] and FAIRY[fairyId].name or "요정"
	if item ~= nil then
		shared.FairyNotify(player, "✨ " .. fairyName .. "에게 " .. item.name .. " 착용!")
	else
		shared.FairyNotify(player, "🧺 " .. fairyName .. "의 코디를 벗겼어요")
	end
end)

remotes.RequestHouse.OnServerEvent:Connect(function(player)
	pushHouse(player)
end)

-- ==============================================================
-- 7. 루프 (요정 떠다니기 · 펫 따라오기 · 코인 모으기 · 소환)
-- ==============================================================
local spawnTimer = 0

RunService.Heartbeat:Connect(function(dt)
	local now = workspace:GetServerTimeNow()

	-- 요정 둥실둥실
	for model, info in pairs(wildFairies) do
		if model.Parent == nil then
			wildFairies[model] = nil
		else
			local bob = math.sin(now * 2 + info.phase) * 0.6
			local swayX = math.cos(now * 0.8 + info.phase) * 0.8
			model:PivotTo(CFrame.new(info.base + Vector3.new(swayX, 4 + bob, 0)))
		end
	end

	-- 펫 따라오기
	for player, model in pairs(pets) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or model.Parent == nil then
			if model.Parent ~= nil then
				model:Destroy()
			end
			pets[player] = nil
		else
			local target = root.CFrame * CFrame.new(-2.6, 2.2, -1.6)
			local current = model:GetPivot()
			local newPos = current.Position:Lerp(target.Position + Vector3.new(0, math.sin(now * 3) * 0.35, 0), math.min(1, dt * 4))
			model:PivotTo(CFrame.new(newPos))
		end
	end

	-- 하우스 안 요정들 자유 놀이
	updateHouseFairies(dt, now)

	-- 초당 코인
	spawnTimer = spawnTimer + dt
	if spawnTimer >= 1 then
		spawnTimer = 0
		for player, data in pairs(PlayerData) do
			refreshHouseFairies(player)
			local rate = 0
			for _, fairyId in ipairs(data.House) do
				local fd = data.Fairies[fairyId]
				if fd ~= nil then
					rate = rate + (0.05 + 0.016 * (fd.level or 1)) * (0.35 + (fd.aff or 0) / 100)
				end
			end
			if rate > 0 and (data.Pending or 0) < 600 then
				data.Pending = math.min(600, (data.Pending or 0) + rate)
			end
		end
	end

	-- 요정 소환
	if #wildFairies < 8 then
		spawnFairyCooldown = (spawnFairyCooldown or 0) + dt
		if spawnFairyCooldown > 6 then
			spawnFairyCooldown = 0
			spawnFairy()
		end
	end
end)

-- 이미 접속해 있던 플레이어도 하우스 배정
for _, player in ipairs(Players:GetPlayers()) do
	if player:GetAttribute("HouseIndex") == nil then
		player:SetAttribute("HouseIndex", assignHouse(player))
	end
	refreshDecorFor(player)
end

-- 접속/퇴장 처리
Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("HouseIndex", assignHouse(player))
	refreshDecorFor(player)
	task.wait(2)
	-- 첫 요정을 하우스에 넣어 주기 (빈 하우스 방지)
	local data = PlayerData[player]
	if data ~= nil and #data.House == 0 then
		shared.FairyNotify(player, "🏠 마법 콤팩트로 요정을 잡아 하우스에 초대해 보세요!")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for index, owner in pairs(usedHouses) do
		if owner == player then
			usedHouses[index] = nil
		end
	end
	local pet = pets[player]
	if pet ~= nil and pet.Parent ~= nil then
		pet:Destroy()
	end
	pets[player] = nil
	local group = houseGroups[player]
	if group ~= nil then
		for _, f in ipairs(group.fairies) do
			if f.model.Parent ~= nil then
				f.model:Destroy()
			end
		end
		houseGroups[player] = nil
	end
	sessions[player] = nil
end)

task.wait(1)
for i = 1, 6 do
	spawnFairy()
end

print("[FairyCatch] 캐치 & 하우스 코어 준비 완료")

-- ==============================================================
-- 13. 요정 타운 (학업 · 땅 매입 · 건설 · 장사 · 병원/마트/장비점)
--     · 아카데미에서 스스로 공부 → 전공·학업 Lv 상승
--     · 땅을 사고 건물을 올리면 3D 상점이 세워짐 (Lv.1~3)
--     · 요정이 스스로 출근해 장사 · 마트 쇼핑 · 병원 치료 · 장비 구매
-- ==============================================================
local function startTown()
	local FAC_LIST = shared.FairyConfig.TOWN or {}
	local FAC_BY_SLOT = {}
	local FAC_BY_ID = {}
	for _, fac in ipairs(FAC_LIST) do
		FAC_BY_SLOT[fac.slot] = fac
		FAC_BY_ID[fac.id] = fac
	end
	local SLOT_COUNT = #FAC_LIST

	local HOSP, MART, GEAR = 3, 2, 5 -- 병원 / 마트 / 장비점 슬롯
	local SHOP_X = { -63, -42, -21, 0, 21, 42, 63 }
	local SHOP_Z = 168
	local ACADEMY = Vector3.new(0, 0, 138)
	local STUDY_RATE = 9
	local STUDY_NEED = { 70, 130, 210, 320, 0 }
	local SNACK_COST, HEAL_COST = 20, 35
	local MAJORS = { pastry = "파티시에", designer = "디자이너", barista = "포션바리스타", jeweler = "보석세공사" }
	local MAJOR_KEYS = { "pastry", "designer", "barista", "jeweler" }
	local GEAR = {
		ring = { name = "마법 반지", price = 120, desc = "공부 +25%" },
		charm = { name = "행운 부적", price = 90, desc = "장사 +30%" },
	}

	local TOWN_ROOT = WORLD:FindFirstChild("Town")
	if TOWN_ROOT == nil then
		TOWN_ROOT = Instance.new("Folder")
		TOWN_ROOT.Name = "Town"
		TOWN_ROOT.Parent = WORLD
	end
	local modelFolder = TOWN_ROOT:FindFirstChild("Models")
	if modelFolder == nil then
		modelFolder = Instance.new("Folder")
		modelFolder.Name = "Models"
		modelFolder.Parent = TOWN_ROOT
	end
	local staticsFolder = TOWN_ROOT:FindFirstChild("Buildings")
	if staticsFolder == nil then
		staticsFolder = Instance.new("Folder")
		staticsFolder.Name = "Buildings"
		staticsFolder.Parent = TOWN_ROOT
	end

	-- ---------- 파트 도우미 ----------
	local function tPart(name, size, pos, color, material, parent, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Anchored = true
		p.CanCollide = false
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.Parent = parent
		return p
	end
	local function tLabel(part, text, color, offsetY, width)
		local gui = Instance.new("BillboardGui")
		gui.Name = "SignGui"
		gui.Size = UDim2.new(0, width or 170, 0, 36)
		gui.StudsOffset = Vector3.new(0, offsetY or 0, 0)
		gui.AlwaysOnTop = true
		gui.Parent = part
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundColor3 = Color3.new(1, 1, 1)
		lbl.BackgroundTransparency = 0.06
		lbl.Text = text
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = color or Color3.fromRGB(120, 70, 140)
		lbl.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = lbl
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 2
		stroke.Parent = lbl
		return gui
	end
	local function shopPos(slot)
		return Vector3.new(SHOP_X[slot] or 0, 0, SHOP_Z)
	end

	-- ---------- 아카데미 ----------
	local academy = Instance.new("Model")
	academy.Name = "Academy"
	academy.Parent = staticsFolder
	tPart("Floor", Vector3.new(30, 0.6, 20), ACADEMY + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 247, 230), Enum.Material.SmoothPlastic, academy)
	tPart("Body", Vector3.new(26, 14, 15), ACADEMY + Vector3.new(0, 7.3, 0), Color3.fromRGB(248, 234, 255), Enum.Material.SmoothPlastic, academy)
	tPart("Trim", Vector3.new(27, 1, 16), ACADEMY + Vector3.new(0, 13.6, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, academy)
	tPart("Roof", Vector3.new(29, 2.2, 17.5), ACADEMY + Vector3.new(0, 15, 0), Color3.fromRGB(154, 124, 224), Enum.Material.SmoothPlastic, academy)
	tPart("Tower", Vector3.new(5.5, 6, 5.5), ACADEMY + Vector3.new(0, 19, 0), Color3.fromRGB(255, 250, 255), Enum.Material.SmoothPlastic, academy)
	tPart("TowerRoof", Vector3.new(7, 1.6, 7), ACADEMY + Vector3.new(0, 22.6, 0), Color3.fromRGB(143, 107, 240), Enum.Material.SmoothPlastic, academy)
	tPart("Door", Vector3.new(5, 7, 0.6), ACADEMY + Vector3.new(0, 3.6, 7.6), Color3.fromRGB(107, 74, 156), Enum.Material.SmoothPlastic, academy)
	tPart("WindowL", Vector3.new(4, 5, 0.4), ACADEMY + Vector3.new(-8, 9, 7.6), Color3.fromRGB(215, 240, 255), Enum.Material.Neon, academy, 0.25)
	tPart("WindowR", Vector3.new(4, 5, 0.4), ACADEMY + Vector3.new(8, 9, 7.6), Color3.fromRGB(215, 240, 255), Enum.Material.Neon, academy, 0.25)
	local acadSign = tPart("AcademySign", Vector3.new(12, 3.4, 0.5), ACADEMY + Vector3.new(0, 11.2, 7.8), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, academy)
	tLabel(acadSign, "🏫 마법 아카데미", Color3.fromRGB(122, 74, 168), 0, 200)
	-- 책상 7개
	local DESKS = {}
	for i = 1, 7 do
		local dx = -18 + (i - 1) * 6
		local z = (i <= 4) and 149 or 154
		local desk = tPart("Desk" .. i, Vector3.new(3.4, 0.4, 2.4), Vector3.new(dx, 2.4, z), Color3.fromRGB(224, 180, 137), Enum.Material.SmoothPlastic, academy)
		tPart("DeskLeg" .. i, Vector3.new(3, 2.2, 0.4), Vector3.new(dx, 1.3, z), Color3.fromRGB(201, 154, 109), Enum.Material.SmoothPlastic, academy)
		tPart("Book" .. i, Vector3.new(2, 0.3, 1.4), Vector3.new(dx, 2.75, z), Color3.fromRGB(255, 158, 203), Enum.Material.SmoothPlastic, academy)
		DESKS[i] = Vector3.new(dx, 0, z)
	end
	-- 타운 표지
	local gate = tPart("TownGate", Vector3.new(18, 5, 1), Vector3.new(0, 6, 122), Color3.fromRGB(255, 246, 230), Enum.Material.SmoothPlastic, staticsFolder)
	tLabel(gate, "🏘️ 요정 타운 · 학업 → 땅 → 건물 → 장사 → 쇼핑", Color3.fromRGB(150, 90, 60), 0, 320)

	-- ---------- 부지 · 건물 ----------
	local plotParts = {}   -- [slot] = { model, sign }
	local onPlotClick = nil
	local function clearPlot(slot)
		local rec = plotParts[slot]
		if rec ~= nil and rec.model ~= nil then
			rec.model:Destroy()
		end
		plotParts[slot] = { model = nil, sign = nil }
	end
	local function buildPlot(slot)
		local data = nil
		local fac = FAC_BY_SLOT[slot]
		if fac == nil then
			return
		end
		clearPlot(slot)
		local model = Instance.new("Model")
		model.Name = "Plot_" .. fac.id
		model.Parent = staticsFolder
		local base = shopPos(slot)
		plotParts[slot] = { model = model }
		return model, base
	end
	-- 부지/건물은 플레이어별 상태가 아니라 "가장 높은 레벨"을 보여 줍니다.
	-- (혼자 하는 게임 기준: 첫 플레이어의 타운을 공용으로 렌더)
	local function renderPlot(slot, owned, bld)
		local fac = FAC_BY_SLOT[slot]
		if fac == nil then
			return
		end
		clearPlot(slot)
		local model = Instance.new("Model")
		model.Name = "Plot_" .. fac.id
		model.Parent = staticsFolder
		local base = shopPos(slot)
		local rec = { model = model }
		plotParts[slot] = rec

		local padColor = owned and Color3.fromRGB(206, 240, 190) or Color3.fromRGB(226, 232, 214)
		tPart("Lawn", Vector3.new(16, 0.4, 16), base + Vector3.new(0, 0.2, 0), padColor, Enum.Material.Grass, model)
		for side = -1, 1, 2 do
			tPart("Fence" .. side, Vector3.new(16, 0.4, 0.4), base + Vector3.new(0, 1.4, side * 7.6), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
		end
		if not owned then
			local post = tPart("ForSalePost", Vector3.new(0.5, 4, 0.5), base + Vector3.new(5, 2.2, 6), Color3.fromRGB(194, 148, 107), Enum.Material.SmoothPlastic, model)
			local board = tPart("ForSale", Vector3.new(5, 2.4, 0.3), base + Vector3.new(5, 4.4, 6), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
			tLabel(board, "🚩 매물 " .. tostring(fac.land), Color3.fromRGB(226, 71, 156), 0, 120)
			rec.sign = board
			return
		end
		if bld < 1 then
			local board = tPart("MyLand", Vector3.new(5, 2.4, 0.3), base + Vector3.new(0, 4.4, 5), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
			tLabel(board, "내 땅 · 건설 대기", Color3.fromRGB(47, 143, 191), 0, 140)
			rec.sign = board
			return
		end

		-- 건물
		local H = 9 + (bld - 1) * 3
		local bodyColor = {
			bakery = Color3.fromRGB(255, 226, 236),
			mart = Color3.fromRGB(214, 246, 210),
			hospital = Color3.fromRGB(232, 244, 255),
			cafe = Color3.fromRGB(202, 245, 235),
			gear = Color3.fromRGB(232, 220, 255),
			boutique = Color3.fromRGB(232, 216, 255),
			jewel = Color3.fromRGB(206, 238, 255),
		}
		local roofColor = {
			bakery = Color3.fromRGB(255, 143, 180),
			mart = Color3.fromRGB(123, 212, 127),
			hospital = Color3.fromRGB(168, 214, 245),
			cafe = Color3.fromRGB(99, 220, 201),
			gear = Color3.fromRGB(169, 139, 245),
			boutique = Color3.fromRGB(174, 144, 247),
			jewel = Color3.fromRGB(130, 205, 243),
		}
		local trim = {
			bakery = Color3.fromRGB(255, 127, 164),
			mart = Color3.fromRGB(79, 179, 86),
			hospital = Color3.fromRGB(226, 104, 138),
			cafe = Color3.fromRGB(61, 196, 166),
			gear = Color3.fromRGB(130, 87, 224),
			boutique = Color3.fromRGB(157, 124, 245),
			jewel = Color3.fromRGB(73, 168, 230),
		}
		local c1 = bodyColor[fac.id] or Color3.fromRGB(240, 232, 250)
		local c2 = roofColor[fac.id] or Color3.fromRGB(170, 140, 240)
		local c3 = trim[fac.id] or Color3.fromRGB(200, 120, 180)

		local bodyPart = tPart("Body", Vector3.new(13, H, 11), base + Vector3.new(0, H / 2 + 0.4, 0), c1, Enum.Material.SmoothPlastic, model)
		do
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 24
			click.Parent = bodyPart
			click.MouseClick:Connect(function(pl)
				if onPlotClick ~= nil then
					onPlotClick(pl, slot)
				end
			end)
		end
		tPart("Roof", Vector3.new(15, 1.6, 13), base + Vector3.new(0, H + 1.2, 0), c2, Enum.Material.SmoothPlastic, model)
		tPart("RoofTop", Vector3.new(11, 1.2, 9), base + Vector3.new(0, H + 2.4, 0), c2, Enum.Material.SmoothPlastic, model)
		tPart("Awning", Vector3.new(13.4, 0.6, 2.4), base + Vector3.new(0, H - 2.2, 6.4), c3, Enum.Material.SmoothPlastic, model)
		tPart("Door", Vector3.new(3.4, 5, 0.5), base + Vector3.new(0, 3, 5.7), c3, Enum.Material.SmoothPlastic, model)
		tPart("WindowL", Vector3.new(2.6, 2.6, 0.4), base + Vector3.new(-4.2, 4.6, 5.7), Color3.fromRGB(255, 246, 214), Enum.Material.Neon, model, 0.15)
		tPart("WindowR", Vector3.new(2.6, 2.6, 0.4), base + Vector3.new(4.2, 4.6, 5.7), Color3.fromRGB(255, 246, 214), Enum.Material.Neon, model, 0.15)
		if bld >= 2 then
			tPart("Floor2", Vector3.new(13.4, 0.5, 11.4), base + Vector3.new(0, H - 4.4, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
			tPart("Window2", Vector3.new(6, 2.4, 0.4), base + Vector3.new(0, H - 2.4, 5.7), Color3.fromRGB(255, 246, 214), Enum.Material.Neon, model, 0.15)
		end
		if bld >= 3 then
			local star = tPart("Star", Vector3.new(2.4, 2.4, 2.4), base + Vector3.new(0, H + 4.2, 0), Color3.fromRGB(255, 224, 138), Enum.Material.Neon, model)
			star.Shape = Enum.PartType.Ball
			tPart("Trim", Vector3.new(13.6, 0.5, 11.6), base + Vector3.new(0, H - 0.4, 0), Color3.fromRGB(255, 209, 102), Enum.Material.Neon, model, 0.1)
		end
		-- 업종 표식
		if fac.kind == "hospital" then
			tPart("CrossV", Vector3.new(0.9, 3, 0.4), base + Vector3.new(0, H + 1.2, 6.6), Color3.fromRGB(226, 104, 138), Enum.Material.Neon, model)
			tPart("CrossH", Vector3.new(3, 0.9, 0.4), base + Vector3.new(0, H + 1.2, 6.6), Color3.fromRGB(226, 104, 138), Enum.Material.Neon, model)
		elseif fac.kind == "mart" then
			tPart("Cart", Vector3.new(3.4, 2, 2.4), base + Vector3.new(6.4, 1.4, 6.6), Color3.fromRGB(79, 179, 86), Enum.Material.SmoothPlastic, model)
			tPart("CartTop", Vector3.new(3.4, 0.4, 0.4), base + Vector3.new(6.4, 2.6, 7.8), Color3.fromRGB(79, 179, 86), Enum.Material.SmoothPlastic, model)
		elseif fac.kind == "gear" then
			local ring = tPart("Ring", Vector3.new(2.6, 2.6, 2.6), base + Vector3.new(0, H + 1.4, 6.6), Color3.fromRGB(255, 209, 102), Enum.Material.Neon, model)
			ring.Shape = Enum.PartType.Cylinder
			ring.Orientation = Vector3.new(0, 0, 90)
		end
		local sign = tPart("Sign", Vector3.new(10, 2.6, 0.4), base + Vector3.new(0, H + 3.6, 5), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
		tLabel(sign, fac.icon .. " " .. fac.name .. "  Lv." .. tostring(bld), Color3.fromRGB(107, 58, 94), 0, 200)
		rec.sign = sign
		tPart("Counter", Vector3.new(8, 1, 1.6), base + Vector3.new(0, 2, 7.4), Color3.fromRGB(255, 246, 234), Enum.Material.SmoothPlastic, model)
	end

	-- ---------- 데이터 도우미 ----------
	local function studyData(data, id)
		data.Study[id] = data.Study[id] or { lv = 1, xp = 0, major = nil }
		local s = data.Study[id]
		s.lv = math.clamp(s.lv or 1, 1, 5)
		s.xp = math.max(0, s.xp or 0)
		if s.major ~= nil and MAJORS[s.major] == nil then
			s.major = nil
		end
		return s
	end
	local function careData(data, id)
		data.Care[id] = data.Care[id] or { hp = math.random(72, 100), wallet = math.random(24, 56) }
		local c = data.Care[id]
		c.hp = math.clamp(c.hp or 100, 0, 100)
		c.wallet = math.max(0, c.wallet or 0)
		return c
	end
	local function plotData(data, slot)
		data.Plots[slot] = data.Plots[slot] or { owned = false, bld = 0, income = 0, worker = nil }
		local plot = data.Plots[slot]
		plot.owned = plot.owned == true
		plot.bld = math.clamp(plot.bld or 0, 0, 3)
		plot.income = math.max(0, plot.income or 0)
		return plot
	end
	local function modeOf(data, id)
		local m = data.Mode[id]
		if m == "study" or m == "work" then
			return m
		end
		return "auto"
	end
	local function workerSlot(data, id)
		for slot = 1, SLOT_COUNT do
			local plot = plotData(data, slot)
			if plot.worker == id then
				return slot
			end
		end
		return nil
	end
	local function facilityReady(data, slot)
		local plot = plotData(data, slot)
		return plot.owned and plot.bld > 0
	end
	local function plotRate(data, slot)
		local plot = plotData(data, slot)
		local fac = FAC_BY_SLOT[slot]
		if fac == nil or not plot.owned or plot.bld < 1 then
			return 0
		end
		local r = fac.base * (1 + 0.55 * (plot.bld - 1))
		if plot.worker ~= nil then
			local s = studyData(data, plot.worker)
			local c = careData(data, plot.worker)
			r = r * (1 + 0.2 * (s.lv - 1))
			if fac.major ~= nil and s.major == fac.major then
				r = r * 1.45
			end
			if c.charm then
				r = r * 1.3
			end
		else
			r = r * 0.45
		end
		return r
	end
	local function totalRate(data)
		local sum = 0
		for slot = 1, SLOT_COUNT do
			sum = sum + plotRate(data, slot)
		end
		return sum
	end
	local function labcoatMajor(data)
		local want = {}
		for slot = 1, SLOT_COUNT do
			local plot = plotData(data, slot)
			local fac = FAC_BY_SLOT[slot]
			if fac ~= nil and fac.major ~= nil and plot.owned and plot.bld > 0 and plot.worker == nil then
				table.insert(want, fac.major)
			end
		end
		if #want > 0 and math.random() < 0.72 then
			return want[math.random(#want)]
		end
		return MAJOR_KEYS[math.random(#MAJOR_KEYS)]
	end

	-- ---------- 서버 상태 ----------
	local agents = {}     -- [player] = { fairies = { agent... }, sig = string, folder = Folder }
	local openTown = {}   -- [player] = true (타운 창을 연 플레이어만 TownData 푸시)
	local visitors = {}   -- [player] = { {model, pos, target, shop, timer, t} }

	local function townSpot(slot, idx)
		local base = shopPos(slot)
		return base + Vector3.new(((idx % 2 == 0) and -2.2 or 2.2), 0, 8)
	end

	local function makeAgent(data, id, index, folder)
		local info = FAIRY[id]
		if info == nil then
			return nil
		end
		local rarityInfo = RARITY[info.rarity] or RARITY.common
		local template = templates:FindFirstChild(rarityInfo.template) or templates:FindFirstChild("Fairy_Common")
		if template == nil then
			return nil
		end
		local model = template:Clone()
		model.Name = "Town_" .. id
		model:SetAttribute("FairyId", id)
		local body = model:FindFirstChild("Body")
		if body ~= nil then
			body.Color = info.color
			local prompt = body:FindFirstChildOfClass("ProximityPrompt")
			if prompt ~= nil then
				prompt:Destroy()
			end
		end
		local head = model:FindFirstChild("Head")
		if head ~= nil then
			local tag = head:FindFirstChild("NameTag")
			if tag ~= nil then
				tag.Size = UDim2.new(0, 130, 0, 30)
				tag.StudsOffset = Vector3.new(0, 2.2, 0)
			end
			local bubble = Instance.new("BillboardGui")
			bubble.Name = "TownBubble"
			bubble.Size = UDim2.new(0, 56, 0, 56)
			bubble.StudsOffset = Vector3.new(0, 3.4, 0)
			bubble.AlwaysOnTop = true
			bubble.Enabled = false
			bubble.Parent = head
			local lbl = Instance.new("TextLabel")
			lbl.Name = "BubbleText"
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundColor3 = Color3.new(1, 1, 1)
			lbl.BackgroundTransparency = 0.05
			lbl.Text = ""
			lbl.TextScaled = true
			lbl.Font = Enum.Font.GothamBold
			lbl.TextColor3 = Color3.fromRGB(180, 60, 120)
			lbl.Parent = bubble
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 18)
			corner.Parent = lbl
		end
		model.Parent = folder
		local startPos = DESKS[(index - 1) % #DESKS + 1]
		local agent = {
			id = id,
			index = index,
			model = model,
			pos = Vector3.new(startPos.X, 0, startPos.Z),
			target = Vector3.new(startPos.X, 0, startPos.Z),
			task = "study",
			job = nil,
			timer = 0,
			paid = false,
			gear = nil,
			shop = nil,
			hp = nil,
			phase = math.random() * math.pi * 2,
			speed = 5,
			yaw = 0,
			bubbleT = 0,
		}
		model:PivotTo(CFrame.new(agent.pos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, 0))
		return agent
	end

	local function agentBubble(a, text)
		a.bubbleT = 1.8
		local head = a.model:FindFirstChild("Head")
		local gui = head and head:FindFirstChild("TownBubble")
		if gui ~= nil then
			local lbl = gui:FindFirstChild("BubbleText")
			if lbl ~= nil then
				lbl.Text = text
			end
			gui.Enabled = true
		end
	end

	local function decide(data, a)
		local c = careData(data, a.id)
		local wi = workerSlot(data, a.id)
		a.job = wi
		a.timer = 0
		a.paid = false
		a.gear = nil
		local gearWanted = nil
		if not c.ring then
			gearWanted = "ring"
		elseif not c.charm then
			gearWanted = "charm"
		end
		if c.hp < 42 and facilityReady(data, HOSP) then
			a.task = "hospital"
			a.shop = HOSP
			a.target = townSpot(HOSP, a.index)
		elseif gearWanted ~= nil and c.wallet >= GEAR[gearWanted].price and facilityReady(data, GEAR) and math.random() < 0.5 then
			a.task = "gear"
			a.shop = GEAR
			a.gear = gearWanted
			a.target = townSpot(GEAR, a.index)
		elseif c.wallet >= SNACK_COST and facilityReady(data, MART) and (c.hp < 70 or math.random() < 0.28) then
			a.task = "mart"
			a.shop = MART
			a.target = townSpot(MART, a.index)
		elseif wi ~= nil and modeOf(data, a.id) ~= "study" then
			a.task = "work"
			a.shop = wi
			a.target = townSpot(wi, a.index)
		else
			a.task = "study"
			a.shop = nil
			local d = DESKS[(a.index - 1) % #DESKS + 1]
			a.target = Vector3.new(d.X + ((a.index % 3) - 1) * 1.2, 0, d.Z)
		end
	end

	local function assignWorkers(data)
		for slot = 1, SLOT_COUNT do
			local plot = plotData(data, slot)
			if plot.worker ~= nil then
				local still = false
				for _, id in ipairs(data.House) do
					if id == plot.worker then
						still = true
					end
				end
				if not still then
					plot.worker = nil
				end
			end
			if not plot.owned or plot.bld < 1 then
				plot.worker = nil
			end
		end
		for _, id in ipairs(data.House) do
			local mode = modeOf(data, id)
			local cur = workerSlot(data, id)
			if mode == "study" then
				if cur ~= nil then
					plotData(data, cur).worker = nil
				end
			elseif cur == nil then
				local s = studyData(data, id)
				if s.lv >= 2 then
					local best, bestScore = nil, -1
					for slot = 1, SLOT_COUNT do
						local plot = plotData(data, slot)
						local fac = FAC_BY_SLOT[slot]
						if plot.owned and plot.bld > 0 and plot.worker == nil and fac ~= nil then
							local score = plot.bld * 2
							if fac.major ~= nil and s.major == fac.major then
								score = score + 3.5
							end
							if mode == "work" then
								score = score + 1
							end
							if score > bestScore then
								bestScore = score
								best = slot
							end
						end
					end
					if best ~= nil then
						plotData(data, best).worker = id
					end
				end
			end
		end
	end

	local function addStudy(data, id, amount, a)
		local s = studyData(data, id)
		if s.major == nil then
			s.major = labcoatMajor(data)
		end
		if s.lv >= 5 then
			s.xp = 0
			return
		end
		s.xp = s.xp + amount
		while s.lv < 5 and s.xp >= (STUDY_NEED[s.lv] or 0) do
			s.xp = s.xp - (STUDY_NEED[s.lv] or 0)
			s.lv = s.lv + 1
			if a ~= nil then
				agentBubble(a, "✨")
			end
			local player = nil
			for pl, _ in pairs(PlayerData) do
				if PlayerData[pl] == data then
					player = pl
				end
			end
			if player ~= nil then
				shared.FairyNotify(player, "🎓 " .. (FAIRY[id] and FAIRY[id].name or id) .. " 학업 Lv." .. tostring(s.lv) .. " · " .. (MAJORS[s.major] or ""))
			end
			break
		end
		if s.lv >= 5 then
			s.xp = 0
		end
	end

	local function fairyPay(data, id, slot, amount)
		local c = careData(data, id)
		local pay = math.min(amount, math.max(0, c.wallet))
		c.wallet = c.wallet - pay
		local plot = plotData(data, slot)
		if plot.owned and plot.bld > 0 then
			plot.income = math.min(9999, plot.income + pay)
		end
		return pay
	end

	-- ---------- 모델 동기화 ----------
	local function signature(data)
		local parts = {}
		for _, id in ipairs(data.House) do
			local c = careData(data, id)
			table.insert(parts, id .. ":" .. tostring(c.ring and 1 or 0) .. tostring(c.charm and 1 or 0))
		end
		return table.concat(parts, ",")
	end

	local function syncAgents(player)
		local data = PlayerData[player]
		if data == nil then
			return
		end
		local rec = agents[player]
		local sig = signature(data)
		if rec ~= nil and rec.sig == sig then
			return
		end
		if rec ~= nil then
			for _, a in ipairs(rec.fairies) do
				if a.model ~= nil and a.model.Parent ~= nil then
					a.model:Destroy()
				end
			end
			if rec.folder ~= nil then
				rec.folder:Destroy()
			end
		end
		local folder = Instance.new("Folder")
		folder.Name = "TownFairies_" .. player.Name
		folder.Parent = modelFolder
		rec = { fairies = {}, sig = sig, folder = folder }
		agents[player] = rec
		local index = 0
		for _, id in ipairs(data.House) do
			index = index + 1
			local a = makeAgent(data, id, index, folder)
			if a ~= nil then
				table.insert(rec.fairies, a)
			end
		end
	end

	-- ---------- UI 푸시 ----------
	local function pushTown(player)
		local data = PlayerData[player]
		if data == nil then
			return
		end
		syncAgents(player)
		local rec = agents[player]
		local fairyView = {}
		if rec ~= nil then
			for _, a in ipairs(rec.fairies) do
				local s = studyData(data, a.id)
				local c = careData(data, a.id)
				local status = "대기 중"
				if a.task == "hospital" then
					status = "🏥 병원 치료 중"
				elseif a.task == "mart" then
					status = "🛒 마트 쇼핑 중"
				elseif a.task == "gear" then
					status = "💍 장비 보는 중"
				elseif a.task == "work" then
					status = "🏪 " .. ((a.shop and FAC_BY_SLOT[a.shop] and FAC_BY_SLOT[a.shop].name) or "가게") .. " 장사 중"
				elseif a.task == "study" then
					status = "📚 아카데미 공부 중"
				end
				table.insert(fairyView, {
					id = a.id,
					name = (FAIRY[a.id] and FAIRY[a.id].name) or a.id,
					lv = s.lv,
					xp = s.xp,
					major = s.major,
					hp = math.floor(c.hp),
					wallet = math.floor(c.wallet),
					ring = c.ring == true,
					charm = c.charm == true,
					mode = modeOf(data, a.id),
					status = status,
				})
			end
		end
		local plots = {}
		for slot = 1, SLOT_COUNT do
			local plot = plotData(data, slot)
			table.insert(plots, {
				slot = slot,
				owned = plot.owned,
				bld = plot.bld,
				income = math.floor(plot.income),
				worker = plot.worker,
				rate = plotRate(data, slot),
				upCost = (plot.bld >= 1 and plot.bld < 3) and math.floor((FAC_BY_SLOT[slot].build) * ((plot.bld == 1) and 1.8 or 3.2)) or 0,
			})
		end
		remotes.TownData:FireClient(player, {
			coins = data.Coins,
			fairies = fairyView,
			plots = plots,
			rate = totalRate(data),
			income = (function()
				local sum = 0
				for slot = 1, SLOT_COUNT do
					sum = sum + plotData(data, slot).income
				end
				return math.floor(sum)
			end)(),
		})
	end
	shared.FairyPushTown = pushTown

	-- 마을 건물은 모든 플레이어 중 가장 높은 상태를 함께 보여 줍니다 (공용 마을)
	local function refreshStatics()
		for slot = 1, SLOT_COUNT do
			local owned, bld = false, 0
			for _, data in pairs(PlayerData) do
				local plot = plotData(data, slot)
				if plot.owned then
					owned = true
				end
				if plot.bld > bld then
					bld = plot.bld
				end
			end
			renderPlot(slot, owned, bld)
		end
	end
	shared.FairyRefreshTownStatics = refreshStatics

	-- 첫 렌더
	refreshStatics()

	-- ---------- 원격 이벤트 ----------
	remotes.RequestTown.OnServerEvent:Connect(function(player)
		openTown[player] = true
		local data = PlayerData[player]
		if data ~= nil then
			data.TownSeen = true
		end
		pushTown(player)
	end)

	remotes.BuyPlot.OnServerEvent:Connect(function(player, slot)
		local data = PlayerData[player]
		local fac = FAC_BY_SLOT[tonumber(slot) or 0]
		if data == nil or fac == nil then
			return
		end
		local plot = plotData(data, fac.slot)
		if plot.owned then
			shared.FairyNotify(player, "이미 내 땅이에요")
			return
		end
		if data.Coins < fac.land then
			shared.FairyNotify(player, "코인이 모자라요 🪙 " .. tostring(fac.land) .. " 필요")
			return
		end
		addCoins(player, -fac.land)
		plot.owned = true
		refreshStatics()
		shared.FairyNotify(player, "🎉 " .. fac.icon .. " " .. fac.name .. " 부지를 샀어요! 이제 건물을 올려요")
		savePlayer(player)
		pushTown(player)
	end)

	remotes.UpgradeBuilding.OnServerEvent:Connect(function(player, slot)
		local data = PlayerData[player]
		local fac = FAC_BY_SLOT[tonumber(slot) or 0]
		if data == nil or fac == nil then
			return
		end
		local plot = plotData(data, fac.slot)
		if not plot.owned then
			shared.FairyNotify(player, "먼저 땅을 사야 해요")
			return
		end
		if plot.bld >= 3 then
			shared.FairyNotify(player, "이미 최고 레벨(Lv.3)이에요")
			return
		end
		local cost
		if plot.bld == 0 then
			cost = fac.build
		else
			cost = math.floor(fac.build * ((plot.bld == 1) and 1.8 or 3.2))
		end
		if data.Coins < cost then
			shared.FairyNotify(player, "코인이 모자라요 🪙 " .. tostring(cost) .. " 필요")
			return
		end
		addCoins(player, -cost)
		plot.bld = plot.bld + 1
		refreshStatics()
		shared.FairyNotify(player, "🏗️ " .. fac.name .. " Lv." .. tostring(plot.bld) .. " 완성! 매출이 커져요")
		savePlayer(player)
		pushTown(player)
	end)

	remotes.CollectBusiness.OnServerEvent:Connect(function(player, slot)
		local data = PlayerData[player]
		if data == nil then
			return
		end
		if slot == nil or slot == 0 then
			local sum = 0
			for i = 1, SLOT_COUNT do
				local plot = plotData(data, i)
				local n = math.floor(plot.income)
				if n > 0 then
					plot.income = plot.income - n
					sum = sum + n
				end
			end
			if sum < 1 then
				shared.FairyNotify(player, "아직 모인 코인이 없어요 · 요정들이 장사 중이에요")
			else
				addCoins(player, sum)
				shared.FairyNotify(player, "💰 마을 상점가에서 +" .. tostring(sum) .. " 코인 수거!")
			end
		else
			local fac = FAC_BY_SLOT[tonumber(slot) or 0]
			if fac == nil then
				return
			end
			local plot = plotData(data, fac.slot)
			local n = math.floor(plot.income)
			if n < 1 then
				shared.FairyNotify(player, "아직 수거할 코인이 없어요")
				return
			end
			plot.income = plot.income - n
			addCoins(player, n)
			shared.FairyNotify(player, "💰 " .. fac.icon .. " +" .. tostring(n) .. " 코인 수거!")
		end
		savePlayer(player)
		pushTown(player)
	end)

	remotes.SetFairyMode.OnServerEvent:Connect(function(player, fairyId, mode)
		local data = PlayerData[player]
		if data == nil or fairyId == nil then
			return
		end
		local m = "auto"
		if mode == "study" or mode == "work" then
			m = mode
		end
		data.Mode[fairyId] = m
		if m ~= "work" then
			local wi = workerSlot(data, fairyId)
			if wi ~= nil then
				plotData(data, wi).worker = nil
			end
		end
		local rec = agents[player]
		if rec ~= nil then
			for _, a in ipairs(rec.fairies) do
				if a.id == fairyId then
					decide(data, a)
				end
			end
		end
		shared.FairyNotify(player, (FAIRY[fairyId] and FAIRY[fairyId].name or "요정") .. " 모드: " .. (m == "auto" and "자유" or (m == "study" and "공부" or "장사")))
		savePlayer(player)
		pushTown(player)
	end)

	remotes.CareFairy.OnServerEvent:Connect(function(player, fairyId, what)
		local data = PlayerData[player]
		if data == nil or fairyId == nil then
			return
		end
		local c = careData(data, fairyId)
		local name = (FAIRY[fairyId] and FAIRY[fairyId].name) or "요정"
		if what == "heal" then
			if not facilityReady(data, HOSP) then
				shared.FairyNotify(player, "🏥 요정 병원을 먼저 지어 주세요")
				return
			end
			if c.hp >= 99 then
				shared.FairyNotify(player, name .. "는 지금 아주 건강해요")
				return
			end
			if data.Coins < HEAL_COST then
				shared.FairyNotify(player, "코인이 모자라요 🪙 " .. tostring(HEAL_COST))
				return
			end
			addCoins(player, -HEAL_COST)
			plotData(data, HOSP).income = plotData(data, HOSP).income + HEAL_COST
			c.hp = 100
			shared.FairyNotify(player, "🏥 " .. name .. " 치료 완료! 체력이 가득 찼어요")
		elseif what == "snack" then
			if not facilityReady(data, MART) then
				shared.FairyNotify(player, "🛒 해피 마트를 먼저 지어 주세요")
				return
			end
			if data.Coins < SNACK_COST then
				shared.FairyNotify(player, "코인이 모자라요 🪙 " .. tostring(SNACK_COST))
				return
			end
			addCoins(player, -SNACK_COST)
			plotData(data, MART).income = plotData(data, MART).income + SNACK_COST
			c.hp = math.min(100, c.hp + 12)
			shared.FairyNotify(player, "🛒 " .. name .. "에게 간식을 샀어요 · 체력 +12")
		elseif what == "ring" or what == "charm" then
			local gear = GEAR[what]
			if not facilityReady(data, GEAR) then
				shared.FairyNotify(player, "💍 마법 잡화·장비점을 먼저 지어 주세요")
				return
			end
			if c[what] then
				shared.FairyNotify(player, name .. "는 이미 " .. gear.name .. "을(를) 갖고 있어요")
				return
			end
			if data.Coins < gear.price then
				shared.FairyNotify(player, "코인이 모자라요 🪙 " .. tostring(gear.price))
				return
			end
			addCoins(player, -gear.price)
			plotData(data, GEAR).income = plotData(data, GEAR).income + gear.price
			c[what] = true
			shared.FairyNotify(player, "✨ " .. name .. "에게 " .. gear.name .. " 선물! " .. gear.desc)
		end
		savePlayer(player)
		pushTown(player)
	end)

	-- 상점 건물을 직접 눌러도 매출 수거
	onPlotClick = function(player, slot)
		local data = PlayerData[player]
		if data == nil then
			return
		end
		local fac = FAC_BY_SLOT[slot]
		local plot = plotData(data, slot)
		local n = math.floor(plot.income)
		if n > 0 then
			plot.income = plot.income - n
			addCoins(player, n)
			shared.FairyNotify(player, "💰 " .. ((fac and fac.name) or "가게") .. " +" .. tostring(n) .. " 코인 수거!")
			savePlayer(player)
			pushTown(player)
		else
			pushTown(player)
		end
	end

	-- ---------- 루프 ----------
	local syncTimer = 0
	local saveTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		syncTimer = syncTimer + dt
		for player, rec in pairs(agents) do
			local data = PlayerData[player]
			if data ~= nil then
			if syncTimer > 0.8 then
				syncAgents(player)
				assignWorkers(data)
			end
			for _, a in ipairs(rec.fairies) do
				if a.model.Parent ~= nil then
					local c = careData(data, a.id)
					local s = studyData(data, a.id)
					a.bubbleT = math.max(0, a.bubbleT - dt)
					local flat = Vector3.new(a.target.X - a.pos.X, 0, a.target.Z - a.pos.Z)
					local dist = flat.Magnitude
					if dist > 0.6 then
						local step = math.min(dist, a.speed * dt)
						a.pos = a.pos + flat.Unit * step
						a.yaw = math.atan2(flat.X, flat.Z)
					else
						a.pos = Vector3.new(a.target.X, 0, a.target.Z)
						if a.task == "study" then
							local sp = STUDY_RATE * (1 + (c.ring and 0.25 or 0))
							if s.major == nil then
								s.major = labcoatMajor(data)
							end
							addStudy(data, a.id, sp * dt, a)
							c.hp = math.max(0, c.hp - 0.3 * dt)
							c.wallet = c.wallet + 0.05 * dt
							if math.random() < dt * 0.35 then
								agentBubble(a, "📚")
							end
							if a.timer == 0 then
								a.timer = 1
							end
						elseif a.task == "work" then
							c.hp = math.max(0, c.hp - 0.45 * dt)
							c.wallet = c.wallet + 0.7 * dt
							if math.random() < dt * 0.25 then
								agentBubble(a, "💰")
							end
							if c.hp < 42 and facilityReady(data, HOSP) then
								decide(data, a)
							end
						elseif a.task == "hospital" then
							if not a.paid then
								a.paid = true
								fairyPay(data, a.id, HOSP, 18)
								agentBubble(a, "🏥")
							end
							c.hp = math.min(100, c.hp + 9 * dt)
							if c.hp >= 99.4 then
								a.timer = a.timer + dt
								if a.timer > 1.2 then
									decide(data, a)
								end
							end
						elseif a.task == "mart" then
							if not a.paid then
								a.paid = true
								fairyPay(data, a.id, MART, SNACK_COST)
								c.hp = math.min(100, c.hp + 14)
								agentBubble(a, "🛒")
							end
							a.timer = a.timer + dt
							if a.timer > 2.4 then
								decide(data, a)
							end
						elseif a.task == "gear" then
							if not a.paid then
								a.paid = true
								local gear = GEAR[a.gear]
								if gear ~= nil then
									local paid = fairyPay(data, a.id, GEAR, gear.price)
									if paid >= gear.price - 0.01 then
										c[a.gear] = true
										agentBubble(a, "💍")
										shared.FairyNotify(player, "💍 " .. ((FAIRY[a.id] and FAIRY[a.id].name) or "요정") .. "가 " .. gear.name .. "을(를) 샀어요")
									end
								end
							end
							a.timer = a.timer + dt
							if a.timer > 2.4 then
								decide(data, a)
							end
						end
					end
					-- 장시간 같은 일 → 가끔 쇼핑/휴식
					if a.task == "study" or a.task == "work" then
						a.timer = (a.timer or 0) + dt
						if a.timer > 22 and math.random() < dt * 0.35 then
							decide(data, a)
						end
					end
					local hover = 3.2 + math.sin(workspace:GetServerTimeNow() * 2 + a.phase) * 0.22
					a.model:PivotTo(CFrame.new(Vector3.new(a.pos.X, hover, a.pos.Z)) * CFrame.Angles(0, a.yaw, 0))
					if a.bubbleT <= 0 then
						local head = a.model:FindFirstChild("Head")
						local gui = head and head:FindFirstChild("TownBubble")
						if gui ~= nil and gui.Enabled then
							gui.Enabled = false
						end
					end
				end
			end
			-- 매출 누적
			for slot = 1, SLOT_COUNT do
				local plot = plotData(data, slot)
				if plot.owned and plot.bld > 0 and plot.income < 9999 then
					plot.income = math.min(9999, plot.income + plotRate(data, slot) * dt)
				end
			end
			end
		end
		if syncTimer > 0.8 then
			syncTimer = 0
		end
		saveTimer = saveTimer + dt
		if saveTimer > 20 then
			saveTimer = 0
			for player, _ in pairs(agents) do
				savePlayer(player)
			end
		end
		for player, _ in pairs(openTown) do
			if agents[player] == nil then
				openTown[player] = nil
			end
		end
	end)

	-- 1초마다 타운 창을 연 플레이어에게 상태 푸시
	task.spawn(function()
		while true do
			task.wait(1)
			for player, _ in pairs(openTown) do
				if player.Parent ~= nil then
					pushTown(player)
				else
					openTown[player] = nil
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		openTown[player] = nil
		task.wait(2)
		local data = PlayerData[player]
		if data ~= nil then
			syncAgents(player)
		end
		refreshStatics()
	end)
	Players.PlayerRemoving:Connect(function(player)
		openTown[player] = nil
		local rec = agents[player]
		if rec ~= nil then
			if rec.folder ~= nil then
				rec.folder:Destroy()
			end
			agents[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData[player]
		if data ~= nil then
			syncAgents(player)
		end
	end

	print("[FairyCatch] 요정 타운 준비 완료 · 부지 " .. tostring(SLOT_COUNT) .. "곳")
end

task.spawn(startTown)

