--[[ ============================================================
  04_ClientHUD.client.lua
  🍀 운빨·조합 터렛 디펜스 — 메인 HUD (모바일·PC 공용)
  ------------------------------------------------------------
  붙여넣는 곳 : StarterPlayer > StarterPlayerScripts (LocalScript)
  하는 일
    · 고정 쿼터뷰 카메라 (+ 피격 흔들림 · 화면 플래시)
    · 상단: 웨이브 · 넥서스 HP · 미네랄 · 가스 · 보석 / 4인 파티
    · 보스 HP 바 · 콤보 표시 · 데미지 숫자(데미지 합산)
    · 하단: 뽑기 · 합성 · 지원 · 공격력/공속 · 내 패드
    · 우측: 🛍 상점 / 🎁 혜택 / 💖 부활
    · 유물 3~4지선다 · 승리/패배 · 넥서스 붕괴 시 12초 부활 창구
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TD_Remotes")
local RD = {
	State = remotes:WaitForChild("TD_State"),
	FX = remotes:WaitForChild("TD_FX"),
	Draw = remotes:WaitForChild("TD_Draw"),
	Merge = remotes:WaitForChild("TD_Merge"),
	Upgrade = remotes:WaitForChild("TD_Upgrade"),
	Support = remotes:WaitForChild("TD_Support"),
	PickRelic = remotes:WaitForChild("TD_PickRelic"),
	Prompt = remotes:WaitForChild("TD_Prompt"),
}

-- ---------------------------------------------------------------
-- UI 버스 (06·07 화면 열기)
-- ---------------------------------------------------------------
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

-- ---------------------------------------------------------------
-- 카메라
-- ---------------------------------------------------------------
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 52
local CAM_POS = Vector3.new(0, 74, 62)
local CAM_LOOK = Vector3.new(0, 0, -4)
local shakeT, shakeAmp = 0, 0

camera.CFrame = CFrame.lookAt(CAM_POS, CAM_LOOK)

RunService.RenderStepped:Connect(function(dt)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local p = CAM_POS
	if shakeT > 0 then
		shakeT = math.max(0, shakeT - dt)
		local k = shakeAmp * (shakeT / 0.35)
		p = p + Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k)
	end
	camera.CFrame = CFrame.lookAt(p, CAM_LOOK)
end)

-- ---------------------------------------------------------------
-- 팔레트 · 헬퍼
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
local TIER_COLORS = Shared.TIER_COLORS
local MAX_WAVE = Shared.MAX_WAVE

local gui = Instance.new("ScreenGui")
gui.Name = "TD_HUD"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

local function label(parent, size, pos, text, color, font, zindex)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = color or C.text
	l.Font = font or FONT2
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
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
	b.ZIndex = zindex or 2
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
local top = frame(gui, UDim2.new(1, -16, 0, 104), UDim2.new(0, 8, 0, 8), C.panel, 0.06, 10)
stroke(top, C.cyan, 1)
gradient(top, Color3.fromRGB(30, 46, 58), Color3.fromRGB(10, 16, 22), 90)

local waveBox = frame(top, UDim2.new(0, 92, 0, 40), UDim2.new(0, 8, 0, 8), C.bg, 0.2, 6)
stroke(waveBox, C.line, 1)
label(waveBox, UDim2.new(1, -12, 0, 12), UDim2.new(0, 6, 0, 3), "WAVE", C.green, FONT2)
local waveLabel = label(waveBox, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 14), "1 / " .. MAX_WAVE, C.text, FONT)

local coreBox = frame(top, UDim2.new(1, -300, 0, 40), UDim2.new(0, 108, 0, 8), C.bg, 0.2, 6)
stroke(coreBox, C.line, 1)
label(coreBox, UDim2.new(0, 70, 0, 14), UDim2.new(0, 8, 0, 3), "NEXUS", C.cyan, FONT2)
local coreText = label(coreBox, UDim2.new(0, 80, 0, 14), UDim2.new(0.55, 0, 0, 3), "30 / 30", C.text, FONT2)
local coreBarBg = frame(coreBox, UDim2.new(1, -16, 0, 13), UDim2.new(0, 8, 0, 21), Color3.fromRGB(8, 12, 16), 0, 4)
local coreBar = frame(coreBarBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.green, 0, 4)
gradient(coreBar, Color3.fromRGB(90, 255, 170), Color3.fromRGB(255, 201, 77), 0)

