--[[ ============================================================
  07_ClientMeta.client.lua
  🍀 운빨·조합 터렛 디펜스 — 혜택 화면 (출석 · 체류 보상 · 일일 퀘스트 · 영구 강화)
  ------------------------------------------------------------
  붙여넣는 곳 : StarterPlayer > StarterPlayerScripts (LocalScript)
  여는 방법 : HUD 오른쪽 🎁 혜택 버튼
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TD_Remotes")
local RD_Meta = remotes:WaitForChild("TD_Meta")
local RD_Action = remotes:WaitForChild("TD_MetaAction")

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
	disabled = Color3.fromRGB(56, 66, 74),
}
local FONT = Enum.Font.GothamBlack
local FONT2 = Enum.Font.GothamBold

local gui = Instance.new("ScreenGui")
gui.Name = "TD_Meta"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 21
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
layer.Active = true

local card = frame(layer, UDim2.new(0.95, 0, 0.92, 0), UDim2.new(0.025, 0, 0.04, 0), C.panel, 0, 12, 61)
stroke(card, C.green, 1.5)

local title = label(card, UDim2.new(1, -150, 0, 30), UDim2.new(0, 12, 0, 8), "🎁 혜택 · 미션", C.green, FONT, 62)
local closeBtn = button(card, UDim2.new(0, 44, 0, 30), UDim2.new(1, -56, 0, 8), "✕", C.panel2, 62)
local gemText = label(card, UDim2.new(0, 120, 0, 20), UDim2.new(1, -186, 0, 14), "💠 0", C.gold, FONT2, 62, Enum.TextXAlignment.Right)

local tabRow = frame(card, UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 42), Color3.new(), 1, 6, 62)
local tabBtns, tabFrames = {}, {}
local TABS = { { key = "daily", text = "출석" }, { key = "play", text = "체류 보상" }, { key = "quest", text = "미션" }, { key = "up", text = "영구 강화" } }
for i, t in ipairs(TABS) do
	local b = button(tabRow, UDim2.new(0.25, -4, 1, 0), UDim2.new((i - 1) * 0.25, 2, 0, 0), t.text, C.bg, 63)
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
		tabBtns[t.key].TextColor3 = active and C.green or C.dim
		tabFrames[t.key].Visible = active
	end
end
for _, t in ipairs(TABS) do
	tabBtns[t.key].MouseButton1Click:Connect(function() selectTab(t.key) end)
end

-- ---------------------------------------------------------------
-- 상태
-- ---------------------------------------------------------------
local M = nil
local playRefs = {}
local baseClock = os.clock()
local baseSeconds = 0

