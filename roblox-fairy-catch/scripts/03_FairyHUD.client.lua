--[[
  03_FairyHUD.client.lua
  ------------------------------------------------------------------
  붙여넣는 위치 : StarterPlayer > StarterPlayerScripts  (LocalScript)
  하는 일
    · 화면 UI 전부를 코드로 자동 생성 (따로 배치할 것 없음)
      - 코인 / 도감 / 상점 버튼
      - 마법 콤팩트 캐치 미니게임 (회전하는 하트, 반짝 구간, 타이머)
      - 요정 하우스 (친밀도·레벨·밥/놀기/쓰다듬기·코인 수확)
      - 요정 도감 12종 / 꾸미기 상점
    · 실제 판정은 서버(02번 스크립트)가 합니다. 이 스크립트는 화면만 담당.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local DebrisService = game:GetService("Debris")
local function Debris_Add(inst, time)
	DebrisService:AddItem(inst, time)
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local net = ReplicatedStorage:WaitForChild("FairyNet")
local catalog = ReplicatedStorage:WaitForChild("FairyCatalog")

local remotes = {
	CatchStart = net:WaitForChild("CatchStart"),
	CatchTap = net:WaitForChild("CatchTap"),
	CatchResult = net:WaitForChild("CatchResult"),
	RequestHouse = net:WaitForChild("RequestHouse"),
	HouseData = net:WaitForChild("HouseData"),
	FairyAction = net:WaitForChild("FairyAction"),
	Harvest = net:WaitForChild("Harvest"),
	BuyDecor = net:WaitForChild("BuyDecor"),
	BuyWear = net:WaitForChild("BuyWear"),
	SetWear = net:WaitForChild("SetWear"),
	Notify = net:WaitForChild("Notify"),
	RequestTown = net:WaitForChild("RequestTown"),
	TownData = net:WaitForChild("TownData"),
	BuyPlot = net:WaitForChild("BuyPlot"),
	UpgradeBuilding = net:WaitForChild("UpgradeBuilding"),
	CollectBusiness = net:WaitForChild("CollectBusiness"),
	SetFairyMode = net:WaitForChild("SetFairyMode"),
	CareFairy = net:WaitForChild("CareFairy"),
}

-- ==============================================================
-- 도감 목록 (ReplicatedStorage > FairyCatalog 에서 읽기)
-- ==============================================================
local FAIRY_ORDER = {}
local FAIRY = {}
for _, obj in ipairs(catalog:GetChildren()) do
	local info = {
		id = obj.Name,
		name = obj:GetAttribute("DisplayName") or obj.Name,
		rarity = obj:GetAttribute("Rarity") or "common",
		color = obj:GetAttribute("Color") or Color3.fromRGB(255, 170, 210),
	}
	table.insert(FAIRY_ORDER, info)
	FAIRY[info.id] = info
end
table.sort(FAIRY_ORDER, function(a, b)
	local rank = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }
	return (rank[a.rarity] or 9) < (rank[b.rarity] or 9)
end)

local RARITY_COLOR = {
	common = Color3.fromRGB(159, 212, 255),
	uncommon = Color3.fromRGB(143, 240, 216),
	rare = Color3.fromRGB(192, 166, 255),
	epic = Color3.fromRGB(255, 158, 203),
	legendary = Color3.fromRGB(255, 209, 102),
}
local RARITY_LABEL = {
	common = "일반", uncommon = "고급", rare = "희귀", epic = "영웅", legendary = "전설",
}

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
-- 코디 카탈로그 (01 스크립트가 ReplicatedStorage > FairyWearCatalog 에 올려 둔 목록)
-- ==============================================================
local WEAR_ICON = {
	princess = "👑", cloak = "🌌", apron = "🍰", tutu = "🎀", pajama = "☁️", galaxy = "✨", ladybug = "🐞",
	tiara = "👑", ribbon = "🎀", beret = "🎨", flowercrown = "🌸",
	sunglasses = "🕶️", wand = "🪄", angelwing = "👼", bell = "🔔", umbrella = "🌂",
}
local WEAR_LABEL = { dress = "👗 의상", head = "👑 머리", acc = "🕶️ 소품" }
local WEAR = {}
local WEAR_LIST = { dress = {}, head = {}, acc = {} }
do
	local wearCatalog = ReplicatedStorage:WaitForChild("FairyWearCatalog", 10)
	if wearCatalog ~= nil then
		for _, obj in ipairs(wearCatalog:GetChildren()) do
			local kind = obj:GetAttribute("Kind")
			if kind ~= nil and WEAR_LIST[kind] ~= nil then
				local info = {
					id = obj.Name,
					name = obj:GetAttribute("DisplayName") or obj.Name,
					price = obj:GetAttribute("Price") or 0,
					color = obj:GetAttribute("Color") or Color3.fromRGB(255, 170, 210),
					icon = WEAR_ICON[obj.Name] or "✨",
					kind = kind,
				}
				WEAR[obj.Name] = info
				table.insert(WEAR_LIST[kind], info)
			end
		end
	end
	for _, list in pairs(WEAR_LIST) do
		table.sort(list, function(a, b)
			return a.price < b.price
		end)
	end
end

-- ==============================================================
-- UI 도우미
-- ==============================================================
local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius, strokeColor, strokeThickness)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = inst
	if strokeColor ~= nil then
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor
		stroke.Thickness = strokeThickness or 2
		stroke.Parent = inst
	end
	return corner
end

local function gradient(inst, c1, c2, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(1, c2),
	})
	g.Rotation = rotation or 90
	g.Parent = inst
	return g
end

local PINK = Color3.fromRGB(255, 134, 194)
local PINK_DEEP = Color3.fromRGB(242, 95, 168)
local LAV = Color3.fromRGB(183, 156, 255)
local CREAM = Color3.fromRGB(255, 250, 253)
local INK = Color3.fromRGB(92, 53, 82)

local gui = make("ScreenGui", {
	Name = "FairyHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- ==============================================================
-- 상단 HUD
-- ==============================================================
local topBar = make("Frame", {
	Name = "TopBar",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 12, 0, 12),
	Size = UDim2.new(1, -24, 0, 44),
}, gui)

local coinPill = make("Frame", {
	Name = "CoinPill",
	Size = UDim2.fromOffset(132, 40),
	BackgroundColor3 = CREAM,
	BorderSizePixel = 0,
}, topBar)
round(coinPill, 20, Color3.new(1, 1, 1), 3)

local coinIcon = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.fromOffset(24, 40),
	Text = "◉",
	TextColor3 = Color3.fromRGB(255, 200, 80),
	TextScaled = true,
	Font = Enum.Font.GothamBold,
}, coinPill)

local coinLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(38, 0),
	Size = UDim2.new(1, -46, 1, 0),
	Text = "0",
	TextColor3 = Color3.fromRGB(179, 72, 127),
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
}, coinPill)

local buttonRow = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(200, 40),
}, topBar)

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, buttonRow)

local function topButton(text, order)
	local btn = make("TextButton", {
		Name = "Btn_" .. text,
		Size = UDim2.fromOffset(60, 38),
		BackgroundColor3 = CREAM,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Color3.fromRGB(160, 88, 140),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		LayoutOrder = order,
		AutoButtonColor = true,
	}, buttonRow)
	round(btn, 14, Color3.new(1, 1, 1), 3)
	return btn
end

local dexButton = topButton("도감", 1)
local shopButton = topButton("상점", 2)
local townButton = topButton("🏘️ 타운", 3)

local hint = make("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(1, -40, 0, 24),
	Text = "요정 앞에서 E(모바일은 버튼) → 마법 콤팩트로 포획!",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextStrokeTransparency = 0.3,
	TextStrokeColor3 = Color3.fromRGB(120, 40, 100),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
}, gui)

-- ==============================================================
-- 토스트
-- ==============================================================
local toastHolder = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.new(0, 340, 0, 100),
	AnchorPoint = Vector2.new(0.5, 0),
}, gui)
make("UIListLayout", {
	Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

local toastOrder = 0
local function toast(text)
	toastOrder = toastOrder + 1
	local frame = make("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.04,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = toastOrder,
	}, toastHolder)
	round(frame, 17, Color3.new(1, 1, 1), 2)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Text = text,
		TextColor3 = Color3.fromRGB(125, 47, 95),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}, frame)
	task.delay(3, function()
		if frame.Parent ~= nil then
			TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				end
			end
			task.delay(0.35, function()
				frame:Destroy()
			end)
		end
	end)
end

-- ==============================================================
-- 캐치 미니게임
-- ==============================================================
local catchOverlay = make("Frame", {
	Name = "CatchOverlay",
	Visible = false,
	BackgroundColor3 = Color3.fromRGB(40, 12, 50),
	BackgroundTransparency = 0.28,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 20,
}, gui)

local tapButton = make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 21,
}, catchOverlay)

local catchTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0.5, 0, 0, 60),
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(1, -40, 0, 56),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 22,
}, catchOverlay)

local compact = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 20),
	Size = UDim2.fromOffset(300, 300),
	BackgroundColor3 = Color3.fromRGB(255, 240, 250),
	BorderSizePixel = 0,
	ZIndex = 22,
}, catchOverlay)
round(compact, 150, Color3.new(1, 1, 1), 6)
gradient(compact, Color3.fromRGB(255, 248, 253), Color3.fromRGB(255, 205, 235), 90)

local RING_RADIUS = 118
local DOT_COUNT = 36
local ringDots = {}
for i = 1, DOT_COUNT do
	local angle = ((i - 1) / DOT_COUNT) * math.pi * 2 - math.pi / 2
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(angle) * RING_RADIUS, 0.5, math.sin(angle) * RING_RADIUS),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.fromRGB(255, 224, 240),
		BorderSizePixel = 0,
		ZIndex = 23,
	}, compact)
	round(dot, 6)
	ringDots[i] = dot
end

local innerCircle = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(176, 176),
	BackgroundColor3 = Color3.fromRGB(255, 251, 255),
	BorderSizePixel = 0,
	ZIndex = 23,
}, compact)
round(innerCircle, 90, Color3.fromRGB(255, 214, 102), 3)
gradient(innerCircle, Color3.fromRGB(255, 255, 255), Color3.fromRGB(237, 220, 255), 90)

local fairyGlyph = make("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(140, 140),
	Text = "🧚",
	TextScaled = true,
	ZIndex = 24,
}, innerCircle)

local pointer = make("Frame", {
	Name = "Pointer",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -RING_RADIUS),
	Size = UDim2.fromOffset(20, 20),
	BackgroundColor3 = PINK_DEEP,
	BorderSizePixel = 0,
	ZIndex = 25,
	Rotation = 45,
}, compact)
round(pointer, 5, Color3.new(1, 1, 1), 2)

local heartsRow = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 12),
	Size = UDim2.fromOffset(200, 24),
	ZIndex = 24,
}, compact)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, heartsRow)

local heartPips = {}
local function setHearts(hits, need)
	for i = 1, need do
		if heartPips[i] == nil then
			local pip = make("Frame", {
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				LayoutOrder = i,
				ZIndex = 24,
				Rotation = 45,
			}, heartsRow)
			round(pip, 5)
			heartPips[i] = pip
		end
		heartPips[i].Visible = true
		if i <= hits then
			heartPips[i].BackgroundColor3 = PINK_DEEP
			heartPips[i].BackgroundTransparency = 0
		else
			heartPips[i].BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			heartPips[i].BackgroundTransparency = 0.5
		end
	end
	for i = need + 1, #heartPips do
		heartPips[i].Visible = false
	end
end

local timerBack = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 48),
	Size = UDim2.fromOffset(220, 10),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	ZIndex = 24,
}, compact)
round(timerBack, 5)
local timerFill = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 209, 102),
	BorderSizePixel = 0,
	ZIndex = 25,
}, timerBack)
round(timerFill, 5)

local catchInfo = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0.5, 0, 1, -70),
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(1, -40, 0, 24),
	Text = "하트가 반짝 구간에 올 때 탭!",
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.35,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 22,
}, catchOverlay)

local catchState = nil

local function showCatch(data)
	catchState = {
		name = data.name,
		rarity = data.rarity,
		angle0 = data.angle0,
		arcStart = data.arcStart,
		arcLen = data.arcLen,
		speed = data.speed,
		t0 = data.t0,
		hits = 0,
		need = data.need,
		time = data.time,
		startedAt = workspace:GetServerTimeNow(),
		done = false,
	}
	catchTitle.Text = data.name .. "  ·  " .. (RARITY_LABEL[data.rarity] or "일반")
	catchTitle.TextColor3 = RARITY_COLOR[data.rarity] or Color3.new(1, 1, 1)
	setHearts(0, data.need)
	timerFill.Size = UDim2.fromScale(1, 1)
	for _, name in ipairs({ "HousePanel", "DexPanel", "ShopPanel", "TownPanel" }) do
		local panel = gui:FindFirstChild(name)
		if panel ~= nil then
			panel.Visible = false
		end
	end
	catchOverlay.Visible = true