local minBox = frame(top, UDim2.new(0, 78, 0, 40), UDim2.new(1, -190, 0, 8), C.bg, 0.2, 6)
stroke(minBox, C.line, 1)
label(minBox, UDim2.new(1, -10, 0, 12), UDim2.new(0, 5, 0, 3), "💎 미네랄", C.dim, FONT2)
local minLabel = label(minBox, UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, 14), "100", C.text, FONT)

local gasBox = frame(top, UDim2.new(0, 60, 0, 40), UDim2.new(1, -110, 0, 8), C.bg, 0.2, 6)
stroke(gasBox, C.line, 1)
label(gasBox, UDim2.new(1, -10, 0, 12), UDim2.new(0, 5, 0, 3), "⛽ 가스", C.dim, FONT2)
local gasLabel = label(gasBox, UDim2.new(1, -10, 0, 22), UDim2.new(0, 5, 0, 14), "30", C.green, FONT)

local gemBox = frame(top, UDim2.new(0, 44, 0, 40), UDim2.new(1, -48, 0, 8), C.bg, 0.2, 6)
stroke(gemBox, C.line, 1)
label(gemBox, UDim2.new(1, -8, 0, 12), UDim2.new(0, 4, 0, 3), "💠", C.dim, FONT2)
local gemLabel = label(gemBox, UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 0, 14), "0", C.text, FONT)

local statusLabel = label(top, UDim2.new(1, -16, 0, 16), UDim2.new(0, 10, 0, 52), "", C.dim, FONT2)

local partyRow = frame(top, UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 0, 68), Color3.new(), 1, 6)
local partyChips = {}
for lane = 1, 4 do
	local chip = frame(partyRow, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.25 * (lane - 1), 2, 0, 0), C.bg, 0.25, 5)
	stroke(chip, C.line, 1)
	local dot = frame(chip, UDim2.new(0, 7, 0, 7), UDim2.new(0, 5, 0.18, 0), C.cyan, 0, 4)
	local nameLabel = label(chip, UDim2.new(1, -22, 0, 10), UDim2.new(0, 15, 0, 2), "P1", C.text, FONT2)
	local sub = label(chip, UDim2.new(1, -22, 0, 9), UDim2.new(0, 15, 0, 12), "0/4", C.dim, FONT2)
	local dpsLabel = label(chip, UDim2.new(0, 46, 0, 9), UDim2.new(1, -48, 0, 22), "", C.dim, FONT2)
	partyChips[lane] = { chip = chip, dot = dot, nameLabel = nameLabel, sub = sub, dpsLabel = dpsLabel }
end

-- 보스 HP 바
local bossBar = frame(gui, UDim2.new(0, 340, 0, 30), UDim2.new(0.5, -170, 0, 118), C.bg, 0.15, 8)
stroke(bossBar, Color3.fromRGB(255, 120, 90), 2)
local bossName = label(bossBar, UDim2.new(1, -16, 0, 12), UDim2.new(0, 8, 0, 3), "ULTRALISK", Color3.fromRGB(255, 170, 140), FONT)
local bossBg = frame(bossBar, UDim2.new(1, -16, 0, 10), UDim2.new(0, 8, 0, 17), Color3.fromRGB(40, 10, 12), 0, 4)
local bossFill = frame(bossBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(255, 90, 80), 0, 4)
bossBar.Visible = false

-- 콤보
local comboLabel = label(gui, UDim2.new(0, 260, 0, 44), UDim2.new(0.5, -130, 0, 152), "", C.gold, FONT)
comboLabel.TextXAlignment = Enum.TextXAlignment.Center
comboLabel.TextTransparency = 1
comboLabel.TextStrokeTransparency = 0.4

