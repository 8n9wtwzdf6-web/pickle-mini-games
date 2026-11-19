--=============================================================================
-- 03_TycoonHUD.client.lua
-- 위치 : StarterGui
-- 타입 : LocalScript
-- 역할 : 화면 좌측 상단 Cash · Launches 표시, 우측 상단 게임패스 구매 버튼,
--        발사 카운트다운 / 알림 메시지 표시 (UI는 코드로 전부 생성)
--
-- ※ 게임패스 ID는 이 스크립트가 아니라 01_PlayerDataAndPasses 의 CONFIG에서
--    설정합니다. 01이 ReplicatedStorage.RocketTycoonConfig 에 값을 넣어 주고
--    이 화면은 그 값을 읽어서 씁니다.
--=============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 리스폰/재실행 시 중복 생성 방지
local previous = playerGui:FindFirstChild("RocketTycoonHUD")
if previous ~= nil then
	previous:Destroy()
end

--=============================================================================
-- [1] 색상 · 도우미
--=============================================================================
local PALETTE = {
	panel = Color3.fromRGB(16, 20, 38),
	panelEdge = Color3.fromRGB(90, 120, 220),
	accent = Color3.fromRGB(255, 205, 90),
	text = Color3.fromRGB(238, 242, 255),
	subtext = Color3.fromRGB(165, 178, 210),
	green = Color3.fromRGB(120, 255, 165),
	rowNormal = Color3.fromRGB(30, 40, 74),
	rowOwned = Color3.fromRGB(26, 62, 44),
	rowOff = Color3.fromRGB(28, 34, 56),
}

local function formatMoney(value)
	local number = math.floor(tonumber(value) or 0)
	local text = tostring(number)
	local reversed = text:reverse()
	reversed = (reversed:gsub("(%d%d%d)", "%1,"))
	reversed = reversed:reverse()
	reversed = reversed:gsub("^,", "")
	return reversed
end

local function corner(parent, radius)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
	return uiCorner
end

local function stroke(parent, color, thickness)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = thickness or 1.5
	uiStroke.Transparency = 0.25
	uiStroke.Parent = parent
	return uiStroke
end

--=============================================================================
-- [2] HUD 기본 틀
--=============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RocketTycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

-- 좌측 상단: Cash / Launches 패널
local statsPanel = Instance.new("Frame")
statsPanel.Name = "StatsPanel"
statsPanel.Position = UDim2.new(0, 16, 0, 16)
statsPanel.Size = UDim2.new(0, 252, 0, 124)
statsPanel.BackgroundColor3 = PALETTE.panel
statsPanel.BackgroundTransparency = 0.12
statsPanel.BorderSizePixel = 0
statsPanel.Parent = screenGui
corner(statsPanel, 14)
stroke(statsPanel, PALETTE.panelEdge, 1.5)

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = statsPanel

local cashCaption = Instance.new("TextLabel")
cashCaption.Name = "CashCaption"
cashCaption.Position = UDim2.new(0, 0, 0, 0)
cashCaption.Size = UDim2.new(1, 0, 0, 16)
cashCaption.BackgroundTransparency = 1
cashCaption.Font = Enum.Font.GothamBold
cashCaption.TextSize = 12
cashCaption.TextXAlignment = Enum.TextXAlignment.Left
cashCaption.TextColor3 = PALETTE.subtext
cashCaption.Text = "CASH  (보유 금액)"
cashCaption.Parent = statsPanel

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashValue"
cashLabel.Position = UDim2.new(0, 0, 0, 16)
cashLabel.Size = UDim2.new(1, 0, 0, 42)
cashLabel.BackgroundTransparency = 1
cashLabel.Font = Enum.Font.GothamBlack
cashLabel.TextSize = 34
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.TextColor3 = PALETTE.accent
cashLabel.Text = "$0"
cashLabel.Parent = statsPanel

local launchesLabel = Instance.new("TextLabel")
launchesLabel.Name = "LaunchesValue"
launchesLabel.Position = UDim2.new(0, 0, 0, 60)
launchesLabel.Size = UDim2.new(1, 0, 0, 24)
launchesLabel.BackgroundTransparency = 1
launchesLabel.Font = Enum.Font.GothamBold
launchesLabel.TextSize = 18
launchesLabel.TextXAlignment = Enum.TextXAlignment.Left
launchesLabel.TextColor3 = PALETTE.text
launchesLabel.Text = "발사 0회"
launchesLabel.Parent = statsPanel

local ownerLabel = Instance.new("TextLabel")
ownerLabel.Name = "OwnerStatus"
ownerLabel.Position = UDim2.new(0, 0, 0, 86)
ownerLabel.Size = UDim2.new(1, 0, 0, 18)
ownerLabel.BackgroundTransparency = 1
ownerLabel.Font = Enum.Font.Gotham
ownerLabel.TextSize = 13
ownerLabel.TextXAlignment = Enum.TextXAlignment.Left
ownerLabel.TextColor3 = PALETTE.subtext
ownerLabel.Text = "기지: 미보유 — ClaimPad 터치"
ownerLabel.Parent = statsPanel