end

local function hideCatch()
	catchOverlay.Visible = false
	catchState = nil
end

local function angleNow(state)
	local now = workspace:GetServerTimeNow()
	return (state.angle0 + state.speed * (now - state.t0)) % 360
end

tapButton.MouseButton1Click:Connect(function()
	if catchState == nil or catchState.done then
		return
	end
	remotes.CatchTap:FireServer()
end)

remotes.CatchStart.OnClientEvent:Connect(function(data)
	showCatch(data)
end)

remotes.CatchResult.OnClientEvent:Connect(function(result)
	if result == nil then
		return
	end
	if result.result == "hit" or result.result == "miss" then
		if catchState ~= nil then
			catchState.angle0 = result.angle0 or catchState.angle0
			catchState.t0 = result.t0 or catchState.t0
			catchState.arcStart = result.arcStart or catchState.arcStart
			catchState.arcLen = result.arcLen or catchState.arcLen
			catchState.speed = result.speed or catchState.speed
			catchState.hits = result.hits or catchState.hits
			catchState.need = result.need or catchState.need
			if result.result == "miss" then
				catchState.time = math.max(0, catchState.time - 1.6)
				catchInfo.Text = "빗나갔어요! 시간이 줄어들어요"
				task.delay(0.7, function()
					if catchState ~= nil then
						catchInfo.Text = "하트가 반짝 구간에 올 때 탭!"
					end
				end)
			end
			setHearts(catchState.hits, catchState.need)
		end
	elseif result.result == "win" then
		if catchState ~= nil then
			catchState.done = true
		end
		task.delay(0.5, function()
			hideCatch()
			showResult(result)
		end)
	elseif result.result == "fail" then
		if catchState ~= nil then
			catchState.done = true
		end
		catchInfo.Text = "도망갔어요… 다시 도전!"
		task.delay(0.9, function()
			hideCatch()
		end)
	end
end)

-- 결과 카드
local resultCard = make("Frame", {
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(280, 240),
	BackgroundColor3 = Color3.fromRGB(255, 250, 253),
	ZIndex = 30,
}, gui)
round(resultCard, 24, Color3.new(1, 1, 1), 4)
gradient(resultCard, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 234, 246), 90)

local resultTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 18),
	Size = UDim2.new(1, -32, 0, 30),
	Text = "포획 성공!",
	TextColor3 = PINK_DEEP,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 31,
}, resultCard)

local resultName = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 0, 42),
	Text = "",
	TextColor3 = INK,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 31,
}, resultCard)

local resultCoins = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 104),
	Size = UDim2.new(1, -32, 0, 32),
	Text = "",
	TextColor3 = Color3.fromRGB(200, 120, 0),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 31,
}, resultCard)

local resultOk = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, -64),
	Size = UDim2.new(1, -60, 0, 44),
	BackgroundColor3 = PINK,
	Text = "확인",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 31,
}, resultCard)
round(resultOk, 16, Color3.new(1, 1, 1), 3)

local function showResult(result)
	resultName.Text = result.name or ""
	resultCoins.Text = "+" .. tostring(result.coins or 0) .. " 코인" .. (result.isNew and "  (첫 발견!)" or "")
	resultCard.Visible = true
end

resultOk.MouseButton1Click:Connect(function()
	resultCard.Visible = false
end)

-- ==============================================================
-- 하우스 패널
-- ==============================================================
local houseData = nil
local selectedFairy = nil
local housePanel = make("Frame", {
	Visible = false,
	Name = "HousePanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0.86, 0),
	BackgroundColor3 = Color3.fromRGB(255, 246, 252),
	ZIndex = 40,
}, gui)
round(housePanel, 24, Color3.new(1, 1, 1), 4)
gradient(housePanel, Color3.fromRGB(255, 252, 254), Color3.fromRGB(244, 232, 255), 90)

local houseTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.new(1, -120, 0, 32),
	Text = "내 요정 하우스",
	TextColor3 = INK,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 41,
}, housePanel)

local closeHouse = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(38, 32),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "X",
	TextColor3 = Color3.fromRGB(180, 90, 150),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 41,
}, housePanel)
round(closeHouse, 12, Color3.fromRGB(255, 224, 240), 2)

local roomFrame = make("Frame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 0, 150),
	BackgroundColor3 = Color3.fromRGB(255, 231, 243),
	BorderSizePixel = 0,
	ZIndex = 41,
}, housePanel)
round(roomFrame, 18, Color3.new(1, 1, 1), 3)
gradient(roomFrame, Color3.fromRGB(255, 235, 246), Color3.fromRGB(232, 216, 255), 90)

local roomGlyph = make("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(110, 110),
	Text = "🏠",
	TextScaled = true,
	ZIndex = 42,
}, roomFrame)

local roomLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, -34),
	Size = UDim2.new(1, -20, 0, 26),
	Text = "",
	TextColor3 = Color3.fromRGB(150, 100, 135),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 42,
}, roomFrame)

local fairyBar = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 216),
	Size = UDim2.new(1, -32, 0, 62),
}, housePanel)

local fairyScroll = make("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	CanvasSize = UDim2.new(0, 0, 0, 62),
	ScrollBarThickness = 3,
	ScrollingDirection = Enum.ScrollingDirection.X,
}, fairyBar)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, fairyScroll)

local affBack = make("Frame", {
	Position = UDim2.fromOffset(16, 284),
	Size = UDim2.new(1, -32, 0, 14),
	BackgroundColor3 = Color3.fromRGB(255, 227, 241),
	BorderSizePixel = 0,
}, housePanel)
round(affBack, 7, Color3.new(1, 1, 1), 2)
local affFill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = PINK,
	BorderSizePixel = 0,
}, affBack)
round(affFill, 7)
gradient(affFill, Color3.fromRGB(255, 209, 102), Color3.fromRGB(255, 143, 199), 0)

local affLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 258),
	Size = UDim2.new(1, -32, 0, 22),
	Text = "",
	TextColor3 = Color3.fromRGB(160, 116, 143),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, housePanel)

local actionRow = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 306),
	Size = UDim2.new(1, -32, 0, 62),
}, housePanel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actionRow)

