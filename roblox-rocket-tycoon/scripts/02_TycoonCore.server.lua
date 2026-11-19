--=============================================================================
-- 02_TycoonCore.server.lua
-- 위치 : ServerScriptService
-- 타입 : Script  (서버 스크립트, LocalScript 아님)
-- 역할 : 기지 소유권(ClaimPad) / 드로퍼(Dropper) 광석 생성 / 컨베이어 이동 /
--        수거함(Collector) 판매·Cash 지급(2배·자동수거 지원) /
--        업그레이드 버튼(Buttons) / 로켓 발사 시퀀스(LaunchButton)
--
-- 선행 조건 : Workspace에 'TycoonPlot' 모델이 있어야 합니다 (README 3장 구조 참고).
--             없으면 이 스크립트는 경고만 남기고 조용히 대기합니다(에러 없음).
--=============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--=============================================================================
-- [1] 설정 --- 밸런스는 여기 숫자만 바꾸면 됩니다 ---
--=============================================================================
local CONFIG = {
	PLOT_NAME = "TycoonPlot",     -- 기지 모델 이름 (다인용 확장 시 TycoonPlot2 로 복제 + 이 이름만 변경)
	ORE_BASE_VALUE = 8,          -- 광석 1개 기본 가치
	ORE_VALUE_VARIANCE = 3,      -- 광석마다 +0 ~ +3 랜덤
	SPAWN_INTERVAL = 2.2,        -- 광석 생성 간격(초)
	CONVEYOR_SPEED = 12,         -- 컨베이어 이동 속도 (studs/초)
	MAX_ORES = 90,               -- 동시에 존재하는 광석 최대 개수
	AUTO_COLLECT_SECONDS = 2,    -- 자동 수거 패스: 정산 주기(초)
	LAUNCH_REWARD = 250,         -- 로켓 1회 발사 보상 Cash
	LAUNCH_COUNTDOWN = 5,        -- 발사 카운트다운(초)
	LAUNCH_RISE_SECONDS = 6,     -- 로켓이 올라가는 시간(초)
	LAUNCH_RISE_HEIGHT = 220,    -- 로켓이 올라가는 높이(studs)
	RESET_DELAY_SECONDS = 1.5,   -- 발사 후 다음 발사 준비까지 대기
	STEP_WAIT_SECONDS = 0.45,    -- 드로퍼에서 컨베이어로 떨어지는 시간
}

local ORE_COLORS = {
	Color3.fromRGB(255, 196, 64),   -- 금
	Color3.fromRGB(120, 220, 255),  -- 얼음 결정
	Color3.fromRGB(190, 140, 255),  -- 보라 수정
	Color3.fromRGB(255, 120, 120),  -- 붉은 광석
	Color3.fromRGB(140, 255, 170),  -- 초록 광석
}

--=============================================================================
-- [2] 공용 객체 / 알림
--=============================================================================
local notifyEvent = ReplicatedStorage:WaitForChild("RocketTycoonNotify", 30)

local function notify(player, text, kind)
	if player == nil or player.Parent == nil then
		return
	end
	if notifyEvent ~= nil then
		notifyEvent:FireClient(player, { kind = kind or "toast", text = text })
	else
		print("[RocketTycoon:Core] " .. tostring(text))
	end
end

local function formatMoney(amount)
	local text = tostring(math.floor(amount))
	local reversed = text:reverse()
	reversed = (reversed:gsub("(%d%d%d)", "%1,"))
	reversed = reversed:reverse()
	reversed = reversed:gsub("^,", "")
	return reversed
end

--=============================================================================
-- [3] TycoonPlot 안의 파트 찾기
--=============================================================================
local plot = Workspace:WaitForChild(CONFIG.PLOT_NAME, 30)
if plot == nil then
	warn("[RocketTycoon:Core] Workspace에 '" .. CONFIG.PLOT_NAME .. "' 모델이 없어 스크립트를 시작하지 않습니다. README 3장의 구조를 먼저 만들어 주세요.")
	return
end

-- HUD의 "내 기지" 표시는 기본 기지(TycoonPlot)만 담당한다
local IS_PRIMARY_PLOT = (CONFIG.PLOT_NAME == "TycoonPlot")

local function findPart(name, required)
	local object = plot:FindFirstChild(name, true)
	if object ~= nil and object:IsA("BasePart") then
		return object
	end
	if required then
		warn("[RocketTycoon:Core] '" .. name .. "' 파트를 찾지 못했습니다. README 3장의 이름과 정확히 같은지 확인해 주세요.")
	end
	return nil
