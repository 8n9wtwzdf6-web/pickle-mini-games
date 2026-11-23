--[[ ============================================================
  02_WaveGachaMerge.server.lua
  🍀 운빨·조합 터렛 디펜스 — 4인 협동 게임 서버
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService (일반 Script)
  반드시 01_MapAndTurrets 를 먼저 실행해야 합니다.
  담당
    · 접속한 플레이어를 P1~P4 라인에 자동 배정 (최대 4인 협동)
    · 20웨이브 + 5웨이브마다 보스(넥서스 공성) + 유물 3지선다
    · 랜덤 뽑기(미네랄) · 같은 터렛 2개 합성 진화(★3까지) · 공용 가스 강화
    · 터렛 360° 추적 · 반동 · 투사체/레이저 · 피격/폭발 이펙트
    · 클라이언트 HUD와 상태 동기화 (ReplicatedStorage.TD_State)
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- ---------------------------------------------------------------
-- CONFIG (01과 동일해야 함)
-- ---------------------------------------------------------------
local LANE_X = { -13.5, -4.5, 4.5, 13.5 }
local LANE_COLORS = {
	Color3.fromRGB(79, 216, 255),
	Color3.fromRGB(92, 255, 176),
	Color3.fromRGB(176, 123, 255),
	Color3.fromRGB(255, 194, 77),
}
local LANE_NAMES = { "P1", "P2", "P3", "P4" }
local SLOT_Z = { -20, -6, 8, 22 }
local VIP_SLOT_Z = 32
local SLOT_X_OFF = -2.3
local ENEMY_X_OFF = 2.3
local NEXUS_POS = Vector3.new(0, 0, 32)
local PATH_Z0, PATH_Z1 = -31, 27

local MAX_WAVE = 20
local GACHA_COST = 18
local GACHA_W = { 0.62, 0.27, 0.08, 0.025, 0.005 }
local CORE_MAX = 30

local TIER_NAMES = { "일반", "희귀", "영웅", "전설", "신화" }
local TIER_COLORS = {
	Color3.fromRGB(184, 198, 210),
	Color3.fromRGB(62, 155, 255),
	Color3.fromRGB(169, 115, 255),
	Color3.fromRGB(255, 194, 77),
	Color3.fromRGB(255, 91, 209),
}

-- 터렛 10종: kind 1 = 단일 화력, 2 = 범위/특수
local TURRETS = {
	{ -- 일반
		{ name = "머린 터렛", dmg = 9, cd = 0.52, range = 22, shots = 1, proj = "bullet", speed = 190, splash = 0 },
		{ name = "기관총 터렛", dmg = 4, cd = 0.42, range = 21, shots = 3, proj = "bullet", speed = 200, splash = 0 },
	},
	{ -- 희귀
		{ name = "화염방사 터렛", dmg = 7, cd = 0.13, range = 20, shots = 1, proj = "flame", speed = 120, splash = 3 },
		{ name = "파이어뱃 포탑", dmg = 19, cd = 0.36, range = 22, shots = 2, proj = "flame", speed = 110, splash = 7 },
	},
	{ -- 영웅
		{ name = "미사일 포탑", dmg = 66, cd = 0.39, range = 27, shots = 1, proj = "missile", speed = 95, splash = 7 },
		{ name = "발키리 포탑", dmg = 17, cd = 0.20, range = 26, shots = 2, proj = "missile", speed = 100, splash = 9 },
	},
	{ -- 전설
		{ name = "시즈 캐논", dmg = 256, cd = 0.49, range = 31, shots = 1, proj = "shell", speed = 140, splash = 11 },
		{ name = "배틀크루저 포탑", dmg = 104, cd = 0.20, range = 30, shots = 1, proj = "beam", speed = 0, splash = 4 },
	},
	{ -- 신화
		{ name = "다크 템플러 타워", dmg = 356, cd = 0.198, range = 34, shots = 1, proj = "beam", speed = 0, splash = 7 },
		{ name = "아콘 레이저 타워", dmg = 536, cd = 0.30, range = 34, shots = 1, proj = "beam", speed = 0, splash = 5 },
	},
}

local ENEMIES = {
	zergling = { model = "zergling", hp = 1.0, reward = 2 },
	hydra = { model = "hydra", hp = 1.8, reward = 3 },
	roach = { model = "roach", hp = 3.0, reward = 4 },
	mutalisk = { model = "mutalisk", hp = 1.6, reward = 3 },
	boss = { model = "boss", hp = 15, reward = 80 },
}

local RELICS = {
	{ key = "atk", name = "화력 증폭", desc = "모든 터렛 공격력 +25%" },
	{ key = "spd", name = "초전도 장전", desc = "모든 터렛 공격속도 +20%" },
	{ key = "range", name = "정밀 조준", desc = "사거리 +18%" },
	{ key = "minerals", name = "미네랄 채굴기", desc = "미네랄 획득 +35%" },
	{ key = "gas", name = "가스 정제소", desc = "가스 획득 +40%" },
	{ key = "luck", name = "행운의 뽑기", desc = "희귀 이상 확률 ×1.6" },
	{ key = "boom", name = "폭발 탄두", desc = "30% 확률로 범위 폭발" },
	{ key = "shield", name = "코어 실드", desc = "넥서스 최대 HP +6 및 회복" },
	{ key = "bounty", name = "전리품 사냥", desc = "적 처치 미네랄 +2" },
	{ key = "auto", name = "자동 합성 장치", desc = "합성 가능 시 자동 진화" },
}

-- ---------------------------------------------------------------
-- 상태
-- ---------------------------------------------------------------
local Game = {
	wave = 0,
	waveActive = false,
	timer = 12,
	core = CORE_MAX,
	coreMax = CORE_MAX,
	gas = 30,
	atkLv = 0,
	spdLv = 0,
	speed = 1,
	relics = {},
	bossWave = false,
	bossLane = 0,
	relicChoices = {},
	relicPending = false,
	over = false,
	kills = 0,
}

local arena = Workspace:WaitForChild("TDArena")
local padsFolder = arena:WaitForChild("Pads")
local nexus = arena:WaitForChild("Nexus")
local nexusCrystal = nexus:FindFirstChild("Crystal")
local nexusFill = nexusCrystal and nexusCrystal:FindFirstChild("NexusHP") and nexusCrystal.NexusHP:FindFirstChild("Fill")
local nexusText = nexusFill and nexusFill.Parent:FindFirstChildOfClass("TextLabel")

local enemyFolder = Instance.new("Folder")
enemyFolder.Name = "TD_EnemiesLive"
enemyFolder.Parent = Workspace
local projFolder = Instance.new("Folder")
projFolder.Name = "TD_Projectiles"
projFolder.Parent = Workspace
local fxFolder = Instance.new("Folder")
fxFolder.Name = "TD_FX"
fxFolder.Parent = Workspace

local enemyTemplates = ReplicatedStorage:WaitForChild("TD_Enemies")
local turretTemplates = ReplicatedStorage:WaitForChild("TD_Turrets")

-- ---------------------------------------------------------------
-- 플레이어 → 라인 배정
-- ---------------------------------------------------------------
local laneOwner = { nil, nil, nil, nil }
local playerLane = {}
local playerMinerals = {}
local playerStats = {}

Players.CharacterAutoLoads = false

local function assignLane(player)
	for lane = 1, 4 do
		if laneOwner[lane] == nil then
			laneOwner[lane] = player
			playerLane[player] = lane
			playerMinerals[player] = 100
			playerStats[player] = { draws = 0, merges = 0, pity = 0 }
			player:SetAttribute("Lane", lane)
			player:SetAttribute("Minerals", 100)
			return lane
		end
	end
	return nil
end

-- ---------------------------------------------------------------
-- 터렛
-- ---------------------------------------------------------------
local pads = {}          -- pads[lane][slot] = record
local padList = {}

local function padCF(lane, slot)
	return CFrame.new(LANE_X[lane] + SLOT_X_OFF, 0.35, SLOT_Z[slot] or VIP_SLOT_Z)
end

local function collectPads()
	local children = padsFolder:GetChildren()
	table.sort(children, function(a, b)
		local la, sa = a:GetAttribute("Lane") or 0, a:GetAttribute("Slot") or 0
		local lb, sb = b:GetAttribute("Lane") or 0, b:GetAttribute("Slot") or 0
		if la == lb then return sa < sb end
		return la < lb
	end)
	for _, pad in ipairs(children) do
		local lane = pad:GetAttribute("Lane")
		local slot = pad:GetAttribute("Slot")
		if lane and slot then
			pads[lane] = pads[lane] or {}
			pads[lane][slot] = { pad = pad, tier = 0, kind = 0, star = 0, model = nil, heads = {}, cd = 0, yaw = 0, target = nil }
			table.insert(padList, { lane = lane, slot = slot, rec = pads[lane][slot] })
		end
	end
end
collectPads()

local function statsFor(rec)
	if rec.tier <= 0 then return nil end
	local def = TURRETS[rec.tier][rec.kind]
	local starMul = 1 + 0.35 * (rec.star or 0)
	local atkMul = (1 + Game.atkLv * 0.12) * (1 + 0.25 * (Game.relics.atk or 0))
	local spdMul = (1 + Game.spdLv * 0.08) * (1 + 0.20 * (Game.relics.spd or 0))
	local padOwner = laneOwner[rec.pad:GetAttribute("Lane")]
	if padOwner and padOwner:GetAttribute("Pass2x") then spdMul = spdMul * 1.25 end
	local rangeMul = 1 + 0.18 * (Game.relics.range or 0)
	return {
		def = def,
		dmg = def.dmg * starMul * atkMul,
		cd = math.max(0.06, def.cd / spdMul),
		range = def.range * rangeMul,
		dps = (def.dmg * starMul * atkMul * def.shots) / math.max(0.06, def.cd / spdMul),
	}
end

local function clearTurret(rec)
	if rec.model then
		rec.model:Destroy()
		rec.model = nil
	end
	rec.heads = {}
	rec.tier = 0
	rec.kind = 0
	rec.star = 0
	rec.pad:SetAttribute("Tier", 0)
	rec.pad:SetAttribute("Kind", 0)
	rec.pad:SetAttribute("Star", 0)
	local ring = rec.pad:FindFirstChild("Ring")
	if ring then ring.Color = LANE_COLORS[rec.pad:GetAttribute("Lane")] end
end

local function installTurret(rec, tier, kind, star, owner)
	clearTurret(rec)
	local templateName = "T" .. tier .. "_" .. kind
	local template = turretTemplates:FindFirstChild(templateName)
	if not template then return nil end
	local model = template:Clone()
	model.Parent = Workspace.TDArena
	local baseCF = padCF(rec.pad:GetAttribute("Lane"), rec.pad:GetAttribute("Slot"))
	model:PivotTo(baseCF * CFrame.new(0, 0.1, 0))
	rec.model = model
	rec.tier = tier
	rec.kind = kind
	rec.star = star or 0
	rec.cd = math.random() * 0.2
	rec.heads = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Head" then
			table.insert(rec.heads, { part = p, offset = baseCF:ToObjectSpace(p.CFrame) })
		end
	end
	rec.pad:SetAttribute("Tier", tier)
	rec.pad:SetAttribute("Kind", kind)
	rec.pad:SetAttribute("Star", rec.star)
	rec.pad:SetAttribute("Owner", owner or 0)
	local ring = rec.pad:FindFirstChild("Ring")
	if ring then ring.Color = TIER_COLORS[tier] end
	return rec
end

-- ---------------------------------------------------------------
-- 적
-- ---------------------------------------------------------------
local enemies = {}

local mergeLen = {}
for lane = 1, 4 do
	local dx = LANE_X[lane] + ENEMY_X_OFF
	mergeLen[lane] = math.sqrt(dx * dx + (NEXUS_POS.Z - PATH_Z1) ^ 2)
end

local function posAt(lane, dist)
	local lx = LANE_X[lane] + ENEMY_X_OFF
	local straight = PATH_Z1 - PATH_Z0
	if dist <= straight then
		return Vector3.new(lx, 1.4, PATH_Z0 + dist)
	end
	local t = math.clamp((dist - straight) / mergeLen[lane], 0, 1)
	return Vector3.new(lx * (1 - t), 1.4, PATH_Z1 + t * (NEXUS_POS.Z - PATH_Z1))
end

local function totalLen(lane)
	return (PATH_Z1 - PATH_Z0) + mergeLen[lane]
end

local function spawnEnemy(kind, lane)
	local tpl = enemyTemplates:FindFirstChild(ENEMIES[kind].model or kind)
	if not tpl then return nil end
	if lane == nil then lane = math.random(1, 4) end
	local model = tpl:Clone()
	model.Parent = enemyFolder
	local isBoss = tpl:GetAttribute("Boss") or false
	local baseHp = 60 * (1.262 ^ math.max(0, Game.wave - 1))
	local hp = math.max(40, baseHp * (ENEMIES[kind].hp or 1))
	local e = {
		kind = kind,
		lane = lane,
		dist = 0,
		hp = hp,
		maxHp = hp,
		model = model,
		alive = true,
		speed = tpl:GetAttribute("Speed") or 8,
		armor = tpl:GetAttribute("Armor") or 0,
		reward = tpl:GetAttribute("Reward") or 2,
		coreDamage = tpl:GetAttribute("CoreDamage") or 1,
		air = tpl:GetAttribute("Air") or false,
		boss = isBoss,
		siegeT = 2.0,
		ownerLane = lane,
	}
	if e.air then
		e.airLaneX = LANE_X[lane] + ENEMY_X_OFF
	end
	model:PivotTo(CFrame.new(posAt(lane, 0)))
	-- 체력바
	local hpGui = Instance.new("BillboardGui")
	hpGui.Size = UDim2.fromScale(isBoss and 9 or 3.2, isBoss and 1.4 or 0.5)
	hpGui.StudsOffset = Vector3.new(0, isBoss and 9 or 4.6, 0)
	hpGui.AlwaysOnTop = true
	hpGui.Parent = model.PrimaryPart
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(6, 10, 14)
	bg.BorderSizePixel = 0
	bg.Parent = hpGui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 0.7)
	fill.Position = UDim2.fromScale(0, 0.15)
	fill.BackgroundColor3 = isBoss and Color3.fromRGB(255, 120, 90) or Color3.fromRGB(120, 255, 160)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	e.hpFill = fill
	table.insert(enemies, e)
	return e
end

local function burst(pos, color, count, size)
	for i = 1, count do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(size, size, size)
		p.Position = pos
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Parent = fxFolder
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		local target = pos + dir * math.random(3, 9)
		local tw = TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			Transparency = 1,
			Size = Vector3.new(size * 0.2, size * 0.2, size * 0.2),
		})
		tw:Play()
		Debris:AddItem(p, 0.5)
	end
