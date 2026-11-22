--[[
  03_NeonVaultHUD.client.lua
  --------------------------------------------------------------------------------
  붙여넣는 위치: StarterPlayer > StarterPlayerScripts  (LocalScript)
  하는 일:
    · 네온 다크 사이버 HUD
       - 현금 / 초당 수익 / 수금 대기 / 훔친 횟수
       - 내 방어막 남은 시간 게이지
       - 전리품 운반 남은 시간 게이지
       - 4대 테마 도감 버튼
       - 상점·게임패스 모달
       - 🛸 드론 해킹 버튼 (재사용 대기 표시)
       - 🔒 즉시 잠금 버튼 (게임패스 보유 시)
    · 서버 알림(토스트) 표시
    · 뽑기 결과 연출
  ※ UI 는 코드가 전부 자동 생성합니다. 화면에 따로 배치할 필요 없습니다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("NeonVaultRemotes", 30)
if remotes == nil then
	return
end
local notifyRemote = remotes:WaitForChild("Notify", 20)
local rollFx = remotes:WaitForChild("RollFx", 20)
local requestHack = remotes:WaitForChild("RequestHack", 20)
local requestLock = remotes:WaitForChild("RequestInstantLock", 20)
if notifyRemote == nil or requestHack == nil or requestLock == nil then
	return
end

local configFolder = ReplicatedStorage:WaitForChild("NeonVaultConfig", 30)
local COST_FOLDER = nil
if configFolder ~= nil then
	COST_FOLDER = configFolder:FindFirstChild("GachaCost")
end

-- ==============================================================
-- 팔레트 / 헬퍼
-- ==============================================================
local CYAN = Color3.fromRGB(0, 232, 255)
local MAGENTA = Color3.fromRGB(255, 46, 190)
local VIOLET = Color3.fromRGB(150, 110, 255)
local GOLD = Color3.fromRGB(255, 198, 58)
local RED = Color3.fromRGB(255, 84, 96)
local GREEN = Color3.fromRGB(90, 240, 160)
local WHITE = Color3.fromRGB(232, 244, 255)
local DIM = Color3.fromRGB(150, 170, 205)
local PANEL = Color3.fromRGB(12, 16, 32)

local function fmt(value)
	local n = math.floor(tonumber(value) or 0)
	local negative = ""
	if n < 0 then
		negative = "-"
		n = -n
	end
	local text = tostring(n)
	local out = ""
	local count = 0
	for i = #text, 1, -1 do
		out = string.sub(text, i, i) .. out
		count = count + 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return negative .. out
end

local RARITY_LABEL = { common = "일반", rare = "희귀", epic = "영웅", legendary = "전설" }
local RARITY_COLOR = {
	common = Color3.fromRGB(198, 214, 236),
	rare = Color3.fromRGB(84, 186, 255),
	epic = Color3.fromRGB(190, 116, 255),
	legendary = Color3.fromRGB(255, 190, 70),
}
local THEME_LABEL = { gem = "💎 보석", egg = "🦖 공룡 알", monster = "🐉 전설 몬스터", drone = "🛸 사이버 드론" }

local function corner(inst, radius)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius or 12)
	ui.Parent = inst
	return ui
end

local function stroke(inst, color, thickness, transparency)
	local ui = Instance.new("UIStroke")
	ui.Color = color or CYAN
	ui.Thickness = thickness or 1.6
	ui.Transparency = transparency or 0.25
	ui.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ui.Parent = inst
	return ui
end

local function makeLabel(parent, properties)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = WHITE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	for key, value in pairs(properties) do
		label[key] = value
	end
	label.Parent = parent
	return label
end

local function makeButton(parent, text, color, size, position)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(18, 24, 44)
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = color or WHITE
	button.TextSize = 16
	button.Parent = parent
	corner(button, 14)
	stroke(button, color or CYAN, 1.6, 0.15)
	return button
end

-- ==============================================================
-- 루트 GUI
-- ==============================================================
local old = playerGui:FindFirstChild("NeonVaultHUD")
if old ~= nil then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "NeonVaultHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
gui.Parent = playerGui

-- ==============================================================
-- 좌측 상단 : 현금 패널
-- ==============================================================
local moneyPanel = Instance.new("Frame")
moneyPanel.Name = "MoneyPanel"
moneyPanel.Size = UDim2.new(0, 216, 0, 96)
moneyPanel.Position = UDim2.new(0, 12, 0, 10)
moneyPanel.BackgroundColor3 = PANEL
moneyPanel.BackgroundTransparency = 0.18
moneyPanel.BorderSizePixel = 0
moneyPanel.Parent = gui
corner(moneyPanel, 16)
stroke(moneyPanel, CYAN, 1.8, 0.2)

local moneyGlow = Instance.new("UIGradient")
moneyGlow.Color = ColorSequence.new(Color3.fromRGB(40, 90, 140), Color3.fromRGB(14, 18, 34))
moneyGlow.Rotation = 90
moneyGlow.Parent = moneyPanel

local cashLabel = makeLabel(moneyPanel, {
	Size = UDim2.new(1, -24, 0, 34),
	Position = UDim2.new(0, 14, 0, 8),
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	TextColor3 = GOLD,
	Text = "$0",
})
local incomeLabel = makeLabel(moneyPanel, {
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.new(0, 14, 0, 42),
	TextSize = 14,
	TextColor3 = GREEN,
	Text = "+$0 /초",
})
local pendingLabel = makeLabel(moneyPanel, {
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.new(0, 14, 0, 64),
	TextSize = 13,
	TextColor3 = DIM,
	Text = "수금 대기 $0  ·  훔침 0",
})

-- ==============================================================
-- 우측 상단 : 방어막 패널
-- ==============================================================
local shieldPanel = Instance.new("Frame")
shieldPanel.Name = "ShieldPanel"
shieldPanel.Size = UDim2.new(0, 168, 0, 78)
shieldPanel.Position = UDim2.new(1, -180, 0, 10)
shieldPanel.BackgroundColor3 = PANEL
shieldPanel.BackgroundTransparency = 0.18
shieldPanel.BorderSizePixel = 0
shieldPanel.Parent = gui
corner(shieldPanel, 16)
local shieldStroke = stroke(shieldPanel, CYAN, 1.8, 0.2)

local shieldTitle = makeLabel(shieldPanel, {
	Size = UDim2.new(1, -20, 0, 22),
	Position = UDim2.new(0, 12, 0, 8),
	TextSize = 14,
	TextColor3 = CYAN,
	Text = "🛡 내 방어막",
})
local shieldTime = makeLabel(shieldPanel, {
	Size = UDim2.new(1, -20, 0, 26),
	Position = UDim2.new(0, 12, 0, 26),
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = WHITE,
	Text = "60초",
})
local shieldBarBg = Instance.new("Frame")
shieldBarBg.Size = UDim2.new(1, -24, 0, 8)
shieldBarBg.Position = UDim2.new(0, 12, 1, -18)
shieldBarBg.BackgroundColor3 = Color3.fromRGB(30, 38, 60)
shieldBarBg.BorderSizePixel = 0
shieldBarBg.Parent = shieldPanel
corner(shieldBarBg, 4)

local shieldBar = Instance.new("Frame")
shieldBar.Size = UDim2.new(1, 0, 1, 0)
shieldBar.BackgroundColor3 = CYAN
shieldBar.BorderSizePixel = 0
shieldBar.Parent = shieldBarBg
corner(shieldBar, 4)

-- ==============================================================
-- 좌측 하단 : 내 기지 요약 / 도감 / 상점 버튼
-- ==============================================================
local sideButtons = Instance.new("Frame")
sideButtons.Name = "SideButtons"
sideButtons.Size = UDim2.new(0, 112, 0, 176)
sideButtons.Position = UDim2.new(0, 12, 1, -196)
sideButtons.BackgroundTransparency = 1
sideButtons.Parent = gui

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = sideButtons

local function addSideButton(text, color, order)
	local button = makeButton(sideButtons, text, color, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0))
	button.LayoutOrder = order
	button.TextSize = 13
	button.TextWrapped = true
	return button
