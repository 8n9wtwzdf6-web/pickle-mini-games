--[[ ============================================================
  04_ClientHUD.client.lua  —  v3.0
  🌌 우주 5아레나 HUD
  ------------------------------------------------------------
  붙여넣는 곳 : StarterPlayer > StarterPlayerScripts (LocalScript)
  하는 일
    · 내 부유 아레나를 비추는 전략 카메라 (+ 전체 뷰 · 흔들림 · 플래시)
    · 상단: STAGE 진행 · NEXUS HP · 미네랄/가스/보석
    · 우측: 5팀 실시간 순위표 (스테이지 경쟁 → 보스 딜량 경쟁)
    · 타일 터치로 자유 건설 · 유닛 선택(모드전환/스킬/이동/판매) · 이종족 융합
    · 🔮뽑기 · ⚡합성 · 공격력/공속 · 궤도폭격/수리
    · 🛍상점 · 🎁혜택 · 💖부활 · 🌌테마 · 인트로(테마/종족 선택)
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

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
	Build = remotes:WaitForChild("TD_Build"),
}

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
-- 팔레트 · 헬퍼
-- ---------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(8, 12, 18),
	panel = Color3.fromRGB(16, 24, 34),
	panel2 = Color3.fromRGB(26, 38, 50),
	line = Color3.fromRGB(66, 104, 128),
	cyan = Color3.fromRGB(79, 216, 255),
	green = Color3.fromRGB(92, 255, 176),
	gold = Color3.fromRGB(255, 201, 77),
	violet = Color3.fromRGB(176, 123, 255),
	pink = Color3.fromRGB(255, 91, 209),
	red = Color3.fromRGB(255, 95, 109),
	text = Color3.fromRGB(228, 240, 250),
	dim = Color3.fromRGB(150, 176, 194),
	dark = Color3.fromRGB(34, 46, 58),
}
local FONT = Enum.Font.GothamBlack
local FONT2 = Enum.Font.GothamBold
local TIER_COLORS = Shared.TIER_COLORS
local TIER_NAMES = Shared.TIER_NAMES

local gui = Instance.new("ScreenGui")
gui.Name = "TD_HUD"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 3
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
	s.Thickness = thickness or 1.4
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
	b.ZIndex = zindex or 3
	b.Parent = parent
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, 8)
	u.Parent = b
	stroke(b, C.line, 1.2)
	return b
end

local function gradient(f, c1, c2, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rot or 90
	g.Parent = f
	return g
end

local function factionDef(key)
	return Shared.FACTION_BY_KEY[key] or Shared.FACTIONS[1]
end

-- ---------------------------------------------------------------
-- 카메라
-- ---------------------------------------------------------------
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 55

local S = {
	team = 0,
	faction = "human",
	expanded = false,
	units = {},
	unitMap = {},
	hand = {},
	fusions = {},
	selected = nil,
	handIndex = 1,
	view = 1,          -- 1 = 내 아레나, 2 = 아레나+중앙, 3 = 전체 우주
	moveMode = false,
	boss = nil,
	downed = false,
}
local camPos = Vector3.new(0, 90, -160)
local camLook = Vector3.new(0, 0, 0)
local wantPos = camPos
local wantLook = camLook
local shakeT, shakeAmp = 0, 0
local arenaModel = nil
local arenaCF = CFrame.new()
local introDone = false

-- UI 갱신 함수 (먼저 이름을 잡아 둡니다)
local refreshHand, refreshFusions, refreshRank, applyState, selectTheme, selectFaction, openIntro

local function resolveArena()
	if S.team <= 0 then return end
	local world = Workspace:FindFirstChild("TDWorld")
	local arenas = world and world:FindFirstChild("Arenas")
	if not arenas then return end
	arenaModel = arenas:FindFirstChild("Arena_" .. S.team)
	if not arenaModel then return end
	arenaCF = arenaModel:GetPivot()
	-- 세로 화면(폰)에서는 아레나가 다 보이도록 카메라를 더 멀리
	local vp = camera.ViewportSize
	local portrait = (vp.X / math.max(1, vp.Y)) < 1.2
	local k = portrait and 1.5 or 1.0
	if S.view == 1 then
		wantPos = (arenaCF * CFrame.new(0, 66 * k, -52 * k)).Position
		wantLook = (arenaCF * CFrame.new(0, 0, 4)).Position
	elseif S.view == 2 then
		wantPos = (arenaCF * CFrame.new(0, 120 * k, -110 * k)).Position
		wantLook = (arenaCF * CFrame.new(0, 0, 20)).Position
	else
		wantPos = Vector3.new(0, 260 * k, -300 * k)
		wantLook = Vector3.new(0, 0, 0)
	end
end

RunService.RenderStepped:Connect(function(dt)
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	resolveArena()
	local p = camPos:Lerp(wantPos, math.min(1, dt * 4.5))
	local l = camLook:Lerp(wantLook, math.min(1, dt * 4.5))
	if shakeT > 0 then
		shakeT = math.max(0, shakeT - dt)
		local k = shakeAmp * (shakeT / 0.35)
		p = p + Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k)
	end
	camPos = p
	camLook = l
	camera.CFrame = CFrame.lookAt(p, l)
end)

-- ---------------------------------------------------------------
-- 상단 HUD
-- ---------------------------------------------------------------
local top = frame(gui, UDim2.new(1, -12, 0, 106), UDim2.new(0, 6, 0, 6), C.panel, 0.05, 10)
stroke(top, C.cyan, 1)
gradient(top, Color3.fromRGB(28, 44, 58), Color3.fromRGB(8, 12, 18), 90)

-- 1줄 : STAGE · NEXUS · 미네랄 (화면 폭에 비례)
local stageBox = frame(top, UDim2.new(0.25, -4, 0, 44), UDim2.new(0, 4, 0, 4), C.bg, 0.15, 6)
stroke(stageBox, C.line, 1)
label(stageBox, UDim2.new(1, -10, 0, 12), UDim2.new(0, 5, 0, 3), "STAGE", C.green, FONT2)
local stageLabel = label(stageBox, UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 14), "0 / 40", C.text, FONT)
local stageSub = label(stageBox, UDim2.new(1, -10, 0, 10), UDim2.new(0, 5, 0, 34), "", C.dim, FONT2)

local coreBox = frame(top, UDim2.new(0.46, -4, 0, 44), UDim2.new(0.25, 1, 0, 4), C.bg, 0.15, 6)
stroke(coreBox, C.line, 1)
label(coreBox, UDim2.new(0, 70, 0, 12), UDim2.new(0, 6, 0, 3), "NEXUS", C.cyan, FONT2)
local coreText = label(coreBox, UDim2.new(0, 86, 0, 12), UDim2.new(0.48, 0, 0, 3), "30 / 30", C.text, FONT2)
local coreBg = frame(coreBox, UDim2.new(1, -12, 0, 12), UDim2.new(0, 6, 0, 20), Color3.fromRGB(8, 12, 16), 0, 4)
local coreFill = frame(coreBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.green, 0, 4)
gradient(coreFill, Color3.fromRGB(90, 255, 170), Color3.fromRGB(255, 201, 77), 0)
local waveLabel = label(coreBox, UDim2.new(1, -12, 0, 10), UDim2.new(0, 6, 0, 34), "", C.dim, FONT2)

