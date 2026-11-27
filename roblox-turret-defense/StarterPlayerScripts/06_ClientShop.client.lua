--[[ ============================================================
  06_ClientShop.client.lua
  🍀 운빨·조합 터렛 디펜스 — 상점 UI (게임패스 6종 · 상품 14종 · 확률 공개)
  ------------------------------------------------------------
  붙여넣는 곳 : StarterPlayer > StarterPlayerScripts (LocalScript)
  여는 방법 : HUD 오른쪽 🛍 상점 버튼
  ※ 결제는 로블록스 기본 창(PromptGamePassPurchase / PromptProductPurchase)으로 진행합니다.
    가격·상품 구성은 ReplicatedStorage.TDShared 에서 읽어 옵니다.
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TD_Remotes")
local RD_Prompt = remotes:WaitForChild("TD_Prompt")

local uiBus = ReplicatedStorage:FindFirstChild("TD_UIBus")
if not uiBus then
	uiBus = Instance.new("Folder")
	uiBus.Name = "TD_UIBus"
	uiBus.Parent = ReplicatedStorage
end
local uiOpen = uiBus:FindFirstChild("Open")
if not uiOpen then
	uiOpen = Instance.new("BindableEvent")
	uiOpen.Name = "Open"
	uiOpen.Parent = uiBus
end

local C = {
	bg = Color3.fromRGB(10, 16, 22),
	panel = Color3.fromRGB(16, 26, 36),
	panel2 = Color3.fromRGB(27, 42, 54),
	line = Color3.fromRGB(70, 110, 132),
	cyan = Color3.fromRGB(79, 216, 255),
	green = Color3.fromRGB(92, 255, 176),
	gold = Color3.fromRGB(255, 201, 77),
	red = Color3.fromRGB(255, 95, 109),
	text = Color3.fromRGB(226, 240, 250),
	dim = Color3.fromRGB(150, 176, 194),
	disabled = Color3.fromRGB(60, 70, 78),
}
local FONT = Enum.Font.GothamBlack
local FONT2 = Enum.Font.GothamBold

local gui = Instance.new("ScreenGui")
gui.Name = "TD_Shop"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function frame(parent, size, pos, color, transparency, radius, zindex)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or C.panel
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.ZIndex = zindex or 1
	f.Parent = parent
	if radius ~= false then
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(0, radius or 8)
		u.Parent = f
	end
	return f
end

local function stroke(f, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or C.line
	s.Thickness = thickness or 1.5
	s.Transparency = 0.15
	s.Parent = f
	return s
end

local function label(parent, size, pos, text, color, font, zindex, align)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = color or C.text
	l.Font = font or FONT2
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.ZIndex = zindex or 2
	l.Parent = parent
	return l
end

local function button(parent, size, pos, text, color, zindex)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or C.panel2
	b.BorderSizePixel = 0
	b.Text = text or ""
	b.TextColor3 = C.text
	b.Font = FONT
	b.TextScaled = true
	b.AutoButtonColor = true
	b.ZIndex = zindex or 3
	b.Parent = parent
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, 8)
	u.Parent = b
	stroke(b, C.line, 1.2)
	return b
end

-- ---------------------------------------------------------------
-- 틀
-- ---------------------------------------------------------------
local layer = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(2, 6, 10), 0.35, false, 60)
layer.Visible = false
layer.Active = false

local card = frame(layer, UDim2.new(0.95, 0, 0.92, 0), UDim2.new(0.025, 0, 0.04, 0), C.panel, 0, 12, 61)
stroke(card, C.cyan, 1.5)

local title = label(card, UDim2.new(1, -110, 0, 30), UDim2.new(0, 12, 0, 8), "🛍 상점", C.cyan, FONT, 62)
local closeBtn = button(card, UDim2.new(0, 44, 0, 30), UDim2.new(1, -56, 0, 8), "✕", C.panel2, 62)
local gemText = label(card, UDim2.new(0, 130, 0, 20), UDim2.new(1, -200, 0, 14), "💠 0", C.gold, FONT2, 62, Enum.TextXAlignment.Right)

local tabRow = frame(card, UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 42), Color3.new(), 1, 6, 62)
local tabBtns, tabFrames = {}, {}
local TABS = { { key = "pass", text = "게임패스" }, { key = "product", text = "상품" }, { key = "odds", text = "확률 공개" } }
for i, t in ipairs(TABS) do
	local b = button(tabRow, UDim2.new(1 / 3, -4, 1, 0), UDim2.new((i - 1) / 3, 2, 0, 0), t.text, C.bg, 63)
	tabBtns[t.key] = b

	local sf = Instance.new("ScrollingFrame")
	sf.Size = UDim2.new(1, -24, 1, -86)
	sf.Position = UDim2.new(0, 12, 0, 80)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = C.line
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.ZIndex = 62
	sf.Visible = (i == 1)
	sf.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = sf

	tabFrames[t.key] = sf
end

