--[[ ============================================================
  04_ClientHUD.client.lua
  🍀 운빨·조합 터렛 디펜스 — 모바일/PC 공용 HUD
  ------------------------------------------------------------
  붙여넣는 곳 : StarterPlayer > StarterPlayerScripts (LocalScript)
  하는 일
    · 고정 쿼터뷰 카메라 (PC·모바일 동일)
    · 상단: 웨이브 · 넥서스 HP · 미네랄 · 가스 / 4인 파티 현황
    · 하단: 뽑기 · 합성 · 공격력 · 공속 · 지원 작전
    · 내 라인 4칸(등급 색) · 합성 가능 표시
    · 유물 3지선다 · 승리/패배 화면 · 토스트/배너
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TD_Remotes")
local RD = {
	Draw = remotes:WaitForChild("TD_Draw"),
	Merge = remotes:WaitForChild("TD_Merge"),
	Upgrade = remotes:WaitForChild("TD_Upgrade"),
	Support = remotes:WaitForChild("TD_Support"),
	State = remotes:WaitForChild("TD_State"),
	Toast = remotes:WaitForChild("TD_Toast"),
	Banner = remotes:WaitForChild("TD_Banner"),
	Relic = remotes:WaitForChild("TD_Relic"),
	PickRelic = remotes:WaitForChild("TD_PickRelic"),
}

-- ---------------------------------------------------------------
-- 카메라 (쿼터뷰 고정)
-- ---------------------------------------------------------------
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 52
local camPos = Vector3.new(0, 74, 62)
local camLook = Vector3.new(0, 0, -4)
camera.CFrame = CFrame.lookAt(camPos, camLook)

task.spawn(function()
	while true do
		task.wait(0.2)
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		if camera.CFrame.Position ~= camPos then
			camera.CFrame = CFrame.lookAt(camPos, camLook)
		end
	end
end)

-- ---------------------------------------------------------------
-- 팔레트
-- ---------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(10, 16, 22),
	panel = Color3.fromRGB(18, 30, 40),
	panel2 = Color3.fromRGB(27, 42, 54),
	line = Color3.fromRGB(70, 110, 132),
	cyan = Color3.fromRGB(79, 216, 255),
	green = Color3.fromRGB(92, 255, 176),
	gold = Color3.fromRGB(255, 201, 77),
	violet = Color3.fromRGB(176, 123, 255),
	pink = Color3.fromRGB(255, 91, 209),
	red = Color3.fromRGB(255, 95, 109),
	text = Color3.fromRGB(226, 240, 250),
	dim = Color3.fromRGB(150, 176, 194),
}
local FONT = Enum.Font.GothamBlack
local FONT2 = Enum.Font.GothamBold
local TIER_COLORS = {
	Color3.fromRGB(184, 198, 210),
	Color3.fromRGB(62, 155, 255),
	Color3.fromRGB(169, 115, 255),
	Color3.fromRGB(255, 194, 77),
	Color3.fromRGB(255, 91, 209),
}
local TIER_NAMES = { "일반", "희귀", "영웅", "전설", "신화" }

-- ---------------------------------------------------------------
-- UI 헬퍼
-- ---------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TD_HUD"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function frame(parent, size, pos, color, transparency, radius)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or C.panel
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
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

local function label(parent, size, pos, text, color, font, scaled)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = color or C.text
	l.Font = font or FONT2
	l.TextScaled = scaled ~= false
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent, size, pos, text, color)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or C.panel2
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = C.text
	b.Font = FONT
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Parent = parent
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, 8)
	u.Parent = b
	stroke(b, C.line, 1.5)
	return b
end

local function gradient(f, color1, color2, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(color1, color2)
	g.Rotation = rotation or 90
	g.Parent = f
	return g
end

-- ---------------------------------------------------------------
-- 상단 HUD
-- ---------------------------------------------------------------
local top = frame(gui, UDim2.new(1, -16, 0, 100), UDim2.new(0, 8, 0, 8), C.panel, 0.06, 10)
stroke(top, C.cyan, 1)
gradient(top, Color3.fromRGB(30, 46, 58), Color3.fromRGB(10, 16, 22), 90)

-- 웨이브
local waveBox = frame(top, UDim2.new(0, 96, 0, 40), UDim2.new(0, 8, 0, 8), C.bg, 0.2, 6)
stroke(waveBox, C.line, 1)
label(waveBox, UDim2.new(1, -12, 0, 12), UDim2.new(0, 6, 0, 4), "WAVE", C.green, FONT2)
local waveLabel = label(waveBox, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 15), "1 / 20", C.text, FONT)