-- 우측 상단: 게임패스 패널
local passPanel = Instance.new("Frame")
passPanel.Name = "PassPanel"
passPanel.AnchorPoint = Vector2.new(1, 0)
passPanel.Position = UDim2.new(1, -16, 0, 16)
passPanel.Size = UDim2.new(0, 236, 0, 0)
passPanel.AutomaticSize = Enum.AutomaticSize.Y
passPanel.BackgroundColor3 = PALETTE.panel
passPanel.BackgroundTransparency = 0.12
passPanel.BorderSizePixel = 0
passPanel.Parent = screenGui
corner(passPanel, 14)
stroke(passPanel, PALETTE.panelEdge, 1.5)

local passPadding = Instance.new("UIPadding")
passPadding.PaddingLeft = UDim.new(0, 12)
passPadding.PaddingRight = UDim.new(0, 12)
passPadding.PaddingTop = UDim.new(0, 10)
passPadding.PaddingBottom = UDim.new(0, 10)
passPadding.Parent = passPanel

local passLayout = Instance.new("UIListLayout")
passLayout.FillDirection = Enum.FillDirection.Vertical
passLayout.Padding = UDim.new(0, 8)
passLayout.SortOrder = Enum.SortOrder.LayoutOrder
passLayout.Parent = passPanel

local passTitle = Instance.new("TextLabel")
passTitle.Name = "PassTitle"
passTitle.LayoutOrder = 1
passTitle.Size = UDim2.new(1, 0, 0, 18)
passTitle.BackgroundTransparency = 1
passTitle.Font = Enum.Font.GothamBold
passTitle.TextSize = 13
passTitle.TextXAlignment = Enum.TextXAlignment.Left
passTitle.TextColor3 = PALETTE.subtext
passTitle.Text = "게임패스"
passTitle.Parent = passPanel

--=============================================================================
-- [3] 알림(토스트) · 카운트다운 (다른 곳에서 쓰므로 먼저 정의)
--=============================================================================
local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "Toast"
toastLabel.AnchorPoint = Vector2.new(0.5, 1)
toastLabel.Position = UDim2.new(0.5, 0, 1, -28)
toastLabel.Size = UDim2.new(0.8, 0, 0, 50)
toastLabel.BackgroundColor3 = Color3.fromRGB(10, 14, 28)
toastLabel.BackgroundTransparency = 1
toastLabel.BorderSizePixel = 0
toastLabel.Font = Enum.Font.GothamBold
toastLabel.TextSize = 18
toastLabel.TextWrapped = true
toastLabel.TextColor3 = PALETTE.text
toastLabel.TextTransparency = 1
toastLabel.Text = ""
toastLabel.Parent = screenGui
corner(toastLabel, 12)

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "Countdown"
countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
countdownLabel.Position = UDim2.new(0.5, 0, 0.34, 0)
countdownLabel.Size = UDim2.new(0, 620, 0, 150)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextScaled = true
countdownLabel.TextColor3 = Color3.fromRGB(255, 236, 170)
countdownLabel.TextStrokeTransparency = 0.25
countdownLabel.TextStrokeColor3 = Color3.fromRGB(90, 40, 10)
countdownLabel.TextTransparency = 1
countdownLabel.Text = ""
countdownLabel.Parent = screenGui

local toastToken = 0

local function showToast(text)
	if text == nil or text == "" then
		return
	end
	toastToken = toastToken + 1
	local token = toastToken
	toastLabel.Text = tostring(text)
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.25
	task.delay(2.6, function()
		if token ~= toastToken then
			return
		end
		TweenService:Create(toastLabel, TweenInfo.new(0.35), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	end)
end

local countdownToken = 0

local function showCountdown(text)
	countdownToken = countdownToken + 1
	local token = countdownToken
	countdownLabel.Text = tostring(text)
	countdownLabel.TextTransparency = 0
	countdownLabel.Size = UDim2.new(0, 620, 0, 150)
	if text == "발사!" then
		countdownLabel.TextColor3 = Color3.fromRGB(255, 150, 90)
	else
		countdownLabel.TextColor3 = Color3.fromRGB(255, 236, 170)
	end
	TweenService:Create(countdownLabel, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 460, 0, 120),
	}):Play()
	task.delay(0.85, function()
		if token ~= countdownToken then
			return
		end
		TweenService:Create(countdownLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

--=============================================================================
-- [4] 상태값 연결 (leaderstats)
--=============================================================================
local cashValue = nil
local launchesValue = nil

local function flashCash()
	cashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TweenService:Create(cashLabel, TweenInfo.new(0.45), { TextColor3 = PALETTE.accent }):Play()
end

local function updateCash()
	if cashValue == nil then
		return
	end
	cashLabel.Text = "$" .. formatMoney(cashValue.Value)
end

local function updateLaunches()
	if launchesValue == nil then
		return
	end
	launchesLabel.Text = "발사 " .. tostring(math.floor(launchesValue.Value)) .. "회"
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 40)
	if stats == nil then
		return
	end
	cashValue = stats:WaitForChild("Cash", 20)
	launchesValue = stats:WaitForChild("Launches", 20)
	if cashValue ~= nil then
		updateCash()
		local lastCash = cashValue.Value
		cashValue:GetPropertyChangedSignal("Value"):Connect(function()
			local newCash = cashValue.Value
			if newCash > lastCash then
				flashCash()
			end
			lastCash = newCash
			updateCash()
		end)
	end
	if launchesValue ~= nil then
		updateLaunches()
		launchesValue:GetPropertyChangedSignal("Value"):Connect(updateLaunches)
	end
end)