end

local collectionButton = addSideButton("📖 도감", VIOLET, 1)
local shopButton = addSideButton("🛒 상점", GOLD, 2)
local lockButton = addSideButton("🔒 즉시 잠금", CYAN, 3)

-- ==============================================================
-- 우측 하단 : 드론 해킹 버튼
-- ==============================================================
local hackButton = Instance.new("TextButton")
hackButton.Name = "HackButton"
hackButton.Size = UDim2.new(0, 128, 0, 128)
hackButton.Position = UDim2.new(1, -144, 1, -152)
hackButton.BackgroundColor3 = Color3.fromRGB(38, 20, 62)
hackButton.BackgroundTransparency = 0.08
hackButton.BorderSizePixel = 0
hackButton.Font = Enum.Font.GothamBlack
hackButton.Text = "🛸\n해킹"
hackButton.TextColor3 = Color3.fromRGB(214, 196, 255)
hackButton.TextSize = 20
hackButton.AutoButtonColor = true
hackButton.Parent = gui
corner(hackButton, 64)
stroke(hackButton, VIOLET, 2.4, 0.1)

local hackInfo = makeLabel(hackButton, {
	Size = UDim2.new(1, 0, 0, 16),
	Position = UDim2.new(0, 0, 1, -22),
	TextSize = 12,
	TextColor3 = Color3.fromRGB(180, 160, 240),
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "파워 0",
})