end

local function ringFX(pos, color, radius)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Parent = fxFolder
	TweenService:Create(ring, TweenInfo.new(0.5), { Size = Vector3.new(0.2, radius * 5, radius * 5), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.55)
end

local function damageEnemy(e, amount, doBoom)
	if not e.alive then return end
	local dmg = amount * (1 - (e.armor or 0))
	e.hp = e.hp - dmg
	if doBoom and math.random() < 0.3 then
		for _, other in ipairs(enemies) do
			if other.alive and other ~= e and (other.model.PrimaryPart.Position - e.model.PrimaryPart.Position).Magnitude < 10 then
				other.hp = other.hp - amount * 0.4
			end
		end
		ringFX(e.model.PrimaryPart.Position, Color3.fromRGB(255, 176, 58), 6)
	end
	if e.hp <= 0 then
		e.alive = false
		e.model:Destroy()
		Game.kills = Game.kills + 1
		local owner = laneOwner[e.lane]
		if owner then
			local gain = math.round(e.reward * (1 + 0.35 * (Game.relics.minerals or 0)) + 2 * (Game.relics.bounty or 0))
			playerMinerals[owner] = (playerMinerals[owner] or 0) + gain
		end
		burst(e.model and e.model.PrimaryPart and e.model.PrimaryPart.Position or Vector3.new(), e.boss and Color3.fromRGB(255, 176, 58) or Color3.fromRGB(255, 120, 60), e.boss and 26 or 6, e.boss and 2 or 1.1)
		ringFX(e.model and e.model.PrimaryPart and e.model.PrimaryPart.Position or Vector3.new(), e.boss and Color3.fromRGB(255, 194, 77) or Color3.fromRGB(255, 120, 60), e.boss and 18 or 4)
		if e.boss then
			Game.gas = Game.gas + 40
			openRelicPick()
		end
	end
end

-- ---------------------------------------------------------------
-- 투사체
-- ---------------------------------------------------------------
local projectiles = {}

local function fireTurret(rec, stats, target)
	local def = stats.def
	local basePos = rec.pad.PrimaryPart.Position + Vector3.new(0, 3.2, 0)
	local muzzlePos = basePos + Vector3.new(0, 0, -3)
	for _, h in ipairs(rec.heads) do
		if h.part.Name == "HeadMuzzle" or h.part.Name == "HeadTip1" then
			muzzlePos = h.part.Position
			break
		end
	end
	if def.proj == "beam" then
		local pos = muzzlePos
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = (rec.tier >= 5) and Color3.fromRGB(255, 120, 220) or Color3.fromRGB(140, 225, 255)
		p.Size = Vector3.new(0.4, 0.4, (target.model.PrimaryPart.Position - pos).Magnitude)
		p.CFrame = CFrame.lookAt(pos, target.model.PrimaryPart.Position) * CFrame.new(0, 0, -p.Size.Z / 2)
		p.Parent = fxFolder
		Debris:AddItem(p, 0.16)
		TweenService:Create(p, TweenInfo.new(0.16), { Transparency = 1 }):Play()
		damageEnemy(target, stats.dmg, (Game.relics.boom or 0) > 0)
		if def.splash > 0 then
			for _, other in ipairs(enemies) do
				if other.alive and other ~= target and (other.model.PrimaryPart.Position - target.model.PrimaryPart.Position).Magnitude < def.splash then
					damageEnemy(other, stats.dmg * 0.4, false)
				end
			end
		end
		return
	end

	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.9, 0.9, 0.9)
	p.Position = muzzlePos
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = TIER_COLORS[rec.tier]
	p.Parent = projFolder
	table.insert(projectiles, {
		part = p,
		target = target,
		dmg = stats.dmg,
		speed = def.speed,
		splash = def.splash,
		life = 3,
		tier = rec.tier,
	})