local minBox = frame(top, UDim2.new(0.29, -4, 0, 44), UDim2.new(0.71, 3, 0, 4), C.bg, 0.15, 6)
stroke(minBox, C.line, 1)
label(minBox, UDim2.new(1, -8, 0, 12), UDim2.new(0, 4, 0, 3), "💎 미네랄", C.dim, FONT2)
local minLabel = label(minBox, UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 0, 15), "100", C.text, FONT)

-- 2줄 : 가스 · 보석 · 팀
local gasBox = frame(top, UDim2.new(0.24, -4, 0, 22), UDim2.new(0, 4, 0, 52), C.bg, 0.2, 5)
stroke(gasBox, C.line, 1)
local gasLabel = label(gasBox, UDim2.new(1, -8, 1, 0), UDim2.new(0, 4, 0, 0), "⛽ 30", C.green, FONT2)

local gemBox = frame(top, UDim2.new(0.24, -4, 0, 22), UDim2.new(0.24, 1, 0, 52), C.bg, 0.2, 5)
stroke(gemBox, C.line, 1)
local gemLabel = label(gemBox, UDim2.new(1, -8, 1, 0), UDim2.new(0, 4, 0, 0), "💠 0", C.gold, FONT2)

local teamLabel = label(top, UDim2.new(0.51, -6, 0, 22), UDim2.new(0.48, 3, 0, 52), "", C.cyan, FONT2)
teamLabel.TextScaled = false
teamLabel.TextSize = 12

-- 3줄 : 상태 · 버프
local statusLabel = label(top, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, 76), "", C.dim, FONT2)
statusLabel.TextScaled = false
statusLabel.TextSize = 12
local buffLabel = label(top, UDim2.new(1, -12, 0, 13), UDim2.new(0, 6, 0, 90), "", C.gold, FONT2)
buffLabel.TextScaled = false
buffLabel.TextSize = 11

-- 스테이지 진행 바 (상단 패널 맨 아래)
local stageBarBg = frame(gui, UDim2.new(1, -12, 0, 5), UDim2.new(0, 6, 0, 112), C.bg, 0.25, 4)
local stageBar = frame(stageBarBg, UDim2.new(0, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.green, 0, 4)
gradient(stageBar, Color3.fromRGB(90, 255, 170), Color3.fromRGB(79, 216, 255), 0)

-- ---------------------------------------------------------------
-- 5팀 순위표
-- ---------------------------------------------------------------
local rankPanel = frame(gui, UDim2.new(0, 198, 0, 162), UDim2.new(1, -204, 0, 122), C.panel, 0.08, 10)
stroke(rankPanel, C.gold, 1.2)
local rankTitle = label(rankPanel, UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 0, 3), "🏁 5 TEAM RANK", C.gold, FONT)
local rankMode = label(rankPanel, UDim2.new(1, -12, 0, 11), UDim2.new(0, 6, 0, 18), "STAGE RACE", C.dim, FONT2)
local rankRows = {}
for i = 1, 5 do
	local row = frame(rankPanel, UDim2.new(1, -10, 0, 24), UDim2.new(0, 5, 0, 31 + (i - 1) * 25), C.bg, 0.35, 5)
	stroke(row, C.line, 1)
	local medal = label(row, UDim2.new(0, 20, 1, 0), UDim2.new(0, 3, 0, 0), tostring(i), C.gold, FONT)
	local icon = label(row, UDim2.new(0, 20, 1, 0), UDim2.new(0, 22, 0, 0), "👤", C.text, FONT2)
	local nameL = label(row, UDim2.new(0, 74, 1, 0), UDim2.new(0, 40, 0, 0), "휴먼", C.text, FONT2)
	local valL = label(row, UDim2.new(0, 78, 1, 0), UDim2.new(1, -80, 0, 0), "", C.dim, FONT2)
	valL.TextXAlignment = Enum.TextXAlignment.Right
	rankRows[i] = { row = row, medal = medal, icon = icon, nameL = nameL, valL = valL }
end

-- 보스 HP 바
local bossBar = frame(gui, UDim2.new(1, -218, 0, 36), UDim2.new(0, 6, 0, 122), C.bg, 0.1, 8)
stroke(bossBar, Color3.fromRGB(255, 90, 110), 2)
local bossName = label(bossBar, UDim2.new(1, -12, 0, 14), UDim2.new(0, 8, 0, 2), "👁️ 오메가 파괴신", Color3.fromRGB(255, 170, 180), FONT)
local bossBg = frame(bossBar, UDim2.new(1, -12, 0, 12), UDim2.new(0, 6, 0, 20), Color3.fromRGB(40, 8, 14), 0, 4)
local bossFill = frame(bossBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(255, 70, 110), 0, 4)
local bossTime = label(bossBar, UDim2.new(0, 80, 0, 12), UDim2.new(1, -88, 0, 4), "", C.gold, FONT2)
bossTime.TextXAlignment = Enum.TextXAlignment.Right
bossBar.Visible = false

-- ---------------------------------------------------------------
-- 하단 건설 바
-- ---------------------------------------------------------------
local bottom = frame(gui, UDim2.new(1, -12, 0, 118), UDim2.new(0, 6, 1, -124), C.panel, 0.05, 10)
stroke(bottom, C.line, 1)
gradient(bottom, Color3.fromRGB(22, 36, 48), Color3.fromRGB(6, 10, 16), 90)

local drawBtn = button(bottom, UDim2.new(0.22, -6, 0, 48), UDim2.new(0, 5, 0, 5), "", Color3.fromRGB(23, 65, 79))
local drawTitle = label(drawBtn, UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 3), "🔮 유닛 뽑기", Color3.fromRGB(215, 248, 255), FONT)
local drawSub = label(drawBtn, UDim2.new(1, -10, 0, 14), UDim2.new(0, 5, 0, 26), "💎 " .. Shared.GACHA_COST, Color3.fromRGB(170, 220, 235), FONT2)

local mergeBtn = button(bottom, UDim2.new(0.18, -6, 0, 48), UDim2.new(0.22, 2, 0, 5), "", Color3.fromRGB(61, 50, 24))
local mergeTitle = label(mergeBtn, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 3), "⚡ 합성", Color3.fromRGB(255, 231, 163), FONT)
local mergeSub = label(mergeBtn, UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 0, 26), "", Color3.fromRGB(230, 200, 130), FONT2)