-- ---------------------------------------------------------------
-- 하단 조작
-- ---------------------------------------------------------------
local bottom = frame(gui, UDim2.new(1, -16, 0, 122), UDim2.new(0, 8, 1, -130), C.panel, 0.06, 10)
stroke(bottom, C.line, 1)
gradient(bottom, Color3.fromRGB(24, 38, 50), Color3.fromRGB(8, 14, 19), 90)

local drawBtn = button(bottom, UDim2.new(0.42, -6, 0, 54), UDim2.new(0, 6, 0, 6), "", Color3.fromRGB(23, 65, 79))
local drawTitle = label(drawBtn, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 5), "🔮 랜덤 뽑기", Color3.fromRGB(215, 248, 255), FONT)
local drawSub = label(drawBtn, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, 32), "💎 " .. Shared.GACHA_COST, Color3.fromRGB(170, 220, 235), FONT2)

local mergeBtn = button(bottom, UDim2.new(0.29, -6, 0, 54), UDim2.new(0.42, 2, 0, 6), "", Color3.fromRGB(61, 50, 24))
local mergeTitle = label(mergeBtn, UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 5), "⚡ 합성 진화", Color3.fromRGB(255, 231, 163), FONT)
local mergeSub = label(mergeBtn, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, 32), "가능 0쌍", Color3.fromRGB(230, 200, 130), FONT2)

local supportBtn = button(bottom, UDim2.new(0.29, -6, 0, 25), UDim2.new(0.71, 2, 0, 6), "🎯 폭격 120", Color3.fromRGB(40, 34, 60))
local supportTitle = label(supportBtn, UDim2.new(1, -8, 1, 0), UDim2.new(0, 4, 0, 0), "🎯 폭격 120", Color3.fromRGB(226, 210, 255), FONT2)
supportTitle.TextXAlignment = Enum.TextXAlignment.Center
local repairBtn = button(bottom, UDim2.new(0.29, -6, 0, 25), UDim2.new(0.71, 2, 0, 35), "🔧 수리 90", Color3.fromRGB(34, 44, 40))
local repairTitle = label(repairBtn, UDim2.new(1, -8, 1, 0), UDim2.new(0, 4, 0, 0), "🔧 수리 90", Color3.fromRGB(210, 240, 230), FONT2)
repairTitle.TextXAlignment = Enum.TextXAlignment.Center

local atkBtn = button(bottom, UDim2.new(0.32, -4, 0, 50), UDim2.new(0, 6, 0, 64), "")
local atkTitle = label(atkBtn, UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 4), "⚔ 공격력 Lv.0", C.text, FONT2)
local atkSub = label(atkBtn, UDim2.new(1, -10, 0, 15), UDim2.new(0, 5, 0, 26), "⛽ 25", C.green, FONT2)

local spdBtn = button(bottom, UDim2.new(0.32, -4, 0, 50), UDim2.new(0.32, 2, 0, 64), "")
local spdTitle = label(spdBtn, UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 4), "⚡ 공속 Lv.0", C.text, FONT2)
local spdSub = label(spdBtn, UDim2.new(1, -10, 0, 15), UDim2.new(0, 5, 0, 26), "⛽ 30", C.green, FONT2)

local padRow = frame(bottom, UDim2.new(0.36, -4, 0, 50), UDim2.new(0.64, 2, 0, 64), C.bg, 0.3, 6)
stroke(padRow, C.line, 1)
local padCells = {}
for i = 1, 6 do
	local cell = frame(padRow, UDim2.new(1 / 6, -3, 1, -8), UDim2.new((i - 1) / 6, 2, 0, 4), Color3.fromRGB(26, 36, 45), 0, 4)
	stroke(cell, C.line, 1)
	local t = label(cell, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 0.34, 0), "", C.text, FONT2)
	t.TextXAlignment = Enum.TextXAlignment.Center
	padCells[i] = { cell = cell, label = t }
end