-- 넥서스 HP
local coreBox = frame(top, UDim2.new(1, -220, 0, 40), UDim2.new(0, 112, 0, 8), C.bg, 0.2, 6)
stroke(coreBox, C.line, 1)
label(coreBox, UDim2.new(0, 74, 0, 14), UDim2.new(0, 8, 0, 3), "NEXUS", C.cyan, FONT2)
local coreText = label(coreBox, UDim2.new(0, 80, 0, 14), UDim2.new(0.56, 0, 0, 3), "30 / 30", C.text, FONT2)
local coreBarBg = frame(coreBox, UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 21), Color3.fromRGB(8, 12, 16), 0, 4)
local coreBar = frame(coreBarBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.green, 0, 4)
gradient(coreBar, Color3.fromRGB(90, 255, 170), Color3.fromRGB(255, 201, 77), 0)

-- 미네랄 / 가스
local minBox = frame(top, UDim2.new(0, 90, 0, 40), UDim2.new(1, -198, 0, 8), C.bg, 0.2, 6)
stroke(minBox, C.line, 1)
label(minBox, UDim2.new(1, -12, 0, 12), UDim2.new(0, 6, 0, 4), "💎 미네랄", C.dim, FONT2)
local minLabel = label(minBox, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 15), "100", C.text, FONT)

local gasBox = frame(top, UDim2.new(0, 90, 0, 40), UDim2.new(1, -102, 0, 8), C.bg, 0.2, 6)
stroke(gasBox, C.line, 1)
label(gasBox, UDim2.new(1, -12, 0, 12), UDim2.new(0, 6, 0, 4), "⛽ 가스", C.dim, FONT2)
local gasLabel = label(gasBox, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 15), "30", C.green, FONT)

-- 상태 줄 (웨이브 대기/보스/내 라인)
local statusLabel = label(top, UDim2.new(1, -16, 0, 18), UDim2.new(0, 10, 0, 52), "", C.dim, FONT2)

-- 파티 칩 4개
local partyRow = frame(top, UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 72), Color3.new(), 1, 6)
local partyChips = {}
for lane = 1, 4 do
	local chip = frame(partyRow, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.25 * (lane - 1), 2, 0, 0), C.bg, 0.25, 5)
	stroke(chip, C.line, 1)
	local dot = frame(chip, UDim2.new(0, 7, 0, 7), UDim2.new(0, 5, 0.5, -3), C.cyan, 0, 4)
	local nameLabel = label(chip, UDim2.new(1, -46, 0, 11),					UDim2.new(0, 15, 0, 3), "P1", C.text, FONT2)
	local sub = label(chip, UDim2.new(1, -46, 0, 9), UDim2.new(0, 15, 0, 13), "0/4", C.dim, FONT2)
	local dpsLabel = label(chip, UDim2.new(0, 40, 0, 11), UDim2.new(1, -42, 0, 12), "", C.dim, FONT2)
	partyChips[lane] = { chip = chip, dot = dot, nameLabel = nameLabel, sub = sub, dpsLabel = dpsLabel }
end

-- ---------------------------------------------------------------
-- 하단 조작
-- ---------------------------------------------------------------
local bottom = frame(gui, UDim2.new(1, -16, 0, 116), UDim2.new(0, 8, 1, -124), C.panel, 0.06, 10)
stroke(bottom, C.line, 1)
gradient(bottom, Color3.fromRGB(24, 38, 50), Color3.fromRGB(8, 14, 19), 90)

local drawBtn = button(bottom, UDim2.new(0.42, -6, 0, 52), UDim2.new(0, 6, 0, 6), "", Color3.fromRGB(23, 65, 79))
local drawTitle = label(drawBtn, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 5), "🔮 랜덤 뽑기", Color3.fromRGB(215, 248, 255), FONT)
local drawSub = label(drawBtn, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, 31), "💎 18", Color3.fromRGB(170, 220, 235), FONT2)