local fusionBtn = button(bottom, UDim2.new(0.18, -6, 0, 48), UDim2.new(0.40, 2, 0, 5), "", Color3.fromRGB(48, 32, 66))
local fusionTitle = label(fusionBtn, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 3), "🧬 융합", Color3.fromRGB(220, 200, 255), FONT)
local fusionSub = label(fusionBtn, UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 0, 26), "이종족", Color3.fromRGB(190, 170, 220), FONT2)

local atkBtn = button(bottom, UDim2.new(0.20, -6, 0, 48), UDim2.new(0.58, 2, 0, 5), "", C.panel2)
local atkTitle = label(atkBtn, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 3), "⚔ 공격력 Lv.0", C.text, FONT2)
local atkSub = label(atkBtn, UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 0, 24), "⛽ 25", C.green, FONT2)

local spdBtn = button(bottom, UDim2.new(0.20, -6, 0, 48), UDim2.new(0.78, 2, 0, 5), "", C.panel2)
local spdTitle = label(spdBtn, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 3), "⚡ 공속 Lv.0", C.text, FONT2)
local spdSub = label(spdBtn, UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 0, 24), "⛽ 30", C.green, FONT2)

-- 대기열(손패)
local handRow = frame(bottom, UDim2.new(0.62, -4, 0, 42), UDim2.new(0, 5, 0, 58), Color3.new(), 1, 6)
local handCells = {}
for i = 1, 4 do
	local cell = button(handRow, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.25 * (i - 1), 2, 0, 0), "", C.bg)
	cell.Text = ""
	local cellStroke = cell:FindFirstChildOfClass("UIStroke")
	local t = label(cell, UDim2.new(1, -4, 0, 16), UDim2.new(0, 2, 0, 2), "", C.text, FONT2)
	t.TextXAlignment = Enum.TextXAlignment.Center
	local s = label(cell, UDim2.new(1, -4, 0, 12), UDim2.new(0, 2, 0, 18), "", C.dim, FONT2)
	s.TextXAlignment = Enum.TextXAlignment.Center
	cell.MouseButton1Click:Connect(function()
		if S.hand[i] then
			S.handIndex = i
			refreshHand()
		end
	end)
	handCells[i] = { btn = cell, title = t, sub = s, stroke = cellStroke }
end

local supportBtn = button(bottom, UDim2.new(0.18, -4, 0, 34), UDim2.new(0.63, 2, 0, 62), "🎯 폭격 120", Color3.fromRGB(40, 34, 60))
local repairBtn = button(bottom, UDim2.new(0.18, -4, 0, 34), UDim2.new(0.82, 2, 0, 62), "🔧 수리 90", Color3.fromRGB(34, 44, 40))

-- 선택 유닛 패널
local unitPanel = frame(gui, UDim2.new(0, 300, 0, 64), UDim2.new(0.5, -150, 1, -196), C.panel, 0.05, 8)
stroke(unitPanel, C.cyan, 1.2)
unitPanel.Visible = false
local unitTitle = label(unitPanel, UDim2.new(1, -12, 0, 18), UDim2.new(0, 6, 0, 3), "", C.text, FONT)
local unitSub = label(unitPanel, UDim2.new(1, -12, 0, 13), UDim2.new(0, 6, 0, 21), "", C.dim, FONT2)
local uMode = button(unitPanel, UDim2.new(0.24, -3, 0, 24), UDim2.new(0, 4, 0, 37), "🔄 모드", C.panel2)
local uSkill = button(unitPanel, UDim2.new(0.24, -3, 0, 24), UDim2.new(0.24, 1, 0, 37), "✨ 스킬", C.panel2)
local uMove = button(unitPanel, UDim2.new(0.24, -3, 0, 24), UDim2.new(0.48, 2, 0, 37), "↔ 이동", C.panel2)
local uSell = button(unitPanel, UDim2.new(0.24, -3, 0, 24), UDim2.new(0.72, 3, 0, 37), "💎 판매", Color3.fromRGB(58, 34, 34))

-- 우측 세로 버튼
local side = frame(gui, UDim2.new(0, 58, 0, 286), UDim2.new(1, -66, 0.5, -80), Color3.new(), 1)
local shopBtn = button(side, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 0), "🛍\n상점", Color3.fromRGB(46, 40, 24))
local metaBtn = button(side, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 56), "🎁\n혜택", Color3.fromRGB(28, 48, 40))
local reviveBtn = button(side, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 112), "💖\n부활 0", Color3.fromRGB(52, 28, 34))
local themeBtn = button(side, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 168), "🌌\n테마", Color3.fromRGB(32, 38, 62))
local viewBtn = button(side, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 224), "👥\n아레나", Color3.fromRGB(30, 44, 52))

-- ---------------------------------------------------------------
-- 토스트 / 배너 / 플래시
-- ---------------------------------------------------------------
local toast = frame(gui, UDim2.new(0, 300, 0, 54), UDim2.new(0.5, -150, 0, 250), C.bg, 0.06, 8)
local toastStroke = stroke(toast, C.cyan, 1.5)
toast.Visible = false
local toastTitle = label(toast, UDim2.new(1, -14, 0, 24), UDim2.new(0, 7, 0, 4), "", C.text, FONT)
toastTitle.TextXAlignment = Enum.TextXAlignment.Center
local toastSub = label(toast, UDim2.new(1, -14, 0, 16), UDim2.new(0, 7, 0, 30), "", C.dim, FONT2)
toastSub.TextXAlignment = Enum.TextXAlignment.Center

local banner = label(gui, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0.3, 0), "", C.gold, FONT)
banner.TextXAlignment = Enum.TextXAlignment.Center
banner.TextTransparency = 1
banner.TextStrokeTransparency = 0.55

local flash = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1), 1, false, 40)
flash.ZIndex = 40
flash.Active = false
flash.Visible = false