local function selectTab(key)
	for _, t in ipairs(TABS) do
		local active = (t.key == key)
		tabBtns[t.key].BackgroundColor3 = active and C.panel2 or C.bg
		tabBtns[t.key].TextColor3 = active and C.cyan or C.dim
		tabFrames[t.key].Visible = active
	end
	if key == "product" then
		RD_Prompt:FireServer("pass_info")
	end
end
for _, t in ipairs(TABS) do
	tabBtns[t.key].MouseButton1Click:Connect(function() selectTab(t.key) end)
end

-- ---------------------------------------------------------------
-- 행 만들기 도우미
-- ---------------------------------------------------------------
local function makeRow(parent, height, order)
	local row = frame(parent, UDim2.new(1, -6, 0, height), UDim2.new(0, 0, 0, 0), C.panel2, 0.1, 8, 63)
	row.LayoutOrder = order
	stroke(row, C.line, 1)
	return row
end

-- ---------------------------------------------------------------
-- ① 게임패스 탭
-- ---------------------------------------------------------------
local passRows = {}
for i, pass in ipairs(Shared.PASSES) do
	local row = makeRow(tabFrames.pass, 76, i)
	local name = label(row, UDim2.new(0.62, -8, 0, 20), UDim2.new(0, 10, 0, 8), pass.name, C.text, FONT, 64)
	local desc = label(row, UDim2.new(0.62, -8, 0, 34), UDim2.new(0, 10, 0, 30), pass.desc, C.dim, FONT2, 64)
	desc.TextScaled = false
	desc.TextSize = 12
	desc.TextWrapped = true
	local price = label(row, UDim2.new(0.36, -8, 0, 16), UDim2.new(0.63, 4, 0, 8), "R$ " .. Shared.comma(pass.price), C.gold, FONT2, 64, Enum.TextXAlignment.Right)
	local buy = button(row, UDim2.new(0.36, -8, 0, 30), UDim2.new(0.63, 4, 0, 38), "구매", Color3.fromRGB(30, 70, 60), 64)
	buy.MouseButton1Click:Connect(function()
		RD_Prompt:FireServer("pass", pass.key)
	end)
	passRows[pass.key] = { btn = buy, price = price, row = row }
end

-- ---------------------------------------------------------------
-- ② 상품 탭
-- ---------------------------------------------------------------
local GROUP_TITLE = {
	impulse = "⚡ 저가 충동구매 (25~49 R$)",
	social = "🎁 팀 선물 · 소셜 과금 (49~79 R$)",
	bundle = "💠 패키지 · 고가 (79~799 R$)",
}
local productRows = {}
local order = 0
for _, groupKey in ipairs({ "impulse", "social", "bundle" }) do
	order = order + 1
	local head = frame(tabFrames.product, UDim2.new(1, -6, 0, 18), UDim2.new(0, 0, 0, 0), Color3.new(), 1, 4, 63)
	head.LayoutOrder = order
	label(head, UDim2.new(1, 0, 1, 0), UDim2.new(0, 2, 0, 0), GROUP_TITLE[groupKey], C.dim, FONT2, 64)

	for _, product in ipairs(Shared.PRODUCTS) do
		if product.group == groupKey then
			order = order + 1
			local row = makeRow(tabFrames.product, 74, order)
			local name = label(row, UDim2.new(0.64, -8, 0, 20), UDim2.new(0, 10, 0, 6), product.name, C.text, FONT, 64)
			local desc = label(row, UDim2.new(0.64, -8, 0, 30), UDim2.new(0, 10, 0, 28), product.desc, C.dim, FONT2, 64)
			desc.TextScaled = false
			desc.TextSize = 11
			desc.TextWrapped = true
			local price = label(row, UDim2.new(0.32, -8, 0, 14), UDim2.new(0.66, 4, 0, 6), "R$ " .. Shared.comma(product.price), C.gold, FONT2, 64, Enum.TextXAlignment.Right)
			local buy = button(row, UDim2.new(0.32, -8, 0, 28), UDim2.new(0.66, 4, 0, 38), "구매", Color3.fromRGB(30, 70, 60), 64)
			buy.MouseButton1Click:Connect(function()
				RD_Prompt:FireServer("product", product.key)
			end)
			local badge
			if product.badge then
				badge = label(row, UDim2.new(0.32, -8, 0, 12), UDim2.new(0.66, 4, 0, 24), product.badge, C.cyan, FONT2, 64, Enum.TextXAlignment.Right)
				badge.TextScaled = false
				badge.TextSize = 10
			end
			productRows[product.key] = { btn = buy, price = price, row = row, badge = badge, def = product }
		end
	end
end