-- ==============================================================
-- 운반 게이지 (전리품 들고 있을 때)
-- ==============================================================
local carryPanel = Instance.new("Frame")
carryPanel.Name = "CarryPanel"
carryPanel.Size = UDim2.new(0, 220, 0, 46)
carryPanel.Position = UDim2.new(0.5, -110, 1, -104)
carryPanel.BackgroundColor3 = Color3.fromRGB(54, 18, 24)
carryPanel.BackgroundTransparency = 0.15
carryPanel.BorderSizePixel = 0
carryPanel.Visible = false
carryPanel.Parent = gui
corner(carryPanel, 12)
stroke(carryPanel, RED, 1.6, 0.1)

local carryLabel = makeLabel(carryPanel, {
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.new(0, 10, 0, 5),
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 190, 190),
	Text = "🕵️ 전리품 운반 중",
})
local carryBarBg = Instance.new("Frame")
carryBarBg.Size = UDim2.new(1, -20, 0, 8)
carryBarBg.Position = UDim2.new(0, 10, 1, -16)
carryBarBg.BackgroundColor3 = Color3.fromRGB(40, 20, 28)
carryBarBg.BorderSizePixel = 0
carryBarBg.Parent = carryPanel
corner(carryBarBg, 4)
local carryBar = Instance.new("Frame")
carryBar.Size = UDim2.new(1, 0, 1, 0)
carryBar.BackgroundColor3 = RED
carryBar.BorderSizePixel = 0
carryBar.Parent = carryBarBg
corner(carryBar, 4)

-- ==============================================================
-- 토스트 알림
-- ==============================================================
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.new(0, 300, 0, 200)
toastHolder.Position = UDim2.new(0.5, -150, 0, 96)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local function toast(text)
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(10, 14, 28)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Size = UDim2.new(1, 0, 0, 32)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextSize = 13
	label.TextColor3 = WHITE
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = toastHolder
	corner(label, 10)
	stroke(label, CYAN, 1.2, 0.5)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	task.delay(4, function()
		if label.Parent ~= nil then
			TweenService:Create(label, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			for _, child in ipairs(label:GetChildren()) do
				if child:IsA("UIStroke") then
					TweenService:Create(child, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
			task.delay(0.6, function()
				label:Destroy()
			end)
		end
	end)
end

notifyRemote.OnClientEvent:Connect(function(text)
	toast(text)
end)

-- ==============================================================
-- 모달 공통
-- ==============================================================
local function makeModal(title, height)
	local modal = Instance.new("Frame")
	modal.Name = "Modal"
	modal.Size = UDim2.new(0, 300, 0, height)
	modal.Position = UDim2.new(0.5, -150, 0.5, -height / 2)
	modal.BackgroundColor3 = Color3.fromRGB(9, 12, 24)
	modal.BackgroundTransparency = 0.04
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 40
	modal.Parent = gui
	corner(modal, 18)
	stroke(modal, CYAN, 2, 0.15)

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -70, 0, 40)
	header.Position = UDim2.new(0, 16, 0, 8)
	header.Font = Enum.Font.GothamBlack
	header.Text = title
	header.TextColor3 = CYAN
	header.TextSize = 18
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 41
	header.Parent = modal

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 34, 0, 34)
	close.Position = UDim2.new(1, -46, 0, 10)
	close.BackgroundColor3 = Color3.fromRGB(40, 20, 30)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBlack
	close.Text = "✕"
	close.TextColor3 = Color3.fromRGB(255, 140, 150)
	close.TextSize = 16
	close.ZIndex = 41
	close.Parent = modal
	corner(close, 8)
	close.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -24, 1, -64)
	content.Position = UDim2.new(0, 12, 0, 54)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = CYAN
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ZIndex = 41
	content.Parent = modal

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	return modal, content
end