end

-- ---------------------------------------------------------------
-- 터렛 사격/회전 업데이트
-- ---------------------------------------------------------------
local function updateTurret(rec, dt)
	if rec.tier <= 0 or not rec.model then return end
	local stats = statsFor(rec)
	if not stats then return end
	local basePos = rec.pad.PrimaryPart.Position

	-- 타깃 찾기 (사거리 내 가장 앞선 적)
	local best, bestScore = nil, -math.huge
	for _, e in ipairs(enemies) do
		if e.alive then
			local d = (e.model.PrimaryPart.Position - basePos).Magnitude
			if d <= stats.range then
				local score = e.dist + (e.boss and 40 or 0)
				if score > bestScore then bestScore = score; best = e end
			end
		end
	end
	rec.target = best

	if best then
		local to = best.model.PrimaryPart.Position - basePos
		local yaw = math.atan2(-to.X, -to.Z)
		local delta = ((yaw - rec.yaw + math.pi * 3) % (math.pi * 2)) - math.pi
		rec.yaw = rec.yaw + delta * math.min(1, dt * 9)
		local padBase = padCF(rec.pad:GetAttribute("Lane"), rec.pad:GetAttribute("Slot")) * CFrame.new(0, 0.1, 0)
		for _, h in ipairs(rec.heads) do
			h.part.CFrame = padBase * CFrame.Angles(0, rec.yaw, 0) * h.offset
		end
	end

	rec.cd = rec.cd - dt
	if rec.cd <= 0 and best then
		rec.cd = stats.cd
		local shots = stats.def.shots or 1
		for i = 1, shots do
			if best.alive then
				task.delay(i * 0.05, function()
					if best.alive and rec.tier > 0 then fireTurret(rec, stats, best) end
				end)
			end
		end
		-- 반동: 상부를 살짝 뒤로
		local padBase = padCF(rec.pad:GetAttribute("Lane"), rec.pad:GetAttribute("Slot")) * CFrame.new(0, 0.1, 0)
		for _, h in ipairs(rec.heads) do
			local back = padBase * CFrame.Angles(0, rec.yaw, 0) * h.offset * CFrame.new(0, 0, 0.35)
			TweenService:Create(h.part, TweenInfo.new(0.07), { CFrame = back }):Play()
			task.delay(0.08, function()
				if h.part.Parent then
					TweenService:Create(h.part, TweenInfo.new(0.12), { CFrame = padBase * CFrame.Angles(0, rec.yaw, 0) * h.offset }):Play()
				end
			end)
		end
	end