end

local claimPad = findPart("ClaimPad", true)
local conveyor = findPart("Conveyor", true)
local collector = findPart("Collector", true)
local dropper1 = findPart("Dropper1", true)
local launchButton = findPart("LaunchButton", false)
local buttonsFolder = plot:FindFirstChild("Buttons", true)

if claimPad == nil or conveyor == nil or collector == nil or dropper1 == nil then
	warn("[RocketTycoon:Core] 필수 파트(ClaimPad / Conveyor / Collector / Dropper1)가 부족해 시작하지 않습니다.")
	return
end
if buttonsFolder == nil then
	warn("[RocketTycoon:Core] 'Buttons' 폴더가 없습니다. 업그레이드 버튼 없이 진행합니다.")
end
if launchButton == nil then
	warn("[RocketTycoon:Core] 'LaunchButton' 파트가 없습니다. 로켓 발사 기능 없이 진행합니다.")
end

-- 광석 보관 폴더
local oreFolder = Workspace:FindFirstChild("TycoonOres")
if oreFolder == nil then
	oreFolder = Instance.new("Folder")
	oreFolder.Name = "TycoonOres"
	oreFolder.Parent = Workspace
end

--=============================================================================
-- [4] 상태
--=============================================================================
local STATE = {
	Owner = nil,                 -- 기지 주인 (Player)
	Ready = false,               -- 소유권 확보 후 생산 시작
	OreValue = CONFIG.ORE_BASE_VALUE,
	SpawnInterval = CONFIG.SPAWN_INTERVAL,
	ConveyorSpeed = CONFIG.CONVEYOR_SPEED,
	LaunchReward = CONFIG.LAUNCH_REWARD,
	PendingCash = 0,             -- 수거함에 쌓인 정산 대기 금액
	Unlocked = {},               -- 업그레이드 버튼 이름 → true
	Launching = false,
	RiseTween = nil,             -- 진행 중인 로켓 상승 Tween
	Droppers = {},               -- { Part, Lane, Timer }
	Session = 0,                 -- 리셋 세대 번호(발사 코루틴 취소용)
}

--=============================================================================
-- [5] 컨베이어 경로 계산 (Collector에 가까운 쪽으로 자동으로 흐르게)
--=============================================================================
local conveyorHalf
local travelAxis
local laneAxis
local conveyorLift = Vector3.new(0, conveyor.Size.Y * 0.5 + 1.2, 0)
if conveyor.Size.Z >= conveyor.Size.X then
	travelAxis = conveyor.CFrame.LookVector
	laneAxis = conveyor.CFrame.RightVector
	conveyorHalf = conveyor.Size.Z * 0.5
else
	travelAxis = conveyor.CFrame.RightVector
	laneAxis = conveyor.CFrame.LookVector
	conveyorHalf = conveyor.Size.X * 0.5
end

local endA = conveyor.Position - travelAxis * conveyorHalf + conveyorLift
local endB = conveyor.Position + travelAxis * conveyorHalf + conveyorLift
local pathStart, pathEnd
if (endA - collector.Position).Magnitude < (endB - collector.Position).Magnitude then
	pathStart = endB
	pathEnd = endA
else
	pathStart = endA
	pathEnd = endB
end
local pathLength = math.max((pathEnd - pathStart).Magnitude, 1)
local laneRight = laneAxis

local function laneStart(lane)
	return pathStart + laneRight * lane
end

local function laneEnd(lane)
	return pathEnd + laneRight * lane
end

-- 첫 드로퍼 등록 (Lane 0)
table.insert(STATE.Droppers, {
	Part = dropper1,
	Lane = 0,
	Timer = 0,
})

--=============================================================================
-- [6] 돈 지급 도우미 (leaderstats.Cash 를 단일 기준으로 사용)
--=============================================================================
local function getStat(player, statName)
	if player == nil then
		return nil
	end
	local folder = player:FindFirstChild("leaderstats")
	if folder == nil then
		return nil
	end
	local value = folder:FindFirstChild(statName)
	if value ~= nil and value:IsA("NumberValue") then
		return value
	end
	return nil
end

local function payout(player, amount)
	local cash = getStat(player, "Cash")
	if cash == nil then
		return false
	end
	cash.Value = cash.Value + amount
	return true
end

local function getCash(player)
	local cash = getStat(player, "Cash")
	if cash == nil then
		return 0
	end
	return cash.Value