-- ---------------------------------------------------------------
-- 융합 패널
-- ---------------------------------------------------------------
local fuseLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 6, 10), 0.4, false, 30)
fuseLayer.Visible = false
fuseLayer.Active = true
local fuseCard = frame(fuseLayer, UDim2.new(0.9, 0, 0.62, 0), UDim2.new(0.05, 0, 0.19, 0), C.panel, 0, 10, 31)
stroke(fuseCard, C.violet, 1.5)
local fuseTitle = label(fuseCard, UDim2.new(1, -90, 0, 24), UDim2.new(0, 10, 0, 8), "🧬 이종족 융합", C.violet, FONT, 32)
local fuseClose = button(fuseCard, UDim2.new(0, 40, 0, 26), UDim2.new(1, -48, 0, 8), "✕", C.panel2, 32)
local fuseInfo = label(fuseCard, UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 32), "", C.dim, FONT2, 32)
fuseInfo.TextScaled = false
fuseInfo.TextSize = 11
local fuseRows = {}
for i = 1, 5 do
	local row = frame(fuseCard, UDim2.new(1, -16, 0, 56), UDim2.new(0, 8, 0, 50 + (i - 1) * 60), C.panel2, 0.1, 6, 32)
	stroke(row, C.line, 1)
	local icon = label(row, UDim2.new(0, 30, 1, 0), UDim2.new(0, 4, 0, 0), "", C.text, FONT, 33)
	local nm = label(row, UDim2.new(0.55, -34, 0, 18), UDim2.new(0, 36, 0, 5), "", C.text, FONT, 33)
	local ds = label(row, UDim2.new(0.55, -34, 0, 14), UDim2.new(0, 36, 0, 24), "", C.dim, FONT2, 33)
	ds.TextScaled = false
	ds.TextSize = 10
	local status = label(row, UDim2.new(0.55, -34, 0, 13), UDim2.new(0, 36, 0, 40), "", C.gold, FONT2, 33)
	status.TextScaled = false
	status.TextSize = 10
	local go = button(row, UDim2.new(0.28, -8, 0, 34), UDim2.new(0.7, 2, 0.5, -17), "융합", Color3.fromRGB(64, 44, 92), 33)
	go.MouseButton1Click:Connect(function()
		RD.Build:FireServer("fuse", row:GetAttribute("FusionKey"))
	end)
	fuseRows[i] = { row = row, icon = icon, name = nm, desc = ds, status = status, btn = go }
end

-- ---------------------------------------------------------------
-- 유물 · 결과 · 부활
-- ---------------------------------------------------------------
local relicLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 6, 10), 0.32, false, 35)
relicLayer.Visible = false
relicLayer.Active = true
local relicCard = frame(relicLayer, UDim2.new(0.9, 0, 0, 340), UDim2.new(0.05, 0, 0.5, -170), C.panel, 0, 10, 36)
stroke(relicCard, C.gold, 2)
local relicTitle = label(relicCard, UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 8), "보스 격파! 유물을 선택하세요", C.gold, FONT, 37)
relicTitle.TextXAlignment = Enum.TextXAlignment.Center
local relicButtons = {}
for i = 1, 4 do
	local b = button(relicCard, UDim2.new(1, -20, 0, 64), UDim2.new(0, 10, 0, 42 + (i - 1) * 72), "", C.panel2, 37)
	local nm = label(b, UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 8), "", C.text, FONT, 38)
	local ds = label(b, UDim2.new(1, -16, 0, 15), UDim2.new(0, 8, 0, 32), "", C.dim, FONT2, 38)
	b.Visible = false
	relicButtons[i] = { btn = b, name = nm, desc = ds }
end

local resultLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 6, 10), 0.15, false, 35)
resultLayer.Visible = false
resultLayer.Active = true
local resultCard = frame(resultLayer, UDim2.new(0.9, 0, 0, 250), UDim2.new(0.05, 0, 0.5, -125), C.panel, 0, 10, 36)
stroke(resultCard, C.cyan, 2)
local resultTitle = label(resultCard, UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 12), "", C.text, FONT, 37)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
local resultSub = label(resultCard, UDim2.new(1, -20, 0, 130), UDim2.new(0, 10, 0, 52), "", C.dim, FONT2, 37)
resultSub.TextXAlignment = Enum.TextXAlignment.Center
resultSub.TextScaled = false
resultSub.TextSize = 14
resultSub.TextWrapped = true
local resultClose = button(resultCard, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 196), "계속 보기", C.panel2, 37)

local reviveLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(30, 4, 8), 0.1, false, 36)
reviveLayer.Visible = false
reviveLayer.Active = true
local reviveCard = frame(reviveLayer, UDim2.new(0.9, 0, 0, 232), UDim2.new(0.05, 0, 0.5, -116), C.panel, 0, 10, 37)
stroke(reviveCard, C.red, 2)
local reviveTitle = label(reviveCard, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 10), "💥 넥서스 붕괴!", C.red, FONT, 38)
reviveTitle.TextXAlignment = Enum.TextXAlignment.Center
local reviveSub = label(reviveCard, UDim2.new(1, -20, 0, 50), UDim2.new(0, 10, 0, 42), "12초 안에 부활하면 이어서 싸웁니다", C.text, FONT2, 38)
reviveSub.TextXAlignment = Enum.TextXAlignment.Center
reviveSub.TextScaled = false
reviveSub.TextSize = 13
reviveSub.TextWrapped = true
local reviveUse = button(reviveCard, UDim2.new(1, -20, 0, 42), UDim2.new(0, 10, 0, 104), "💖 부활권 사용", Color3.fromRGB(70, 30, 40), 38)
local reviveBuy = button(reviveCard, UDim2.new(1, -20, 0, 42), UDim2.new(0, 10, 0, 154), "⚡ 즉시 부활 (25 R$)", Color3.fromRGB(80, 60, 20), 38)
local reviveGive = button(reviveCard, UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 200), "포기하고 결과 보기", C.panel2, 38)

-- ---------------------------------------------------------------
-- 인트로 (테마 · 종족 선택)
-- ---------------------------------------------------------------
local introLayer = frame(gui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(2, 5, 9), 0.06, false, 50)
introLayer.Active = true
introLayer.Visible = false
local introCard = frame(introLayer, UDim2.new(0.94, 0, 0.86, 0), UDim2.new(0.03, 0, 0.07, 0), C.panel, 0, 12, 51)
stroke(introCard, C.cyan, 1.6)
local introTitle = label(introCard, UDim2.new(1, -20, 0, 30), UDim2.new(0, 12, 0, 10), "🌌 터렛 디펜스 v3 · 우주 5아레나", C.cyan, FONT, 52)
local introSub = label(introCard, UDim2.new(1, -20, 0, 16), UDim2.new(0, 12, 0, 40), "맵 테마와 종족을 고르고, 자유롭게 건설하세요", C.dim, FONT2, 52)
introSub.TextScaled = false
introSub.TextSize = 12

local themeRow = frame(introCard, UDim2.new(1, -24, 0, 56), UDim2.new(0, 12, 0, 62), Color3.new(), 1, 6, 52)
local themeBtns = {}
for i, key in ipairs(Shared.THEME_ORDER) do
	local t = Shared.THEMES[key]
	local b = button(themeRow, UDim2.new(0.333, -4, 1, 0), UDim2.new((i - 1) / 3, 2, 0, 0), t.name, C.bg, 53)
	b.TextScaled = false
	b.TextSize = 15
	b.MouseButton1Click:Connect(function()
		RD.Prompt:FireServer("theme", key)
		selectTheme(key)
	end)
	themeBtns[key] = b
end