end

-- ---------------------------------------------------------------
-- 웨이브
-- ---------------------------------------------------------------
local spawnQueue = {}
local waveClock = 0

local function buildWave(w)
	local q = {}
	local count = 4 + math.floor(w * 0.8)
	local interval = math.max(0.32, 0.68 - w * 0.014)
	local laneCursor = math.random(1, 4)
	local boss = (w % 5 == 0)
	local bossAt = math.floor(count / 2)
	local t = 0.5
	for i = 1, count do
		if boss and i == bossAt then
			Game.bossLane = math.random(1, 4)
			table.insert(q, { t = t, kind = "boss", lane = Game.bossLane })
			t = t + 1.6
		end
		local kind = "zergling"
		local roll = math.random()
		if w >= 2 and roll < 0.36 then kind = "hydra" end
		if w >= 4 and roll > 0.9 then kind = "mutalisk" end
		if w >= 6 and roll > 0.66 and roll < 0.8 then kind = "roach" end
		laneCursor = (laneCursor + 1 + ((math.random() < 0.3) and 1 or 0)) % 4
		if laneCursor == 0 then laneCursor = 4 end
		table.insert(q, { t = t, kind = kind, lane = laneCursor })
		t = t + interval
	end
	if boss and bossAt >= count then
		Game.bossLane = math.random(1, 4)
		table.insert(q, { t = t + 0.6, kind = "boss", lane = Game.bossLane })
	end
	return q