-- 우측 세로 버튼
local side = frame(gui, UDim2.new(0, 62, 0, 190), UDim2.new(1, -72, 0.5, -95), Color3.new(), 1)
local shopBtn = button(side, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 0), "🛍\n상점", Color3.fromRGB(46, 40, 24))
local metaBtn = button(side, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 64), "🎁\n혜택", Color3.fromRGB(28, 48, 40))
local reviveBtn = button(side, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 128), "💖\n부활 0", Color3.fromRGB(52, 28, 34))
shopBtn.TextScaled = true
metaBtn.TextScaled = true
reviveBtn.TextScaled = true

-- 혜택/부스트 표시줄
local buffRow = frame(gui, UDim2.new(0, 300, 0, 20), UDim2.new(0, 8, 0, 118), Color3.new(), 1)
local buffLabel = label(buffRow, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "", C.gold, FONT2)

-- ---------------------------------------------------------------
-- 토스트 / 배너 / 유물 / 결과 / 부활
-- ---------------------------------------------------------------
local toast = frame(gui, UDim2.new(0, 280, 0, 58), UDim2.new(0.5, -140, 0, 190), C.bg, 0.08, 8)
local toastStroke = stroke(toast, C.cyan, 1.5)
toast.Visible = false
local toastTitle = label(toast, UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 5), "", C.text, FONT)
toastTitle.TextXAlignment = Enum.TextXAlignment.Center
local toastSub = label(toast, UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 32), "", C.dim, FONT2)
toastSub.TextXAlignment = Enum.TextXAlignment.Center

local banner = label(gui, UDim2.new(1, 0, 0, 52), UDim2.new(0, 0, 0.28, 0), "", C.gold, FONT)
banner.TextXAlignment = Enum.TextXAlignment.Center
banner.TextTransparency = 1
banner.TextStrokeTransparency = 0.6

local giftLabel = label(gui, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.42, 0), "", C.cyan, FONT)
giftLabel.TextXAlignment = Enum.TextXAlignment.Center
giftLabel.TextTransparency = 1

local flash = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1), 1, false, 30)
flash.ZIndex = 30
flash.Active = false
flash.Visible = false

local relicLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 6, 10), 0.35, false, 20)
relicLayer.Visible = false
relicLayer.Active = true
local relicCard = frame(relicLayer, UDim2.new(0, 320, 0, 350), UDim2.new(0.5, -160, 0.5, -175), C.panel, 0, 10, 21)
stroke(relicCard, C.gold, 2)
local relicTitle = label(relicCard, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 10), "보스 처치! 유물을 선택하세요", C.gold, FONT, 22)
relicTitle.TextXAlignment = Enum.TextXAlignment.Center
local relicButtons = {}
for i = 1, 4 do
	local b = button(relicCard, UDim2.new(1, -20, 0, 66), UDim2.new(0, 10, 0, 44 + (i - 1) * 74), "", C.panel2, 22)
	local nm = label(b, UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 8), "", C.text, FONT, 23)
	local ds = label(b, UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 34), "", C.dim, FONT2, 23)
	b.Visible = false
	relicButtons[i] = { btn = b, name = nm, desc = ds }
end

local resultLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 6, 10), 0.2, false, 20)
resultLayer.Visible = false
resultLayer.Active = true
local resultCard = frame(resultLayer, UDim2.new(0, 320, 0, 230), UDim2.new(0.5, -160, 0.5, -115), C.panel, 0, 10, 21)
stroke(resultCard, C.cyan, 2)
local resultTitle = label(resultCard, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 16), "", C.text, FONT, 22)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
local resultSub = label(resultCard, UDim2.new(1, -20, 0, 110), UDim2.new(0, 10, 0, 56), "", C.dim, FONT2, 22)
resultSub.TextXAlignment = Enum.TextXAlignment.Center
resultSub.TextWrapped = true
resultSub.TextScaled = false
resultSub.TextSize = 15
local resultClose = button(resultCard, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 176), "계속 보기", C.panel2, 22)

