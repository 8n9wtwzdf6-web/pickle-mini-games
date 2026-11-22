--[[
  02_VaultStealCore.server.lua
  --------------------------------------------------------------------------------
  붙여넣는 위치: ServerScriptService  (일반 Script, 01 다음에 넣으면 됩니다)
  하는 일:
    · 기지 배정 · 금고 전시대 배치 · 초당 수익/수금
    · 뽑기(4대 테마 · 등급 뽑기)와 도감 기록
    · 레이저 방어막 타이머 (켜짐 60초 → 꺼짐 30초 반복)
    · 훔치기 (ProximityPrompt → 들고 이동 → 내 금고 도착 시 소유권 이전,
               주인에게 잡히거나 15초 지나면 원래 자리로 반환)
    · 🛸 사이버 드론 해킹 (적 금고 방어막 남은 시간 감소 / 즉시 무력화)
    · 즉시 잠금(게임패스) 스킬
    · 🐾 펫 팔로우 — 가장 강한 전시품/드론이 3D 모델로 캐릭터 옆을 따라다님
    · 🌿 은신 수풀 — 수풀 존 안에서는 반투명 은신 + 이름표 숨김 + 추격 회피
    · 💛 황금 하이퍼 코어 — 45초마다 중앙 아레나에 등장, 먼저 차지하면
         현금 보너스 + 상대 3기지 방어막 25초 무력화
    · ⚡ 가속 / 🟢 점프 패드
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local world = Workspace:WaitForChild("NeonVaultWorld", 40)
if world == nil then
	warn("[NeonVault] Workspace.NeonVaultWorld 를 찾지 못했습니다. build_layout.lua 를 먼저 실행하세요.")
	return
end

local plotsFolder = world:WaitForChild("Plots", 20)
local templatesFolder = ServerStorage:WaitForChild("NeonVaultTemplates", 20)
local remotes = ReplicatedStorage:WaitForChild("NeonVaultRemotes", 30)
local configFolder = ReplicatedStorage:WaitForChild("NeonVaultConfig", 30)
if plotsFolder == nil or templatesFolder == nil or remotes == nil then
	warn("[NeonVault] 맵/템플릿/리모트가 없습니다. build_layout.lua 와 01 스크립트를 먼저 적용하세요.")
	return
end

local function ensureRemote(name)
	local existing = remotes:FindFirstChild(name)
	if existing ~= nil then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local notifyRemote = ensureRemote("Notify")
local rollFx = ensureRemote("RollFx")
local requestHackRemote = ensureRemote("RequestHack")
local requestLockRemote = ensureRemote("RequestInstantLock")

-- ==============================================================
-- 1. 밸런스 설정
-- ==============================================================
local SHIELD_ON_TIME = 60
local SHIELD_OFF_TIME = 30
local CARRY_TIME = 15
local HACK_COOLDOWN = 18
local INSTANT_LOCK_COOLDOWN = 45
local COLLECT_BONUS = 0.05
local MAX_SLOTS = 8
local CORE_INTERVAL = 45
local CORE_LIFETIME = 28
local CORE_RADIUS = 15
local CORE_REWARD = 1500
local CORE_SHIELD_CUT = 25
local PET_SIDE_OFFSET = 6
local PET_HEIGHT = 9
local STEALTH_TRANSPARENCY = 0.85

local RARITY_ORDER = { "common", "rare", "epic", "legendary" }
local RARITY = {
	common = { label = "일반", weight = 62, color = Color3.fromRGB(198, 214, 236), mult = 1 },
	rare = { label = "희귀", weight = 25, color = Color3.fromRGB(84, 186, 255), mult = 2.5 },
	epic = { label = "영웅", weight = 10, color = Color3.fromRGB(190, 116, 255), mult = 6 },
	legendary = { label = "전설", weight = 3, color = Color3.fromRGB(255, 190, 70), mult = 15 },
}

local THEMES = {
	gem = { label = "💎 보석", cost = 40, template = "Template_Gem", base = 2, height = 2.2, names = { "네온 수정", "루비 파편", "심연의 사파이어", "무한의 프리즘" } },
	egg = { label = "🦖 공룡 알", cost = 180, template = "Template_Egg", base = 6, height = 2.6, names = { "점박이 알", "발광 알", "고대의 알", "태고룡 알" } },
	monster = { label = "🐉 전설 몬스터", cost = 700, template = "Template_Monster", base = 18, height = 3.4, names = { "그림자 새끼", "화염 와이번", "심해 크라켄", "전설의 용" } },
	drone = { label = "🛸 사이버 드론", cost = 2600, template = "Template_Drone", base = 60, height = 2.6, names = { "정찰 드론", "해커 드론", "스텔스 드론", "오버로드 드론" } },
}

-- ==============================================================
-- 2. 상태 테이블
-- ==============================================================
local plotState = {}      -- [plot] = { on = bool, endsAt = number }
local plotOwner = {}      -- [plot] = userId
local carrying = {}       -- [player] = { ... }

local function now()
	return Workspace:GetServerTimeNow()
end

local function notify(player, text)
	if player ~= nil and player.Parent ~= nil and notifyRemote ~= nil then
		notifyRemote:FireClient(player, text)
	end
end

local function getPlot(index)
	return plotsFolder:FindFirstChild("Plot" .. tostring(index))
end

local function plotOfPlayer(player)
	local index = player:GetAttribute("VaultIndex") or 0
	if index == 0 then
		return nil
	end
	return getPlot(index)
end

local function ownerPlayerOf(plot)
	local userId = plotOwner[plot]
	if userId == nil then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function plotCenter(plot)
	local base = plot:FindFirstChild("Base")
	if base == nil then
		return Vector3.new(0, 0, 0)
	end
	return base.Position
end

-- 기지 크기에 맞춘 '내 금고 도착' 판정 반경 (대형 맵 대응)
local function plotReturnRadius(plot)
	local base = plot:FindFirstChild("Base")
	if base == nil then
		return 34
	end
	return math.max(base.Size.X, base.Size.Z) * 0.55
end

-- ==============================================================
-- 3. 전시대 · 전시품
-- ==============================================================
local function getPedestal(plot, slot)
	local folder = plot:FindFirstChild("Pedestals")
	if folder == nil then
		return nil
	end
	return folder:FindFirstChild("Slot" .. tostring(slot))
end

local function displaysOf(plot)
	return plot:FindFirstChild("Displays")
end

local function getDisplayBySlot(plot, slot)
	local folder = displaysOf(plot)
	if folder == nil then
		return nil
	end
	for _, display in ipairs(folder:GetChildren()) do
		if display:GetAttribute("Slot") == slot then
			return display
		end
	end
	return nil
end

local function refreshStealPrompts(plot)
	local folder = plot:FindFirstChild("Pedestals")
	if folder == nil then
		return
	end
	local state = plotState[plot]
	local shieldOff = (state ~= nil and state.on == false) and (plotOwner[plot] ~= nil)
	for _, pedestal in ipairs(folder:GetChildren()) do
		local prompt = pedestal:FindFirstChild("StealPrompt")
		if prompt ~= nil then
			local slot = pedestal:GetAttribute("Slot")
			local hasItem = (slot ~= nil) and (getDisplayBySlot(plot, slot) ~= nil)
			prompt.Enabled = shieldOff and hasItem
		end
	end
end

local function setShieldVisual(plot, on)
	local shield = plot:FindFirstChild("Shield")
	if shield == nil then
		return
	end
	for _, wall in ipairs(shield:GetChildren()) do
		if wall:IsA("BasePart") then
			local isWall = string.sub(wall.Name, 1, 10) == "ShieldWall"
			local isDome = wall.Name == "ShieldDome"
			if isWall or isDome then
				if on then
					wall.Transparency = isDome and 0.55 or 0.7
					wall.CanQuery = false
				else
					wall.Transparency = 1
				end
			end
		end
	end
end

local function clearPlot(plot)
	local folder = displaysOf(plot)
	if folder ~= nil then
		for _, display in ipairs(folder:GetChildren()) do
			display:Destroy()
		end
	end
	plotOwner[plot] = nil
	plot:SetAttribute("Owner", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("ShieldOn", true)
	plot:SetAttribute("Income", 0)
	plotState[plot] = { on = true, endsAt = now() + SHIELD_ON_TIME }
	setShieldVisual(plot, true)
	refreshStealPrompts(plot)
end

local function tintModel(model, color)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local name = descendant.Name
			if name == "Core" or name == "CoreLight" or name == "Head" then
				descendant.Color = color
			elseif string.sub(name, 1, 5) == "Shard" or string.sub(name, 1, 6) == "Rotor" or string.sub(name, 1, 3) == "Eye" then
				descendant.Color = color
			end
		end
	end
end

local function placeItem(plot, itemDef, slot)
	local template = templatesFolder:FindFirstChild(itemDef.template)
	if template == nil then
		return false
	end
	local pedestal = getPedestal(plot, slot)
	if pedestal == nil then
		return false
	end
	local existing = getDisplayBySlot(plot, slot)
	if existing ~= nil then
		existing:Destroy()
	end
	local model = template:Clone()
	model.Name = "Display"
	model:SetAttribute("Slot", slot)
	model:SetAttribute("ItemId", itemDef.id)
	model:SetAttribute("ItemName", itemDef.name)
	model:SetAttribute("Theme", itemDef.theme)
	model:SetAttribute("Rarity", itemDef.rarity)
	model:SetAttribute("Income", itemDef.income)
	tintModel(model, RARITY[itemDef.rarity].color)
	local target = pedestal.Position + Vector3.new(0, itemDef.height, 0)
	model:PivotTo(CFrame.new(target))
	model.Parent = displaysOf(plot)

	local prompt = pedestal:FindFirstChild("StealPrompt")
	if prompt ~= nil then
		prompt.ObjectText = itemDef.name
	end
	refreshStealPrompts(plot)
	return true
end

local function firstFreeSlot(plot)
	for slot = 1, MAX_SLOTS do
		if getDisplayBySlot(plot, slot) == nil then
			return slot
		end
	end
	return nil
end

local function weakestSlot(plot)
	local folder = displaysOf(plot)
	if folder == nil then
		return nil
	end
	local weakest = nil
	local weakestIncome = math.huge
	for _, display in ipairs(folder:GetChildren()) do
		local income = display:GetAttribute("Income") or 0
		if income < weakestIncome then
			weakestIncome = income
			weakest = display:GetAttribute("Slot")
		end
	end
	return weakest
end

local function addItemToVault(player, itemDef)
	local plot = plotOfPlayer(player)
	if plot == nil then
		return false, "기지가 없습니다"
	end
	local slot = firstFreeSlot(plot)
	local replaced = false
	if slot == nil then
		slot = weakestSlot(plot)
		replaced = true
	end
	if slot == nil then
		return false, "전시대가 가득 찼습니다"
	end
	placeItem(plot, itemDef, slot)
	if replaced then
		notify(player, "♻️ 전시대가 가득 차서 가장 약한 전시품을 교체했습니다.")
	end
	return true, "ok"
end

-- ==============================================================
-- 4. 도감 기록
-- ==============================================================
local function bumpCollection(player, themeId, rarity)
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Collection") or "{}")
	end)
	local collection = {}
	if ok and type(decoded) == "table" then
		collection = decoded
	end
	local entry = collection[themeId]
	if type(entry) ~= "table" then
		entry = { count = 0, best = "" }
	end
	entry.count = (entry.count or 0) + 1
	local bestIndex = 0
	for i, rar in ipairs(RARITY_ORDER) do
		if rar == entry.best then
			bestIndex = i
		end
	end
	for i, rar in ipairs(RARITY_ORDER) do
		if rar == rarity then
			if i > bestIndex then
				entry.best = rarity
			end
		end
	end
	collection[themeId] = entry
	player:SetAttribute("Collection", HttpService:JSONEncode(collection))
end

-- ==============================================================
-- 5. 뽑기
-- ==============================================================
local function pickRarity()
	local total = 0
	for _, key in ipairs(RARITY_ORDER) do
		total = total + RARITY[key].weight
	end
	local roll = math.random() * total
	local acc = 0
	for _, key in ipairs(RARITY_ORDER) do
		acc = acc + RARITY[key].weight
		if roll <= acc then
			return key
		end
	end
	return "common"
end

local function themeCost(themeId)
	local theme = THEMES[themeId]
	if theme == nil then
		return 0
	end
	local folder = configFolder:FindFirstChild("GachaCost")
	local value = nil
	if folder ~= nil then
		value = folder:FindFirstChild(themeId)
	end
	if value ~= nil and value:IsA("NumberValue") and value.Value > 0 then
		return math.floor(value.Value)
	end
	return theme.cost
end

local function doGacha(player, themeId)
	local theme = THEMES[themeId]
	if theme == nil then
		return
	end
	if (player:GetAttribute("DataLoaded") ~= true) then
		notify(player, "⏳ 데이터를 불러오는 중입니다. 잠시 후 다시 시도하세요.")
		return
	end
	if player:GetAttribute("VaultIndex") == 0 then
		notify(player, "기지가 없어 뽑기를 사용할 수 없습니다.")
		return
	end
	local cost = themeCost(themeId)
	local cash = player:GetAttribute("Cash") or 0
	if cash < cost then
		notify(player, "💸 현금이 부족합니다. 필요 $" .. tostring(cost) .. " (보유 $" .. tostring(math.floor(cash)) .. ")")
		return
	end
	player:SetAttribute("Cash", cash - cost)

	local rarity = pickRarity()
	local rarityIndex = 1
	for i, key in ipairs(RARITY_ORDER) do
		if key == rarity then
			rarityIndex = i
		end
	end
	local itemDef = {
		id = themeId .. "_" .. rarity,
		theme = themeId,
		rarity = rarity,
		name = theme.names[rarityIndex],
		income = math.floor(theme.base * RARITY[rarity].mult + 0.5),
		template = theme.template,
		height = theme.height,
	}

	local ok = addItemToVault(player, itemDef)
	if not ok then
		player:SetAttribute("Cash", cash)
		notify(player, "전시대에 놓을 자리가 없습니다.")
		return
	end

	bumpCollection(player, themeId, rarity)
	if themeId == "drone" then
		local power = rarityIndex
		local best = player:GetAttribute("DroneBest") or 0
		if power > best then
			player:SetAttribute("DroneBest", power)
			notify(player, "🛸 드론 해킹 성능이 강화되었습니다! (해킹 파워 " .. tostring(power) .. ")")
		end
		player:SetAttribute("DroneCount", (player:GetAttribute("DroneCount") or 0) + 1)
	end

	notify(player, "🎰 [" .. RARITY[rarity].label .. "] " .. itemDef.name .. " 획득! +$" .. tostring(itemDef.income) .. "/초")
	if rollFx ~= nil then
		rollFx:FireClient(player, themeId, itemDef.name, rarity, itemDef.income)
	end
end

-- ==============================================================
-- 6. 방어막 / 수익 / 상태 표시 루프
-- ==============================================================
local function startShield(plot, seconds)
	local state = plotState[plot]
	if state == nil then
		state = { on = true, endsAt = 0 }
		plotState[plot] = state
	end
	state.on = true
	state.endsAt = now() + seconds
	plot:SetAttribute("ShieldOn", true)
	plot:SetAttribute("ShieldEnds", state.endsAt)
	setShieldVisual(plot, true)
	refreshStealPrompts(plot)
end

local function updateStatusGui(plot)
	local anchor = plot:FindFirstChild("StatusAnchor")
	if anchor == nil then
		return
	end
	local gui = anchor:FindFirstChild("PlotStatusGui")
	if gui == nil then
		return
	end
	local label = gui:FindFirstChild("StatusLabel")
	if label == nil then
		return
	end
	local index = plot:GetAttribute("PlotIndex") or 0
	local owner = ownerPlayerOf(plot)
	if owner == nil then
		label.Text = "기지 " .. tostring(index) .. " · 빈 기지"
		label.TextColor3 = Color3.fromRGB(150, 160, 185)
		return
	end
	local state = plotState[plot]
	local remaining = 0
	if state ~= nil then
		remaining = math.max(0, math.floor(state.endsAt - now()))
	end
	if state ~= nil and state.on then
		label.Text = "기지 " .. tostring(index) .. " · @" .. owner.Name .. "\n🛡 방어막 " .. tostring(remaining) .. "초"
		label.TextColor3 = Color3.fromRGB(120, 230, 255)
	else
		label.Text = "기지 " .. tostring(index) .. " · @" .. owner.Name .. "\n⚠ 무방비 " .. tostring(remaining) .. "초"
		label.TextColor3 = Color3.fromRGB(255, 96, 96)
	end
end

local function tickShields()
	for i = 1, 4 do
		local plot = getPlot(i)
		if plot ~= nil then
			local state = plotState[plot]
			if state == nil then
				state = { on = true, endsAt = now() + SHIELD_ON_TIME }
				plotState[plot] = state
			elseif state.on then
				if now() >= state.endsAt then
					state.on = false
					state.endsAt = now() + SHIELD_OFF_TIME
					plot:SetAttribute("ShieldOn", false)
					plot:SetAttribute("ShieldEnds", state.endsAt)
					setShieldVisual(plot, false)
					refreshStealPrompts(plot)
					local owner = ownerPlayerOf(plot)
					if owner ~= nil then
						notify(owner, "⚠️ 방어막이 꺼졌습니다! 30초 동안 약탈당할 수 있습니다.")
					end
				end
			else
				if now() >= state.endsAt then
					startShield(plot, SHIELD_ON_TIME)
					local owner = ownerPlayerOf(plot)
					if owner ~= nil then
						notify(owner, "🛡 방어막이 다시 켜졌습니다.")
					end
				end
			end
			plot:SetAttribute("ShieldEnds", state.endsAt)
			local owner = ownerPlayerOf(plot)
			if owner ~= nil then
				owner:SetAttribute("ShieldOn", state.on)
				owner:SetAttribute("ShieldEnds", state.endsAt)
			end
			updateStatusGui(plot)
		end
	end
end

local function tickIncome()
	for i = 1, 4 do
		local plot = getPlot(i)
		if plot ~= nil then
			local owner = ownerPlayerOf(plot)
			if owner ~= nil then
				local total = 0
				local folder = displaysOf(plot)
				if folder ~= nil then
					for _, display in ipairs(folder:GetChildren()) do
						total = total + (display:GetAttribute("Income") or 0)
					end
				end
				local mult = 1
				if owner:GetAttribute("Has2xCash") == true then
					mult = 2
				end
				local perSec = total * mult
				plot:SetAttribute("Income", perSec)
				owner:SetAttribute("IncomePerSec", perSec)
				if perSec > 0 then
					local pending = owner:GetAttribute("Pending") or 0
					local cap = math.max(400, perSec * 90)
					pending = math.min(cap, pending + perSec)
					owner:SetAttribute("Pending", pending)
				end
			end
		end
	end
end

local function collectPending(player, sourcePlot)
	local plot = plotOfPlayer(player)
	if plot == nil then
		return
	end
	if sourcePlot ~= nil and sourcePlot ~= plot then
		notify(player, "다른 사람의 수금 패드입니다.")
		return
	end
	local pending = player:GetAttribute("Pending") or 0
	if pending < 1 then
		notify(player, "💤 아직 모인 수익이 없습니다.")
		return
	end
	local bonus = math.floor(pending * COLLECT_BONUS)
	local gained = math.floor(pending) + bonus
	player:SetAttribute("Pending", 0)
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + gained)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + gained)
	if bonus > 0 then
		notify(player, "💰 $" .. tostring(gained) .. " 수금! (직접 수금 보너스 +$" .. tostring(bonus) .. ")")
	else
		notify(player, "💰 $" .. tostring(gained) .. " 수금!")
	end