local function updateOwnerStatus()
	if player:GetAttribute("TycoonOwner") == true then
		ownerLabel.Text = "기지: 내 기지 운영 중"
		ownerLabel.TextColor3 = PALETTE.green
	else
		ownerLabel.Text = "기지: 미보유 — ClaimPad 터치"
		ownerLabel.TextColor3 = PALETTE.subtext
	end
end
updateOwnerStatus()
player:GetAttributeChangedSignal("TycoonOwner"):Connect(updateOwnerStatus)

--=============================================================================
-- [5] 게임패스 버튼 (ID는 01 스크립트의 CONFIG에서 설정)
--=============================================================================
local configFolder = ReplicatedStorage:WaitForChild("RocketTycoonConfig", 30)
local doubleCashId = 0
local autoCollectId = 0
if configFolder ~= nil then
	doubleCashId = tonumber(configFolder:GetAttribute("DoubleCashPassId")) or 0
	autoCollectId = tonumber(configFolder:GetAttribute("AutoCollectPassId")) or 0
end

local passRows = {}

local function getPassPrice(passId)
	if passId <= 0 then
		return nil
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if ok and info ~= nil and info.PriceInRobux ~= nil then
		return tonumber(info.PriceInRobux)
	end
	return nil
end

local function refreshPassRow(attributeName)
	local row = passRows[attributeName]
	if row == nil then
		return
	end
	local owned = player:GetAttribute(attributeName) == true
	if row.PassId <= 0 then
		row.Button.Text = row.Title .. "\n게임패스 미설정"
		row.Button.TextColor3 = PALETTE.subtext
		row.Button.BackgroundColor3 = PALETTE.rowOff
	elseif owned then
		row.Button.Text = row.Title .. "\n보유 중 · 적용됨"
		row.Button.TextColor3 = PALETTE.green
		row.Button.BackgroundColor3 = PALETTE.rowOwned
	else
		local price = getPassPrice(row.PassId)
		local priceText = "R$ ?"
		if price ~= nil then
			if price <= 0 then
				priceText = "무료"
			else
				priceText = "R$ " .. formatMoney(price)
			end
		end
		row.Button.Text = row.Title .. "\n구매  " .. priceText
		row.Button.TextColor3 = PALETTE.text
		row.Button.BackgroundColor3 = PALETTE.rowNormal
	end
end

local function makePassRow(order, title, passId, attributeName, description)
	local button = Instance.new("TextButton")
	button.Name = "Pass_" .. tostring(order)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 50)
	button.BackgroundColor3 = PALETTE.rowNormal
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextWrapped = true
	button.TextColor3 = PALETTE.text
	button.Text = title .. "\n" .. description
	button.Parent = passPanel
	corner(button, 10)
	stroke(button, Color3.fromRGB(110, 145, 240), 1)

	passRows[attributeName] = {
		Button = button,
		Title = title,
		PassId = passId,
	}

	local lastClick = 0
	button.MouseButton1Click:Connect(function()
		if os.clock() - lastClick < 1 then
			return
		end
		lastClick = os.clock()
		if passId <= 0 then
			showToast("게임패스 ID가 아직 설정되지 않았습니다. (README 5장 참고)")
			return
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end)
		if not ok then
			showToast("게임패스 구매 창을 열 수 없습니다: " .. tostring(err))
		end
	end)

	return button
end

makePassRow(2, "2배 수익", doubleCashId, "HasDoubleCash", "모든 광석 판매가 2배")
makePassRow(3, "자동 수거", autoCollectId, "HasAutoCollect", "수거함을 자동으로 정산")

for attributeName in pairs(passRows) do
	refreshPassRow(attributeName)
end

player:GetAttributeChangedSignal("HasDoubleCash"):Connect(function()
	refreshPassRow("HasDoubleCash")
end)
player:GetAttributeChangedSignal("HasAutoCollect"):Connect(function()
	refreshPassRow("HasAutoCollect")
end)

--=============================================================================
-- [6] 서버 알림 연결
--=============================================================================
local notifyEvent = ReplicatedStorage:WaitForChild("RocketTycoonNotify", 30)
if notifyEvent ~= nil then
	notifyEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.kind == "countdown" then
			showCountdown(payload.text)
		else
			showToast(payload.text)
		end
	end)
end

task.delay(2, function()
	if player:GetAttribute("TycoonOwner") ~= true then
		showToast("초록색 ClaimPad를 터치해서 내 기지를 시작하세요!")
	end
end)

print("[RocketTycoon:HUD] 화면 준비 완료")