local mergeBtn = button(bottom, UDim2.new(0.29, -6, 0, 52), UDim2.new(0.42, 2, 0, 6), "", Color3.fromRGB(61, 50, 24))
local mergeTitle = label(mergeBtn, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 5), "⚡ 합성 진화", Color3.fromRGB(255, 231, 163), FONT)
local mergeSub = label(mergeBtn, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, 31), "가능 0쌍", Color3.fromRGB(230, 200, 130), FONT2)

local supportBtn = button(bottom, UDim2.new(0.29, -6, 0, 52), UDim2.new(0.71, 2, 0, 6), "", Color3.fromRGB(40, 34, 60))
local supportTitle = label(supportBtn, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 5), "🎯 지원 작전", Color3.fromRGB(226, 210, 255), FONT)
local supportSub = label(supportBtn, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, 31), "폭격·수리", Color3.fromRGB(190, 175, 235), FONT2)

local atkBtn = button(bottom, UDim2.new(0.32, -4, 0, 44), UDim2.new(0, 6, 0, 62), "")
local atkTitle = label(atkBtn, UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 3), "⚔ 공격력 Lv.0", C.text, FONT2)
local atkSub = label(atkBtn, UDim2.new(1, -10, 0, 14), UDim2.new(0, 5, 0, 22), "⛽ 25", C.green, FONT2)

local spdBtn = button(bottom, UDim2.new(0.32, -4, 0, 44), UDim2.new(0.32, 2, 0, 62), "")
local spdTitle = label(spdBtn, UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 3), "⚡ 공속 Lv.0", C.text, FONT2)
local spdSub = label(spdBtn, UDim2.new(1, -10, 0, 14), UDim2.new(0, 5, 0, 22), "⛽ 30", C.green, FONT2)

local padRow = frame(bottom, UDim2.new(0.36, -4, 0, 44), UDim2.new(0.64, 2, 0, 62), C.bg, 0.3, 6)
stroke(padRow, C.line, 1)
local padCells = {}
for i = 1, 5 do
	local cell = frame(padRow, UDim2.new(0.2, -3, 1, -8), UDim2.new(0.2 * (i - 1), 2, 0, 4), Color3.fromRGB(26, 36, 45), 0, 4)
	stroke(cell, C.line, 1)
	local t = label(cell, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 0.5, -6), "", C.text, FONT2)
	t.TextXAlignment = Enum.TextXAlignment.Center
	padCells[i] = { cell = cell, label = t }
end

-- ---------------------------------------------------------------
-- 토스트 / 배너 / 유물 / 결과
-- ---------------------------------------------------------------
local toast = frame(gui, UDim2.new(0, 260, 0, 56), UDim2.new(0.5, -130, 0, 116), C.bg, 0.08, 8)
stroke(toast, C.cyan, 1.5)
toast.Visible = false
local toastTitle = label(toast, UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 5), "", C.text, FONT)
toastTitle.TextXAlignment = Enum.TextXAlignment.Center
local toastSub = label(toast, UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 32), "", C.dim, FONT2)
toastSub.TextXAlignment = Enum.TextXAlignment.Center

local banner = label(gui, UDim2.new(1, 0, 0, 46), UDim2.new(0, 0, 0.3, 0), "", C.gold, FONT)
banner.TextXAlignment = Enum.TextXAlignment.Center
banner.TextTransparency = 1
banner.TextStrokeTransparency = 0.6

local relicLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 6, 10), 0.35, false)
relicLayer.Visible = false
local relicCard = frame(relicLayer, UDim2.new(0, 320, 0, 330), UDim2.new(0.5, -160, 0.5, -165), C.panel, 0, 10)
stroke(relicCard, C.gold, 2)
local relicTitle = label(relicCard, UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 12), "보스 처치! 유물을 선택하세요", C.gold, FONT)
relicTitle.TextXAlignment = Enum.TextXAlignment.Center
local relicButtons = {}
for i = 1, 3 do
	local b = button(relicCard, UDim2.new(1, -20, 0, 74), UDim2.new(0, 10, 0, 50 + (i - 1) * 84), "")
	b.Text = ""
	local nm = label(b, UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 12), "", C.text, FONT)
	local ds = label(b, UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 38), "", C.dim, FONT2)
	relicButtons[i] = { btn = b, name = nm, desc = ds }