-- 부활 창구 (넥서스 붕괴 12초)
local reviveLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(30, 4, 8), 0.15, false, 25)
reviveLayer.Visible = false
reviveLayer.Active = true
local reviveCard = frame(reviveLayer, UDim2.new(0, 320, 0, 230), UDim2.new(0.5, -160, 0.5, -115), C.panel, 0, 10, 26)
stroke(reviveCard, C.red, 2)
local reviveTitle = label(reviveCard, UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 14), "💥 넥서스 붕괴!", C.red, FONT, 27)
reviveTitle.TextXAlignment = Enum.TextXAlignment.Center
local reviveSub = label(reviveCard, UDim2.new(1, -20, 0, 54), UDim2.new(0, 10, 0, 48), "부활하면 전장이 정리되고 이어서 갑니다", C.text, FONT2, 27)
reviveSub.TextXAlignment = Enum.TextXAlignment.Center
reviveSub.TextWrapped = true
reviveSub.TextScaled = false
reviveSub.TextSize = 14
local reviveUseBtn = button(reviveCard, UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 110), "💖 부활권 사용", Color3.fromRGB(70, 30, 40), 27)
local reviveBuyBtn = button(reviveCard, UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 0, 162), "💖 부활권 구매 (25 R$)", Color3.fromRGB(80, 60, 20), 27)

-- ---------------------------------------------------------------
-- 데미지 숫자 풀
-- ---------------------------------------------------------------
local dmgGui = Instance.new("ScreenGui")
dmgGui.Name = "TD_Damage"
dmgGui.IgnoreGuiInset = true
dmgGui.ResetOnSpawn = false
dmgGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
dmgGui.DisplayOrder = 5
dmgGui.Parent = player:WaitForChild("PlayerGui")

local DMG_POOL = 26
local dmgPool = {}
local dmgActive = {}
for i = 1, DMG_POOL do
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 110, 0, 26)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l.Font = FONT
	l.TextScaled = true
	l.Visible = false
	l.ZIndex = 40
	l.Parent = dmgGui
	dmgPool[i] = l
end

local function showDamage(worldPos, amount, boss)
	if amount < 1 then return end
	local lbl
	for _, l in ipairs(dmgPool) do
		if not l.Visible then
			lbl = l
			break
		end
	end
	if not lbl then return end
	lbl.Text = "−" .. Shared.comma(amount)
	lbl.TextColor3 = boss and Color3.fromRGB(255, 170, 90) or (amount > 2000 and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(240, 250, 255))
	lbl.TextScaled = true
	lbl.TextSize = boss and 24 or 18
	lbl.Visible = true
	lbl.TextTransparency = 0
	table.insert(dmgActive, { label = lbl, pos = worldPos, t = 0, life = 0.85 })
end

RunService.RenderStepped:Connect(function(dt)
	for i = #dmgActive, 1, -1 do
		local d = dmgActive[i]
		d.t = d.t + dt
		if d.t >= d.life then
			d.label.Visible = false
			table.remove(dmgActive, i)
		else
			local world = d.pos + Vector3.new(0, d.t * 9, 0)
			local screen, onScreen = camera:WorldToViewportPoint(world)
			if onScreen then
				d.label.Position = UDim2.new(0, screen.X - 55, 0, screen.Y - 13)
				d.label.TextTransparency = math.min(1, d.t / d.life)
			else
				d.label.Visible = false
			end
		end
	end
end)

-- ---------------------------------------------------------------
-- 버튼 연결
-- ---------------------------------------------------------------
drawBtn.MouseButton1Click:Connect(function() RD.Draw:FireServer() end)
mergeBtn.MouseButton1Click:Connect(function() RD.Merge:FireServer() end)
atkBtn.MouseButton1Click:Connect(function() RD.Upgrade:FireServer("atk") end)
spdBtn.MouseButton1Click:Connect(function() RD.Upgrade:FireServer("spd") end)
supportBtn.MouseButton1Click:Connect(function() RD.Support:FireServer("strike") end)
repairBtn.MouseButton1Click:Connect(function() RD.Support:FireServer("repair") end)
resultClose.MouseButton1Click:Connect(function() resultLayer.Visible = false end)
shopBtn.MouseButton1Click:Connect(function() uiOpen:Fire("shop") end)
metaBtn.MouseButton1Click:Connect(function() uiOpen:Fire("meta") end)
reviveBtn.MouseButton1Click:Connect(function() RD.Prompt:FireServer("revive_use") end)
reviveUseBtn.MouseButton1Click:Connect(function() RD.Prompt:FireServer("revive_use") end)
reviveBuyBtn.MouseButton1Click:Connect(function() RD.Prompt:FireServer("product", "PRODUCT_REVIVE") end)