end

local function hasPass(player, attributeName)
	return player ~= nil and player:GetAttribute(attributeName) == true
end

local function isOwner(player)
	return STATE.Owner ~= nil and STATE.Owner == player
end

--=============================================================================
-- [7] 광석 생성 / 이동
--=============================================================================
local ores = {}

local function spawnOre(dropperData)
	if #ores >= CONFIG.MAX_ORES then
		return
	end
	local dropper = dropperData.Part
	if dropper == nil or dropper.Parent == nil then
		return
	end

	local size = math.random(14, 20) / 10
	local part = Instance.new("Part")
	part.Name = "Ore"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = ORE_COLORS[math.random(1, #ORE_COLORS)]
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(dropper.Position - Vector3.new(0, dropper.Size.Y * 0.5 + 1.5, 0))
	part.Parent = oreFolder

	local value = math.max(1, STATE.OreValue + math.random(0, CONFIG.ORE_VALUE_VARIANCE))

	table.insert(ores, {
		Part = part,
		Phase = "drop",
		DropFrom = part.Position,
		T = 0,
		Distance = 0,
		Value = value,
		Lane = dropperData.Lane,
	})
end

local function removeOre(index)
	local ore = ores[index]
	if ore ~= nil and ore.Part ~= nil then
		ore.Part:Destroy()
	end
	table.remove(ores, index)
end

local function updateOres(deltaTime)
	for index = #ores, 1, -1 do
		local ore = ores[index]
		if ore.Part == nil or ore.Part.Parent == nil then
			table.remove(ores, index)
		elseif ore.Phase == "drop" then
			ore.T = ore.T + deltaTime / CONFIG.STEP_WAIT_SECONDS
			local alpha = math.min(1, ore.T)
			local target = laneStart(ore.Lane)
			ore.Part.CFrame = CFrame.new(ore.DropFrom:Lerp(target, alpha)) * CFrame.Angles(0, alpha * 2, 0)
			if alpha >= 1 then
				ore.Phase = "travel"
				ore.Distance = 0
			end
		else
			ore.Distance = ore.Distance + STATE.ConveyorSpeed * deltaTime
			local alpha = math.min(1, ore.Distance / pathLength)
			ore.Part.CFrame = CFrame.new(laneStart(ore.Lane):Lerp(laneEnd(ore.Lane), alpha)) * CFrame.Angles(0, ore.Distance * 0.5, 0)
			if alpha >= 1 then
				-- 수거함 도착 → 정산 대기 금액에 추가 (2배 패스는 도착 시점에 적용)
				local multiplier = 1
				if hasPass(STATE.Owner, "HasDoubleCash") then
					multiplier = 2
				end
				STATE.PendingCash = STATE.PendingCash + ore.Value * multiplier
				ore.Part:Destroy()
				table.remove(ores, index)
			end
		end
	end
end

--=============================================================================
-- [8] 수거함(Collector) 표시 + 정산
--=============================================================================
local collectorGui = Instance.new("BillboardGui")
collectorGui.Name = "CollectorBillboard"
collectorGui.Size = UDim2.new(0, 240, 0, 64)
collectorGui.StudsOffset = Vector3.new(0, collector.Size.Y * 0.5 + 2.2, 0)
collectorGui.AlwaysOnTop = true
collectorGui.MaxDistance = 90
collectorGui.Adornee = collector
collectorGui.Parent = collector

local collectorLabel = Instance.new("TextLabel")
collectorLabel.BackgroundTransparency = 1
collectorLabel.Size = UDim2.new(1, 0, 1, 0)
collectorLabel.Font = Enum.Font.GothamBold
collectorLabel.TextScaled = true
collectorLabel.TextColor3 = Color3.fromRGB(255, 240, 190)
collectorLabel.TextStrokeTransparency = 0.4
collectorLabel.Text = "수거함"
collectorLabel.Parent = collectorGui

local function refreshCollectorLabel()
	if STATE.PendingCash > 0 then
		collectorLabel.Text = "수거 대기  $" .. formatMoney(STATE.PendingCash) .. "\n(터치해서 수거)"
		collectorLabel.TextColor3 = Color3.fromRGB(255, 226, 120)
	else
		collectorLabel.Text = "수거함\n(대기 중)"
		collectorLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
	end
end

local function collectPending(source)
	if STATE.Owner == nil then
		return 0
	end
	if STATE.PendingCash <= 0 then
		return 0
	end
	local amount = STATE.PendingCash
	if payout(STATE.Owner, amount) then
		STATE.PendingCash = 0
		refreshCollectorLabel()
		if source == "auto" then
			notify(STATE.Owner, "자동 수거  +$" .. formatMoney(amount))
		end
		return amount
	end
	return 0
end

refreshCollectorLabel()

local collectorDebounce = 0
collector.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player == nil then
		local model = hit:FindFirstAncestorOfClass("Model")
		if model ~= nil then
			player = Players:GetPlayerFromCharacter(model)
		end
	end
	if player == nil then
		return
	end
	if not isOwner(player) then
		notify(player, "다른 플레이어의 기지입니다. ClaimPad를 터치해 내 기지를 먼저 만드세요.")
		return
	end
	if os.clock() - collectorDebounce < 0.4 then
		return
	end
	collectorDebounce = os.clock()
	local amount = collectPending("manual")
	if amount > 0 then
		notify(player, "수거 완료  +$" .. formatMoney(amount))
	else
		notify(player, "수거할 광석이 아직 없습니다.")
	end
end)

--=============================================================================
-- [9] 드로퍼(광석 생산기)
--=============================================================================
local function updateDroppers(deltaTime)
	for _, dropperData in ipairs(STATE.Droppers) do
		if dropperData.Part ~= nil and dropperData.Part.Parent ~= nil then
			dropperData.Timer = dropperData.Timer + deltaTime
			if dropperData.Timer >= STATE.SpawnInterval then
				dropperData.Timer = 0
				spawnOre(dropperData)
			end
		end
	end
end

local LANE_OFFSETS = { 0, -2.2, 2.2 }

local function addExtraDropper()
	local index = #STATE.Droppers + 1
	local lane = LANE_OFFSETS[index] or 0
	local position = laneStart(lane) + Vector3.new(0, 4.7, 0)

	local part = Instance.new("Part")
	part.Name = "Dropper" .. tostring(index)
	part.Size = Vector3.new(4.5, 4.5, 4.5)
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(255, 138, 60)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = plot

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 120, 0, 26)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 200, 150)
	label.TextStrokeTransparency = 0.5
	label.Text = "드릴 " .. tostring(index) .. "호기"
	label.Parent = gui

	table.insert(STATE.Droppers, {
		Part = part,
		Lane = lane,
		Timer = 0,
	})