end

-- ==============================================================
-- 7. 훔치기
-- ==============================================================
local function releaseCarry(player, returnToSource)
	local data = carrying[player]
	if data == nil then
		return
	end
	carrying[player] = nil
	player:SetAttribute("Carrying", "")
	player:SetAttribute("CarryEnds", 0)
	if data.model ~= nil then
		data.model:Destroy()
	end
	if data.holder ~= nil then
		data.holder:Destroy()
	end
	if returnToSource and data.plot ~= nil and data.plot.Parent ~= nil then
		placeItem(data.plot, data.itemDef, data.slot)
	end
end

local function attachCarry(player, itemDef)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil, nil
	end
	local holder = Instance.new("Part")
	holder.Name = "NeonVaultCarry"
	holder.Size = Vector3.new(1, 1, 1)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.Massless = true
	holder.Anchored = false
	holder.CFrame = root.CFrame * CFrame.new(0, 4.2, 0)
	holder.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = holder
	weld.Parent = holder

	local template = templatesFolder:FindFirstChild(itemDef.template)
	if template == nil then
		return holder, nil
	end
	local model = template:Clone()
	model.Name = "CarriedLoot"
	local primary = model.PrimaryPart
	local primaryCFrame = CFrame.new(0, 0, 0)
	if primary ~= nil then
		primaryCFrame = primary.CFrame
	end
	model.Parent = character
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local rel = primaryCFrame:Inverse() * descendant.CFrame
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			descendant.CFrame = holder.CFrame * rel
			local weldPart = Instance.new("WeldConstraint")
			weldPart.Part0 = holder
			weldPart.Part1 = descendant
			weldPart.Parent = descendant
		end
	end
	tintModel(model, RARITY[itemDef.rarity].color)
	return holder, model