-- 지원 작전은 두 버튼으로 분리 (모바일에서도 한 번에 누름)
for i = 1, 4 do
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
	waveActive = false, combo = 0, passSlots = false,
}

local function setText(lbl, txt, color)
	lbl.Text = txt
	if color then lbl.TextColor3 = color end
end

local function refreshButtons()
	setText(drawSub, "💎 " .. Shared.GACHA_COST .. " · " .. (S.minerals >= Shared.GACHA_COST and "가능" or "부족"),
		S.minerals >= Shared.GACHA_COST and Color3.fromRGB(170, 220, 235) or C.red)
	setText(mergeSub, S.mergeable > 0 and (S.mergeable .. "쌍 합성 가능!") or "가능 0쌍",
		S.mergeable > 0 and C.gold or Color3.fromRGB(150, 150, 130))
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
	S.combo = d.combo or 0
	if d.passes then S.passSlots = d.passes.slots == true end

	setText(waveLabel, S.wave .. " / " .. MAX_WAVE)
	setText(minLabel, Shared.comma(S.minerals))
	setText(gasLabel, Shared.comma(S.gas))
	setText(gemLabel, Shared.comma(player:GetAttribute("Gems") or 0))
	setText(coreText, S.core .. " / " .. S.coreMax)
	local frac = math.clamp(S.core / math.max(1, S.coreMax), 0, 1)
	coreBar.Size = UDim2.new(frac, 0, 1, 0)
	coreBar.BackgroundColor3 = frac > 0.5 and C.green or (frac > 0.25 and C.gold or C.red)

	-- 보스 바
	if d.boss then
		bossBar.Visible = true
		bossFill.Size = UDim2.new(math.clamp(d.boss.hp / math.max(1, d.boss.maxHp), 0, 1), 0, 1, 0)
		bossName.Text = "☠ ULTRALISK · " .. Shared.comma(d.boss.hp) .. " HP"
	else
		bossBar.Visible = false
	end

	-- 콤보
	if S.combo >= 3 then
		comboLabel.Text = "COMBO ×" .. S.combo
		comboLabel.TextTransparency = 0
		comboLabel.TextColor3 = S.combo >= 20 and C.pink or (S.combo >= 10 and C.gold or C.cyan)
	else
		comboLabel.TextTransparency = 1
	end

	-- 파티
	if d.party then
		for lane = 1, 4 do
			local p = d.party[lane]
			local chip = partyChips[lane]
			if p and chip then
				chip.dot.BackgroundColor3 = (lane == S.lane) and C.gold or C.cyan
				chip.nameLabel.Text = (lane == S.lane) and ("나·" .. tostring(p.name)) or tostring(p.name)
				chip.sub.Text = p.ai and ("AI · " .. p.turrets .. "/6") or (p.turrets .. "/6")
				chip.dpsLabel.Text = p.dps > 0 and (Shared.comma(p.dps) .. " DPS") or ""
			end
		end
	end

	-- 내 패드
	if d.pads then
		for i = 1, 6 do
			local cell = padCells[i]
			local pd = d.pads[i]
			if cell then
				if pd and pd.tier and pd.tier > 0 then
					cell.cell.BackgroundColor3 = TIER_COLORS[pd.tier]
					cell.label.Text = (pd.star and pd.star > 0) and ("★" .. pd.star) or ("T" .. pd.tier)
					cell.label.TextColor3 = Color3.fromRGB(10, 16, 22)
				elseif pd and pd.locked then
					cell.cell.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
					cell.label.Text = "🔒"
					cell.label.TextColor3 = Color3.fromRGB(120, 120, 120)
				else
					cell.cell.BackgroundColor3 = Color3.fromRGB(26, 36, 45)
					cell.label.Text = ""
				end
			end
		end
	end

	-- 상태줄
	-- 부활 성공/패배 판정이 오면 창구를 닫습니다
	if not d.downed then
		reviveLayer.Visible = false
	end
	local st
	if d.downed then
		st = "💥 넥서스 붕괴 · 부활 대기 " .. (d.reviveSeconds or 0) .. "초"
	elseif S.waveActive then
		st = "진행 중 · W" .. S.wave
	else
		st = "다음 웨이브 " .. S.timer .. "초"
	end
	setText(statusLabel, st .. "   ·   내 라인 P" .. S.lane, C.dim)

	-- 부스트/팀버프
	local buffs = {}
	if (d.boostDmg or 0) > 0 then table.insert(buffs, "🔥2배 " .. math.floor(d.boostDmg / 60) .. "m") end
	if (d.boostGold or 0) > 0 then table.insert(buffs, "💎2배 " .. math.floor(d.boostGold / 60) .. "m") end
	if (d.teamSpeed or 0) > 0 then table.insert(buffs, "⚡팀공속 " .. math.floor(d.teamSpeed / 60) .. "m") end
	if d.passes and d.passes.vip then table.insert(buffs, "👑VIP") end
	if d.passes and d.passes.auto then table.insert(buffs, "🧲자동") end
	if d.passes and d.passes.luck then table.insert(buffs, "🍀럭키") end
	setText(buffLabel, table.concat(buffs, "  "), C.gold)

	-- 부활 버튼
	setText(reviveBtn, "💖\n부활 " .. (d.reviveStock or player:GetAttribute("ReviveStock") or 0))
	refreshButtons()
