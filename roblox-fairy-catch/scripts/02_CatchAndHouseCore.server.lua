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