end

local function trySteal(player, plot, pedestal)
	if plot == nil or pedestal == nil then
		return
	end
	if plotOwner[plot] == nil then
		notify(player, "빈 기지입니다.")
		return
	end
	if plotOwner[plot] == player.UserId then
		notify(player, "내 금고의 전시품은 훔칠 수 없습니다.")
		return
	end
	local state = plotState[plot]
	if state == nil or state.on then
		notify(player, "🛡 방어막이 켜져 있어 훔칠 수 없습니다.")
		return
	end
	if carrying[player] ~= nil then
		notify(player, "이미 전리품을 들고 있습니다. 먼저 내 금고로 가져가세요.")
		return
	end
	local slot = pedestal:GetAttribute("Slot")
	local display = getDisplayBySlot(plot, slot)
	if display == nil then
		notify(player, "빈 전시대입니다.")
		return
	end
	local themeId = display:GetAttribute("Theme")
	local themeDef = THEMES[themeId]
	if themeDef == nil then
		notify(player, "전시품 정보를 읽을 수 없습니다.")
		return
	end
	local itemDef = {
		id = display:GetAttribute("ItemId"),
		theme = themeId,
		rarity = display:GetAttribute("Rarity"),
		name = display:GetAttribute("ItemName"),
		income = display:GetAttribute("Income"),
		template = themeDef.template,
		height = themeDef.height,
	}
	display:Destroy()
	refreshStealPrompts(plot)

	local holder, model = attachCarry(player, itemDef)
	carrying[player] = {
		itemDef = itemDef,
		slot = slot,
		plot = plot,
		endsAt = now() + CARRY_TIME,
		holder = holder,
		model = model,
	}
	player:SetAttribute("Carrying", itemDef.name)
	player:SetAttribute("CarryEnds", now() + CARRY_TIME)
	notify(player, "🕵️ " .. itemDef.name .. " 훔쳤습니다! 15초 안에 내 금고로!")
	local owner = ownerPlayerOf(plot)
	if owner ~= nil then
		notify(owner, "🚨 " .. player.Name .. " 이(가) " .. itemDef.name .. " 을(를) 훔쳐 갑니다! 잡으세요!")
	end