end

local function startWave()
	Game.wave = Game.wave + 1
	Game.waveActive = true
	waveClock = 0
	spawnQueue = buildWave(Game.wave)
	Game.bossWave = (Game.wave % 5 == 0)
	for _, p in ipairs(Players:GetPlayers()) do
		TD_Banner:FireClient(p, "WAVE " .. Game.wave, Game.bossWave and ("BOSS · " .. LANE_NAMES[Game.bossLane] .. " 라인") or "DEFEND THE NEXUS")
	end
end

local function clearWaveReward()
	local w = Game.wave
	local minGain = math.round(12 + w * 3)
	local gasGain = math.round(10 + w)
	Game.gas = Game.gas + gasGain
	Game.waveActive = false
	for lane = 1, 4 do
		local owner = laneOwner[lane]
		if owner then
			playerMinerals[owner] = (playerMinerals[owner] or 0) + math.round(minGain * 0.55)
		end
	end
	if Game.wave >= MAX_WAVE then
		Game.over = true
		for _, p in ipairs(Players:GetPlayers()) do
			TD_State:FireClient(p, { event = "win", wave = Game.wave })
		end
	else
		Game.timer = math.max(4.5, 8 - w * 0.15)
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("Pass2x") then
				Game.timer = Game.timer * 0.7
				break
			end
		end
	end
end