local factionRow = frame(introCard, UDim2.new(1, -24, 0, 170), UDim2.new(0, 12, 0, 126), Color3.new(), 1, 6, 52)
local factionBtns = {}
for i, f in ipairs(Shared.FACTIONS) do
	local col = (i - 1) % 3
	local row = math.floor((i - 1) / 3)
	local b = button(factionRow, UDim2.new(0.333, -4, 0.5, -4), UDim2.new(col / 3, 2, row / 2, 2), "", C.bg, 53)
	local icon = label(b, UDim2.new(0, 26, 0, 22), UDim2.new(0, 6, 0, 6), f.icon, f.color, FONT, 54)
	local nm = label(b, UDim2.new(1, -34, 0, 16), UDim2.new(0, 30, 0, 5), f.name, C.text, FONT, 54)
	local tg = label(b, UDim2.new(1, -10, 0, 12), UDim2.new(0, 6, 0, 26), f.tag, C.dim, FONT2, 54)
	tg.TextScaled = false
	tg.TextSize = 9
	local perk = label(b, UDim2.new(1, -10, 0, 12), UDim2.new(0, 6, 1, -18), f.perk, f.color, FONT2, 54)
	perk.TextScaled = false
	perk.TextSize = 9
	b.MouseButton1Click:Connect(function()
		RD.Prompt:FireServer("faction", f.key)
		selectFaction(f.key)
	end)
	factionBtns[f.key] = b
end

local introStart = button(introCard, UDim2.new(1, -24, 0, 46), UDim2.new(0, 12, 1, -56), "⚔ 전투 시작", Color3.fromRGB(30, 74, 66), 52)
introStart.TextScaled = false
introStart.TextSize = 20

local introHint = label(introCard, UDim2.new(1, -24, 0, 14), UDim2.new(0, 12, 1, -78), "이미 배치한 유닛은 그대로 · 종족을 바꾸면 다른 팀 아레나로 이동합니다", C.dim, FONT2, 52)
introHint.TextScaled = false
introHint.TextSize = 10

selectTheme = function(key)
	for k, b in pairs(themeBtns) do
		b.BackgroundColor3 = (k == key) and Color3.fromRGB(28, 66, 82) or C.bg
		b.TextColor3 = (k == key) and C.cyan or C.dim
	end
end

selectFaction = function(key)
	for k, b in pairs(factionBtns) do
		b.BackgroundColor3 = (k == key) and Color3.fromRGB(34, 56, 70) or C.bg
	end
end

openIntro = function()
	introLayer.Visible = true
	selectTheme(S.theme or "sf")
	selectFaction(S.faction)
end

introStart.MouseButton1Click:Connect(function()
	introLayer.Visible = false
	introDone = true
end)

-- ---------------------------------------------------------------
-- 데미지 숫자 풀
-- ---------------------------------------------------------------
local dmgGui = Instance.new("ScreenGui")
dmgGui.Name = "TD_Damage"
dmgGui.IgnoreGuiInset = true
dmgGui.ResetOnSpawn = false
dmgGui.DisplayOrder = 2
dmgGui.Parent = player:WaitForChild("PlayerGui")

local DMG_POOL = 30
local dmgPool, dmgActive = {}, {}
for i = 1, DMG_POOL do
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0, 110, 0, 26)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.25
	l.Font = FONT
	l.TextScaled = true
	l.Visible = false
	l.ZIndex = 5
	l.Parent = dmgGui
	dmgPool[i] = l
end

local function showDamage(worldPos, amount, hero)
	if amount < 1 then return end
	local lbl
	for _, l in ipairs(dmgPool) do
		if not l.Visible then
			lbl = l
			break
		end
	end
	if not lbl then return end
	lbl.Text = "−" .. Shared.short(amount)
	lbl.TextColor3 = hero and Color3.fromRGB(255, 180, 90) or (amount > 5000 and Color3.fromRGB(255, 225, 130) or Color3.fromRGB(240, 250, 255))
	lbl.TextSize = hero and 26 or 18
	lbl.Visible = true
	lbl.TextTransparency = 0
	table.insert(dmgActive, { label = lbl, pos = worldPos, t = 0, life = 0.9 })
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
-- 그리드 클릭 (자유 건설 · 유닛 선택 · 이동)
-- ---------------------------------------------------------------
local selectionBox = Instance.new("SelectionBox")
selectionBox.Name = "TD_Select"
selectionBox.LineThickness = 0.08
selectionBox.Color3 = Color3.fromRGB(120, 235, 255)
selectionBox.Adornee = nil
selectionBox.Parent = player:WaitForChild("PlayerGui")
selectionBox.Visible = false

local moveBox = Instance.new("SelectionBox")
moveBox.LineThickness = 0.06
moveBox.Color3 = Color3.fromRGB(255, 200, 90)
moveBox.Adornee = nil
moveBox.Parent = player:WaitForChild("PlayerGui")
moveBox.Visible = false

local function unitAt(col, row)
	for _, u in ipairs(S.units) do
		if u.col == col and u.row == row then return u end
	end
	return nil
end

local function posToColRow(pos)
	if not arenaModel then return nil end
	local localPos = arenaCF:PointToObjectSpace(pos)
	local N = Shared.UNIVERSE.GRID_N
	local CELL = Shared.UNIVERSE.CELL
	local col = math.floor((localPos.X + (N * CELL) / 2) / CELL) + 1
	local row = math.floor((localPos.Z + (N * CELL) / 2) / CELL) + 1
	if col < 1 or col > N or row < 1 or row > N then return nil end
	return col, row
end

local function selectUnit(col, row)
	local u = unitAt(col, row)
	if not u then
		S.selected = nil
		unitPanel.Visible = false
		selectionBox.Visible = false
		return
	end
	S.selected = { col = col, row = row }
	unitPanel.Visible = true
	local f = factionDef(u.faction)
	local form = f.forms[u.form or 1]
	if u.fusionKey then
		local def = Shared.FUSION_BY_KEY[u.fusionKey]
		unitTitle.Text = "🧬 " .. (def and def.name or "융합 유닛") .. " · " .. Shared.comma(u.dps) .. " DPS"
		unitSub.Text = "융합 유닛 · 스킬 " .. (def and def.skill or "") .. " (T" .. u.tier .. ")"
	else
		unitTitle.Text = f.icon .. " " .. form.name .. " T" .. u.tier .. ((u.star or 0) > 0 and (" ★" .. u.star) or "") .. " · " .. Shared.comma(u.dps) .. " DPS"
		unitSub.Text = form.tag .. " · " .. form.skill .. " (" .. Shared.TIER_NAMES[u.tier] .. ")"
	end
	uMode.Text = u.fusionKey and "🔄 없음" or ("🔄 모드" .. (u.modeCd > 0 and (" " .. u.modeCd .. "s") or ""))
	uSkill.Text = "✨ 스킬" .. (u.skillCd > 0 and (" " .. u.skillCd .. "s") or "")
	local cell = arenaModel and arenaModel:FindFirstChild("Cells")
	cell = cell and cell:FindFirstChild("Cell_" .. col .. "_" .. row)
	selectionBox.Adornee = cell
	selectionBox.Visible = true
end