end

local function resolveCarry(player)
	local data = carrying[player]
	if data == nil then
		return
	end
	local character = player.Character
	if character == nil or character:FindFirstChild("HumanoidRootPart") == nil then
		releaseCarry(player, true)
		return
	end
	local root = character.HumanoidRootPart
	local myPlot = plotOfPlayer(player)
	if myPlot ~= nil then
		local distance = (root.Position - plotCenter(myPlot)).Magnitude
		if distance < plotReturnRadius(myPlot) then
			local itemDef = data.itemDef
			releaseCarry(player, false)
			local ok = addItemToVault(player, itemDef)
			if not ok then
				notify(player, "전시대가 가득 차 전리품을 놓쳤습니다.")
				return
			end
			player:SetAttribute("Steals", (player:GetAttribute("Steals") or 0) + 1)
			bumpCollection(player, itemDef.theme, itemDef.rarity)
			notify(player, "✅ 약탈 성공! " .. itemDef.name .. " 이(가) 내 금고에 전시되었습니다.")
			local victim = Players:GetPlayerByUserId(plotOwner[data.plot] or 0)
			if victim ~= nil then
				notify(victim, "💀 " .. player.Name .. " 이(가) " .. itemDef.name .. " 을(를) 훔쳐 갔습니다.")
			end
			return
		end
	end
	local sourceOwner = ownerPlayerOf(data.plot)
	if sourceOwner ~= nil and sourceOwner.Character ~= nil then
		local ownerRoot = sourceOwner.Character:FindFirstChild("HumanoidRootPart")
		if ownerRoot ~= nil then
			local catchRange = (player:GetAttribute("Stealthed") == true) and 5 or 9
			if (ownerRoot.Position - root.Position).Magnitude < catchRange then
				local itemName = data.itemDef.name
				releaseCarry(player, true)
				notify(player, "❌ 잡혔습니다! " .. itemName .. " 이(가) 원래 자리로 돌아갑니다.")
				notify(sourceOwner, "🛡 " .. player.Name .. " 을(를) 잡아 전리품을 되찾았습니다!")
				return
			end
		end
	end
	if now() >= data.endsAt then
		local itemName = data.itemDef.name
		releaseCarry(player, true)
		notify(player, "⏰ 시간 초과! " .. itemName .. " 이(가) 원래 자리로 돌아갑니다.")
		if sourceOwner ~= nil then
			notify(sourceOwner, "🔁 경보가 울려 " .. itemName .. " 이(가) 돌아왔습니다.")
		end
	end