local actionButtons = {}
local ACTIONS = {
	{ id = "feed", label = "밥 주기", cost = "5코인 · +12" },
	{ id = "play", label = "놀아주기", cost = "무료 · +18" },
	{ id = "pet", label = "쓰다듬기", cost = "무료 · +7" },
}
for i, act in ipairs(ACTIONS) do
	local btn = make("TextButton", {
		Size = UDim2.new(1 / 3, -6, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = act.label .. "\n" .. act.cost,
		TextColor3 = Color3.fromRGB(138, 79, 125),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		LayoutOrder = i,
	}, actionRow)
	round(btn, 16, Color3.fromRGB(255, 224, 240), 2)
	btn.MouseButton1Click:Connect(function()
		if selectedFairy ~= nil then
			remotes.FairyAction:FireServer(selectedFairy, act.id)
		else
			toast("먼저 요정을 선택해 주세요")
		end
	end)
	actionButtons[act.id] = btn
end

local harvestBtn = make("TextButton", {
	Position = UDim2.fromOffset(16, 376),
	Size = UDim2.new(1, -32, 0, 44),
	BackgroundColor3 = Color3.fromRGB(255, 224, 138),
	Text = "코인 수확 · 0",
	TextColor3 = Color3.fromRGB(106, 59, 0),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
}, housePanel)
round(harvestBtn, 16, Color3.new(1, 1, 1), 3)
harvestBtn.MouseButton1Click:Connect(function()
	remotes.Harvest:FireServer()
end)

local decorBtn = make("TextButton", {
	Position = UDim2.fromOffset(16, 426),
	Size = UDim2.new(0.5, -22, 0, 40),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	Text = "🛋️ 가구 상점",
	TextColor3 = Color3.fromRGB(150, 100, 175),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
}, housePanel)
round(decorBtn, 14, Color3.fromRGB(235, 220, 255), 2)

local wardrobeBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 426),
	Size = UDim2.new(0.5, -22, 0, 40),
	BackgroundColor3 = Color3.fromRGB(255, 224, 240),
	Text = "👗 요정 꾸미기",
	TextColor3 = Color3.fromRGB(190, 70, 140),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
}, housePanel)
round(wardrobeBtn, 14, Color3.fromRGB(255, 170, 210), 2)

closeHouse.MouseButton1Click:Connect(function()
	housePanel.Visible = false
end)

local function refreshHouse()
	if houseData == nil then
		return
	end
	coinLabel.Text = tostring(houseData.coins or 0)
	-- 요정 목록
	for _, child in ipairs(fairyScroll:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	local house = houseData.house or {}
	if selectedFairy == nil or houseData.fairies[selectedFairy] == nil then
		selectedFairy = house[1]
	end
	for index = 1, (houseData.slots or 4) do
		local fairyId = house[index]
		local btn = make("TextButton", {
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = fairyId and (FAIRY[fairyId] and FAIRY[fairyId].name or fairyId) or "+",
			TextColor3 = fairyId and INK or Color3.fromRGB(160, 130, 200),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			LayoutOrder = index,
		}, fairyScroll)
		round(btn, 14, fairyId == selectedFairy and PINK or Color3.fromRGB(240, 230, 250), 3)
		btn.MouseButton1Click:Connect(function()
			selectedFairy = fairyId
			refreshHouse()
		end)
	end
	fairyScroll.CanvasSize = UDim2.new(0, math.max(0, (houseData.slots or 4) * 64), 0, 62)

	-- 선택한 요정 정보
	local fairyId = selectedFairy
	if fairyId ~= nil and houseData.fairies[fairyId] ~= nil then
		local info = FAIRY[fairyId]
		local data = houseData.fairies[fairyId]
		affLabel.Text = (info and info.name or fairyId) .. "   Lv." .. tostring(data.level or 1) .. "   친밀도 " .. tostring(math.floor(data.aff or 0)) .. "/100"
		affFill.Size = UDim2.fromScale(math.clamp((data.aff or 0) / 100, 0, 1), 1)
		roomLabel.Text = (info and info.name or fairyId) .. "가 하우스에서 신나게 놀고 있어요"
		roomGlyph.Text = "🏡"
	else
		affLabel.Text = "요정을 잡아 하우스에 초대해 보세요"
		affFill.Size = UDim2.fromScale(0, 1)
		roomLabel.Text = "아직 비어 있어요 · 마을에서 요정을 잡아 보세요"
		roomGlyph.Text = "🏠"
	end
	harvestBtn.Text = "코인 수확 · " .. tostring(math.floor(houseData.pending or 0))
end


-- ==============================================================
-- 도감 패널
-- ==============================================================
local dexPanel = make("Frame", {
	Name = "DexPanel",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0.84, 0),
	BackgroundColor3 = Color3.fromRGB(255, 246, 252),
	ZIndex = 40,
}, gui)
round(dexPanel, 24, Color3.new(1, 1, 1), 4)
gradient(dexPanel, Color3.fromRGB(255, 252, 254), Color3.fromRGB(240, 233, 255), 90)

local dexTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.new(1, -120, 0, 32),
	Text = "요정 도감",
	TextColor3 = INK,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 41,
}, dexPanel)

local dexClose = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(38, 32),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "X",
	TextColor3 = Color3.fromRGB(180, 90, 150),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 41,
}, dexPanel)
round(dexClose, 12, Color3.fromRGB(255, 224, 240), 2)
dexClose.MouseButton1Click:Connect(function()
	dexPanel.Visible = false
end)

local dexGrid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 1, -72),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0),
}, dexPanel)
make("UIGridLayout", {
	CellSize = UDim2.new(1 / 3, -6, 0, 92),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, dexGrid)

local function refreshDex()
	if houseData == nil then
		return
	end
	for _, child in ipairs(dexGrid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local count = 0
	for index, info in ipairs(FAIRY_ORDER) do
		local owned = houseData.fairies[info.id] ~= nil
		if owned then
			count = count + 1
		end
		local card = make("Frame", {
			BackgroundColor3 = owned and Color3.new(1, 1, 1) or Color3.fromRGB(240, 236, 244),
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, dexGrid)
		round(card, 14, owned and info.color or Color3.fromRGB(225, 220, 232), 3)

		local glyph = make("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 34),
			Text = owned and "🧚" or "?",
			TextColor3 = owned and info.color or Color3.fromRGB(180, 172, 190),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
		}, card)

		make("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 40),
			Size = UDim2.new(1, -4, 0, 20),
			Text = owned and info.name or "???",
			TextColor3 = owned and INK or Color3.fromRGB(170, 162, 178),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
		}, card)

		make("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 62),
			Size = UDim2.new(1, -4, 0, 22),
			Text = RARITY_LABEL[info.rarity] or "",
			TextColor3 = RARITY_COLOR[info.rarity] or PINK,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
		}, card)
	end
	dexTitle.Text = "요정 도감   " .. tostring(count) .. " / " .. tostring(#FAIRY_ORDER)
	dexGrid.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#FAIRY_ORDER / 3) * 98)
end

dexButton.MouseButton1Click:Connect(function()
	dexPanel.Visible = not dexPanel.Visible
	if dexPanel.Visible then
		remotes.RequestHouse:FireServer()
		refreshDex()
	end
end)

-- ==============================================================
-- 상점 패널 (가구 12종 · 의상 · 악세사리)
-- ==============================================================
local shopPanel = make("Frame", {
	Name = "ShopPanel",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0.76, 0),
	BackgroundColor3 = Color3.fromRGB(255, 246, 252),
	ZIndex = 40,
}, gui)
round(shopPanel, 24, Color3.new(1, 1, 1), 4)
gradient(shopPanel, Color3.fromRGB(255, 252, 254), Color3.fromRGB(240, 233, 255), 90)

local shopTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -120, 0, 26),
	Text = "하우스 꾸미기 상점",
	TextColor3 = INK,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 41,
}, shopPanel)

local shopClose = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(38, 30),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "X",
	TextColor3 = Color3.fromRGB(180, 90, 150),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 41,
}, shopPanel)
round(shopClose, 12, Color3.fromRGB(255, 224, 240), 2)
shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

local shopTab = "furn"
local wardrobeTab = "dress"
local refreshWardrobe
local openWardrobe
local shopTabs = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 44),
	Size = UDim2.new(1, -32, 0, 32),
	ZIndex = 41,
}, shopPanel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, shopTabs)

local shopTabButtons = {}
local function styleShopTabs()
	for tab, btn in pairs(shopTabButtons) do
		if tab == shopTab then
			btn.BackgroundColor3 = PINK
			btn.TextColor3 = Color3.new(1, 1, 1)
		else
			btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextColor3 = Color3.fromRGB(160, 88, 140)
		end
	end
end

local shopList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 82),
	Size = UDim2.new(1, -32, 1, -94),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ZIndex = 41,
}, shopPanel)
make("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, shopList)

local function clearList(list)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function shopRow(index, icon, name, priceText, priceColor, onTap)
	local row = make("TextButton", {
		Name = "Row" .. index,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = index,
		Text = "",
		AutoButtonColor = true,
		ZIndex = 42,
	}, shopList)
	round(row, 14, Color3.fromRGB(240, 228, 246), 2)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(38, 52),
		Text = icon,
		TextScaled = true,
		ZIndex = 43,
	}, row)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(0.55, 0, 1, 0),
		Text = name,
		TextColor3 = INK,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 43,
	}, row)

	make("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.38, 0, 1, 0),
		Text = priceText,
		TextColor3 = priceColor,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 43,
	}, row)

	row.MouseButton1Click:Connect(onTap)
	return row
end

local function refreshShop()
	local ownedDecor = (houseData and houseData.decor) or {}
	local ownedWear = (houseData and houseData.owned) or {}
	styleShopTabs()
	clearList(shopList)
	local count = 0

	if shopTab == "furn" then
		for index, item in ipairs(DECOR) do
			count = count + 1
			local owned = ownedDecor[item.id] == true
			local priceText = owned and "설치됨 ✓" or (tostring(item.price) .. " 코인")
			local priceColor = owned and Color3.fromRGB(80, 170, 140) or Color3.fromRGB(200, 120, 0)
			local itemId = item.id
			shopRow(index, "🛋️", item.name, priceText, priceColor, function()
				if not owned then
					remotes.BuyDecor:FireServer(itemId)
				else
					toast("이미 설치된 가구예요")
				end
			end)
		end
	else
		local list = WEAR_LIST[shopTab]
		for index, item in ipairs(list) do
			count = count + 1
			local owned = ownedWear[item.id] == true
			local priceText = owned and "보유 ✓" or (tostring(item.price) .. " 코인")
			local priceColor = owned and Color3.fromRGB(80, 170, 140) or Color3.fromRGB(200, 120, 0)
			local itemId = item.id
			shopRow(index, item.icon, item.name, priceText, priceColor, function()
				if owned then
					wardrobeTab = item.kind
					openWardrobe()
				else
					remotes.BuyWear:FireServer(itemId)
				end
			end)
		end
	end
	shopList.CanvasSize = UDim2.new(0, 0, 0, count * 60)
	shopTitle.Text = "하우스 꾸미기 상점 · " ..
		(shopTab == "furn" and "가구 12종" or (shopTab == "dress" and "의상" or "악세사리"))
end

local function setShopTab(tab)
	shopTab = tab
	refreshShop()
end

for order, def in ipairs({ { "furn", "🛋️ 가구" }, { "dress", "👗 의상" }, { "acc", "🕶️ 악세사리" } }) do
	local btn = make("TextButton", {
		Name = "Tab_" .. def[1],
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = def[2],
		TextColor3 = Color3.fromRGB(160, 88, 140),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		LayoutOrder = order,
		ZIndex = 42,
	}, shopTabs)
	round(btn, 12, Color3.new(1, 1, 1), 2)
	local tabId = def[1]
	btn.MouseButton1Click:Connect(function()
		setShopTab(tabId)
	end)
	shopTabButtons[tabId] = btn
end

-- ==============================================================
-- 요정 꾸미기(코디) 창 — 슬롯별 아이콘/색 + 즉시 3D 반영
-- ==============================================================
local wardrobePanel = make("Frame", {
	Name = "WardrobePanel",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0.74, 0),
	BackgroundColor3 = Color3.fromRGB(255, 246, 252),
	ZIndex = 44,
}, gui)
round(wardrobePanel, 24, Color3.new(1, 1, 1), 4)
gradient(wardrobePanel, Color3.fromRGB(255, 252, 254), Color3.fromRGB(246, 233, 255), 90)

local wardrobeTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -120, 0, 26),
	Text = "👗 요정 꾸미기",
	TextColor3 = INK,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 45,
}, wardrobePanel)

local wardrobeClose = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(38, 30),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "X",
	TextColor3 = Color3.fromRGB(180, 90, 150),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 45,
}, wardrobePanel)
round(wardrobeClose, 12, Color3.fromRGB(255, 224, 240), 2)
wardrobeClose.MouseButton1Click:Connect(function()
	wardrobePanel.Visible = false
end)