end

-- ---------------------------------------------------------------
-- 리모트 이벤트
-- ---------------------------------------------------------------
RD.State.OnClientEvent:Connect(function(d)
	local e = d.event
	if e == "state" then
		applyState(d)
	elseif e == "assigned" then
		S.lane = d.lane or S.lane
	elseif e == "toast" then
		toastTitle.Text = d.title or ""
		toastSub.Text = d.sub or ""
		toast.Visible = true
		toast.BackgroundTransparency = 0.08
		if d.tier then
			toastStroke.Color = TIER_COLORS[math.clamp(d.tier, 1, 5)]
		else
			toastStroke.Color = C.cyan
		end
		task.delay(1.7, function()
			if toast.Visible then toast.Visible = false end
		end)
	elseif e == "banner" then
		banner.Text = (d.title or "") .. ((d.sub and d.sub ~= "") and ("\n" .. d.sub) or "")
		banner.TextTransparency = 0
		banner.TextSize = 34
		banner.TextColor3 = C.gold
		task.delay(2.0, function()
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end)
	elseif e == "gift" then
		giftLabel.Text = "🎁 " .. (d.title or "") .. "\n" .. (d.by or "") .. " 님의 선물!"
		giftLabel.TextColor3 = C.cyan
		giftLabel.TextTransparency = 0
		task.delay(2.4, function()
			TweenService:Create(giftLabel, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end)
	elseif e == "bossDown" then
		bossBar.Visible = false
		banner.Text = "☠ BOSS DOWN"
		banner.TextTransparency = 0
		task.delay(1.5, function()
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end)
	elseif e == "relic" then
		for i = 1, 4 do
			local p = d.picks[i]
			local rb = relicButtons[i]
			if p then
				rb.btn.Visible = true
				rb.name.Text = p.name
				rb.desc.Text = p.desc
			else
				rb.btn.Visible = false
			end
		end
		relicLayer.Visible = true
	elseif e == "relicDone" then
		relicLayer.Visible = false
	elseif e == "reviveOffer" then
		reviveLayer.Visible = true
		setText(reviveSub, "부활하면 전장이 정리되고 다음 웨이브가 시작됩니다\n남은 부활권 " .. (d.stock or 0) .. "장")
		if (d.stock or 0) > 0 then
			reviveUseBtn.Text = "💖 부활권 사용"
			reviveUseBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 44)
		else
			reviveUseBtn.Text = "부활권 없음"
			reviveUseBtn.BackgroundColor3 = Color3.fromRGB(40, 32, 34)
		end
		task.spawn(function()
			local left = d.seconds or 12
			while left > 0 and reviveLayer.Visible do
				reviveTitle.Text = "💥 넥서스 붕괴! " .. left .. "초"
				task.wait(1)
				left = left - 1
			end
			reviveLayer.Visible = false
			reviveTitle.Text = "💥 넥서스 붕괴!"
		end)
	elseif e == "win" then
		reviveLayer.Visible = false
		resultLayer.Visible = true
		setText(resultTitle, "🏆 임무 성공!", C.cyan)
		setText(resultSub, (d.wave or 0) .. "웨이브 완료 · 보석 +" .. (d.gems or 0)
			.. "\n최고 기록 " .. (d.best or 0) .. "웨이브"
			.. "\n잠시 후 새 판이 시작됩니다 (상점에서 영구 강화!)", C.text)
	elseif e == "lose" then
		reviveLayer.Visible = false
		resultLayer.Visible = true
		setText(resultTitle, "코어 붕괴", C.red)
		setText(resultSub, "도달 " .. (d.wave or 0) .. "웨이브 · 보석 +" .. (d.gems or 0)
			.. "\n최고 기록 " .. (d.best or 0) .. "웨이브"
			.. "\n부활권을 미리 준비하면 1탭으로 되살아납니다", C.text)
	elseif e == "restart" then
		resultLayer.Visible = false
		reviveLayer.Visible = false
		relicLayer.Visible = false
		banner.Text = "새 판 시작!"
		banner.TextTransparency = 0
		task.delay(1.4, function()
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end)
	elseif e == "drawn" then
		drawBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 140)
		task.delay(0.2, function()
			drawBtn.BackgroundColor3 = Color3.fromRGB(23, 65, 79)
		end)
	elseif e == "metaDirty" then
		setText(gemLabel, Shared.comma(player:GetAttribute("Gems") or 0))
	end