-- ==============================================================
-- 도감 모달
-- ==============================================================
local collectionModal, collectionContent = makeModal("📖 네온 도감", 400)

local function refreshCollection()
	for _, child in ipairs(collectionContent:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local raw = player:GetAttribute("Collection") or "{}"
	local collection = {}
	local ok, decoded = pcall(function()
		return game:GetService("HttpService"):JSONDecode(raw)
	end)
	if ok and type(decoded) == "table" then
		collection = decoded
	end

	for _, themeId in ipairs({ "gem", "egg", "monster", "drone" }) do
		local entry = collection[themeId]
		local count = 0
		local best = "-"
		if type(entry) == "table" then
			count = entry.count or 0
			if entry.best ~= nil and entry.best ~= "" then
				best = RARITY_LABEL[entry.best] or entry.best
			end
		end
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 58)
		row.BackgroundColor3 = Color3.fromRGB(16, 22, 42)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.ZIndex = 42
		row.Parent = collectionContent
		corner(row, 12)
		stroke(row, VIOLET, 1.2, 0.5)

		makeLabel(row, {
			Size = UDim2.new(1, -20, 0, 24),
			Position = UDim2.new(0, 12, 0, 6),
			TextSize = 15,
			TextColor3 = WHITE,
			Text = THEME_LABEL[themeId] or themeId,
			ZIndex = 43,
		})
		makeLabel(row, {
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 12, 0, 30),
			TextSize = 12,
			TextColor3 = DIM,
			Text = "보유 " .. tostring(count) .. "개  ·  최고 등급 " .. best,
			ZIndex = 43,
		})
	end
end

collectionButton.MouseButton1Click:Connect(function()
	refreshCollection()
	collectionModal.Visible = not collectionModal.Visible
end)

-- ==============================================================
-- 상점 모달
-- ==============================================================
local shopModal, shopContent = makeModal("🛒 상점 · 게임패스", 430)

local function configId(key)
	if configFolder == nil then
		return 0
	end
	local value = configFolder:FindFirstChild(key)
	if value ~= nil and value:IsA("NumberValue") then
		return math.floor(value.Value)
	end
	return 0
end