end

-- ==============================================================
-- 8. 드론 해킹 / 즉시 잠금
-- ==============================================================
local function beam(origin, target)
	local distance = (target - origin).Magnitude
	local beamPart = Instance.new("Part")
	beamPart.Name = "HackBeam"
	beamPart.Size = Vector3.new(1.4, 1.4, distance)
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = Color3.fromRGB(180, 120, 255)
	beamPart.Transparency = 0.15
	beamPart.CFrame = CFrame.lookAt(origin + (target - origin) * 0.5, target)
	beamPart.Parent = Workspace
	TweenService:Create(beamPart, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(0.1, 0.1, distance) }):Play()
	task.delay(0.75, function()
		if beamPart.Parent ~= nil then
			beamPart:Destroy()
		end
	end)
end

local function requestHack(player)
	local power = player:GetAttribute("DroneBest") or 0
	if power <= 0 then
		notify(player, "🛸 해킹하려면 사이버 드론이 필요합니다. 중앙 타워에서 드론을 뽑으세요.")
		return
	end
	local readyAt = player:GetAttribute("HackReadyAt") or 0
	if now() < readyAt then
		notify(player, "⏳ 해킹 재충전 중 " .. tostring(math.ceil(readyAt - now())) .. "초")
		return
	end
	local myPlot = plotOfPlayer(player)
	local character = player.Character
	local origin = nil
	if character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil then
		origin = character.HumanoidRootPart.Position
	end
	if origin == nil then
		origin = Vector3.new(0, 5, 0)
	end

	local bestPlot = nil
	local bestDistance = math.huge
	for i = 1, 4 do
		local plot = getPlot(i)
		if plot ~= nil and plot ~= myPlot and plotOwner[plot] ~= nil then
			local state = plotState[plot]
			if state ~= nil and state.on then
				local distance = (plotCenter(plot) - origin).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestPlot = plot
				end
			end
		end
	end
	if bestPlot == nil then
		notify(player, "지금 해킹할 방어막이 없습니다. (모두 꺼져 있거나 상대가 없습니다)")
		return
	end

	local state = plotState[bestPlot]
	local cut = 8 + power * 6
	state.endsAt = state.endsAt - cut
	player:SetAttribute("HackReadyAt", now() + HACK_COOLDOWN)
	beam(origin, plotCenter(bestPlot) + Vector3.new(0, 10, 0))
	if state.endsAt <= now() then
		state.on = false
		state.endsAt = now() + SHIELD_OFF_TIME
		bestPlot:SetAttribute("ShieldOn", false)
		setShieldVisual(bestPlot, false)
		refreshStealPrompts(bestPlot)
		notify(player, "🛸 해킹 성공! 기지 " .. tostring(bestPlot:GetAttribute("PlotIndex")) .. " 방어막을 완전히 무력화했습니다!")
		local victim = ownerPlayerOf(bestPlot)
		if victim ~= nil then
			notify(victim, "🛸 해킹당했습니다! 방어막이 즉시 꺼졌습니다.")
		end
	else
		notify(player, "🛸 해킹 성공! 기지 " .. tostring(bestPlot:GetAttribute("PlotIndex")) .. " 방어막 -" .. tostring(cut) .. "초")
		local victim = ownerPlayerOf(bestPlot)
		if victim ~= nil then
			notify(victim, "🛸 해킹으로 방어막 시간이 " .. tostring(cut) .. "초 줄었습니다.")
		end
	end
	bestPlot:SetAttribute("ShieldEnds", state.endsAt)
end

local function requestInstantLock(player)
	if player:GetAttribute("HasInstantLock") ~= true then
		notify(player, "🔒 '즉시 잠금' 게임패스가 필요합니다. 상점에서 구매할 수 있습니다.")
		return
	end
	local readyAt = player:GetAttribute("InstantLockReadyAt") or 0
	if now() < readyAt then
		notify(player, "⏳ 잠금 재사용까지 " .. tostring(math.ceil(readyAt - now())) .. "초")
		return
	end
	local plot = plotOfPlayer(player)
	if plot == nil then
		notify(player, "기지가 없습니다.")
		return
	end
	startShield(plot, SHIELD_ON_TIME)
	player:SetAttribute("InstantLockReadyAt", now() + INSTANT_LOCK_COOLDOWN)
	notify(player, "🔒 방어막을 즉시 잠갔습니다! 60초 보호")