-- ---------------------------------------------------------------
-- ③ 확률 공개 탭
-- ---------------------------------------------------------------
do
	local sf = tabFrames.odds
	local y = 0
	local function text(block, h, txt, color, size, order)
		local row = frame(sf, UDim2.new(1, -6, 0, h), UDim2.new(0, 0, 0, 0), C.panel2, 0.1, 8, 63)
		row.LayoutOrder = order
		local l = label(row, UDim2.new(1, -14, 1, -10), UDim2.new(0, 8, 0, 5), txt, color or C.text, FONT2, 64)
		l.TextScaled = false
		l.TextSize = size or 12
		l.TextWrapped = true
		return row
	end
	text(sf, 44, "🎲 터렛 뽑기 확률 (미네랄 " .. Shared.GACHA_COST .. " 소모)", C.cyan, 14, 1)
	for i = 1, 5 do
		local _, _, pct = Shared.tierOdds(player:GetAttribute("PassLuck") == true, false)
		text(sf, 26, Shared.TIER_NAMES[i] .. "   " .. string.format("%.2f%%", pct[i]), Shared.TIER_COLORS[i], 13, 1 + i)
	end
	text(sf, 76,
		"• 럭키 뽑기 패스 보유 시 전설·신화 확률이 1.8배로 오릅니다.\n"
		.. "• " .. Shared.PITY_BASE .. "회 안에 희귀 이상 1회 확정(천장), 패스 보유 시 " .. Shared.PITY_PASS .. "회.\n"
		.. "• 유물 '행운의 뽑기'를 얻으면 희귀 이상 확률이 추가로 오릅니다.",
		C.dim, 11, 8)
	text(sf, 96,
		"확률 표기는 결제성 재화로 뽑기를 이용할 수 있는 경우를 포함해 항상 공개됩니다. "
		.. "미네랄은 플레이(적 처치·웨이브)로 얻거나 보석 상품으로 구매할 수 있습니다. "
		.. "뽑기 결과는 서버에서 무작위로 결정되며, 표시된 확률은 등급별 가중치입니다.",
		C.dim, 11, 9)
	text(sf, 60,
		"⚠ 결제는 로블록스 계정 잔액(로벅스)으로만 이루어지며, 환불·청약철회는 로블록스 정책을 따릅니다. "
		.. "미성년자 결제는 보호자 동의가 필요합니다.",
		C.red, 11, 10)
end

-- ---------------------------------------------------------------
-- 상태 갱신
-- ---------------------------------------------------------------
local function refreshPasses()
	for _, pass in ipairs(Shared.PASSES) do
		local row = passRows[pass.key]
		if row then
			local owned = player:GetAttribute(pass.attr) == true
			if owned then
				row.btn.Text = "보유 중"
				row.btn.BackgroundColor3 = C.disabled
				row.btn.Active = false
				row.price.Text = "✔"
				row.price.TextColor3 = C.green
			elseif (pass.id or 0) <= 0 then
				row.btn.Text = "준비 중"
				row.btn.BackgroundColor3 = C.disabled
				row.btn.Active = false
			else
				row.btn.Text = "구매"
				row.btn.BackgroundColor3 = Color3.fromRGB(30, 70, 60)
				row.btn.Active = true
				row.price.Text = "R$ " .. Shared.comma(pass.price)
				row.price.TextColor3 = C.gold
			end
		end
	end
end

local function refreshProducts()
	for key, row in pairs(productRows) do
		local def = row.def
		if (def.id or 0) <= 0 then
			row.btn.Text = "준비 중"
			row.btn.BackgroundColor3 = C.disabled
		else
			row.btn.Text = "구매"
			row.btn.BackgroundColor3 = Color3.fromRGB(30, 70, 60)
		end
	end
	local starter = productRows["PRODUCT_STARTER"]
	if starter then
		local ends = player:GetAttribute("OfferEnds") or 0
		local left = ends - os.time()
		if left > 0 and (starter.def.id or 0) > 0 then
			starter.badge.Text = "⏰ " .. math.floor(left / 60) .. "분 " .. (left % 60) .. "초 남음"
			starter.badge.TextColor3 = C.red
		elseif starter.badge then
			starter.badge.Text = starter.def.badge or ""
			starter.badge.TextColor3 = C.cyan
		end
	end
end

local function refreshGems()
	gemText.Text = "💠 " .. Shared.comma(player:GetAttribute("Gems") or 0)
end

task.spawn(function()
	while true do
		task.wait(1)
		if layer.Visible then
			refreshProducts()
		end
	end
end)

for _, pass in ipairs(Shared.PASSES) do
	player:GetAttributeChangedSignal(pass.attr):Connect(refreshPasses)
end
player:GetAttributeChangedSignal("Gems"):Connect(refreshGems)

-- ---------------------------------------------------------------
-- 열기/닫기
-- ---------------------------------------------------------------
local function open(tab)
	layer.Visible = true
	card.Size = UDim2.new(0.95, 0, 0.2, 0)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.95, 0, 0.92, 0),
	}):Play()
	selectTab(tab or "pass")
	refreshPasses()
	refreshProducts()
	refreshGems()
	RD_Prompt:FireServer("pass_info")
end

local function close()
	layer.Visible = false
end

closeBtn.MouseButton1Click:Connect(close)
uiOpen.Event:Connect(function(what)
	if what == "shop" then
		open("pass")
	end
end)

refreshPasses()
refreshProducts()
refreshGems()

print("[TD] 06_ClientShop 준비 완료 — 패스 " .. #Shared.PASSES .. "종 · 상품 " .. #Shared.PRODUCTS .. "종")