end

--=============================================================================
-- [10] 업그레이드 버튼
--=============================================================================
local buttonUis = {}
local buttonDebounce = {}

local UPGRADES = {
	{
		Name = "Button_Drill1",
		Title = "드릴 강화 I",
		Info = "광석 가치 +6",
		Cost = 100,
		Apply = function()
			STATE.OreValue = STATE.OreValue + 6
		end,
	},
	{
		Name = "Button_Speed1",
		Title = "컨베이어 가속 I",
		Info = "속도 +5 / 생산 -0.2초",
		Cost = 250,
		Apply = function()
			STATE.ConveyorSpeed = STATE.ConveyorSpeed + 5
			STATE.SpawnInterval = math.max(0.7, STATE.SpawnInterval - 0.2)
		end,
	},
	{
		Name = "Button_Drill2",
		Title = "드릴 강화 II",
		Info = "광석 가치 +12",
		Cost = 450,
		Apply = function()
			STATE.OreValue = STATE.OreValue + 12
		end,
	},
	{
		Name = "Button_Dropper2",
		Title = "드릴 2호기",
		Info = "생산 라인 +1",
		Cost = 900,
		Apply = function()
			addExtraDropper()
		end,
	},
	{
		Name = "Button_Speed2",
		Title = "컨베이어 가속 II",
		Info = "속도 +6 / 생산 -0.25초",
		Cost = 1500,
		Apply = function()
			STATE.ConveyorSpeed = STATE.ConveyorSpeed + 6
			STATE.SpawnInterval = math.max(0.7, STATE.SpawnInterval - 0.25)
		end,
	},
	{
		Name = "Button_Drill3",
		Title = "드릴 강화 III",
		Info = "광석 가치 +20",
		Cost = 3000,
		Apply = function()
			STATE.OreValue = STATE.OreValue + 20
		end,
	},
	{
		Name = "Button_Dropper3",
		Title = "드릴 3호기",
		Info = "생산 라인 +1",
		Cost = 7000,
		Apply = function()
			addExtraDropper()
		end,
	},
	{
		Name = "Button_LaunchUpgrade",
		Title = "발사대 강화",
		Info = "발사 보상 +750",
		Cost = 5000,
		Apply = function()
			STATE.LaunchReward = STATE.LaunchReward + 750
		end,
	},
}