local function clickWorld(pos)
	if not arenaModel then return end
	local cells = arenaModel:FindFirstChild("Cells")
	if not cells then return end
	local inset = select(1, GuiService:GetGuiInset())
	local ray = camera:ViewportPointToRay(pos.X - (inset and inset.X or 0), pos.Y - (inset and inset.Y or 0))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { cells }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if not result then
		S.selected = nil
		unitPanel.Visible = false
		selectionBox.Visible = false
		return
	end
	local hit = result.Instance
	local col = hit:GetAttribute("Col")
	local row = hit:GetAttribute("Row")
	if not col or not row then return end

	local unit = unitAt(col, row)
	if S.moveMode and S.selected then
		RD.Build:FireServer("move4", S.selected.col, S.selected.row, col, row)
		S.moveMode = false
		moveBox.Visible = false
		return
	end
	if unit then
		selectUnit(col, row)
		return
	end
	if S.hand[S.handIndex] then
		RD.Build:FireServer("place", S.handIndex, col, row)
		selectionBox.Adornee = hit
		selectionBox.Visible = true
	elseif S.selected then
		selectUnit(col, row)
	else
		selectionBox.Adornee = hit
		selectionBox.Visible = true
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if introLayer.Visible or fuseLayer.Visible or relicLayer.Visible or resultLayer.Visible or reviveLayer.Visible then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		clickWorld(input.Position)
	end
end)

-- ---------------------------------------------------------------
-- 버튼 연결
-- ---------------------------------------------------------------
drawBtn.MouseButton1Click:Connect(function() RD.Draw:FireServer() end)
mergeBtn.MouseButton1Click:Connect(function() RD.Merge:FireServer() end)
fusionBtn.MouseButton1Click:Connect(function()
	fuseLayer.Visible = true
	refreshFusions()
end)
fuseClose.MouseButton1Click:Connect(function() fuseLayer.Visible = false end)
atkBtn.MouseButton1Click:Connect(function() RD.Upgrade:FireServer("atk") end)
spdBtn.MouseButton1Click:Connect(function() RD.Upgrade:FireServer("spd") end)
supportBtn.MouseButton1Click:Connect(function() RD.Support:FireServer("strike") end)
repairBtn.MouseButton1Click:Connect(function() RD.Support:FireServer("repair") end)
shopBtn.MouseButton1Click:Connect(function() uiOpen:Fire("shop") end)
metaBtn.MouseButton1Click:Connect(function() uiOpen:Fire("meta") end)
themeBtn.MouseButton1Click:Connect(function() openIntro() end)
viewBtn.MouseButton1Click:Connect(function()
	S.view = (S.view % 3) + 1
	viewBtn.Text = (S.view == 1) and "👥\n아레나" or ((S.view == 2) and "👥\n근접" or "👥\n우주")
end)
reviveBtn.MouseButton1Click:Connect(function() RD.Prompt:FireServer("revive_use") end)
reviveUse.MouseButton1Click:Connect(function() RD.Prompt:FireServer("revive_use") end)
reviveBuy.MouseButton1Click:Connect(function() RD.Prompt:FireServer("product", "PRODUCT_REVIVE") end)
reviveGive.MouseButton1Click:Connect(function() reviveLayer.Visible = false end)
resultClose.MouseButton1Click:Connect(function() resultLayer.Visible = false end)

for i = 1, 4 do
	relicButtons[i].btn.MouseButton1Click:Connect(function()
		RD.PickRelic:FireServer(i)
	end)
end

uMode.MouseButton1Click:Connect(function()
	if S.selected then RD.Build:FireServer("mode", S.selected.col, S.selected.row) end
end)
uSkill.MouseButton1Click:Connect(function()
	if S.selected then RD.Build:FireServer("skill", S.selected.col, S.selected.row) end
end)
uMove.MouseButton1Click:Connect(function()
	if S.selected then
		S.moveMode = true
		local cell = arenaModel and arenaModel:FindFirstChild("Cells")
		cell = cell and cell:FindFirstChild("Cell_" .. S.selected.col .. "_" .. S.selected.row)
		moveBox.Adornee = cell
		moveBox.Visible = true
		toastTitle.Text = "↔ 이동 모드"
		toastSub.Text = "옮길 타일을 누르세요"
		toast.Visible = true
		task.delay(2, function() toast.Visible = false end)
	end
end)
uSell.MouseButton1Click:Connect(function()
	if S.selected then
		RD.Build:FireServer("sell", S.selected.col, S.selected.row)
		S.selected = nil
		unitPanel.Visible = false
		selectionBox.Visible = false
	end
end)

-- ---------------------------------------------------------------
-- UI 갱신 함수
-- ---------------------------------------------------------------
local function setText(lbl, txt, color)
	lbl.Text = txt
	if color then lbl.TextColor3 = color end
end

refreshHand = function()
	if #S.hand > 0 and (S.handIndex < 1 or S.handIndex > #S.hand) then
		S.handIndex = 1
	end
	for i = 1, 4 do
		local cell = handCells[i]
		local item = S.hand[i]
		if item then
			local f = factionDef(item.faction)
			cell.btn.Visible = true
			cell.btn.BackgroundColor3 = (i == S.handIndex) and Color3.fromRGB(40, 66, 82) or C.bg
			cell.btn.Text = ""
			setText(cell.title, "T" .. item.tier .. " " .. f.icon .. f.name, TIER_COLORS[item.tier])
			setText(cell.sub, item.support and "지원" or ("모드" .. item.form), item.support and C.violet or C.dim)
			if cell.stroke then
				cell.stroke.Color = (i == S.handIndex) and C.cyan or C.line
				cell.stroke.Thickness = (i == S.handIndex) and 2 or 1
			end
		else
			cell.btn.BackgroundColor3 = C.bg
			setText(cell.title, "", C.dim)
			setText(cell.sub, i == 1 and "뽑기" or "", C.dim)
			if cell.stroke then
				cell.stroke.Color = C.line
				cell.stroke.Thickness = 1
			end
		end
	end
end

refreshFusions = function()
	for i = 1, 5 do
		local row = fuseRows[i]
		local f = S.fusions[i]
		if f then
			row.row.Visible = true
			row.row:SetAttribute("FusionKey", f.key)
			setText(row.icon, f.icon, C.violet)
			setText(row.name, f.name)
			setText(row.desc, f.desc, C.dim)
			local have = (f.haveA or 0) .. "/" .. f.needA .. " · " .. (f.haveB or 0) .. "/" .. f.needB
			setText(row.status, have .. (f.ready and "  ✅ 가능" or ""), f.ready and C.green or C.gold)
			row.btn.BackgroundColor3 = f.ready and Color3.fromRGB(70, 48, 104) or C.dark
			row.btn.Active = f.ready
		else
			row.row.Visible = false
		end
	end
	fuseInfo.Text = "서로 다른 종족 유닛 3 + 2를 합치면 고유 융합 유닛이 탄생합니다 (융합 마스터 패스: 2 + 1)."
		.. " 타 종족 유닛은 영웅 처치 · 지원 소환권(39 R$)로 얻습니다."