-- ---------------------------------------------------------------
-- 유물
-- ---------------------------------------------------------------
function openRelicPick()
	if Game.relicPending then return end
	Game.relicPending = true
	local pool = {}
	for _, r in ipairs(RELICS) do
		if not (r.key == "auto" and (Game.relics.auto or 0) > 0) then table.insert(pool, r) end
	end
	local picks = {}
	for i = 1, 3 do
		if #pool == 0 then break end
		local idx = math.random(1, #pool)
		table.insert(picks, pool[idx])
		table.remove(pool, idx)
	end
	Game.relicChoices = picks
	for _, p in ipairs(Players:GetPlayers()) do
		TD_Relic:FireClient(p, picks)
	end
end

local function applyRelic(key)
	Game.relics[key] = (Game.relics[key] or 0) + 1
	if key == "shield" then
		Game.coreMax = Game.coreMax + 6
		Game.core = Game.coreMax
	elseif key == "gas" then
		Game.gas = Game.gas + 20
	end
	Game.relicPending = false
	Game.relicChoices = {}
	for _, p in ipairs(Players:GetPlayers()) do
		TD_State:FireClient(p, { event = "relicDone" })
	end
end

-- ---------------------------------------------------------------
-- 라인 조작 API (클라이언트 요청)
-- ---------------------------------------------------------------
local function laneOf(player)
	return playerLane[player]
end

local function padFree(rec, player)
	if rec.tier > 0 then return false end
	return true
end

local function playerPads(lane)
	local out = {}
	for slot = 1, 5 do
		local rec = pads[lane] and pads[lane][slot]
		if rec then table.insert(out, { slot = slot, rec = rec }) end
	end
	return out
end

local function vipUnlocked(player)
	return player:GetAttribute("PassVip") == true
end

local function rollTier(player)
	local st = playerStats[player]
	st.pity = st.pity + 1
	local tier = 1
	if st.pity >= 10 then
		local r = math.random()
		if r < 0.62 then tier = 2 elseif r < 0.90 then tier = 3 elseif r < 0.985 then tier = 4 else tier = 5 end
		st.pity = 0
	else
		local w = { GACHA_W[1], GACHA_W[2], GACHA_W[3] * ((Game.relics.luck or 0) > 0 and 1.6 or 1), GACHA_W[4] * ((Game.relics.luck or 0) > 0 and 1.6 or 1), GACHA_W[5] * ((Game.relics.luck or 0) > 0 and 1.6 or 1) }
		local sum = 0
		for _, v in ipairs(w) do sum = sum + v end
		local r = math.random() * sum
		local acc = 0
		for i = 1, 5 do
			acc = acc + w[i]
			if r <= acc then tier = i break end
		end
		if tier >= 2 then st.pity = 0 end
	end
	st.draws = st.draws + 1
	return tier
end

local function freeSlots(lane, player)
	local out = {}
	for slot = 1, 5 do
		local rec = pads[lane] and pads[lane][slot]
		if rec and rec.tier == 0 then
			if slot < 5 or vipUnlocked(player) then
				table.insert(out, rec)
			end
		end
	end
	return out
end

local function drawFor(player)
	local lane = laneOf(player)
	if not lane or Game.over then return end
	if (playerMinerals[player] or 0) < GACHA_COST then return end
	local free = freeSlots(lane, player)
	if #free == 0 then
		TD_Toast:FireClient(player, "내 라인 가득 참", "합성으로 자리를 비우세요")
		return
	end
	playerMinerals[player] = playerMinerals[player] - GACHA_COST
	local tier = rollTier(player)
	local kind = math.random(1, 2)
	local rec = free[math.random(1, #free)]
	installTurret(rec, tier, kind, 0, lane)
	local pos = rec.pad.PrimaryPart.Position
	ringFX(pos + Vector3.new(0, 1, 0), TIER_COLORS[tier], 6)
	burst(pos + Vector3.new(0, 2, 0), TIER_COLORS[tier], tier >= 4 and 16 or 8, 0.7)
	TD_Toast:FireClient(player, TIER_NAMES[tier] .. " · " .. TURRETS[tier][kind].name, (tier >= 4) and "LEGENDARY PULL!" or "")
end

local function findMerge(lane)
	for slotA = 1, 5 do
		local a = pads[lane] and pads[lane][slotA]
		if a and a.tier > 0 and not (a.tier >= 5 and a.star >= 3) then
			for slotB = slotA + 1, 5 do
				local b = pads[lane] and pads[lane][slotB]
				if b and b.tier == a.tier and b.kind == a.kind and b.star == a.star and not (b.tier >= 5 and b.star >= 3) then
					return a, b
				end
			end
		end
	end
	return nil
end

local function doMerge(a, b, player)
	if not a or not b or a.tier ~= b.tier or a.kind ~= b.kind then return false end
	local newTier = math.min(5, a.tier + 1)
	local newStar = (a.tier >= 5) and math.min(3, a.star + 1) or a.star
	local kind = a.kind
	installTurret(a, newTier, kind, newStar, a.pad:GetAttribute("Owner"))
	clearTurret(b)
	local pos = a.pad.PrimaryPart.Position
	ringFX(pos + Vector3.new(0, 1, 0), TIER_COLORS[newTier], 8)
	burst(pos + Vector3.new(0, 3, 0), TIER_COLORS[newTier], newTier >= 4 and 24 or 12, 0.8)
	if player then
		playerStats[player].merges = playerStats[player].merges + 1
		TD_Toast:FireClient(player, "합성 진화!", TIER_NAMES[newTier] .. " · " .. TURRETS[newTier][kind].name)
	end
	return true
end

local function mergeAllFor(player)
	local lane = laneOf(player)
	if not lane then return 0 end
	local n = 0
	while n < 30 do
		local a, b = findMerge(lane)
		if not a then break end
		doMerge(a, b, player)
		n = n + 1
	end
	return n
end

-- ---------------------------------------------------------------
-- 원격 이벤트
-- ---------------------------------------------------------------
local remoteFolder = ReplicatedStorage:FindFirstChild("TD_Remotes")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "TD_Remotes"
	remoteFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
	local r = remoteFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remoteFolder
	end
	return r
end

TD_Draw = ensureRemote("TD_Draw", "RemoteEvent")
TD_Merge = ensureRemote("TD_Merge", "RemoteEvent")
TD_Upgrade = ensureRemote("TD_Upgrade", "RemoteEvent")
TD_Support = ensureRemote("TD_Support", "RemoteEvent")
TD_State = ensureRemote("TD_State", "RemoteEvent")
TD_Mine = ensureRemote("TD_Mine", "RemoteEvent")
TD_Toast = ensureRemote("TD_Toast", "RemoteEvent")
TD_Banner = ensureRemote("TD_Banner", "RemoteEvent")
TD_Relic = ensureRemote("TD_Relic", "RemoteEvent")
TD_PickRelic = ensureRemote("TD_PickRelic", "RemoteEvent")
TD_Grant = ensureRemote("TD_Grant", "BindableEvent")

TD_Draw.OnServerEvent:Connect(function(player)
	drawFor(player)
	if player:GetAttribute("PassAuto") then mergeAllFor(player) end
end)

TD_Merge.OnServerEvent:Connect(function(player)
	mergeAllFor(player)
end)

TD_Upgrade.OnServerEvent:Connect(function(player, which)
	if which == "atk" then
		local cost = 25 + Game.atkLv * 12
		if Game.gas >= cost then Game.gas = Game.gas - cost; Game.atkLv = Game.atkLv + 1 end
	else
		local cost = 30 + Game.spdLv * 14
		if Game.gas >= cost then Game.gas = Game.gas - cost; Game.spdLv = Game.spdLv + 1 end
	end
end)

TD_Support.OnServerEvent:Connect(function(player, which)
	local lane = laneOf(player)
	if not lane then return end
	if which == "strike" then
		if (playerMinerals[player] or 0) < 120 then return end
		playerMinerals[player] = playerMinerals[player] - 120
		for _, e in ipairs(enemies) do
			if e.alive then damageEnemy(e, e.maxHp * 0.45, false) end
		end
		for l = 1, 4 do
			ringFX(Vector3.new(LANE_X[l] + ENEMY_X_OFF, 1, 0), Color3.fromRGB(255, 200, 80), 10)
		end
	elseif which == "repair" then
		if (playerMinerals[player] or 0) < 90 then return end
		playerMinerals[player] = playerMinerals[player] - 90
		Game.core = math.min(Game.coreMax, Game.core + 5)
	end
end)

TD_PickRelic.OnServerEvent:Connect(function(player, index)
	if not Game.relicPending then return end
	if not Game.relicChoices[index] then return end
	applyRelic(Game.relicChoices[index].key)
end)

TD_Grant.Event:Connect(function(player, kind)
	if kind == "minerals250" then
		playerMinerals[player] = (playerMinerals[player] or 0) + 250
	elseif kind == "legend" then
		local lane = laneOf(player)
		local free = lane and freeSlots(lane, player) or {}
		if #free > 0 then
			installTurret(free[1], 4, math.random(1, 2), 0, lane)
		end
	elseif kind == "revive" then
		Game.core = math.min(Game.coreMax, Game.core + 10)
	end
end)

-- ---------------------------------------------------------------
-- 넥서스 피해
-- ---------------------------------------------------------------
local function damageCore(amount, lane)
	Game.core = math.max(0, Game.core - amount)
	for _, p in ipairs(Players:GetPlayers()) do
		TD_State:FireClient(p, { event = "coreHit", lane = lane, core = Game.core })
	end
	local pos = nexusCrystal and nexusCrystal.Position or NEXUS_POS
	ringFX(Vector3.new(pos.X, 2, pos.Z), Color3.fromRGB(255, 80, 90), 14)
	if Game.core <= 0 and not Game.over then
		Game.over = true
		for _, p in ipairs(Players:GetPlayers()) do
			TD_State:FireClient(p, { event = "lose", wave = Game.wave })
		end
	end
end

-- ---------------------------------------------------------------
-- 메인 루프
-- ---------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	-- 넥서스 링 회전
	if nexus then
		for _, p in ipairs(nexus:GetChildren()) do
			local spin = p:GetAttribute("Spin")
			if spin then
				p.CFrame = p.CFrame * CFrame.Angles(0, spin * dt, 0)
			end
		end
	end

	if not Game.over then
		-- 웨이브 타이머
		if not Game.waveActive then
			Game.timer = Game.timer - dt
			if Game.timer <= 0 then startWave() end
		else
			waveClock = waveClock + dt
			while spawnQueue[1] and spawnQueue[1].t <= waveClock do
				local item = table.remove(spawnQueue, 1)
				spawnEnemy(item.kind, item.lane)
			end
		end
	end

	-- 적 이동
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		if not e.alive then
			table.remove(enemies, i)
		else
			local total = totalLen(e.lane)
			if e.dist < total then
				e.dist = math.min(total, e.dist + e.speed * dt * (e.air and 1.15 or 1))
			end
			local pos
			if e.air then
				local t = math.clamp(e.dist / total, 0, 1)
				local sx = LANE_X[e.lane] + ENEMY_X_OFF
				pos = Vector3.new(sx * (1 - t), 7 + math.sin(tick() * 3) * 0.4, PATH_Z0 + t * (NEXUS_POS.Z - PATH_Z0))
			else
				pos = posAt(e.lane, e.dist)
			end
			local dir = posAt(e.lane, math.min(total, e.dist + 1))
			local look = dir - pos
			if look.Magnitude > 0.01 then
				e.model:PivotTo(CFrame.lookAt(pos, pos + look))
			else
				e.model:PivotTo(CFrame.new(pos))
			end
			-- 체력바
			if e.hpFill then
				local frac = math.clamp(e.hp / e.maxHp, 0, 1)
				e.hpFill.Size = UDim2.fromScale(frac, 0.7)
				e.hpFill.BackgroundColor3 = frac > 0.5 and Color3.fromRGB(120, 255, 160) or (frac > 0.25 and Color3.fromRGB(255, 215, 106) or Color3.fromRGB(255, 90, 105))
			end
			-- 넥서스 도달
			if e.dist >= total - 0.5 then
				if e.boss then
					e.siegeT = e.siegeT - dt
					if e.siegeT <= 0 then
						e.siegeT = 2.4
						damageCore(2, e.lane)
						burst(e.model.PrimaryPart.Position, Color3.fromRGB(255, 90, 60), 10, 0.8)
					end
				else
					damageCore(e.coreDamage, e.lane)
					e.alive = false
					e.model:Destroy()
					table.remove(enemies, i)
				end
			end
		end
	end

	-- 터렛
	for _, entry in ipairs(padList) do
		updateTurret(entry.rec, dt)
	end

	-- 자동 합성 패스
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("PassAuto") then
			mergeAllFor(player)
		end
	end

	-- 투사체
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		p.life = p.life - dt
		if not p.part.Parent or p.life <= 0 then
			if p.part then p.part:Destroy() end
			table.remove(projectiles, i)
		else
			local tp
			if p.target and p.target.alive then
				tp = p.target.model.PrimaryPart.Position
			else
				tp = p.part.Position + p.part.CFrame.LookVector * 6
			end
			local dir = tp - p.part.Position
			local dist = dir.Magnitude
			local step = p.speed * dt
			if dist <= math.max(1.2, step) then
				if p.target and p.target.alive then
					damageEnemy(p.target, p.dmg, (Game.relics.boom or 0) > 0)
					if p.splash > 0 then
						for _, other in ipairs(enemies) do
							if other.alive and other ~= p.target and (other.model.PrimaryPart.Position - tp).Magnitude < p.splash then
								damageEnemy(other, p.dmg * 0.4, false)
							end
						end
					end
					burst(tp, TIER_COLORS[p.tier], 5, 0.6)
					ringFX(tp, TIER_COLORS[p.tier], p.splash > 0 and 5 or 2)
				end
				p.part:Destroy()
				table.remove(projectiles, i)
			else
				p.part.CFrame = CFrame.lookAt(p.part.Position, tp) * CFrame.new(0, 0, -math.min(step, dist) / 2)
				p.part.Position = p.part.Position + dir.Unit * math.min(step, dist)
			end
		end
	end

	-- 웨이브 종료
	if Game.waveActive and not Game.over and #spawnQueue == 0 and #enemies == 0 then
		clearWaveReward()
	end

	-- 넥서스 HP UI
	if nexusFill then
		local frac = math.clamp(Game.core / Game.coreMax, 0, 1)
		nexusFill.Size = UDim2.fromScale(frac, 0.72)
		if nexusText then nexusText.Text = "NEXUS " .. Game.core .. " / " .. Game.coreMax end
	end
end)

-- 상태 동기화 (4Hz)
task.spawn(function()
	while true do
		task.wait(0.25)
		local party = {}
		for lane = 1, 4 do
			local owner = laneOwner[lane]
			local turrets, dps = 0, 0
			for slot = 1, 5 do
				local rec = pads[lane] and pads[lane][slot]
				if rec and rec.tier > 0 then
					turrets = turrets + 1
					local st = statsFor(rec)
					if st then dps = dps + st.dps end
				end
			end
			table.insert(party, {
				lane = lane,
				name = owner and owner.DisplayName or "AI",
				ai = owner == nil,
				turrets = turrets,
				dps = math.floor(dps),
			})
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local lane = playerLane[player]
			local myPads = {}
			if lane then
				for slot = 1, 5 do
					local rec = pads[lane] and pads[lane][slot]
					if rec then
						table.insert(myPads, { slot = slot, tier = rec.tier, kind = rec.kind, star = rec.star, locked = (slot == 5 and not vipUnlocked(player)) })
					end
				end
			end
			local mergeable = 0
			if lane then
				local copy = {}
				for slot = 1, 5 do
					local rec = pads[lane] and pads[lane][slot]
					if rec and rec.tier > 0 then table.insert(copy, { t = rec.tier, k = rec.kind, s = rec.star }) end
				end
				for a = 1, #copy do
					for b = a + 1, #copy do
						if copy[a].t == copy[b].t and copy[a].k == copy[b].k and copy[a].s == copy[b].s then mergeable = mergeable + 1 end
					end
				end
			end
			TD_State:FireClient(player, {
				event = "state",
				wave = Game.wave,
				waveActive = Game.waveActive,
				timer = math.max(0, math.floor(Game.timer)),
				core = Game.core,
				coreMax = Game.coreMax,
				gas = Game.gas,
				atkLv = Game.atkLv,
				spdLv = Game.spdLv,
				minerals = playerMinerals[player] or 0,
				pity = playerStats[player] and playerStats[player].pity or 0,
				lane = lane,
				party = party,
				pads = myPads,
				mergeable = mergeable,
				relics = Game.relics,
				kills = Game.kills,
			})
		end
	end
end)

-- ---------------------------------------------------------------
-- 접속/퇴장
-- ---------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	local lane = assignLane(player)
	if not lane then
		player:Kick("이 서버는 4인 협동 정원이 찼습니다. 다시 접속해 주세요.")
		return
	end
	TD_State:FireClient(player, { event = "assigned", lane = lane, laneName = LANE_NAMES[lane] })
	TD_Banner:FireClient(player, LANE_NAMES[lane] .. " 라인 배정", "내 라인 터렛을 뽑기·합성으로 키우세요")
end)

Players.PlayerRemoving:Connect(function(player)
	local lane = playerLane[player]
	if lane and laneOwner[lane] == player then
		laneOwner[lane] = nil
	end
	playerLane[player] = nil
	playerMinerals[player] = nil
	playerStats[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	if not playerLane[player] then assignLane(player) end
end

print("[TD] 02_WaveGachaMerge 시작 — 4인 협동 라인 배정 · 20웨이브 · 뽑기/합성/강화")
