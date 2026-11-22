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
}

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
	model.Parent = workspace
	if model.PrimaryPart ~= nil then
		model:PivotTo(CFrame.new(player.Character and player.Character:GetPivot().Position or Vector3.new(0, 20, 0)))
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
local HOUSE_SPOTS = {
	Vector3.new(-5.0, 0, 2.0),   -- 소파
	Vector3.new(5.0, 0, 3.0),    -- 침대
	Vector3.new(4.6, 0, -3.8),   -- 그네
	Vector3.new(-4.4, 0, -3.8),  -- 점프 패드
	Vector3.new(1.4, 0, -4.4),   -- 간식 테이블
}

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

local function makeHouseFairyModel(fairyId)
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

	local body = model:FindFirstChild("Body")
	if body ~= nil then
		body.Color = info.color
		local oldPrompt = body:FindFirstChildOfClass("ProximityPrompt")
		if oldPrompt ~= nil then
			oldPrompt:Destroy()
		end
		body.CanCollide = false
	end

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
		table.insert(parts, id)
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

local function chooseHouseAction(f, center)
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
		local spot = HOUSE_SPOTS[math.random(#HOUSE_SPOTS)]
		f.target = center + spot
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
		local model = makeHouseFairyModel(fairyId)
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
					chooseHouseAction(f, center)
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
						if math.random() < 0.5 then
							showBubble(f, pickEmoji())
						end
					else
						chooseHouseAction(f, center)
					end
				end
			end

			-- 벽 밖으로 나가지 않게
			f.pos = Vector3.new(
				math.clamp(f.pos.X, center.X - 5.9, center.X + 5.9),
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
	shared.FairyNotify(player, "🎀 " .. item.name .. " 설치 완료!")
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
end

-- 접속/퇴장 처리
Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("HouseIndex", assignHouse(player))
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