local function refreshButton(upgrade)
	local ui = buttonUis[upgrade.Name]
	if ui == nil then
		return
	end
	local part = ui.Part
	if STATE.Unlocked[upgrade.Name] then
		ui.Title.Text = upgrade.Title
		ui.Info.Text = upgrade.Info .. "  ·  해금 완료"
		ui.Info.TextColor3 = Color3.fromRGB(120, 255, 160)
		part.Color = Color3.fromRGB(70, 170, 90)
	else
		ui.Title.Text = upgrade.Title .. "  $" .. formatMoney(upgrade.Cost)
		ui.Info.Text = upgrade.Info
		ui.Info.TextColor3 = Color3.fromRGB(200, 210, 230)
		part.Color = Color3.fromRGB(70, 90, 130)
	end
end

local function refreshAllButtons()
	for _, upgrade in ipairs(UPGRADES) do
		refreshButton(upgrade)
	end
end

local function tryBuy(player, upgrade)
	if not isOwner(player) then
		notify(player, "내 기지에서만 업그레이드할 수 있어요. ClaimPad를 먼저 터치하세요.")
		return
	end
	if STATE.Unlocked[upgrade.Name] then
		notify(player, upgrade.Title .. " : 이미 해금했습니다.")
		return
	end
	local cash = getCash(player)
	if cash < upgrade.Cost then
		notify(player, string.format("%s : $%s 필요 (보유 $%s)", upgrade.Title, formatMoney(upgrade.Cost), formatMoney(cash)))
		return
	end
	if payout(player, -upgrade.Cost) == false then
		return
	end
	STATE.Unlocked[upgrade.Name] = true
	upgrade.Apply()
	refreshButton(upgrade)
	notify(player, string.format("%s 해금!  -$%s", upgrade.Title, formatMoney(upgrade.Cost)))
end

if buttonsFolder ~= nil then
	for _, upgrade in ipairs(UPGRADES) do
		local part = buttonsFolder:FindFirstChild(upgrade.Name, true)
		if part ~= nil and part:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "UpgradeBillboard"
			gui.Size = UDim2.new(0, 220, 0, 62)
			gui.StudsOffset = Vector3.new(0, part.Size.Y * 0.5 + 1.6, 0)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 70
			gui.Adornee = part
			gui.Parent = part

			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.BackgroundTransparency = 1
			title.Size = UDim2.new(1, 0, 0.58, 0)
			title.Font = Enum.Font.GothamBold
			title.TextScaled = true
			title.TextColor3 = Color3.fromRGB(255, 245, 220)
			title.TextStrokeTransparency = 0.45
			title.Text = upgrade.Title
			title.Parent = gui

			local info = Instance.new("TextLabel")
			info.Name = "Info"
			info.BackgroundTransparency = 1
			info.Position = UDim2.new(0, 0, 0.58, 0)
			info.Size = UDim2.new(1, 0, 0.42, 0)
			info.Font = Enum.Font.Gotham
			info.TextScaled = true
			info.TextColor3 = Color3.fromRGB(200, 210, 230)
			info.TextStrokeTransparency = 0.6
			info.Text = upgrade.Info
			info.Parent = gui

			buttonUis[upgrade.Name] = { Part = part, Title = title, Info = info }
			refreshButton(upgrade)

			part.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player == nil then
					return
				end
				local key = tostring(player.UserId) .. upgrade.Name
				if os.clock() - (buttonDebounce[key] or 0) < 0.8 then
					return
				end
				buttonDebounce[key] = os.clock()
				tryBuy(player, upgrade)
			end)
		else
			warn("[RocketTycoon:Core] 버튼 '" .. upgrade.Name .. "' 파트가 Buttons 폴더에 없습니다. (건너뜀)")
		end
	end
end

--=============================================================================
-- [11] 로켓 모델 준비 (모든 파트 Anchored 처리 + 연기/불꽃 파티클 자동 생성)
--=============================================================================
local rocket = {
	Model = nil,
	Part = nil,
	Primary = nil,
	Origin = CFrame.new(),
	Flame = nil,
	Smoke = nil,
	Light = nil,
}