end)

RD.FX.OnClientEvent:Connect(function(d)
	if d.kind == "dmg" then
		showDamage(d.pos, d.amount or 0, d.boss)
	elseif d.kind == "flash" then
		flash.BackgroundColor3 = d.color or Color3.new(1, 1, 1)
		flash.Visible = true
		flash.BackgroundTransparency = 0.55
		TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.delay(0.45, function() flash.Visible = false end)
	elseif d.kind == "shake" then
		shakeT = 0.35
		shakeAmp = 2 + (d.strength or 0.4) * 3
	elseif d.kind == "coreHit" then
		flash.BackgroundColor3 = Color3.fromRGB(255, 60, 70)
		flash.Visible = true
		flash.BackgroundTransparency = 0.7
		TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		task.delay(0.4, function() flash.Visible = false end)
		shakeT = 0.3
		shakeAmp = 2.5
	elseif d.kind == "waveClear" then
		comboLabel.Text = "WAVE " .. (d.wave or 0) .. " CLEAR"
		comboLabel.TextColor3 = C.green
		comboLabel.TextTransparency = 0
		task.delay(0.9, function()
			TweenService:Create(comboLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end)
	elseif d.kind == "bossWarn" then
		banner.Text = "⚠ BOSS INCOMING"
		banner.TextColor3 = Color3.fromRGB(255, 100, 90)
		banner.TextTransparency = 0
		flash.BackgroundColor3 = Color3.fromRGB(255, 80, 70)
		flash.Visible = true
		flash.BackgroundTransparency = 0.8
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.55, function() flash.Visible = false end)
		task.delay(1.6, function()
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			banner.TextColor3 = C.gold
		end)
	end
end)

-- 보석/부활권 속성 변화 반영
player:GetAttributeChangedSignal("Gems"):Connect(function()
	setText(gemLabel, Shared.comma(player:GetAttribute("Gems") or 0))
end)
player:GetAttributeChangedSignal("ReviveStock"):Connect(function()
	setText(reviveBtn, "💖\n부활 " .. (player:GetAttribute("ReviveStock") or 0))
end)

print("[TD] 04_ClientHUD 준비 완료 — 4인 협동 HUD v" .. Shared.VERSION)