local function addShopRow(title, description, color, id, isPass)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 74)
	row.BackgroundColor3 = Color3.fromRGB(16, 22, 42)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.ZIndex = 42
	row.Parent = shopContent
	corner(row, 12)
	stroke(row, color, 1.4, 0.4)

	makeLabel(row, {
		Size = UDim2.new(1, -110, 0, 24),
		Position = UDim2.new(0, 12, 0, 8),
		TextSize = 15,
		TextColor3 = color,
		Text = title,
		ZIndex = 43,
	})
	makeLabel(row, {
		Size = UDim2.new(1, -110, 0, 34),
		Position = UDim2.new(0, 12, 0, 32),
		TextSize = 11,
		TextColor3 = DIM,
		Text = description,
		TextWrapped = true,
		ZIndex = 43,
	})
	local buy = makeButton(row, "구매", color, UDim2.new(0, 84, 0, 34), UDim2.new(1, -96, 0.5, -17))
	buy.ZIndex = 43
	buy.TextSize = 14
	buy.MouseButton1Click:Connect(function()
		if id <= 0 then
			toast("🛠 아직 판매 등록 전입니다. (스튜디오에서 ID 입력 후 사용 가능)")
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
end

addShopRow("⚡ 2배 수익", "모든 전시품 수익이 2배가 됩니다. (영구)", GOLD, configId("GAMEPASS_2X_CASH"), true)
addShopRow("🔒 즉시 잠금", "방어막을 즉시 다시 켭니다. (쿨타임 45초)", CYAN, configId("GAMEPASS_INSTANT_LOCK"), true)
addShopRow("🛸 해킹 드론 팩", "오버로드 드론 1대 지급 — 해킹 파워 최대치", VIOLET, configId("GAMEPASS_DRONE_PACK"), true)
addShopRow("💵 현금 팩 S", "$2,500 즉시 충전", GREEN, configId("PRODUCT_CASH_SMALL"), false)
addShopRow("💰 현금 팩 M", "$15,000 즉시 충전", GREEN, configId("PRODUCT_CASH_BIG"), false)
addShopRow("🔥 현금 팩 L", "$100,000 즉시 충전", RED, configId("PRODUCT_CASH_MEGA"), false)

shopButton.MouseButton1Click:Connect(function()
	shopModal.Visible = not shopModal.Visible
end)

-- ==============================================================
-- 버튼 동작
-- ==============================================================
hackButton.MouseButton1Click:Connect(function()
	requestHack:FireServer()
end)

lockButton.MouseButton1Click:Connect(function()
	requestLock:FireServer()
end)

-- 내 금고 전시대에서는 '훔치기' 프롬프트를 숨깁니다(로컬 전용).
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name ~= "StealPrompt" then
		return
	end
	local pedestal = prompt.Parent
	if pedestal == nil or pedestal.Parent == nil then
		return
	end
	local plot = pedestal.Parent.Parent
	if plot == nil then
		return
	end
	if plot:GetAttribute("Owner") == player.UserId then
		prompt.Enabled = false
	end
end)