local chipRow = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 44),
	Size = UDim2.new(1, -28, 0, 58),
	ZIndex = 45,
}, wardrobePanel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, chipRow)

local chipButtons = {}
for order, slot in ipairs({ "dress", "head", "acc" }) do
	local chip = make("TextButton", {
		Name = "Chip_" .. slot,
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 244, 251),
		Text = "",
		LayoutOrder = order,
		ZIndex = 46,
	}, chipRow)
	round(chip, 14, Color3.new(1, 1, 1), 2)
	make("TextLabel", {
		Name = "SlotName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 18),
		Text = WEAR_LABEL[slot],
		TextColor3 = Color3.fromRGB(150, 90, 140),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		ZIndex = 47,
	}, chip)
	make("TextLabel", {
		Name = "SlotValue",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 20),
		Size = UDim2.new(1, -8, 0, 30),
		Text = "없음",
		TextColor3 = Color3.fromRGB(180, 160, 180),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		ZIndex = 47,
	}, chip)
	local slotId = slot
	chip.MouseButton1Click:Connect(function()
		wardrobeTab = slotId
		refreshWardrobe()
	end)
	chipButtons[slot] = chip
end

local wardrobeList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 110),
	Size = UDim2.new(1, -32, 1, -122),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ZIndex = 45,
}, wardrobePanel)
make("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, wardrobeList)

-- 착용 순간 UI 반짝
local function wardrobeSparkle()
	for i = 1, 8 do
		local star = make("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.3 + math.random() * 0.4, 0, 0.35 + math.random() * 0.3, 0),
			Size = UDim2.fromOffset(30, 30),
			Text = (i % 2 == 0) and "✨" or "💖",
			TextScaled = true,
			ZIndex = 60,
		}, wardrobePanel)
		local target = star.Position - UDim2.fromOffset(math.random() * 40 - 20, 60 + math.random() * 40)
		local tween = TweenService:Create(star, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			TextTransparency = 1,
		})
		tween:Play()
		Debris_Add(star, 0.8)
	end
end

refreshWardrobe = function()
	if houseData == nil then
		return
	end
	local fairyId = selectedFairy
	local info = fairyId and FAIRY[fairyId] or nil
	wardrobeTitle.Text = info and ("👗 " .. info.name .. " 꾸미기") or "👗 요정 꾸미기"
	local wear = (houseData.wear and fairyId and houseData.wear[fairyId]) or {}
	local owned = houseData.owned or {}

	for slot, chip in pairs(chipButtons) do
		local itemId = wear[slot]
		local item = itemId and WEAR[itemId] or nil
		local value = chip:FindFirstChild("SlotValue")
		if value ~= nil then
			value.Text = item and (item.icon .. " " .. item.name) or "비어 있음"
			value.TextColor3 = item and INK or Color3.fromRGB(180, 160, 180)
		end
		chip.BackgroundColor3 = item and item.color or Color3.fromRGB(255, 244, 251)
		chip.BackgroundTransparency = item and 0.35 or 0
	end

	clearList(wardrobeList)
	local list = WEAR_LIST[wardrobeTab]
	local wearing = wear[wardrobeTab]
	for index, item in ipairs(list) do
		local isOwned = owned[item.id] == true
		local isOn = wearing == item.id
		local priceText
		if isOn then
			priceText = "착용 중 ✓"
		elseif isOwned then
			priceText = "입히기"
		else
			priceText = tostring(item.price) .. " 코인"
		end
		local priceColor = isOn and Color3.fromRGB(235, 70, 150)
			or (isOwned and Color3.fromRGB(80, 170, 140) or Color3.fromRGB(200, 120, 0))
		local row = shopRow(index, item.icon, item.name, priceText, priceColor, function()
			if selectedFairy == nil then
				toast("먼저 요정을 선택해 주세요")
				return
			end
			if isOn then
				remotes.SetWear:FireServer(selectedFairy, wardrobeTab, nil)
			elseif isOwned then
				remotes.SetWear:FireServer(selectedFairy, wardrobeTab, item.id)
				wardrobeSparkle()
			else
				remotes.BuyWear:FireServer(item.id)
			end
		end)
		row.Parent = wardrobeList
	end
	wardrobeList.CanvasSize = UDim2.new(0, 0, 0, #list * 60)
end

openWardrobe = function()
	if selectedFairy == nil then
		toast("하우스에서 요정을 먼저 선택해 주세요")
		return
	end
	if houseData ~= nil then
		remotes.RequestHouse:FireServer()
	end
	wardrobePanel.Visible = true
	refreshWardrobe()
end

shopButton.MouseButton1Click:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
	if shopPanel.Visible then
		wardrobePanel.Visible = false
		remotes.RequestHouse:FireServer()
		refreshShop()
	end
end)

decorBtn.MouseButton1Click:Connect(function()
	housePanel.Visible = false
	shopPanel.Visible = true
	wardrobePanel.Visible = false
	setShopTab("furn")
end)

wardrobeBtn.MouseButton1Click:Connect(function()
	housePanel.Visible = false
	shopPanel.Visible = false
	openWardrobe()
end)

-- ==============================================================
-- 안내 / 알림
-- ==============================================================
remotes.Notify.OnClientEvent:Connect(function(text)
	toast(text)
end)

-- ==============================================================
-- 렌더 루프 (포인터 회전 · 반짝 구간 · 타이머)
-- ==============================================================
RunService.RenderStepped:Connect(function(dt)
	if catchState == nil then
		return
	end
	local angle = angleNow(catchState)
	local rad = math.rad(angle - 90)
	pointer.Position = UDim2.new(0.5, math.cos(rad) * RING_RADIUS, 0.5, math.sin(rad) * RING_RADIUS)

	-- 반짝 구간 하이라이트
	for i = 1, DOT_COUNT do
		local dotAngle = ((i - 1) / DOT_COUNT) * 360
		local diff = (dotAngle - catchState.arcStart) % 360
		local inArc = diff <= catchState.arcLen
		local dot = ringDots[i]
		if inArc then
			dot.BackgroundColor3 = PINK_DEEP
			dot.Size = UDim2.fromOffset(14, 14)
		else
			dot.BackgroundColor3 = Color3.fromRGB(255, 224, 240)
			dot.Size = UDim2.fromOffset(10, 10)
		end
	end

	-- 타이머
	if not catchState.done then
		catchState.time = math.max(0, catchState.time - dt)
		timerFill.Size = UDim2.fromScale(math.clamp(catchState.time / 12, 0, 1), 1)
		if catchState.time <= 0 then
			catchState.done = true
		end
	end

	-- 안쪽 원 반짝
	local pulse = 1 + math.sin(workspace:GetServerTimeNow() * 6) * 0.04
	innerCircle.Size = UDim2.fromOffset(176 * pulse, 176 * pulse)
end)