end

local resultLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 6, 10), 0.2, false)
resultLayer.Visible = false
local resultCard = frame(resultLayer, UDim2.new(0, 300, 0, 200), UDim2.new(0.5, -150, 0.5, -100), C.panel, 0, 10)
stroke(resultCard, C.cyan, 2)
local resultTitle = label(resultCard, UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 20), "", C.text, FONT)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
local resultSub = label(resultCard, UDim2.new(1, -20, 0, 60), UDim2.new(0, 10, 0, 66), "", C.dim, FONT2)
resultSub.TextXAlignment = Enum.TextXAlignment.Center
resultSub.TextWrapped = true

-- ---------------------------------------------------------------
-- 버튼 연결
-- ---------------------------------------------------------------
drawBtn.MouseButton1Click:Connect(function() RD.Draw:FireServer() end)
mergeBtn.MouseButton1Click:Connect(function() RD.Merge:FireServer() end)
atkBtn.MouseButton1Click:Connect(function() RD.Upgrade:FireServer("atk") end)
spdBtn.MouseButton1Click:Connect(function() RD.Upgrade:FireServer("spd") end)
supportBtn.MouseButton1Click:Connect(function() RD.Support:FireServer("strike") end)

for i = 1, 3 do
	relicButtons[i].btn.MouseButton1Click:Connect(function()
		RD.PickRelic:FireServer(i)
	end)
end

-- ---------------------------------------------------------------
-- 상태 반영
-- ---------------------------------------------------------------
local S = {
	minerals = 0, gas = 0, wave = 0, core = 30, coreMax = 30,
	atkLv = 0, spdLv = 0, mergeable = 0, lane = 1, timer = 0,
	waveActive = false, particles = {},
}

local function setText(lbl, txt, color)
	lbl.Text = txt
	if color then lbl.TextColor3 = color end
end

local function refreshButtons()
	setText(drawSub, "💎 18 · " .. (S.minerals >= 18 and "가능" or "부족"), S.minerals >= 18 and Color3.fromRGB(170, 220, 235) or C.red)
	setText(mergeSub, S.mergeable > 0 and (S.mergeable .. "쌍 합성 가능!") or "가능 0쌍", S.mergeable > 0 and C.gold or Color3.fromRGB(150, 150, 130))
	mergeBtn.BackgroundColor3 = S.mergeable > 0 and Color3.fromRGB(92, 74, 30) or Color3.fromRGB(61, 50, 24)
	setText(atkTitle, "⚔ 공격력 Lv." .. S.atkLv)
	setText(atkSub, "⛽ " .. (25 + S.atkLv * 12), S.gas >= (25 + S.atkLv * 12) and C.green or C.red)
	setText(spdTitle, "⚡ 공속 Lv." .. S.spdLv)
	setText(spdSub, "⛽ " .. (30 + S.spdLv * 14), S.gas >= (30 + S.spdLv * 14) and C.green or C.red)
end