do
	local object = plot:FindFirstChild("RocketModel", true)
	if object ~= nil and object:IsA("Model") then
		local primary = object.PrimaryPart
		if primary == nil then
			primary = object:FindFirstChildWhichIsA("BasePart", true)
			if primary ~= nil then
				object.PrimaryPart = primary
				warn("[RocketTycoon:Core] RocketModel.PrimaryPart가 없어 '" .. primary.Name .. "'을(를) 자동 지정했습니다.")
			end
		end
		if primary ~= nil then
			for _, descendant in ipairs(object:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Anchored == false then
					descendant.Anchored = true
				end
			end
			rocket.Model = object
			rocket.Primary = primary
			rocket.Origin = object:GetPivot()
		end
	elseif object ~= nil and object:IsA("BasePart") then
		-- 로켓을 모델이 아닌 파트 하나로 만든 경우도 지원
		rocket.Part = object
		rocket.Origin = object.CFrame
		object.Anchored = true
	else
		warn("[RocketTycoon:Core] 'RocketModel'을 찾지 못했습니다. 로켓 발사 기능 없이 진행합니다.")
	end
end

local rocketCframe = Instance.new("CFrameValue")
rocketCframe.Name = "RocketTweenValue"
rocketCframe.Value = rocket.Origin
rocketCframe.Parent = plot

local function applyRocketCFrame(target)
	if rocket.Model ~= nil then
		rocket.Model:PivotTo(target)
	elseif rocket.Part ~= nil and rocket.Part.Parent ~= nil then
		rocket.Part.CFrame = target
	end
end

rocketCframe:GetPropertyChangedSignal("Value"):Connect(function()
	applyRocketCFrame(rocketCframe.Value)
end)

local function setRocketOffset(height)
	rocketCframe.Value = rocket.Origin + Vector3.new(0, height, 0)
end

-- 파티클 생성 (엔진/분사구)
if rocket.Primary ~= nil or rocket.Part ~= nil then
	local nozzle = rocket.Primary or rocket.Part
	local attachment = Instance.new("Attachment")
	attachment.Name = "ExhaustAttachment"
	attachment.Position = Vector3.new(0, -(nozzle.Size.Y * 0.5), 0)
	attachment.Parent = nozzle

	local flame = Instance.new("ParticleEmitter")
	flame.Name = "Flame"
	flame.Texture = "rbxasset://textures/particles/smoke_main.dds"
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 120, 30))
	flame.LightEmission = 1
	flame.LightInfluence = 0
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 1) })
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	flame.Lifetime = NumberRange.new(0.5, 0.9)
	flame.Rate = 140
	flame.Speed = NumberRange.new(18, 26)
	flame.SpreadAngle = Vector2.new(12, 12)
	flame.Acceleration = Vector3.new(0, -30, 0)
	flame.Enabled = false
	flame.Parent = attachment
	rocket.Flame = flame

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(230, 230, 235), Color3.fromRGB(120, 120, 130))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(0.5, 14), NumberSequenceKeypoint.new(1, 24) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.6, 2.8)
	smoke.Rate = 32
	smoke.Speed = NumberRange.new(10, 18)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Acceleration = Vector3.new(0, -8, 0)
	smoke.Enabled = false
	smoke.Parent = attachment
	rocket.Smoke = smoke

	local light = Instance.new("PointLight")
	light.Name = "ExhaustLight"
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Brightness = 3
	light.Range = 26
	light.Enabled = false
	light.Parent = attachment
	rocket.Light = light
end