remotes.HouseData.OnClientEvent:Connect(function(data, open)
	houseData = data
	if data ~= nil then
		coinLabel.Text = tostring(data.coins or 0)
	end
	if open then
		housePanel.Visible = true
	end
	if housePanel.Visible then
		refreshHouse()
	end
	-- 도감/상점/코디가 열려 있으면 함께 갱신
	if dexPanel.Visible then
		refreshDex()
	end
	if shopPanel.Visible then
		refreshShop()
	end
	if wardrobePanel.Visible then
		refreshWardrobe()
	end
end)

remotes.RequestHouse.OnClientEvent:Connect(function(open)
	if open then
		housePanel.Visible = true
		refreshHouse()
	end
end)

-- ==============================================================
-- 요정 타운 패널 (학업 · 땅 매입 · 건설 · 장사 · 병원/마트/장비점)
-- ==============================================================
local townCatalogList = {}
local townCatalogSlot = {}
do
	local folder = ReplicatedStorage:WaitForChild("FairyTownCatalog", 20)
	if folder ~= nil then
		for _, conf in ipairs(folder:GetChildren()) do
			if conf:IsA("Configuration") then
				local info = {
					slot = conf:GetAttribute("Slot") or 0,
					id = conf.Name,
					name = conf:GetAttribute("DisplayName") or conf.Name,
					icon = conf:GetAttribute("Icon") or "🏪",
					kind = conf:GetAttribute("Kind") or "shop",
					land = conf:GetAttribute("Land") or 0,
					build = conf:GetAttribute("Build") or 0,
				}
				townCatalogSlot[info.slot] = info
				table.insert(townCatalogList, info)
			end
		end
	end
	table.sort(townCatalogList, function(a, b)
		return a.slot < b.slot
	end)
end

local MAJOR_LABEL = {
	pastry = "🥐파티시에",
	designer = "👗디자이너",
	barista = "🧪포션바리스타",
	jeweler = "💎보석세공사",
}

local townData = nil
local townSelected = nil

local townPanel = make("Frame", {
	Name = "TownPanel",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.94, 0, 0.9, 0),
	BackgroundColor3 = Color3.fromRGB(255, 246, 252),
	ZIndex = 40,
}, gui)
round(townPanel, 24, Color3.new(1, 1, 1), 4)
gradient(townPanel, Color3.fromRGB(255, 252, 254), Color3.fromRGB(244, 236, 255), 90)

local townTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 10),
	Size = UDim2.new(1, -80, 0, 30),
	Text = "🏘️ 요정 타운",
	TextColor3 = INK,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 41,
}, townPanel)

local closeTown = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(38, 32),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "X",
	TextColor3 = Color3.fromRGB(180, 90, 150),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 42,
}, townPanel)
round(closeTown, 12, Color3.fromRGB(255, 224, 240), 2)

local townStat = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 42),
	Size = UDim2.new(1, -40, 0, 26),
	Text = "초당 0 코인",
	TextColor3 = Color3.fromRGB(160, 110, 140),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 41,
}, townPanel)

local plotTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 18, 0.115, 0),
	Size = UDim2.new(1, -36, 0, 20),
	Text = "🏪 마을 상점가 · 땅 매입 → 건설 → 증축",
	TextColor3 = Color3.fromRGB(138, 79, 125),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 41,
}, townPanel)

local plotsScroll = make("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 14, 0.155, 0),
	Size = UDim2.new(1, -28, 0.35, 0),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 4,
	BorderSizePixel = 0,
	ZIndex = 41,
}, townPanel)
make("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, plotsScroll)

local fairyTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 18, 0.515, 0),
	Size = UDim2.new(1, -36, 0, 20),
	Text = "🧚 요정 상태 · 요정을 누르면 간식·치료·장비 선물",
	TextColor3 = Color3.fromRGB(138, 79, 125),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 41,
}, townPanel)

local fairyScroll = make("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 14, 0.555, 0),
	Size = UDim2.new(1, -28, 0.33, 0),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 4,
	BorderSizePixel = 0,
	ZIndex = 41,
}, townPanel)
make("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, fairyScroll)

local townHint = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 18, 0.90, 0),
	Size = UDim2.new(1, -36, 0, 34),
	Text = "요정은 스스로 공부하고 장사하고 마트·병원·장비점에서 소비해요. 학업 Lv·건물 Lv·장비가 높을수록 매출이 커집니다.",
	TextColor3 = Color3.fromRGB(170, 130, 160),
	Font = Enum.Font.Gotham,
	TextScaled = true,
	TextWrapped = true,
	ZIndex = 41,
}, townPanel)

local function clearRows(scroll, className)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA(className) then
			child:Destroy()
		end
	end
end