end

refreshRank = function()
	local list = S.rank or {}
	local boss = S.phase == "boss"
	setText(rankMode, boss and "BOSS DMG RANK" or "STAGE RACE", boss and Color3.fromRGB(255, 140, 150) or C.dim)
	for i = 1, 5 do
		local row = rankRows[i]
		local e = list[i]
		if e then
			row.row.Visible = true
			local f = factionDef(e.faction)
			row.row.BackgroundColor3 = e.isMe and Color3.fromRGB(30, 54, 66) or C.bg
			row.medal.Text = (e.rank == 1 and "🥇") or (e.rank == 2 and "🥈") or (e.rank == 3 and "🥉") or tostring(e.rank)
			row.icon.Text = f.icon
			row.nameL.Text = e.ai and (f.name .. " AI") or (e.player or f.name)
			row.nameL.TextColor3 = e.isMe and C.gold or f.color
			if boss then
				row.valL.Text = string.format("%.1f%%", e.pct) .. " · " .. Shared.short(e.dps)
			else
				row.valL.Text = "S" .. e.stage .. " · " .. Shared.short(e.dps)
			end
			row.row.Visible = true
		else
			row.row.Visible = false
		end
	end
end

applyState = function(d)
	S.phase = d.phase or "stage"
	S.stage = d.stage or 0
	S.maxStage = d.maxStage or Shared.MAX_STAGE
	S.stageActive = d.stageActive
	S.stageTimer = d.stageTimer or 0
	S.spawned = d.spawned or 0
	S.stageTotal = d.stageTotal or 100
	S.tierName = d.tierName or ""
	S.core = d.core or 0
	S.coreMax = d.coreMax or 30
	S.minerals = d.minerals or 0
	S.gas = d.gas or 0
	S.gems = d.gems or 0
	S.atkLv = d.atkLv or 0
	S.spdLv = d.spdLv or 0
	S.units = d.units or {}
	S.hand = d.hand or {}
	S.fusions = d.fusions or {}
	S.rank = d.rank or {}
	S.boss = d.boss
	S.downed = d.downed == true
	S.reviveStock = d.reviveStock or 0
	S.expanded = d.expanded == true
	S.theme = d.theme or S.theme
	S.faction = d.faction or S.faction
	S.teamName = d.teamName or S.teamName
	S.boostDmg = d.boostDmg or 0
	S.teamBoost = d.teamBoost or 0
	S.passes = d.passes or {}

	if d.team and d.team ~= S.team then
		S.team = d.team
		resolveArena()
	end

	setText(stageLabel, S.stage .. " / " .. S.maxStage)
	setText(stageSub, S.stageActive and ((S.spawned .. "/" .. S.stageTotal)) or (S.tierName ~= "" and S.tierName or "준비"), S.stageActive and C.green or C.dim)
	setText(coreText, S.core .. " / " .. S.coreMax)
	local frac = math.clamp(S.core / math.max(1, S.coreMax), 0, 1)
	coreFill.Size = UDim2.new(frac, 0, 1, 0)
	coreFill.BackgroundColor3 = frac > 0.5 and C.green or (frac > 0.25 and C.gold or C.red)
	local prog = (S.stageActive and S.spawned > 0) and math.clamp(S.spawned / math.max(1, S.stageTotal), 0, 1) or 0
	stageBar.Size = UDim2.new(prog, 0, 1, 0)
	stageBar.BackgroundColor3 = (S.phase == "boss") and Color3.fromRGB(255, 110, 130) or C.green

	setText(minLabel, Shared.comma(S.minerals))
	setText(gasLabel, Shared.comma(S.gas))
	setText(atkTitle, "⚔ 공격력 Lv." .. S.atkLv)
	setText(atkSub, "⛽ " .. (25 + S.atkLv * 12), S.gas >= (25 + S.atkLv * 12) and C.green or C.red)
	setText(spdTitle, "⚡ 공속 Lv." .. S.spdLv)
	setText(spdSub, "⛽ " .. (30 + S.spdLv * 14), S.gas >= (30 + S.spdLv * 14) and C.green or C.red)
	setText(gemLabel, "💠 " .. Shared.comma(S.gems))

	local f = factionDef(S.faction)
	setText(teamLabel, f.icon .. " " .. (S.teamName or f.name) .. " 팀 · 자유 건설 " .. (S.expanded and "8×8" or "6×6"), f.color)

	local st
	if S.phase == "boss" then
		st = "👁️ 최종 보스 레이드 · 중앙에 총공격!"
	elseif S.downed then
		st = "💥 넥서스 붕괴 · 부활 대기 " .. (d.reviveSeconds or 0) .. "초"
	elseif S.stageActive then
		st = "웨이브 진행 · W" .. S.stage .. " · 남은 적 " .. (d.alive or 0)
	else
		st = "다음 스테이지 " .. S.stageTimer .. "초"
	end
	setText(statusLabel, st, S.phase == "boss" and Color3.fromRGB(255, 160, 170) or C.dim)

	local buffs = {}
	if S.boostDmg > 0 then table.insert(buffs, "⚡ 과충전 " .. math.ceil(S.boostDmg / 60) .. "m") end
	if S.teamBoost > 0 then table.insert(buffs, "🎁 팀버프 " .. math.ceil(S.teamBoost / 60) .. "m") end
	if S.passes and S.passes.vip then table.insert(buffs, "👑VIP") end
	if S.passes and S.passes.fusion then table.insert(buffs, "🧬융합") end
	if S.passes and S.passes.arena then table.insert(buffs, "🏗️확장") end
	if S.passes and S.passes.auto then table.insert(buffs, "🤖자동") end
	if S.passes and S.passes.luck then table.insert(buffs, "🍀럭키") end
	setText(buffLabel, table.concat(buffs, "  "), C.gold)

	-- 보스 바
	if S.boss then
		bossBar.Visible = true
		bossFill.Size = UDim2.new(math.clamp(S.boss.hp / math.max(1, S.boss.maxHp), 0, 1), 0, 1, 0)
		setText(bossName, "👁️ 오메가 파괴신 · " .. Shared.short(S.boss.hp) .. " / " .. Shared.short(S.boss.maxHp))
		setText(bossTime, "⏳ " .. S.boss.time .. "s", C.gold)
	else
		bossBar.Visible = false
	end

	setText(reviveBtn, "💖\n부활 " .. S.reviveStock)

	-- 선택된 유닛 정보 갱신
	if S.selected then
		local u = unitAt(S.selected.col, S.selected.row)
		if u then
			local ff = factionDef(u.faction)
			if u.fusionKey then
				local def = Shared.FUSION_BY_KEY[u.fusionKey]
				setText(unitTitle, "🧬 " .. (def and def.name or "융합") .. " · " .. Shared.comma(u.dps) .. " DPS")
				setText(unitSub, "융합 유닛 · 스킬 " .. (def and def.skill or ""), C.violet)
			else
				local form = ff.forms[u.form or 1]
				setText(unitTitle, ff.icon .. " " .. form.name .. " T" .. u.tier .. ((u.star or 0) > 0 and (" ★" .. u.star) or "") .. " · " .. Shared.comma(u.dps) .. " DPS")
				setText(unitSub, form.tag .. " · " .. form.skill, C.dim)
			end
			uMode.Text = u.fusionKey and "🔄 없음" or ("🔄 모드" .. (u.modeCd > 0 and (" " .. u.modeCd .. "s") or ""))
			uSkill.Text = "✨ 스킬" .. (u.skillCd > 0 and (" " .. u.skillCd .. "s") or "")
		else
			S.selected = nil
			unitPanel.Visible = false
			selectionBox.Visible = false
		end
	end

	refreshHand()
	refreshRank()
	if fuseLayer.Visible then refreshFusions() end