local function applyState(d)
	S.minerals = d.minerals or S.minerals
	S.gas = d.gas or S.gas
	S.wave = d.wave or S.wave
	S.core = d.core or S.core
	S.coreMax = d.coreMax or S.coreMax
	S.atkLv = d.atkLv or S.atkLv
	S.spdLv = d.spdLv or S.spdLv
	S.mergeable = d.mergeable or 0
	S.lane = d.lane or S.lane
	S.waveActive = d.waveActive
	S.timer = d.timer or 0

	setText(waveLabel, S.wave .. " / 20")
	setText(minLabel, tostring(math.floor(S.minerals)))
	setText(gasLabel, tostring(math.floor(S.gas)))
	setText(coreText, S.core .. " / " .. S.coreMax)
	local frac = math.clamp(S.core / math.max(1, S.coreMax), 0, 1)
	coreBar.Size = UDim2.new(frac, 0, 1, 0)
	coreBar.BackgroundColor3 = frac > 0.5 and C.green or (frac > 0.25 and C.gold or C.red)

	if d.party then
		for lane = 1, 4 do
			local p = d.party[lane]
			local chip = partyChips[lane]
			if p and chip then
				chip.dot.BackgroundColor3 = (lane == S.lane) and C.gold or C.cyan
				chip.nameLabel.Text = (lane == S.lane) and "나 · " .. tostring(p.name) or tostring(p.name)
				chip.sub.Text = p.ai and ("AI · " .. p.turrets .. "/4") or (p.turrets .. "/4")
				chip.dpsLabel.Text = p.dps > 0 and (p.dps .. " DPS") or ""
				chip.dpsLabel.TextColor3 = C.dim
			end
		end
	end

	if d.pads then
		for i = 1, 5 do
			local cell = padCells[i]
			local pd = d.pads[i]
			if cell then
				if pd and pd.tier and pd.tier > 0 then
					cell.cell.BackgroundColor3 = TIER_COLORS[pd.tier]
					cell.label.Text = (pd.star and pd.star > 0) and ("★" .. pd.star) or ("T" .. pd.tier)
					cell.label.TextColor3 = Color3.fromRGB(10, 16, 22)
				elseif pd and pd.locked then
					cell.cell.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
					cell.label.Text = "VIP"
					cell.label.TextColor3 = Color3.fromRGB(120, 120, 120)
				else
					cell.cell.BackgroundColor3 = Color3.fromRGB(26, 36, 45)
					cell.label.Text = ""
				end
			end
		end
	end

	local st = ""
	if d.coreHit then st = "넥서스 피격!" end
	if S.waveActive then
		st = "진행 중 · W" .. S.wave
	else
		st = "다음 웨이브 " .. S.timer .. "초"
	end
	setText(statusLabel, st .. "   ·   내 라인 P" .. S.lane, C.dim)
	refreshButtons()
end

RD.State.OnClientEvent:Connect(function(d)
	if d.event == "state" then
		applyState(d)
	elseif d.event == "assigned" then
		S.lane = d.lane
	elseif d.event == "coreHit" then
		S.core = d.core or S.core
		setText(statusLabel, "넥서스 피격! " .. S.core .. " / " .. S.coreMax, C.red)
	elseif d.event == "win" then
		resultLayer.Visible = true
		setText(resultTitle, "🏆 임무 성공!", C.cyan)
		setText(resultSub, "20웨이브를 모두 막아냈습니다!\n다시 하려면 서버를 나갔다 들어오세요.", C.text)
	elseif d.event == "lose" then
		resultLayer.Visible = true
		setText(resultTitle, "코어 붕괴", C.red)
		setText(resultSub, "도달 웨이브 " .. (d.wave or S.wave) .. ".\n터렛을 합성하고 지원 작전을 쓰세요.", C.text)
	elseif d.event == "relicDone" then
		relicLayer.Visible = false
	end
end)

RD.Toast.OnClientEvent:Connect(function(title, sub)
	setText(toastTitle, title, C.text)
	setText(toastSub, sub or "", C.dim)
	toast.Visible = true
	toast.BackgroundTransparency = 0.08
	task.delay(1.6, function()
		if toast.Visible then toast.Visible = false end
	end)
end)

RD.Banner.OnClientEvent:Connect(function(title, sub)
	banner.Text = title .. (sub and ("\n" .. sub) or "")
	banner.TextTransparency = 0
	banner.TextColor3 = C.gold
	task.delay(1.8, function()
		TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	end)
end)

RD.Relic.OnClientEvent:Connect(function(picks)
	for i = 1, 3 do
		local p = picks[i]
		local rb = relicButtons[i]
		if p and rb then
			rb.btn.Visible = true
			setText(rb.name, p.name, C.text)
			setText(rb.desc, p.desc, C.dim)
		elseif rb then
			rb.btn.Visible = false
		end
	end
	relicLayer.Visible = true
end)

print("[TD] 04_ClientHUD 준비 완료 — 4인 협동 HUD")