local function townPlotRow(info, plot, order)
	local row = make("Frame", {
		Size = UDim2.new(1, -6, 0, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, plotsScroll)
	round(row, 14, Color3.fromRGB(255, 226, 243), 2)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.fromOffset(30, 32),
		Text = info.icon,
		TextScaled = true,
	}, row)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 5),
		Size = UDim2.new(1, -140, 0, 18),
		Text = info.name,
		TextColor3 = Color3.fromRGB(107, 47, 86),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local stateText
	if plot.bld >= 1 then
		local workerName = ""
		if plot.worker ~= nil then
			for _, f in ipairs(townData.fairies or {}) do
				if f.id == plot.worker then
					workerName = " · 점장 " .. f.name
				end
			end
		end
		stateText = "Lv." .. tostring(plot.bld) .. " · 초당 " .. tostring(string.format("%.1f", plot.rate or 0)) .. workerName
	elseif plot.owned then
		stateText = "내 땅 · 건물을 올리면 장사가 시작돼요"
	else
		stateText = "매물 · 땅 " .. tostring(info.land) .. " / 건물 " .. tostring(info.build)
	end
	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(42, 23),
		Size = UDim2.new(1, -140, 0, 16),
		Text = stateText,
		TextColor3 = Color3.fromRGB(170, 140, 160),
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local actText, actColor
	local actFn = nil
	if not plot.owned then
		actText = "🚩 땅 " .. tostring(info.land)
		actColor = Color3.fromRGB(255, 200, 90)
		actFn = function()
			remotes.BuyPlot:FireServer(info.slot)
		end
	elseif plot.bld < 1 then
		actText = "🏗️ 건설 " .. tostring(info.build)
		actColor = Color3.fromRGB(255, 200, 90)
		actFn = function()
			remotes.UpgradeBuilding:FireServer(info.slot)
		end
	elseif plot.bld < 3 then
		actText = "⬆️ Lv." .. tostring(plot.bld + 1) .. " " .. tostring(plot.upCost or 0)
		actColor = Color3.fromRGB(255, 200, 90)
		actFn = function()
			remotes.UpgradeBuilding:FireServer(info.slot)
		end
	else
		actText = "Lv.3 MAX"
		actColor = Color3.fromRGB(230, 220, 235)
	end
	local actBtn = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 5),
		Size = UDim2.fromOffset(92, 24),
		BackgroundColor3 = actColor,
		BorderSizePixel = 0,
		Text = actText,
		TextColor3 = Color3.fromRGB(106, 59, 0),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
	}, row)
	round(actBtn, 9, Color3.new(1, 1, 1), 2)
	if actFn ~= nil then
		actBtn.MouseButton1Click:Connect(actFn)
	end

	local income = math.floor(plot.income or 0)
	local colBtn = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 32),
		Size = UDim2.fromOffset(92, 21),
		BackgroundColor3 = income > 0 and Color3.fromRGB(204, 245, 232) or Color3.fromRGB(240, 236, 244),
		BorderSizePixel = 0,
		Text = "💰 수거 " .. tostring(income),
		TextColor3 = income > 0 and Color3.fromRGB(47, 127, 108) or Color3.fromRGB(170, 150, 165),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}, row)
	round(colBtn, 9, Color3.new(1, 1, 1), 2)
	if income > 0 then
		colBtn.MouseButton1Click:Connect(function()
			remotes.CollectBusiness:FireServer(info.slot)
		end)
	end
end

local refreshTown

local function townFairyRow(f, order)
	local selected = (townSelected == f.id)
	local row = make("TextButton", {
		Size = UDim2.new(1, -6, 0, selected and 96 or 62),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
	}, fairyScroll)
	round(row, 14, selected and PINK or Color3.fromRGB(255, 226, 243), 2)
	row.MouseButton1Click:Connect(function()
		townSelected = f.id
		refreshTown()
	end)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 18),
		Text = f.name .. "  ·  Lv." .. tostring(f.lv) .. "  " .. (MAJOR_LABEL[f.major] or "전공 미정") .. (f.ring and "  💍" or "") .. (f.charm and "  🍀" or ""),
		TextColor3 = Color3.fromRGB(107, 47, 86),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 16),
		Text = "❤ " .. tostring(f.hp) .. "   🪙 " .. tostring(f.wallet) .. "   " .. tostring(f.status),
		TextColor3 = Color3.fromRGB(170, 140, 160),
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local modes = { { "auto", "자유" }, { "study", "공부" }, { "work", "장사" } }
	for index, m in ipairs(modes) do
		local on = (f.mode or "auto") == m[1]
		local b = make("TextButton", {
			Position = UDim2.fromOffset(10 + (index - 1) * 46, 40),
			Size = UDim2.fromOffset(42, 18),
			BackgroundColor3 = on and PINK or Color3.fromRGB(255, 244, 250),
			BorderSizePixel = 0,
			Text = m[2],
			TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(140, 90, 125),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
		}, row)
		round(b, 8, Color3.new(1, 1, 1), 1)
		b.MouseButton1Click:Connect(function()
			remotes.SetFairyMode:FireServer(f.id, m[1])
		end)
	end

	if selected then
		local cares = { { "snack", "🍬 간식" }, { "heal", "🏥 치료" }, { "ring", "💍 반지" }, { "charm", "🍀 부적" } }
		for index, c in ipairs(cares) do
			local b = make("TextButton", {
				Position = UDim2.fromOffset(10 + (index - 1) * 82, 64),
				Size = UDim2.fromOffset(76, 24),
				BackgroundColor3 = Color3.fromRGB(255, 236, 190),
				BorderSizePixel = 0,
				Text = c[2],
				TextColor3 = Color3.fromRGB(106, 59, 0),
				Font = Enum.Font.GothamBold,
				TextScaled = true,
			}, row)
			round(b, 9, Color3.new(1, 1, 1), 1)
			b.MouseButton1Click:Connect(function()
				remotes.CareFairy:FireServer(f.id, c[1])
			end)
		end
	end
end

refreshTown = function()
	if townData == nil then
		return
	end
	local rate = string.format("%.1f", townData.rate or 0)
	local income = tostring(math.floor(townData.income or 0))
	local owned, built = 0, 0
	for _, p in ipairs(townData.plots or {}) do
		if p.owned then
			owned = owned + 1
		end
		if p.bld >= 1 then
			built = built + 1
		end
	end
	townStat.Text = "초당 " .. rate .. " 코인 · 수거 대기 " .. income .. " · 내 땅 " .. tostring(owned) .. "/" .. tostring(#townCatalogList) .. " · 건물 " .. tostring(built)

	clearRows(plotsScroll, "Frame")
	local order = 0
	for _, info in ipairs(townCatalogList) do
		local plot = nil
		for _, p in ipairs(townData.plots or {}) do
			if p.slot == info.slot then
				plot = p
			end
		end
		if plot ~= nil then
			order = order + 1
			townPlotRow(info, plot, order)
		end
	end
	plotsScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(0, #townCatalogList * 64))

	clearRows(fairyScroll, "TextButton")
	local fairyOrder = 0
	local fairyHeight = 0
	for _, f in ipairs(townData.fairies or {}) do
		fairyOrder = fairyOrder + 1
		townFairyRow(f, fairyOrder)
		fairyHeight = fairyHeight + ((townSelected == f.id) and 102 or 68)
	end
	fairyScroll.CanvasSize = UDim2.new(0, 0, 0, fairyHeight)
	coinLabel.Text = tostring(math.floor(townData.coins or 0))
end

townButton.MouseButton1Click:Connect(function()
	townPanel.Visible = not townPanel.Visible
	if townPanel.Visible then
		remotes.RequestTown:FireServer()
		refreshTown()
	end
end)

closeTown.MouseButton1Click:Connect(function()
	townPanel.Visible = false
end)

remotes.TownData.OnClientEvent:Connect(function(data)
	townData = data
	if townPanel.Visible then
		refreshTown()
	end
end)

print("[FairyCatch] HUD 준비 완료")