end

-- ==============================================================
-- 8-B. 🐾 펫 팔로우 (최고 등급 전시품/드론이 캐릭터 옆을 따라다님)
-- ==============================================================
local pets = {}

local function bestDisplayOf(plot)
	if plot == nil then
		return nil
	end
	local folder = displaysOf(plot)
	if folder == nil then
		return nil
	end
	local best = nil
	local bestIncome = -1
	for _, display in ipairs(folder:GetChildren()) do
		local income = display:GetAttribute("Income") or 0
		if income > bestIncome then
			bestIncome = income
			best = display
		end
	end
	return best
end

local function makePetModel(player, templateName)
	local template = templatesFolder:FindFirstChild(templateName)
	if template == nil then
		return nil
	end
	local model = template:Clone()
	model.Name = "FollowPet_" .. player.Name
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	if model.PrimaryPart == nil then
		model.PrimaryPart = model:FindFirstChild("Core")
	end
	-- 처음부터 캐릭터 옆에 나타나도록 위치를 잡고 부모를 설정합니다.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil then
		model:PivotTo(CFrame.new(root.Position + root.CFrame.RightVector * PET_SIDE_OFFSET + Vector3.new(0, PET_HEIGHT, 0)))
	end
	model.Parent = Workspace
	return model
end

local function refreshPet(player)
	local plot = plotOfPlayer(player)
	local best = bestDisplayOf(plot)
	local key = nil
	if best ~= nil then
		key = tostring(best:GetAttribute("ItemId")) .. "#" .. tostring(best:GetAttribute("Slot"))
	end
	local entry = pets[player]
	if entry ~= nil and entry.key == key then
		return
	end
	if entry ~= nil and entry.model ~= nil then
		entry.model:Destroy()
	end
	pets[player] = nil
	if best == nil then
		return
	end
	local themeDef = THEMES[best:GetAttribute("Theme") or "gem"]
	if themeDef == nil then
		return
	end
	local model = makePetModel(player, themeDef.template)
	if model == nil then
		return
	end
	pets[player] = { model = model, key = key, position = nil }
end

local function updatePets(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		refreshPet(player)
		local entry = pets[player]
		if entry ~= nil and entry.model ~= nil then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root ~= nil then
				local bob = math.sin(Workspace:GetServerTimeNow() * 2.4) * 0.8
				local target = root.Position + root.CFrame.RightVector * PET_SIDE_OFFSET + Vector3.new(0, PET_HEIGHT + bob, 0)
				if entry.position == nil then
					entry.position = target
				end
				entry.position = entry.position:Lerp(target, math.min(1, dt * 6))
				local spin = Workspace:GetServerTimeNow() * 1.3
				entry.model:PivotTo(CFrame.new(entry.position) * CFrame.Angles(0, spin, 0))
			end
		end
	end
end

local function clearPet(player)
	local entry = pets[player]
	if entry ~= nil and entry.model ~= nil then
		entry.model:Destroy()
	end
	pets[player] = nil
end

-- ==============================================================
-- 8-C. 🌿 은신 수풀
-- ==============================================================
local bushZones = {}

local function loadBushes()
	bushZones = {}
	local folder = world:FindFirstChild("Bushes")
	if folder == nil then
		return
	end
	for _, bush in ipairs(folder:GetChildren()) do
		local zone = bush:FindFirstChild("BushZone")
		if zone ~= nil then
			local radius = zone:GetAttribute("Radius") or 30
			table.insert(bushZones, { position = zone.Position, radius = math.max(radius, 20) })
		end
	end
end

local function setStealth(player, on)
	if player:GetAttribute("Stealthed") == on then
		return
	end
	player:SetAttribute("Stealthed", on)
	local character = player.Character
	if character == nil then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			if on then
				if descendant:GetAttribute("NVOrigTransparency") == nil then
					descendant:SetAttribute("NVOrigTransparency", descendant.Transparency)
				end
				descendant.Transparency = math.max(descendant.Transparency, STEALTH_TRANSPARENCY)
			else
				local original = descendant:GetAttribute("NVOrigTransparency")
				if original ~= nil then
					descendant.Transparency = original
					descendant:SetAttribute("NVOrigTransparency", nil)
				end
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		if on then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		else
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
	if on then
		notify(player, "🌿 은신 중 — 다른 플레이어에게 보이지 않습니다.")
	else
		notify(player, "🌿 수풀에서 나왔습니다.")
	end
end

local function updateStealth()
	if #bushZones == 0 then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root ~= nil then
			local inside = false
			for _, zone in ipairs(bushZones) do
				local dx = root.Position.X - zone.position.X
				local dz = root.Position.Z - zone.position.Z
				if (dx * dx + dz * dz) < (zone.radius * zone.radius) then
					inside = true
					break
				end
			end
			setStealth(player, inside)
		end
	end
end

-- ==============================================================
-- 8-D. 💛 황금 하이퍼 코어
-- ==============================================================
local coreModel = nil
local coreActive = false
local coreEndsAt = 0
local coreNextAt = 0

local function coreAnchorPart()
	local arena = world:FindFirstChild("Arena")
	local dais = arena and arena:FindFirstChild("CoreDais")
	return dais and dais:FindFirstChild("CoreSpawn") or nil
end

local function publishCoreState()
	Workspace:SetAttribute("NV_CoreActive", coreActive)
	Workspace:SetAttribute("NV_CoreEndsAt", coreEndsAt)
	Workspace:SetAttribute("NV_CoreNextAt", coreNextAt)
end

local function spawnCore()
	local anchor = coreAnchorPart()
	if anchor == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "GoldenHyperCore"

	local ball = Instance.new("Part")
	ball.Name = "CoreBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(16, 16, 16)
	ball.CFrame = anchor.Position
	ball.Anchored = true
	ball.CanCollide = false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 224, 102)
	ball.Transparency = 0.05
	ball.Parent = model

	local ringA = Instance.new("Part")
	ringA.Name = "CoreRingA"
	ringA.Size = Vector3.new(30, 1.6, 30)
	ringA.CFrame = anchor.Position + Vector3.new(0, 2, 0)
	ringA.Anchored = true
	ringA.CanCollide = false
	ringA.Material = Enum.Material.Neon
	ringA.Color = Color3.fromRGB(255, 198, 58)
	ringA.Transparency = 0.2
	ringA.Shape = Enum.PartType.Cylinder
	ringA.CFrame = CFrame.new(anchor.Position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ringA.Parent = model

	local glow = Instance.new("PointLight")
	glow.Brightness = 6
	glow.Range = 60
	glow.Color = Color3.fromRGB(255, 210, 90)
	glow.Parent = ball

	local gui = Instance.new("BillboardGui")
	gui.Name = "CoreGui"
	gui.Adornee = ball
	gui.Size = UDim2.fromOffset(360, 90)
	gui.StudsOffset = Vector3.new(0, 16, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 600
	gui.Parent = ball
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 190)
	label.TextStrokeTransparency = 0.2
	label.Text = "💛 황금 하이퍼 코어 — 먼저 차지하세요!"
	label.Parent = gui

	model.Parent = Workspace
	coreModel = model
	coreActive = true
	coreEndsAt = now() + CORE_LIFETIME
	publishCoreState()

	for _, player in ipairs(Players:GetPlayers()) do
		notify(player, "💛 황금 하이퍼 코어 등장! 중앙 아레나로!")
	end
end

local function despawnCore()
	if coreModel ~= nil then
		coreModel:Destroy()
		coreModel = nil
	end
	coreActive = false
	coreNextAt = now() + CORE_INTERVAL
	publishCoreState()
end

local function claimCore(player)
	local myPlot = plotOfPlayer(player)
	if myPlot == nil then
		return
	end
	for i = 1, 4 do
		local plot = getPlot(i)
		if plot ~= nil and plot ~= myPlot then
			local state = plotState[plot]
			if state ~= nil then
				state.on = false
				state.endsAt = now() + CORE_SHIELD_CUT
				plot:SetAttribute("ShieldOn", false)
				plot:SetAttribute("ShieldEnds", state.endsAt)
				setShieldVisual(plot, false)
				refreshStealPrompts(plot)
			end
		end
	end
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + CORE_REWARD)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + CORE_REWARD)
	player:SetAttribute("Cores", (player:GetAttribute("Cores") or 0) + 1)
	notify(player, "💛 황금 코어 차지! +$" .. tostring(CORE_REWARD) .. " · 상대 3기지 방어막 " .. tostring(CORE_SHIELD_CUT) .. "초 무력화!")
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			notify(other, "😱 " .. player.Name .. " 이(가) 황금 코어를 차지해 내 방어막이 무력화되었습니다!")
		end
	end
	despawnCore()