--=============================================================================
-- [12] 발사 버튼 표시 + 발사 시퀀스
--=============================================================================
local launchLabel = nil
if launchButton ~= nil then
	local gui = Instance.new("BillboardGui")
	gui.Name = "LaunchBillboard"
	gui.Size = UDim2.new(0, 220, 0, 56)
	gui.StudsOffset = Vector3.new(0, launchButton.Size.Y * 0.5 + 1.8, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Adornee = launchButton
	gui.Parent = launchButton

	launchLabel = Instance.new("TextLabel")
	launchLabel.BackgroundTransparency = 1
	launchLabel.Size = UDim2.new(1, 0, 1, 0)
	launchLabel.Font = Enum.Font.GothamBold
	launchLabel.TextScaled = true
	launchLabel.TextColor3 = Color3.fromRGB(255, 235, 200)
	launchLabel.TextStrokeTransparency = 0.4
	launchLabel.Text = "로켓 발사"
	launchLabel.Parent = gui
end

local function setLaunchLabel(text, color)
	if launchLabel ~= nil then
		launchLabel.Text = text
		if color ~= nil then
			launchLabel.TextColor3 = color
		end
	end
end

local function setExhaust(enabled)
	if rocket.Flame ~= nil then
		rocket.Flame.Enabled = enabled
	end
	if rocket.Smoke ~= nil then
		rocket.Smoke.Enabled = enabled
	end
	if rocket.Light ~= nil then
		rocket.Light.Enabled = enabled
	end
end

local launchDebounce = 0

local function runLaunchSequence(player, session)
	setLaunchLabel("카운트다운...", Color3.fromRGB(255, 200, 120))
	for count = CONFIG.LAUNCH_COUNTDOWN, 1, -1 do
		if STATE.Session ~= session then
			return
		end
		notify(player, tostring(count), "countdown")
		setLaunchLabel("발사까지 " .. tostring(count), Color3.fromRGB(255, 200, 120))
		task.wait(1)
	end
	if STATE.Session ~= session then
		return
	end
	notify(player, "발사!", "countdown")
	setLaunchLabel("발사 중...", Color3.fromRGB(255, 140, 90))
	setExhaust(true)

	-- TweenService로 로켓 상승 (가속감을 주기 위해 Quad In)
	local riseTween = TweenService:Create(
		rocketCframe,
		TweenInfo.new(CONFIG.LAUNCH_RISE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = rocket.Origin + Vector3.new(0, CONFIG.LAUNCH_RISE_HEIGHT, 0) }
	)
	STATE.RiseTween = riseTween
	riseTween:Play()
	riseTween.Completed:Wait()
	if STATE.Session ~= session then
		setExhaust(false)
		return
	end
	STATE.RiseTween = nil

	-- 보상 지급
	local reward = STATE.LaunchReward
	if isOwner(player) then
		payout(player, reward)
	end
	local launches = getStat(player, "Launches")
	if launches ~= nil then
		launches.Value = launches.Value + 1
	end
	notify(player, string.format("발사 성공!  +$%s · 총 발사 %d회", formatMoney(reward), math.floor(launches and launches.Value or 0)))
	setExhaust(false)

	task.wait(CONFIG.RESET_DELAY_SECONDS)
	if STATE.Session ~= session then
		return
	end
	setRocketOffset(0)
	setLaunchLabel("로켓 발사  (터치)", Color3.fromRGB(255, 235, 200))
	STATE.Launching = false
end

local function startLaunch(player)
	if not isOwner(player) then
		notify(player, "내 기지에서만 로켓을 발사할 수 있어요.")
		return
	end
	if STATE.Launching then
		notify(player, "이미 발사 준비 중입니다. 잠시만 기다려 주세요.")
		return
	end
	if rocket.Model == nil and rocket.Part == nil then
		notify(player, "로켓 모델(RocketModel)이 없어 발사할 수 없습니다.")
		return
	end
	STATE.Launching = true
	local session = STATE.Session
	task.spawn(function()
		local ok, err = pcall(runLaunchSequence, player, session)
		if not ok then
			warn("[RocketTycoon:Core] 발사 시퀀스 오류: " .. tostring(err))
			STATE.Launching = false
			setExhaust(false)
			setLaunchLabel("로켓 발사  (터치)", Color3.fromRGB(255, 235, 200))
		end
	end)
end

if launchButton ~= nil then
	launchButton.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player == nil then
			return
		end
		if os.clock() - launchDebounce < 1 then
			return
		end
		launchDebounce = os.clock()
		startLaunch(player)
	end)
end

--=============================================================================
-- [13] 기지 리셋 / 소유권
--=============================================================================
local function resetTycoon()
	STATE.Session = STATE.Session + 1
	STATE.Ready = false
	STATE.Launching = false
	if STATE.RiseTween ~= nil then
		STATE.RiseTween:Cancel()
		STATE.RiseTween = nil
	end
	for index = #ores, 1, -1 do
		removeOre(index)
	end
	for index = #STATE.Droppers, 2, -1 do
		local dropperData = STATE.Droppers[index]
		if dropperData.Part ~= nil then
			dropperData.Part:Destroy()
		end
		table.remove(STATE.Droppers, index)
	end
	STATE.Droppers[1].Timer = 0
	STATE.OreValue = CONFIG.ORE_BASE_VALUE
	STATE.ConveyorSpeed = CONFIG.CONVEYOR_SPEED
	STATE.SpawnInterval = CONFIG.SPAWN_INTERVAL
	STATE.LaunchReward = CONFIG.LAUNCH_REWARD
	STATE.PendingCash = 0
	STATE.Unlocked = {}
	refreshCollectorLabel()
	refreshAllButtons()
	setExhaust(false)
	setRocketOffset(0)
	setLaunchLabel("로켓 발사  (터치)", Color3.fromRGB(255, 235, 200))