local function clearFrame(sf)
	for _, child in ipairs(sf:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

local function makeRow(parent, height, order)
	local row = frame(parent, UDim2.new(1, -6, 0, height), UDim2.new(0, 0, 0, 0), C.panel2, 0.1, 8, 63)
	row.LayoutOrder = order
	stroke(row, C.line, 1)
	return row
end

local function sessionSeconds()
	return baseSeconds + (os.clock() - baseClock)
end

-- ---------------------------------------------------------------
-- 출석 탭
-- ---------------------------------------------------------------
local function renderDaily()
	local sf = tabFrames.daily
	clearFrame(sf)
	if not M then return end
	local head = makeRow(sf, 52, 1)
	label(head, UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 6), "📅 " .. (M.daily.streak or 0) .. "일 연속 출석", C.gold, FONT, 64)
	local sub = label(head, UDim2.new(1, -16, 0, 16), UDim2.new(0, 10, 0, 30), "매일 접속하면 보상이 커집니다 (한국 시간 자정 갱신)", C.dim, FONT2, 64)
	sub.TextScaled = false
	sub.TextSize = 11

	local grid = frame(sf, UDim2.new(1, -6, 0, 176), UDim2.new(0, 0, 0, 0), Color3.new(), 1, 6, 63)
	grid.LayoutOrder = 2
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.24, -4, 0, 52)
	gridLayout.CellPadding = UDim2.new(0, 4, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for i, reward in ipairs(M.daily.rewards or Shared.DAILY) do
		local cell = frame(grid, UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), C.bg, 0, 6, 64)
		cell.LayoutOrder = i
		local isToday = ((M.daily.index or 0) + 1) == i
		local done = (M.claimedToday and isToday) or ((i < ((M.daily.index or 0) + 1)))
		stroke(cell, isToday and C.gold or C.line, isToday and 2 or 1)
		local d = label(cell, UDim2.new(1, -6, 0, 12), UDim2.new(0, 3, 0, 4), (i) .. "일", isToday and C.gold or C.dim, FONT2, 65, Enum.TextXAlignment.Center)
		local r = label(cell, UDim2.new(1, -6, 0, 30), UDim2.new(0, 3, 0, 18), done and "✔" or reward.label, done and C.green or C.text, FONT2, 65, Enum.TextXAlignment.Center)
		r.TextScaled = false
		r.TextSize = 9
		r.TextWrapped = true
	end

	local claim = button(sf, UDim2.new(1, -6, 0, 46), UDim2.new(0, 0, 0, 0), "", C.panel2, 63)
	claim.LayoutOrder = 3
	if M.claimedToday then
		claim.Text = "오늘 출석 완료 ✔"
		claim.BackgroundColor3 = C.disabled
	else
		claim.Text = "오늘 출석 받기  (💠 " .. ((M.daily.rewards or Shared.DAILY)[math.clamp((M.daily.index or 0) + 1, 1, #Shared.DAILY)].gems or 0) .. ")"
		claim.BackgroundColor3 = Color3.fromRGB(30, 70, 60)
		claim.MouseButton1Click:Connect(function()
			RD_Action:FireServer("daily")
		end)
	end

	local info = makeRow(sf, 60, 4)
	local i2 = label(info, UDim2.new(1, -16, 1, -10), UDim2.new(0, 10, 0, 5),
		"보석은 '영구 강화'(시작 미네랄·공격력)에 쓰면 매 판이 편해집니다.\n7일 완주 보상은 보석 90 + 부활권 1.",
		C.dim, FONT2, 64)
	i2.TextScaled = false
	i2.TextSize = 11
	i2.TextWrapped = true
end

-- ---------------------------------------------------------------
-- 체류 보상 탭
-- ---------------------------------------------------------------
local function renderPlay()
	local sf = tabFrames.play
	clearFrame(sf)
	playRefs = {}
	if not M then return end
	local head = makeRow(sf, 48, 1)
	label(head, UDim2.new(1, -16, 0, 20), UDim2.new(0, 10, 0, 5), "⏱ 이번 접속 시간", C.green, FONT, 64)
	local timeLbl = label(head, UDim2.new(1, -16, 0, 16), UDim2.new(0, 10, 0, 26), "", C.text, FONT2, 64)
	timeLbl.TextScaled = false
	timeLbl.TextSize = 13
	playRefs.timeLbl = timeLbl

	for i, def in ipairs((M.playtime and M.playtime.list) or {}) do
		local row = makeRow(sf, 62, 1 + i)
		local name = label(row, UDim2.new(0.46, -8, 0, 18), UDim2.new(0, 10, 0, 6), "🎁 " .. def.label .. " 플레이", C.text, FONT, 64)
		local parts = {}
		if (def.minerals or 0) > 0 then table.insert(parts, "미네랄 " .. Shared.comma(def.minerals)) end
		if (def.gems or 0) > 0 then table.insert(parts, "보석 " .. Shared.comma(def.gems)) end
		if (def.revive or 0) > 0 then table.insert(parts, "부활권 " .. def.revive) end
		local sub = label(row, UDim2.new(0.46, -8, 0, 26), UDim2.new(0, 10, 0, 26), table.concat(parts, " · "), C.dim, FONT2, 64)
		sub.TextScaled = false
		sub.TextSize = 10
		sub.TextWrapped = true

		local btn = button(row, UDim2.new(0.5, -8, 0, 34), UDim2.new(0.48, 4, 0, 14), "", C.panel2, 64)
		btn.MouseButton1Click:Connect(function()
			RD_Action:FireServer("playtime", i)
		end)
		playRefs[i] = { btn = btn, def = def }
	end

	local note = makeRow(sf, 46, 9)
	local n = label(note, UDim2.new(1, -16, 1, -10), UDim2.new(0, 10, 0, 5),
		"접속 시간은 이번 세션 기준입니다. 나갔다 들어와도 오늘 받은 보상은 유지됩니다.", C.dim, FONT2, 64)
	n.TextScaled = false
	n.TextSize = 11
	n.TextWrapped = true
end

local function tickPlaytime()
	local secs = sessionSeconds()
	if playRefs.timeLbl then
		local m = math.floor(secs / 60)
		local s = math.floor(secs % 60)
		playRefs.timeLbl.Text = string.format("%d분 %02d초", m, s)
	end
	for i, ref in pairs(playRefs) do
		if type(i) == "number" and ref.btn then
			if ref.def.claimed then
				ref.btn.Text = "완료 ✔"
				ref.btn.BackgroundColor3 = C.disabled
			elseif secs >= ref.def.at then
				ref.btn.Text = "받기"
				ref.btn.BackgroundColor3 = Color3.fromRGB(30, 70, 60)
			else
				local left = math.ceil((ref.def.at - secs) / 60)
				ref.btn.Text = left .. "분 후"
				ref.btn.BackgroundColor3 = C.disabled
			end
		end
	end
end

-- ---------------------------------------------------------------
-- 미션 탭
-- ---------------------------------------------------------------
local function renderQuests()
	local sf = tabFrames.quest
	clearFrame(sf)
	if not M then return end
	local head = makeRow(sf, 44, 1)
	local h = label(head, UDim2.new(1, -16, 0, 18), UDim2.new(0, 10, 0, 5), "🎯 오늘의 미션 (매일 자정 갱신)", C.cyan, FONT, 64)
	h.TextScaled = false
	h.TextSize = 13
	local h2 = label(head, UDim2.new(1, -16, 0, 14), UDim2.new(0, 10, 0, 26), "완료하면 보석을 받습니다. 보석은 영구 강화에 사용", C.dim, FONT2, 64)
	h2.TextScaled = false
	h2.TextSize = 10

	for i, q in ipairs(M.quests or {}) do
		local row = makeRow(sf, 76, 1 + i)
		local name = label(row, UDim2.new(1, -110, 0, 20), UDim2.new(0, 10, 0, 6), q.text, C.text, FONT, 64)
		local prog = label(row, UDim2.new(1, -110, 0, 14), UDim2.new(0, 10, 0, 28), q.progress .. " / " .. q.goal, C.dim, FONT2, 64)
		prog.TextScaled = false
		prog.TextSize = 11
		local barBg = frame(row, UDim2.new(1, -120, 0, 8), UDim2.new(0, 10, 0, 46), C.bg, 0, 4, 64)
		local barFg = frame(barBg, UDim2.new(math.clamp(q.progress / math.max(1, q.goal), 0, 1), 0, 1, 0), UDim2.new(0, 0, 0, 0), q.claimed and C.dim or C.green, 0, 4, 64)

		local btn = button(row, UDim2.new(0, 96, 0, 32), UDim2.new(1, -104, 0, 20), "", C.panel2, 64)
		if q.claimed then
			btn.Text = "완료 ✔"
			btn.BackgroundColor3 = C.disabled
		elseif q.progress >= q.goal then
			btn.Text = "💠 " .. q.gems .. " 받기"
			btn.BackgroundColor3 = Color3.fromRGB(70, 60, 24)
			btn.MouseButton1Click:Connect(function()
				RD_Action:FireServer("quest", q.key)
			end)
		else
			btn.Text = "💠 " .. q.gems
			btn.BackgroundColor3 = C.disabled
		end
	end

	local foot = makeRow(sf, 40, 9)
	local f = label(foot, UDim2.new(1, -16, 1, -8), UDim2.new(0, 10, 0, 4),
		"퀘스트 진행은 판이 바뀌어도 오늘 하루 동안 누적됩니다.", C.dim, FONT2, 64)
	f.TextScaled = false
	f.TextSize = 10
	f.TextWrapped = true
end

-- ---------------------------------------------------------------
-- 영구 강화 탭
-- ---------------------------------------------------------------
local function renderUpgrades()
	local sf = tabFrames.up
	clearFrame(sf)
	if not M then return end
	local head = makeRow(sf, 44, 1)
	local h = label(head, UDim2.new(1, -16, 0, 18), UDim2.new(0, 10, 0, 5), "⚔ 영구 강화 — 매 판 시작부터 강해집니다", C.gold, FONT, 64)
	h.TextScaled = false
	h.TextSize = 12
	local h2 = label(head, UDim2.new(1, -16, 0, 14), UDim2.new(0, 10, 0, 26), "보유 💠 " .. Shared.comma(M.gems or 0), C.dim, FONT2, 64)
	h2.TextScaled = false
	h2.TextSize = 11

	for i, def in ipairs(Shared.UPGRADES) do
		local row = makeRow(sf, 80, 1 + i)
		local lvl = (M.upgrades and M.upgrades[def.key]) or 0
		local name = label(row, UDim2.new(1, -120, 0, 20), UDim2.new(0, 10, 0, 6), def.name .. "  Lv." .. lvl .. " / " .. def.max, C.text, FONT, 64)
		local desc = label(row, UDim2.new(1, -120, 0, 26), UDim2.new(0, 10, 0, 28), def.desc, C.dim, FONT2, 64)
		desc.TextScaled = false
		desc.TextSize = 10
		desc.TextWrapped = true

		local pips = frame(row, UDim2.new(1, -120, 0, 6), UDim2.new(0, 10, 0, 58), C.bg, 0, 3, 64)
		frame(pips, UDim2.new(lvl / def.max, 0, 1, 0), UDim2.new(0, 0, 0, 0), def.key == "permAtk" and C.red or C.cyan, 0, 3, 64)

		local cost = Shared.upgradeCost(def, lvl)
		local btn = button(row, UDim2.new(0, 106, 0, 36), UDim2.new(1, -114, 0, 22), "", C.panel2, 64)
		if lvl >= def.max then
			btn.Text = "MAX"
			btn.BackgroundColor3 = C.disabled
		else
			btn.Text = "💠 " .. Shared.comma(cost)
			btn.BackgroundColor3 = ((M.gems or 0) >= cost) and Color3.fromRGB(70, 60, 24) or C.disabled
			btn.MouseButton1Click:Connect(function()
				RD_Action:FireServer("upgrade", def.key)
			end)
		end
	end

	local foot = makeRow(sf, 64, 9)
	local f = label(foot, UDim2.new(1, -16, 1, -10), UDim2.new(0, 10, 0, 5),
		"보석은 출석·미션·체류 보상으로 무료로 모을 수 있고, 상점의 보석 팩으로도 채울 수 있습니다. "
		.. "강화는 계정에 저장되어 다음 판에도 유지됩니다.", C.dim, FONT2, 64)
	f.TextScaled = false
	f.TextSize = 10
	f.TextWrapped = true
end

local function renderAll()
	gemText.Text = "💠 " .. Shared.comma((M and M.gems) or 0)
	if not M then return end
	baseSeconds = (M.playtime and M.playtime.seconds) or 0
	baseClock = os.clock()
	renderDaily()
	renderPlay()
	renderQuests()
	renderUpgrades()
	tickPlaytime()
end

RD_Meta.OnClientEvent:Connect(function(d)
	if d.event == "meta" then
		M = d
		if layer.Visible then
			renderAll()
		end
	end
end)

RD_Action:FireServer("refresh")

task.spawn(function()
	while true do
		task.wait(1)
		if layer.Visible then
			tickPlaytime()
		end
	end
end)

-- ---------------------------------------------------------------
-- 열기/닫기
-- ---------------------------------------------------------------
local function open(tab)
	layer.Visible = true
	card.Size = UDim2.new(0.95, 0, 0.2, 0)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.95, 0, 0.92, 0),
	}):Play()
	selectTab(tab or "daily")
	RD_Action:FireServer("refresh")
	renderAll()
end

closeBtn.MouseButton1Click:Connect(function()
	layer.Visible = false
end)

uiOpen.Event:Connect(function(what)
	if what == "meta" then
		open("daily")
	end
end)

selectTab("daily")
print("[TD] 07_ClientMeta 준비 완료 — 출석 · 체류 보상 · 미션 · 영구 강화")