end

local function updateCore()
	if not coreActive then
		if coreNextAt == 0 then
			coreNextAt = now() + CORE_INTERVAL
			publishCoreState()
			return
		end
		if now() >= coreNextAt then
			spawnCore()
		end
		return
	end
	local anchor = coreAnchorPart()
	if anchor == nil then
		despawnCore()
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and (root.Position - anchor.Position).Magnitude < CORE_RADIUS then
			claimCore(player)
			return
		end
	end
	if now() >= coreEndsAt then
		despawnCore()
		for _, player in ipairs(Players:GetPlayers()) do
			notify(player, "💛 코어가 사라졌습니다. 다음 스폰을 기다리세요.")
		end
	end
end

-- ==============================================================
-- 8-E. ⚡ 가속 패드 · 🟢 점프 패드
-- ==============================================================
local function connectPadsFolder()
	local pads = world:FindFirstChild("Pads")
	if pads == nil then
		return
	end
	for _, pad in ipairs(pads:GetChildren()) do
		if pad:IsA("BasePart") and pad:GetAttribute("Connected") ~= true then
			if pad:GetAttribute("SpeedPad") == true then
				pad:SetAttribute("Connected", true)
				pad.Touched:Connect(function(hit)
					local character = hit:FindFirstAncestorOfClass("Model")
					if character == nil then
						return
					end
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid == nil or pad:GetAttribute("BoostUntil") ~= nil then
						return
					end
					local boost = pad:GetAttribute("BoostSpeed") or 40
					if humanoid.WalkSpeed >= boost then
						return
					end
					local original = humanoid.WalkSpeed
					humanoid.WalkSpeed = boost
					pad:SetAttribute("BoostUntil", now() + 2)
					task.delay(2, function()
						if humanoid.Parent ~= nil then
							humanoid.WalkSpeed = original
						end
						pad:SetAttribute("BoostUntil", nil)
					end)
				end)
			elseif pad:GetAttribute("JumpPad") == true then
				pad:SetAttribute("Connected", true)
				pad.Touched:Connect(function(hit)
					local root = hit:FindFirstAncestorOfClass("Model")
					if root == nil then
						return
					end
					local part = root:FindFirstChild("HumanoidRootPart")
					if part == nil then
						return
					end
					if now() < (pad:GetAttribute("NextJumpAt") or 0) then
						return
					end
					pad:SetAttribute("NextJumpAt", now() + 1.5)
					part.AssemblyLinearVelocity = Vector3.new(part.AssemblyLinearVelocity.X, pad:GetAttribute("JumpPower") or 90, part.AssemblyLinearVelocity.Z)
				end)
			end
		end
	end
end

-- ==============================================================
-- 9. 프롬프트 연결
-- ==============================================================
local function connectPedestal(pedestal)
	local prompt = pedestal:FindFirstChild("StealPrompt")
	if prompt == nil or prompt:GetAttribute("Connected") == true then
		return
	end
	prompt:SetAttribute("Connected", true)
	prompt.Triggered:Connect(function(player)
		local plot = pedestal.Parent
		plot = plot.Parent
		trySteal(player, plot, pedestal)
	end)
end