end

-- ---------------------------------------------------------------
-- 서버 이벤트
-- ---------------------------------------------------------------
RD.State.OnClientEvent:Connect(function(d)
	local e = d.event
	if e == "state" then
		applyState(d)
	elseif e == "assigned" then
		S.team = d.team
		S.faction = d.faction or S.faction
		S.teamName = d.teamName
		S.theme = d.theme or S.theme
		S.expanded = d.expanded == true
		resolveArena()
		if not introDone then
			openIntro()
		end
	elseif e == "toast" then
		toastTitle.Text = d.title or ""
		toastSub.Text = d.sub or ""
		toast.Visible = true
		toastStroke.Color = d.tier and TIER_COLORS[math.clamp(d.tier, 1, 5)] or C.cyan
		task.delay(1.8, function()
			toast.Visible = false
		end)
	elseif e == "banner" then
		banner.Text = (d.title or "") .. ((d.sub and d.sub ~= "") and ("\n" .. d.sub) or "")
		banner.TextColor3 = d.color or C.gold
		banner.TextTransparency = 0
		banner.TextSize = 32
		task.delay(2.2, function()
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
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
		reviveSub.Text = "12초 안에 부활하면 이어서 싸웁니다\n남은 부활권 " .. (d.stock or 0) .. "장"
		reviveUse.Text = (d.stock or 0) > 0 and "💖 부활권 사용" or "부활권 없음"
		reviveUse.BackgroundColor3 = (d.stock or 0) > 0 and Color3.fromRGB(80, 30, 44) or Color3.fromRGB(40, 32, 34)
		task.spawn(function()
			local left = d.seconds or 12
			while left > 0 and reviveLayer.Visible do
				reviveTitle.Text = "💥 넥서스 붕괴! " .. left .. "초"
				task.wait(1)
				left = left - 1
			end
			reviveTitle.Text = "💥 넥서스 붕괴!"
			reviveLayer.Visible = false
		end)
	elseif e == "win" then
		reviveLayer.Visible = false
		resultLayer.Visible = true
		setText(resultTitle, "🏆 오메가 파괴신 격파!", C.cyan)
		setText(resultSub, "STAGE " .. (d.stage or 0) .. " · 보석 +" .. (d.gems or 0)
			.. "\n보스 누적 딜량 " .. Shared.comma(d.bossDamage or 0)
			.. "\n최고 기록 STAGE " .. (d.best or 0) .. " · 잠시 후 새 판", C.text)
	elseif e == "lose" then
		reviveLayer.Visible = false
		resultLayer.Visible = true
		setText(resultTitle, "넥서스 붕괴", C.red)
		setText(resultSub, "도달 STAGE " .. (d.stage or 0) .. " · 보석 +" .. (d.gems or 0)
			.. "\n최고 기록 STAGE " .. (d.best or 0)
			.. "\n부활권을 미리 준비하면 1탭으로 되살아납니다", C.text)
	elseif e == "restart" then
		resultLayer.Visible = false
		reviveLayer.Visible = false
		relicLayer.Visible = false
		S.selected = nil
		unitPanel.Visible = false
		banner.Text = "새 판 시작!"
		banner.TextTransparency = 0
		task.delay(1.3, function()
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end)
	elseif e == "drawn" then
		drawBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 140)
		task.delay(0.2, function()
			drawBtn.BackgroundColor3 = Color3.fromRGB(23, 65, 79)
		end)
	elseif e == "theme" then
		S.theme = d.theme
		selectTheme(d.theme)
	elseif e == "metaDirty" then
		setText(gemLabel, "💠 " .. Shared.comma(player:GetAttribute("Gems") or 0))
	end
end)

RD.FX.OnClientEvent:Connect(function(d)
	if d.kind == "dmg" then
		for _, entry in ipairs(d.entries or {}) do
			showDamage(entry.pos, entry.amount or 0, entry.hero)
		end
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
	elseif d.kind == "heroWarn" then
		toastTitle.Text = "👑 영웅 몬스터 출현"
		toastSub.Text = "2배 크기 · 처치하면 보너스 드롭"
		toastStroke.Color = C.gold
		toast.Visible = true
		task.delay(2, function() toast.Visible = false end)
	elseif d.kind == "bossWarn" then
		banner.Text = "⚠ FINAL BOSS\n오메가 파괴신 출현!"
		banner.TextColor3 = Color3.fromRGB(255, 110, 120)
		banner.TextTransparency = 0
		banner.TextSize = 38
		flash.BackgroundColor3 = Color3.fromRGB(255, 70, 80)
		flash.Visible = true
		flash.BackgroundTransparency = 0.75
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		shakeT = 0.6
		shakeAmp = 5
		task.delay(3, function()
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end)
	elseif d.kind == "modeSwitch" then
		-- 모드 전환 연출은 서버 파티클로 처리됩니다
	elseif d.kind == "skill" then
		flash.BackgroundColor3 = d.color or C.violet
		flash.Visible = true
		flash.BackgroundTransparency = 0.8
		TweenService:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		task.delay(0.3, function() flash.Visible = false end)
	elseif d.kind == "stageStart" then
		stageBar.Size = UDim2.new(0, 0, 1, 0)
	elseif d.kind == "restart" then
		S.selected = nil
		unitPanel.Visible = false
		selectionBox.Visible = false
	end
end)

player:GetAttributeChangedSignal("Gems"):Connect(function()
	setText(gemLabel, "💠 " .. Shared.comma(player:GetAttribute("Gems") or 0))
end)
player:GetAttributeChangedSignal("ReviveStock"):Connect(function()
	setText(reviveBtn, "💖\n부활 " .. (player:GetAttribute("ReviveStock") or 0))
end)

print("[TD] 04_ClientHUD 준비 완료 — 우주 5아레나 HUD v" .. Shared.VERSION)