end

local claimGui = Instance.new("BillboardGui")
claimGui.Name = "ClaimBillboard"
claimGui.Size = UDim2.new(0, 260, 0, 56)
claimGui.StudsOffset = Vector3.new(0, claimPad.Size.Y * 0.5 + 2.2, 0)
claimGui.AlwaysOnTop = true
claimGui.MaxDistance = 120
claimGui.Adornee = claimPad
claimGui.Parent = claimPad

local claimLabel = Instance.new("TextLabel")
claimLabel.BackgroundTransparency = 1
claimLabel.Size = UDim2.new(1, 0, 1, 0)
claimLabel.Font = Enum.Font.GothamBold
claimLabel.TextScaled = true
claimLabel.TextColor3 = Color3.fromRGB(210, 255, 220)
claimLabel.TextStrokeTransparency = 0.4
claimLabel.Text = "CLAIM\n터치해서 내 기지 시작"
claimLabel.Parent = claimGui

local function refreshClaimLabel()
	if STATE.Owner == nil then
		claimLabel.Text = "CLAIM\n터치해서 내 기지 시작"
		claimLabel.TextColor3 = Color3.fromRGB(210, 255, 220)
		claimPad.Color = Color3.fromRGB(80, 200, 120)
	else
		claimLabel.Text = STATE.Owner.DisplayName .. "의 기지"
		claimLabel.TextColor3 = Color3.fromRGB(255, 235, 200)
		claimPad.Color = Color3.fromRGB(120, 130, 150)
	end
end

refreshClaimLabel()

local claimDebounce = 0

claimPad.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player == nil then
		return
	end
	if os.clock() - claimDebounce < 1 then
		return
	end
	claimDebounce = os.clock()

	if STATE.Owner == player then
		notify(player, "이미 내 기지입니다. 드릴이 광석을 생산하고 있어요!")
		return
	end
	if STATE.Owner ~= nil then
		notify(player, STATE.Owner.DisplayName .. " 님이 사용 중인 기지입니다.")
		return
	end
	-- 데이터 로드가 끝난 뒤에 기지를 열어 준다 (금액 덮어쓰기 방지)
	for _ = 1, 40 do
		if player:GetAttribute("DataLoaded") == true then
			break
		end
		task.wait(0.2)
	end
	if STATE.Owner ~= nil then
		notify(player, "방금 다른 플레이어가 기지를 가져갔습니다.")
		return
	end

	resetTycoon()
	STATE.Owner = player
	STATE.Ready = true
	if IS_PRIMARY_PLOT then
		player:SetAttribute("TycoonOwner", true)
	end
	refreshClaimLabel()
	notify(player, "기지 획득 완료! 드릴이 광석을 생산합니다. 수거함을 터치해 돈을 받으세요.")
end)

local function releaseTycoon(message)
	if STATE.Owner ~= nil then
		collectPending("auto")
		if IS_PRIMARY_PLOT then
			STATE.Owner:SetAttribute("TycoonOwner", false)
		end
		if message ~= nil then
			notify(STATE.Owner, message)
		end
	end
	STATE.Owner = nil
	resetTycoon()
	refreshClaimLabel()
end

Players.PlayerRemoving:Connect(function(player)
	if STATE.Owner == player then
		releaseTycoon(nil)
	end
end)

--=============================================================================
-- [14] 메인 루프
--=============================================================================
RunService.Heartbeat:Connect(function(rawDelta)
	if not STATE.Ready or STATE.Owner == nil then
		return
	end
	local delta = math.min(rawDelta, 0.2)
	updateDroppers(delta)
	updateOres(delta)
end)

-- 자동 수거(게임패스) 루프
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTO_COLLECT_SECONDS)
		if STATE.Ready and STATE.Owner ~= nil and STATE.PendingCash > 0 then
			if hasPass(STATE.Owner, "HasAutoCollect") then
				collectPending("auto")
			end
		end
	end
end)

print("[RocketTycoon:Core] 준비 완료 — 광석 가치 $" .. tostring(STATE.OreValue) .. " / 생산 " .. tostring(STATE.SpawnInterval) .. "초마다 / 컨베이어 " .. tostring(STATE.ConveyorSpeed))