local function connectPads(plot)
	local collectPad = plot:FindFirstChild("CollectPad")
	if collectPad ~= nil then
		local prompt = collectPad:FindFirstChildOfClass("ProximityPrompt")
		if prompt ~= nil and prompt:GetAttribute("Connected") ~= true then
			prompt:SetAttribute("Connected", true)
			prompt.Triggered:Connect(function(player)
				collectPending(player, plot)
			end)
		end
	end
	local enterPad = plot:FindFirstChild("EnterPad")
	if enterPad ~= nil then
		local prompt = enterPad:FindFirstChildOfClass("ProximityPrompt")
		if prompt ~= nil and prompt:GetAttribute("Connected") ~= true then
			prompt:SetAttribute("Connected", true)
			prompt.Triggered:Connect(function(player)
				local myPlot = plotOfPlayer(player)
				if myPlot == nil then
					notify(player, "기지가 없습니다.")
					return
				end
				local character = player.Character
				if character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil then
					local center = plotCenter(myPlot)
					character:PivotTo(CFrame.new(center + Vector3.new(0, 5, 0)))
					notify(player, "🏠 내 금고로 이동했습니다.")
				end
			end)
		end
	end
end

local function connectTower()
	-- 중앙 타워 + 4개 테마 구역 뽑기 패드를 모두 연결합니다.
	for _, descendant in ipairs(world:GetDescendants()) do
		local themeId = descendant:GetAttribute("Theme")
		if themeId ~= nil and THEMES[themeId] ~= nil then
			local prompt = descendant:FindFirstChildOfClass("ProximityPrompt")
			if prompt ~= nil and prompt:GetAttribute("Connected") ~= true then
				prompt:SetAttribute("Connected", true)
				prompt.ObjectText = THEMES[themeId].label .. "  $" .. tostring(themeCost(themeId))
				prompt.Triggered:Connect(function(player)
					doGacha(player, themeId)
				end)
			end
		end
	end
end

-- ==============================================================
-- 10. 기지 배정
-- ==============================================================
local function teleportToPlot(player)
	local plot = plotOfPlayer(player)
	if plot == nil then
		return
	end
	local character = player.Character
	if character == nil or character:FindFirstChild("HumanoidRootPart") == nil then
		return
	end
	character:PivotTo(CFrame.new(plotCenter(plot) + Vector3.new(0, 6, 0)))
end

local function assignPlot(player)
	if (player:GetAttribute("VaultIndex") or 0) > 0 then
		return
	end
	for i = 1, 4 do
		local plot = getPlot(i)
		if plot ~= nil and plotOwner[plot] == nil then
			plotOwner[plot] = player.UserId
			plot:SetAttribute("Owner", player.UserId)
			plot:SetAttribute("OwnerName", player.Name)
			plot:SetAttribute("Income", 0)
			player:SetAttribute("VaultIndex", i)
			plotState[plot] = { on = true, endsAt = now() + SHIELD_ON_TIME }
			startShield(plot, SHIELD_ON_TIME)
			updateStatusGui(plot)
			notify(player, "🏦 기지 " .. tostring(i) .. " 이(가) 배정되었습니다. 60초 뒤 방어막이 꺼집니다!")
			task.delay(0.6, teleportToPlot, player)
			return
		end
	end
	notify(player, "😥 빈 기지가 없습니다. 관전 모드입니다. 누군가 나가면 자동으로 배정됩니다.")
end

local function onCharacterAdded(player, character)
	task.wait(0.4)
	releaseCarry(player, true)
	if (player:GetAttribute("VaultIndex") or 0) > 0 then
		teleportToPlot(player)
	end
end

local function onPlayerAdded(player)
	-- 01 스크립트가 데이터를 세팅할 때까지 기다립니다.
	local waited = 0
	while player:GetAttribute("DataLoaded") ~= true and waited < 15 do
		task.wait(0.25)
		waited = waited + 0.25
	end
	assignPlot(player)
	if player.Character ~= nil then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:SetAttribute("HackReadyAt", 0)
	player:SetAttribute("InstantLockReadyAt", 0)
	player:SetAttribute("CarryEnds", 0)
end

local function onPlayerRemoving(player)
	clearPet(player)
	local plot = plotOfPlayer(player)
	releaseCarry(player, false)
	if plot ~= nil then
		clearPlot(plot)
		player:SetAttribute("VaultIndex", 0)
		player:SetAttribute("ShieldOn", true)
		player:SetAttribute("ShieldEnds", 0)
		player:SetAttribute("IncomePerSec", 0)
		-- 나간 사람이 있던 자리를 기다리던 플레이어에게 배정합니다.
		for _, other in ipairs(Players:GetPlayers()) do
			if (other:GetAttribute("VaultIndex") or 0) == 0 then
				task.spawn(assignPlot, other)
			end
		end
	end
end

-- ==============================================================
-- 11. 리모트 연결 + 초기화
-- ==============================================================
requestHackRemote.OnServerEvent:Connect(function(player)
	requestHack(player)
end)

requestLockRemote.OnServerEvent:Connect(function(player)
	requestInstantLock(player)
end)

-- 맵의 전시대/패드/타워 프롬프트 연결 (맵이 나중에 로드되어도 잡도록 반복)
task.spawn(function()
	for attempt = 1, 40 do
		for i = 1, 4 do
			local plot = getPlot(i)
			if plot ~= nil then
				if plotState[plot] == nil then
					plotState[plot] = { on = true, endsAt = now() + SHIELD_ON_TIME }
				end
				local pedestals = plot:FindFirstChild("Pedestals")
				if pedestals ~= nil then
					for _, pedestal in ipairs(pedestals:GetChildren()) do
						connectPedestal(pedestal)
					end
				end
				connectPads(plot)
				updateStatusGui(plot)
			end
		end
		connectTower()
		connectPadsFolder()
		task.wait(0.5)
	end
end)

-- 초기화: 수풀 / 패드 / 코어
loadBushes()
connectPadsFolder()
publishCoreState()

-- 메인 루프
task.spawn(function()
	local incomeAccum = 0
	while true do
		local dt = task.wait(0.25)
		tickShields()
		updateStealth()
		updateCore()
		incomeAccum = incomeAccum + dt
		if incomeAccum >= 1 then
			incomeAccum = incomeAccum - 1
			tickIncome()
		end
		for player, _ in pairs(carrying) do
			resolveCarry(player)
		end
	end
end)

-- 펫 팔로우는 부드러움을 위해 Heartbeat 사용
RunService.Heartbeat:Connect(function(dt)
	updatePets(math.min(dt, 0.1))
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[NeonVault] 금고·약탈 코어 준비 완료")