-- ==============================================================
-- 뽑기 결과 연출
-- ==============================================================
if rollFx ~= nil then
	rollFx.OnClientEvent:Connect(function(themeId, itemName, rarity, income)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, 250, 0, 120)
		card.Position = UDim2.new(0.5, -125, 0.42, -60)
		card.BackgroundColor3 = Color3.fromRGB(8, 12, 26)
		card.BackgroundTransparency = 0.05
		card.BorderSizePixel = 0
		card.ZIndex = 60
		card.Parent = gui
		corner(card, 16)
		stroke(card, RARITY_COLOR[rarity] or CYAN, 3, 0)
		card.Size = UDim2.new(0, 10, 0, 10)
		TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 250, 0, 120),
			Position = UDim2.new(0.5, -125, 0.42, -60),
		}):Play()

		makeLabel(card, {
			Size = UDim2.new(1, -20, 0, 24),
			Position = UDim2.new(0, 10, 0, 10),
			TextSize = 13,
			TextColor3 = RARITY_COLOR[rarity] or CYAN,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "[" .. (RARITY_LABEL[rarity] or rarity) .. "] " .. (THEME_LABEL[themeId] or themeId),
			ZIndex = 61,
		})
		makeLabel(card, {
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.new(0, 10, 0, 38),
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = itemName,
			ZIndex = 61,
		})
		makeLabel(card, {
			Size = UDim2.new(1, -20, 0, 24),
			Position = UDim2.new(0, 10, 0, 78),
			TextSize = 15,
			TextColor3 = GREEN,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "+$" .. fmt(income) .. " /초",
			ZIndex = 61,
		})
		task.delay(1.8, function()
			if card.Parent ~= nil then
				TweenService:Create(card, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
				for _, child in ipairs(card:GetChildren()) do
					if child:IsA("TextLabel") then
						TweenService:Create(child, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
					elseif child:IsA("UIStroke") then
						TweenService:Create(child, TweenInfo.new(0.35), { Transparency = 1 }):Play()
					end
				end
				task.delay(0.45, function()
					card:Destroy()
				end)
			end
		end)
	end)
end

-- ==============================================================
-- 갱신 루프
-- ==============================================================
local updateAccum = 0
local lastShieldOn = nil

RunService.RenderStepped:Connect(function(dt)
	updateAccum = updateAccum + dt
	if updateAccum < 0.1 then
		return
	end
	updateAccum = 0
	local now = Workspace:GetServerTimeNow()

	local cash = player:GetAttribute("Cash") or 0
	local income = player:GetAttribute("IncomePerSec") or 0
	local pending = player:GetAttribute("Pending") or 0
	local steals = player:GetAttribute("Steals") or 0
	cashLabel.Text = "$" .. fmt(cash)
	incomeLabel.Text = "+$" .. fmt(income) .. " /초"
	pendingLabel.Text = "수금 대기 $" .. fmt(pending) .. "  ·  훔침 " .. tostring(math.floor(steals))

	local shieldOn = player:GetAttribute("ShieldOn") == true
	local shieldEnds = player:GetAttribute("ShieldEnds") or 0
	local remaining = math.max(0, shieldEnds - now)
	local vaultIndex = player:GetAttribute("VaultIndex") or 0
	if vaultIndex == 0 then
		shieldTitle.Text = "🏦 기지 없음"
		shieldTime.Text = "-"
		shieldBar.Size = UDim2.new(0, 0, 1, 0)
	elseif shieldOn then
		shieldTitle.Text = "🛡 내 방어막"
		shieldTime.Text = tostring(math.ceil(remaining)) .. "초"
		shieldBar.Size = UDim2.new(math.clamp(remaining / 60, 0, 1), 0, 1, 0)
	else
		shieldTitle.Text = "⚠ 무방비!"
		shieldTime.Text = tostring(math.ceil(remaining)) .. "초"
		shieldBar.Size = UDim2.new(math.clamp(remaining / 30, 0, 1), 0, 1, 0)
	end
	if shieldOn ~= lastShieldOn then
		lastShieldOn = shieldOn
		shieldBar.BackgroundColor3 = shieldOn and CYAN or RED
		shieldStroke.Color = shieldOn and CYAN or RED
		shieldTime.TextColor3 = shieldOn and WHITE or Color3.fromRGB(255, 160, 160)
	end

	local hackReadyAt = player:GetAttribute("HackReadyAt") or 0
	local hackLeft = math.max(0, hackReadyAt - now)
	if hackLeft > 0 then
		hackButton.Text = "🛸\n" .. tostring(math.ceil(hackLeft))
		hackButton.TextColor3 = Color3.fromRGB(130, 118, 160)
	else
		hackButton.Text = "🛸\n해킹"
		hackButton.TextColor3 = Color3.fromRGB(214, 196, 255)
	end
	local droneBest = player:GetAttribute("DroneBest") or 0
	if droneBest > 0 then
		hackInfo.Text = "파워 " .. tostring(droneBest)
	else
		hackInfo.Text = "드론 필요"
	end

	local carryingName = player:GetAttribute("Carrying") or ""
	if carryingName ~= "" then
		carryPanel.Visible = true
		local carryEnds = player:GetAttribute("CarryEnds") or 0
		local carryLeft = math.max(0, carryEnds - now)
		carryLabel.Text = "🕵️ " .. carryingName .. " 운반 중 · " .. tostring(math.ceil(carryLeft)) .. "초"
		carryBar.Size = UDim2.new(math.clamp(carryLeft / 15, 0, 1), 0, 1, 0)
	else
		carryPanel.Visible = false
	end

	-- 즉시 잠금 버튼 상태
	if player:GetAttribute("HasInstantLock") == true then
		local readyAt = player:GetAttribute("InstantLockReadyAt") or 0
		local left = math.max(0, readyAt - now)
		if left > 0 then
			lockButton.Text = "🔒 " .. tostring(math.ceil(left)) .. "초"
		else
			lockButton.Text = "🔒 즉시 잠금"
		end
	else
		lockButton.Text = "🔒 패스 필요"
	end
end)

task.delay(2, function()
	toast("🎮 중앙 타워에서 뽑기 · 상대 방어막이 꺼지면 침입해 훔치세요!")
end)
