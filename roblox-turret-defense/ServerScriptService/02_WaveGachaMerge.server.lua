--[[ ============================================================
  02_WaveGachaMerge.server.lua
  🍀 운빨·조합 터렛 디펜스 — 4인 협동 게임 서버 (v2)
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService (일반 Script)
  먼저 준비 : ReplicatedStorage의 ModuleScript "TDShared",
              ServerScriptService의 ModuleScript "TDData",
              그리고 01_MapAndTurrets 가 한 번이라도 실행되어 아레나가 있어야 합니다.
  담당
    · 4인 라인 자동 배정 · 20웨이브 · 보스 공성 · 유물 선택
    · 뽑기/합성/리롤 · 공용 가스 강화 · 지원 작전
    · 부스트(2배 데미지/미네랄) · 팀 버프 · 부활(넥서스 붕괴 직전)
    · 데미지 숫자/콤보/보스 경고 연출 송출
    · 상품 지급 창구(Bus.Call) — 03·05 가 여기로 요청
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local Data = require(script.Parent:WaitForChild("TDData"))
local bus = Shared.bus()
local remotes = Shared.remotes()

local GEO = Shared.GEO
local LANE_X = GEO.LANE_X
local LANE_COLORS = GEO.LANE_COLORS
local LANE_NAMES = GEO.LANE_NAMES
local SLOT_Z = GEO.SLOT_Z
local SLOT_X_OFF = GEO.SLOT_X_OFF
local ENEMY_X_OFF = GEO.ENEMY_X_OFF
local NEXUS_POS = GEO.NEXUS_POS
local PATH_Z0, PATH_Z1 = GEO.PATH_Z0, GEO.PATH_Z1

local COST_DRAW = Shared.GACHA_COST
local MAX_WAVE = Shared.MAX_WAVE
local CORE_MAX = Shared.CORE_MAX
local TIER_NAMES = Shared.TIER_NAMES
local TIER_COLORS = Shared.TIER_COLORS

local REVIVE_WINDOW = 12       -- 넥서스 붕괴 후 부활 대기 초
local RESTART_DELAY = 20       -- 승패 후 자동 재시작까지
local AUTO_MERGE_TICK = 0.5    -- 자동 합성 주기(초) — 매 프레임 실행 금지

Shared.remotes()
local RD = {
	State = remotes.TD_State,
	FX = remotes.TD_FX,
	Draw = remotes.TD_Draw,
	Merge = remotes.TD_Merge,
	Upgrade = remotes.TD_Upgrade,
	Support = remotes.TD_Support,
	PickRelic = remotes.TD_PickRelic,
	Prompt = remotes.TD_Prompt,
}

-- ---------------------------------------------------------------
-- 상태
-- ---------------------------------------------------------------
local Game = {
	wave = 0,
	waveActive = false,
	timer = 15,
	core = CORE_MAX,
	coreMax = CORE_MAX,
	gas = 30,
	atkLv = 0,
	spdLv = 0,
	relics = {},
	bossWave = false,
	bossLane = 0,
	boss = nil,
	relicPending = false,
	relicChoices = {},
	over = false,
	downed = false,
	reviveEnds = 0,
	restartAt = 0,
	kills = 0,
	combo = 0,
	comboT = 0,
	teamSpeedUntil = 0,
	started = false,
}

local SP = {}          -- [player] = 세션 상태
local laneOwner = { nil, nil, nil, nil }

Players.CharacterAutoLoads = false

local arena = Workspace:WaitForChild("TDArena", 30)
if not arena then
	warn("[TD] TDArena 가 없습니다. 01_MapAndTurrets 를 먼저 ServerScriptService 에 넣고 한 번 실행하세요.")
	arena = Workspace:WaitForChild("TDArena")
end
local padsFolder = arena:WaitForChild("Pads")
local nexus = arena:WaitForChild("Nexus")
local nexusCrystal = nexus:FindFirstChild("Crystal")
local nexusHP = nexusCrystal and nexusCrystal:FindFirstChild("NexusHP")
local nexusFill = nexusHP and nexusHP:FindFirstChild("Fill")
local nexusText = nexusHP and nexusHP:FindFirstChildOfClass("TextLabel")

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
-- 도우미
-- ---------------------------------------------------------------
local function now()
	return os.clock()
end

local function anyPlayers()
	return #Players:GetPlayers() > 0
end

-- 앞으로 정의될 함수들 (먼저 이름을 잡아 두어야 아래에서 부를 수 있습니다)
local resetMatch
local announceGift

local function isPremium(player)
	local ok, mt = pcall(function() return player.MembershipType end)
	return ok and mt == Enum.MembershipType.Premium
end

local function rewardMultiplier(player, withBonusPass)
	local mul = 1
	if player:GetAttribute("PassVip") then mul = mul + Shared.VIP_BONUS end
	if isPremium(player) then mul = mul + Shared.PREMIUM_BONUS end
	if withBonusPass and player:GetAttribute("PassBonus") then mul = mul + Shared.BONUS_PASS_REWARD end
	local sp = SP[player]
	if sp and sp.boostGoldUntil > now() then mul = mul * 2 end
	return mul
end

-- ===============================================================
-- 1. 라인 배정 · 참가
-- ===============================================================
local function assignLane(player)
	for lane = 1, 4 do
		if laneOwner[lane] == nil then
			laneOwner[lane] = player
			player:SetAttribute("Lane", lane)
			return lane
		end
	end
	return nil
end

local function refreshPassAttributes(player)
	local profile = Data.get(player)
	if not profile then return end
	for _, pass in ipairs(Shared.PASSES) do
		local owned = (profile.passes and profile.passes[pass.key] == true)
		if owned then
			player:SetAttribute(pass.attr, true)
		end
	end
end

local function setupPlayer(player)
	local profile = Data.waitFor(player, 20)
	local lane = assignLane(player)
	if not lane then
		player:Kick("이 서버는 4인 협동 정원이 찼습니다. 다시 접속해 주세요.")
		return
	end
	if not profile then
		warn("[TD] " .. player.Name .. " 프로필을 불러오지 못했습니다 (임시 진행)")
	end

	local startMin = 100
	local startGasBonus = 0
	local permAtk = 0
	if profile then
		local up = profile.upgrades or {}
		startMin = startMin + (up.startMinerals or 0) * 40
		startGasBonus = (up.startGas or 0) * 25
		permAtk = (up.permAtk or 0) * 0.03
	end

	SP[player] = {
		lane = lane,
		minerals = startMin,
		pity = profile and profile.pity or 0,
		permAtk = permAtk,
		boostDmgUntil = 0,
		boostGoldUntil = 0,
		lastDraw = 0,
		metrics = { kills = 0, merges = 0, draws = 0, wave = 0, bossKills = 0, revives = 0 },
		joinedAt = now(),
	}
	if startGasBonus > 0 then
		Game.gas = Game.gas + startGasBonus
	end
	player:SetAttribute("Minerals", startMin)
	refreshPassAttributes(player)

	local stock = profile and profile.reviveStock or 0
	player:SetAttribute("ReviveStock", stock)
	if profile then
		local gems = profile.gems or 0
		player:SetAttribute("Gems", gems)
		player:SetAttribute("BestWave", profile.bestWave or 0)
	end

	RD.State:FireClient(player, { event = "assigned", lane = lane, laneName = LANE_NAMES[lane] })
	RD.State:FireClient(player, { event = "banner", title = LANE_NAMES[lane] .. " 라인 배정", sub = "터렛을 뽑기·합성으로 키우세요" })

	if Game.over and now() >= Game.restartAt then
		resetMatch()
	end
	Game.started = true
end

-- ===============================================================
-- 2. 패드 수집
-- ===============================================================
local pads = {}       -- pads[lane][slot] = rec
local padList = {}

local function padCF(lane, slot)
	return CFrame.new(LANE_X[lane] + SLOT_X_OFF, 0.35, SLOT_Z[slot] or 0)
end

local function collectPads()
	pads = {}
	padList = {}
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
		if lane and slot and pad:IsA("Model") then
			pads[lane] = pads[lane] or {}
			local rec = {
				pad = pad, lane = lane, slot = slot,
				tier = 0, kind = 0, star = 0, model = nil, heads = {},
				cd = 0, yaw = 0, target = nil, retarget = 0,
			}
			pads[lane][slot] = rec
			table.insert(padList, rec)
		end
	end
end
collectPads()

-- 패드가 하나도 안 잡혔으면 잠시 후 다시 수집 (01 실행 시점 차이 대비)
task.spawn(function()
	for _ = 1, 10 do
		if #padList > 0 then return end
		task.wait(1)
		collectPads()
		if #padList > 0 then
			print("[TD] 패드 " .. #padList .. "개 재수집 완료")
			return
		end
	end
	warn("[TD] 터렛 패드를 찾지 못했습니다 — 01_MapAndTurrets 가 ServerScriptService 에 있는지 확인하세요")
end)

local function slotUnlocked(player, slot)
	if slot <= GEO.FREE_SLOTS then return true end
	return player ~= nil and player:GetAttribute("PassSlots") == true
end

-- ===============================================================
-- 3. 터렛
-- ===============================================================
local function statsFor(rec)
	if rec.tier <= 0 then return nil end
	local def = Shared.TURRETS[rec.tier][rec.kind]
	local owner = laneOwner[rec.lane]
	local sp = owner and SP[owner]

	local starMul = 1 + 0.35 * (rec.star or 0)
	local atkMul = (1 + Game.atkLv * 0.12) * (1 + 0.25 * (Game.relics.atk or 0))
	local spdMul = (1 + Game.spdLv * 0.08) * (1 + 0.20 * (Game.relics.spd or 0))
	if sp then
		atkMul = atkMul * (1 + (sp.permAtk or 0))
		if sp.boostDmgUntil > now() then atkMul = atkMul * 2 end
	end
	if owner and owner:GetAttribute("Pass2x") then spdMul = spdMul * 1.25 end
	if Game.teamSpeedUntil > now() then spdMul = spdMul * 1.5 end
	local rangeMul = 1 + 0.18 * (Game.relics.range or 0)

	local cd = math.max(0.05, def.cd / spdMul)
	return {
		def = def,
		dmg = def.dmg * starMul * atkMul,
		cd = cd,
		range = def.range * rangeMul,
		dps = (def.dmg * starMul * atkMul * (def.shots or 1)) / cd,
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
	rec.target = nil
	rec.pad:SetAttribute("Tier", 0)
	rec.pad:SetAttribute("Kind", 0)
	rec.pad:SetAttribute("Star", 0)
	local ring = rec.pad:FindFirstChild("Ring")
	if ring then
		local locked = rec.pad:GetAttribute("Locked") and true or false
		ring.Color = locked and Color3.fromRGB(90, 90, 90) or LANE_COLORS[rec.lane]
	end
end

local function installTurret(rec, tier, kind, star, owner)
	clearTurret(rec)
	local template = turretTemplates:FindFirstChild("T" .. tier .. "_" .. kind)
	if not template then return nil end
	local model = template:Clone()
	model.Parent = arena
	local baseCF = padCF(rec.lane, rec.slot)
	model:PivotTo(baseCF * CFrame.new(0, 0.1, 0))
	rec.model = model
	rec.tier = tier
	rec.kind = kind
	rec.star = star or 0
	rec.cd = math.random() * 0.2
	rec.yaw = 0
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
		TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			Transparency = 1,
			Size = Vector3.new(size * 0.2, size * 0.2, size * 0.2),
		}):Play()
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

-- ===============================================================
-- 4. 적
-- ===============================================================
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

local spawnEnemy
local damageEnemy
local openRelicPick
local damageCore
local endMatch

function spawnEnemy(kind, lane)
	local info = Shared.ENEMIES[kind]
	if not info then return nil end
	local tpl = enemyTemplates:FindFirstChild(info.model)
	if not tpl then return nil end
	if lane == nil then lane = math.random(1, 4) end

	local model = tpl:Clone()
	model.Parent = enemyFolder
	local isBoss = tpl:GetAttribute("Boss") or false
	local baseHp = Shared.WAVE_HP_BASE * (Shared.WAVE_HP_GROWTH ^ math.max(0, Game.wave - 1))
	local hp = math.max(40, baseHp * (info.hp or 1))

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
		dmgAcc = 0,
	}
	model:PivotTo(CFrame.new(posAt(lane, 0)))

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

	if isBoss then
		Game.boss = e
		Game.bossLane = lane
		local beacon = arena:FindFirstChild("Lane" .. lane)
		beacon = beacon and beacon:FindFirstChild("WarnBeacon")
		if beacon then
			beacon.Transparency = 0.15
			beacon.Color = Color3.fromRGB(255, 70, 70)
		end
		RD.FX:FireAllClients({ kind = "bossWarn", lane = lane, pos = Vector3.new(LANE_X[lane], 6, -20) })
		for _, pl in ipairs(Players:GetPlayers()) do
			RD.State:FireClient(pl, {
				event = "banner",
				title = "⚠ BOSS INCOMING",
				sub = LANE_NAMES[lane] .. " 라인으로 공성 보스 접근",
			})
		end
	end
	return e
end

function damageEnemy(e, amount, ownerPlayer, doBoom)
	if not e or not e.alive then return end
	local dmg = amount * (1 - (e.armor or 0))
	e.hp = e.hp - dmg
	e.dmgAcc = (e.dmgAcc or 0) + dmg

	if doBoom and math.random() < 0.3 then
		local ePos = e.model and e.model.PrimaryPart and e.model.PrimaryPart.Position
		for _, other in ipairs(enemies) do
			if other ~= e and other.alive and other.model and other.model.PrimaryPart and ePos then
				if (other.model.PrimaryPart.Position - ePos).Magnitude < 10 then
					other.hp = other.hp - amount * 0.4
				end
			end
		end
		if ePos then ringFX(ePos, Color3.fromRGB(255, 176, 58), 6) end
	end

	if e.hp <= 0 then
		-- ★ 폭발 위치를 지우기 전에 확보 (이전 버전 버그)
		local deathPos = e.model and e.model.PrimaryPart and e.model.PrimaryPart.Position or Vector3.new(0, 2, 0)
		local wasBoss = e.boss
		e.alive = false
		if e.model then e.model:Destroy() end
		Game.kills = Game.kills + 1
		Game.combo = Game.combo + 1
		Game.comboT = now() + 3

		local owner = laneOwner[e.lane]
		if owner and SP[owner] then
			local relicMul = 1 + 0.35 * (Game.relics.minerals or 0)
			local base = e.reward * relicMul + 2 * (Game.relics.bounty or 0)
			if Game.relics.combo then base = base + Game.combo * 0.5 end
			local gain = math.max(1, math.floor(base * rewardMultiplier(owner, false)))
			SP[owner].minerals = SP[owner].minerals + gain
			SP[owner].metrics.kills = SP[owner].metrics.kills + 1
			if wasBoss then
				SP[owner].metrics.bossKills = SP[owner].metrics.bossKills + 1
			end
		end

		burst(deathPos, wasBoss and Color3.fromRGB(255, 176, 58) or Color3.fromRGB(255, 120, 60), wasBoss and 26 or 6, wasBoss and 2 or 1.1)
		ringFX(deathPos, wasBoss and Color3.fromRGB(255, 194, 77) or Color3.fromRGB(255, 120, 60), wasBoss and 18 or 4)

		if wasBoss then
			Game.boss = nil
			Game.gas = Game.gas + 40
			Game.combo = Game.combo + 10
			local lane = arena:FindFirstChild("Lane" .. e.lane)
			local beacon = lane and lane:FindFirstChild("WarnBeacon")
			if beacon then beacon.Transparency = 0.85 end
			for _, pl in ipairs(Players:GetPlayers()) do
				RD.State:FireClient(pl, { event = "bossDown", wave = Game.wave })
			end
			if bus then
				bus.Event:Fire({ type = "bossKill", player = owner })
			end
			openRelicPick()
		end
	end
end

-- ===============================================================
-- 5. 투사체 · 사격
-- ===============================================================
local projectiles = {}

local function fireTurret(rec, stats, target)
	local def = stats.def
	local muzzlePos = rec.pad.PrimaryPart.Position + Vector3.new(0, 3.2, -3)
	for _, h in ipairs(rec.heads) do
		if h.part.Name == "HeadMuzzle" or h.part.Name == "HeadTip1" then
			muzzlePos = h.part.Position
			break
		end
	end
	local owner = laneOwner[rec.lane]

	if def.proj == "beam" then
		local hitPos = target.model and target.model.PrimaryPart and target.model.PrimaryPart.Position or muzzlePos
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = (rec.tier >= 5) and Color3.fromRGB(255, 120, 220) or Color3.fromRGB(140, 225, 255)
		p.Size = Vector3.new(0.4, 0.4, math.max(0.4, (hitPos - muzzlePos).Magnitude))
		p.CFrame = CFrame.lookAt(muzzlePos, hitPos) * CFrame.new(0, 0, -p.Size.Z / 2)
		p.Parent = fxFolder
		Debris:AddItem(p, 0.16)
		TweenService:Create(p, TweenInfo.new(0.16), { Transparency = 1 }):Play()
		damageEnemy(target, stats.dmg, owner, (Game.relics.boom or 0) > 0)
		if (def.splash or 0) > 0 then
			for _, other in ipairs(enemies) do
				if other ~= target and other.alive and other.model and other.model.PrimaryPart then
					if (other.model.PrimaryPart.Position - hitPos).Magnitude < def.splash then
						damageEnemy(other, stats.dmg * 0.4, owner, false)
					end
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
		splash = def.splash or 0,
		life = 3,
		tier = rec.tier,
		owner = owner,
	})
end

local function updateTurret(rec, dt)
	if rec.tier <= 0 or not rec.model then return end
	local stats = statsFor(rec)
	if not stats then return end
	local basePos = rec.pad.PrimaryPart.Position

	rec.retarget = (rec.retarget or 0) - dt
	if rec.retarget <= 0 or not (rec.target and rec.target.alive) then
		rec.retarget = 0.15
		local best, bestScore = nil, -math.huge
		for _, e in ipairs(enemies) do
			if e.alive and e.model and e.model.PrimaryPart then
				local d = (e.model.PrimaryPart.Position - basePos).Magnitude
				if d <= stats.range then
					local score = e.dist + (e.boss and 40 or 0)
					if score > bestScore then
						bestScore = score
						best = e
					end
				end
			end
		end
		rec.target = best
	end
	local best = rec.target

	if best then
		local to = best.model.PrimaryPart.Position - basePos
		local yaw = math.atan2(-to.X, -to.Z)
		local delta = ((yaw - rec.yaw + math.pi * 3) % (math.pi * 2)) - math.pi
		rec.yaw = rec.yaw + delta * math.min(1, dt * 9)
		local padBase = padCF(rec.lane, rec.slot) * CFrame.new(0, 0.1, 0)
		for _, h in ipairs(rec.heads) do
			if h.part.Parent then
				h.part.CFrame = padBase * CFrame.Angles(0, rec.yaw, 0) * h.offset
			end
		end
	end

	rec.cd = rec.cd - dt
	if rec.cd <= 0 and best and best.alive then
		rec.cd = stats.cd
		local shots = stats.def.shots or 1
		for i = 1, shots do
			if best.alive then
				task.delay(i * 0.05, function()
					if best.alive and rec.tier > 0 and rec.model then fireTurret(rec, stats, best) end
				end)
			end
		end
		local padBase = padCF(rec.lane, rec.slot) * CFrame.new(0, 0.1, 0)
		for _, h in ipairs(rec.heads) do
			if h.part.Parent then
				local back = padBase * CFrame.Angles(0, rec.yaw, 0) * h.offset * CFrame.new(0, 0, 0.35)
				TweenService:Create(h.part, TweenInfo.new(0.07), { CFrame = back }):Play()
				task.delay(0.08, function()
					if h.part.Parent then
						TweenService:Create(h.part, TweenInfo.new(0.12), {
							CFrame = padBase * CFrame.Angles(0, rec.yaw, 0) * h.offset,
						}):Play()
					end
				end)
			end
		end
	end
end

-- ===============================================================
-- 6. 뽑기 · 합성 · 리롤
-- ===============================================================
local function freeSlots(lane, player)
	local out = {}
	for slot = 1, #SLOT_Z do
		local rec = pads[lane] and pads[lane][slot]
		if rec and rec.tier == 0 and slotUnlocked(player, slot) then
			table.insert(out, rec)
		end
	end
	return out
end

local function rollTierFor(player)
	local sp = SP[player]
	if not sp then return 1 end
	local luckPass = player:GetAttribute("PassLuck") == true
	local pityGoal = luckPass and Shared.PITY_PASS or Shared.PITY_BASE
	sp.pity = (sp.pity or 0) + 1
	local tier
	if sp.pity >= pityGoal then
		tier = Shared.rollTier(luckPass, true)
		sp.pity = 0
	else
		tier = Shared.rollTier(luckPass or (Game.relics.luck or 0) > 0, false)
		if tier >= 2 then sp.pity = 0 end
	end
	if (Game.relics.luck or 0) > 0 and not luckPass then
		-- 유물 '행운의 뽑기'는 확률을 한 번 더 보정 (희귀 이상 가중)
		if tier == 1 and math.random() < 0.16 then tier = 2 end
	end
	return tier
end

local function placeTurret(player, tier, kind, rec)
	local lane = SP[player] and SP[player].lane or 1
	installTurret(rec, tier, kind, 0, lane)
	local pos = rec.pad.PrimaryPart.Position
	ringFX(pos + Vector3.new(0, 1, 0), TIER_COLORS[tier], 6)
	burst(pos + Vector3.new(0, 2, 0), TIER_COLORS[tier], tier >= 4 and 16 or 8, 0.7)
	return true
end

local function drawFor(player, opts)
	opts = opts or {}
	local sp = SP[player]
	if not sp or Game.over then return 0 end
	local lane = sp.lane
	local draws = 0
	local count = opts.count or 1
	local cost = opts.free and 0 or COST_DRAW
	local guaranteedRare = opts.guaranteedRare or false

	for i = 1, count do
		if not opts.free and sp.minerals < cost then break end
		local free = freeSlots(lane, player)
		if #free == 0 then
			if draws == 0 then
				RD.State:FireClient(player, { event = "toast", title = "내 라인 가득 참", sub = "합성으로 자리를 비우세요" })
			end
			break
		end
		if not opts.free then
			sp.minerals = sp.minerals - cost
		end
		local tier = rollTierFor(player)
		if guaranteedRare and i == count and tier < 2 then tier = 2 end
		local kind = math.random(1, 2)
		local rec = free[math.random(1, #free)]
		placeTurret(player, tier, kind, rec)
		sp.metrics.draws = sp.metrics.draws + 1
		draws = draws + 1
		if tier >= 4 then
			RD.State:FireClient(player, {
				event = "toast",
				title = TIER_NAMES[tier] .. " · " .. Shared.TURRETS[tier][kind].name,
				sub = "LEGENDARY PULL!",
				tier = tier,
			})
			RD.FX:FireAllClients({ kind = "shake", strength = 0.6 })
		end
	end
	if draws > 0 then
		RD.State:FireClient(player, { event = "drawn", count = draws })
	end
	return draws
end

local function findMerge(lane)
	for slotA = 1, #SLOT_Z do
		local a = pads[lane] and pads[lane][slotA]
		if a and a.tier > 0 and not (a.tier >= 5 and a.star >= 3) then
			for slotB = slotA + 1, #SLOT_Z do
				local b = pads[lane] and pads[lane][slotB]
				if b and b.tier == a.tier and b.kind == a.kind and b.star == a.star
					and not (b.tier >= 5 and b.star >= 3) then
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
	installTurret(a, newTier, a.kind, newStar, a.lane)
	clearTurret(b)
	local pos = a.pad.PrimaryPart.Position
	ringFX(pos + Vector3.new(0, 1, 0), TIER_COLORS[newTier], 8)
	burst(pos + Vector3.new(0, 3, 0), TIER_COLORS[newTier], newTier >= 4 and 24 or 12, 0.8)
	if player and SP[player] then
		SP[player].metrics.merges = SP[player].metrics.merges + 1
		RD.State:FireClient(player, {
			event = "toast",
			title = "합성 진화!",
			sub = TIER_NAMES[newTier] .. " · " .. Shared.TURRETS[newTier][a.kind].name,
			tier = newTier,
		})
	end
	return true
end

local function mergeAllFor(player)
	local sp = SP[player]
	if not sp then return 0 end
	local n = 0
	while n < 40 do
		local a, b = findMerge(sp.lane)
		if not a then break end
		doMerge(a, b, player)
		n = n + 1
	end
	return n
end

local function rerollLane(player)
	local sp = SP[player]
	if not sp then return 0 end
	local n = 0
	for slot = 1, #SLOT_Z do
		local rec = pads[sp.lane] and pads[sp.lane][slot]
		if rec and rec.tier > 0 then
			local tier = rec.tier
			if math.random() < 0.25 then tier = math.min(5, tier + 1) end
			installTurret(rec, tier, math.random(1, 2), 0, sp.lane)
			ringFX(rec.pad.PrimaryPart.Position + Vector3.new(0, 1, 0), TIER_COLORS[tier], 7)
			n = n + 1
		end
	end
	if n > 0 then
		RD.State:FireClient(player, { event = "toast", title = "🎲 리롤 완료", sub = n .. "기 재뽑기" })
	end
	return n
end

-- ===============================================================
-- 7. 웨이브
-- ===============================================================
local spawnQueue = {}
local waveClock = 0
local startWave
local clearWaveReward

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

function startWave()
	Game.wave = Game.wave + 1
	Game.waveActive = true
	waveClock = 0
	spawnQueue = buildWave(Game.wave)
	Game.bossWave = (Game.wave % 5 == 0)
	for _, p in ipairs(Players:GetPlayers()) do
		local sp = SP[p]
		if sp then sp.metrics.wave = math.max(sp.metrics.wave, Game.wave) end
		RD.State:FireClient(p, {
			event = "banner",
			title = "WAVE " .. Game.wave .. " / " .. MAX_WAVE,
			sub = Game.bossWave and ("BOSS · " .. LANE_NAMES[Game.bossLane] .. " 라인") or "넥서스를 지켜라",
		})
	end
	if bus then
		bus.Event:Fire({ type = "waveStart", wave = Game.wave })
	end
end

function clearWaveReward()
	local w = Game.wave
	local gasGain = math.round(10 + w)
	Game.gas = Game.gas + gasGain
	Game.waveActive = false
	for lane = 1, 4 do
		local owner = laneOwner[lane]
		if owner and SP[owner] then
			local base = math.round((12 + w * 3) * 0.55)
			local gain = math.max(1, math.floor(base * rewardMultiplier(owner, true)))
			SP[owner].minerals = SP[owner].minerals + gain
			RD.State:FireClient(owner, {
				event = "toast",
				title = "WAVE " .. w .. " 클리어",
				sub = "미네랄 +" .. Shared.comma(gain) .. " · 가스 +" .. gasGain,
			})
		end
	end
	if bus then
		bus.Event:Fire({ type = "waveClear", wave = w })
	end
	-- 웨이브 클리어 연출: 넥서스 확산 링 + 배너
	local npos = nexusCrystal and nexusCrystal.Position or NEXUS_POS
	ringFX(Vector3.new(npos.X, 2, npos.Z), Color3.fromRGB(120, 235, 255), 16)
	for _, p in ipairs(Players:GetPlayers()) do
		RD.FX:FireClient(p, { kind = "waveClear", wave = w })
	end
	if Game.wave >= MAX_WAVE then
		endMatch(true)
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

-- ===============================================================
-- 8. 유물
-- ===============================================================
function openRelicPick()
	if Game.relicPending then return end
	Game.relicPending = true
	local pool = {}
	for _, r in ipairs(Shared.RELICS) do
		if not (r.key == "auto" and (Game.relics.auto or 0) > 0) then
			table.insert(pool, r)
		end
	end
	local picks = {}
	local want = 3
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("PassBonus") then want = 4 break end
	end
	for i = 1, want do
		if #pool == 0 then break end
		local idx = math.random(1, #pool)
		table.insert(picks, pool[idx])
		table.remove(pool, idx)
	end
	Game.relicChoices = picks
	for _, p in ipairs(Players:GetPlayers()) do
		RD.State:FireClient(p, { event = "relic", picks = picks })
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
		RD.State:FireClient(p, { event = "relicDone", relic = key })
	end
end

-- ===============================================================
-- 9. 넥서스 피해 · 부활 · 종료
-- ===============================================================
local function reviveReady(player)
	local stock = player:GetAttribute("ReviveStock") or 0
	return stock > 0
end

local function consumeRevive(player)
	local stock = player:GetAttribute("ReviveStock") or 0
	if stock <= 0 then return false end
	player:SetAttribute("ReviveStock", stock - 1)
	Data.addRevive(player, -1)
	Data.markDirty(player)
	if SP[player] then SP[player].metrics.revives = SP[player].metrics.revives + 1 end
	return true
end

local function reviveNow(player, paid)
	Game.downed = false
	Game.core = math.max(8, math.floor(Game.coreMax * 0.6))
	Game.reviveEnds = 0
	-- 몰려온 적 정리
	for _, e in ipairs(enemies) do
		if e.alive then
			local pos = e.model and e.model.PrimaryPart and e.model.PrimaryPart.Position or NEXUS_POS
			burst(pos, Color3.fromRGB(120, 235, 255), 8, 1.0)
			e.alive = false
			if e.model then e.model:Destroy() end
		end
	end
	enemies = {}
	spawnQueue = {}
	Game.boss = nil
	Game.waveActive = false
	Game.timer = 6
	local name = player and player.DisplayName or "용사"
	for _, p in ipairs(Players:GetPlayers()) do
		RD.State:FireClient(p, {
			event = "banner",
			title = "💖 부활!",
			sub = name .. (paid and " 님이 부활권을 사용했습니다" or " 님이 팀을 되살렸습니다"),
		})
		RD.FX:FireClient(p, { kind = "flash", color = Color3.fromRGB(120, 235, 255) })
	end
	if bus then
		bus.Event:Fire({ type = "revive", player = player })
	end
end

function damageCore(amount, lane)
	if Game.downed or Game.over then return end
	Game.core = math.max(0, Game.core - amount)
	RD.FX:FireAllClients({ kind = "coreHit", lane = lane })
	local pos = nexusCrystal and nexusCrystal.Position or NEXUS_POS
	ringFX(Vector3.new(pos.X, 2, pos.Z), Color3.fromRGB(255, 80, 90), 14)

	if Game.core <= 0 then
		-- ★ 바로 패배가 아니라 '부활 창구'를 12초 엽니다 (저가 충동구매 지점)
		Game.downed = true
		Game.reviveEnds = now() + REVIVE_WINDOW
		Game.waveActive = false
		Game.timer = 99
		for _, p in ipairs(Players:GetPlayers()) do
			RD.State:FireClient(p, {
				event = "reviveOffer",
				seconds = REVIVE_WINDOW,
				stock = p:GetAttribute("ReviveStock") or 0,
				price = 25,
			})
		end
	end
end

function endMatch(won)
	if Game.over then return end
	Game.over = true
	Game.downed = false
	Game.restartAt = now() + RESTART_DELAY
	Game.waveActive = false
	spawnQueue = {}

	local gemsReward = math.max(1, math.floor(Game.wave * 0.7)) + (won and 30 or 0)
	for _, p in ipairs(Players:GetPlayers()) do
		local profile = Data.get(p)
		if profile then
			profile.bestWave = math.max(profile.bestWave or 0, Game.wave)
			profile.totalWaves = (profile.totalWaves or 0) + Game.wave
			profile.runs = (profile.runs or 0) + 1
			profile.totalKills = (profile.totalKills or 0) + (SP[p] and SP[p].metrics.kills or 0)
			if won then profile.wins = (profile.wins or 0) + 1 end
			profile.pity = SP[p] and SP[p].pity or profile.pity
			local bonus = gemsReward
			if p:GetAttribute("PassVip") then bonus = bonus + 5 end
			if isPremium(p) then bonus = bonus + 3 end
			profile.gems = (profile.gems or 0) + bonus
			Data.markDirty(p)
			p:SetAttribute("Gems", profile.gems)
			p:SetAttribute("BestWave", profile.bestWave)
			RD.State:FireClient(p, {
				event = won and "win" or "lose",
				wave = Game.wave,
				gems = bonus,
				kills = SP[p] and SP[p].metrics.kills or 0,
				best = profile.bestWave,
			})
		end
	end
	if bus then
		bus.Event:Fire({ type = "matchEnd", wave = Game.wave, won = won })
	end
	for _, p in ipairs(Players:GetPlayers()) do
		Data.save(p, false)
	end
end

function resetMatch()
	-- 모든 터렛/적 정리
	for _, rec in ipairs(padList) do
		clearTurret(rec)
	end
	for _, e in ipairs(enemies) do
		if e.model then e.model:Destroy() end
	end
	enemies = {}
	spawnQueue = {}
	projectiles = {}
	Game.wave = 0
	Game.waveActive = false
	Game.timer = 12
	Game.coreMax = CORE_MAX
	Game.core = CORE_MAX
	Game.gas = 30
	Game.atkLv = 0
	Game.spdLv = 0
	Game.relics = {}
	Game.relicPending = false
	Game.relicChoices = {}
	Game.over = false
	Game.downed = false
	Game.kills = 0
	Game.combo = 0
	Game.teamSpeedUntil = 0
	Game.boss = nil
	for _, p in ipairs(Players:GetPlayers()) do
		local sp = SP[p]
		if sp then
			local profile = Data.get(p)
			local startMin = 100
			if profile and profile.upgrades then
				startMin = startMin + (profile.upgrades.startMinerals or 0) * 40
				Game.gas = Game.gas + (profile.upgrades.startGas or 0) * 25
			end
			sp.minerals = startMin
			sp.boostDmgUntil = 0
			sp.boostGoldUntil = 0
			sp.metrics = { kills = 0, merges = 0, draws = 0, wave = 0, bossKills = 0, revives = 0 }
		end
		RD.State:FireClient(p, { event = "restart" })
	end
end

-- ===============================================================
-- 10. 보상 지급 창구 (03·05 → 02)
-- ===============================================================
local function awardMinerals(player, amount)
	local sp = SP[player]
	if not sp or not amount then return false end
	sp.minerals = sp.minerals + amount
	return true
end

local grantActions = {}

grantActions["PRODUCT_REVIVE"] = function(player)
	Data.addRevive(player, 1)
	local stock = (player:GetAttribute("ReviveStock") or 0) + 1
	stock = math.min(3, stock)
	player:SetAttribute("ReviveStock", stock)
	RD.State:FireClient(player, {
		event = "toast",
		title = "💖 부활권 +1",
		sub = "보관 " .. stock .. "장 · 넥서스 붕괴 순간 사용",
	})
	-- 붕괴 중에 샀다면 바로 부활
	if Game.downed then
		if consumeRevive(player) then
			reviveNow(player, true)
		end
	end
	return true
end

grantActions["PRODUCT_BOOST_DMG"] = function(player)
	local sp = SP[player]
	if not sp then return false end
	sp.boostDmgUntil = math.max(sp.boostDmgUntil, now()) + 600
	RD.State:FireClient(player, { event = "toast", title = "🔥 데미지 2배 10분", sub = "내 터렛 전체 공격력 2배" })
	return true
end

grantActions["PRODUCT_BOOST_GOLD"] = function(player)
	local sp = SP[player]
	if not sp then return false end
	sp.boostGoldUntil = math.max(sp.boostGoldUntil, now()) + 600
	RD.State:FireClient(player, { event = "toast", title = "💎 미네랄 2배 10분", sub = "적 처치·웨이브 보상 2배" })
	return true
end

grantActions["PRODUCT_REROLL"] = function(player)
	return rerollLane(player) > 0
end

grantActions["PRODUCT_WAVE_SKIP"] = function(player)
	local killed = 0
	for _, e in ipairs(enemies) do
		if e.alive then
			if e.boss then
				damageEnemy(e, e.hp * 0.5, player, false)
			else
				local pos = e.model and e.model.PrimaryPart and e.model.PrimaryPart.Position or Vector3.new()
				e.alive = false
				if e.model then e.model:Destroy() end
				burst(pos, Color3.fromRGB(255, 210, 120), 5, 0.9)
				killed = killed + 1
				Game.kills = Game.kills + 1
			end
		end
	end
	RD.State:FireClient(player, {
		event = "toast",
		title = "⏭ 웨이브 정리",
		sub = killed .. "마리 제거" .. (Game.boss and " · 보스 50% 피해" or ""),
	})
	return true
end

grantActions["PRODUCT_TEAM_GOLD"] = function(player)
	for _, p in ipairs(Players:GetPlayers()) do
		awardMinerals(p, 150)
	end
	announceGift(player, "💎 팀 전체 미네랄 +150", Color3.fromRGB(120, 235, 255))
	return true
end

grantActions["PRODUCT_TEAM_SPEED"] = function(player)
	Game.teamSpeedUntil = math.max(Game.teamSpeedUntil, now()) + 300
	announceGift(player, "⚡ 팀 전체 공속 +50% (5분)", Color3.fromRGB(255, 210, 120))
	for _, rec in ipairs(padList) do
		if rec.tier > 0 then
			ringFX(rec.pad.PrimaryPart.Position + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 210, 120), 4)
		end
	end
	-- 5분 유지 팀 오라 (넥서스 둘레)
	local aura = Instance.new("Part")
	aura.Shape = Enum.PartType.Cylinder
	aura.Size = Vector3.new(0.4, 34, 34)
	aura.CFrame = CFrame.new(NEXUS_POS + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	aura.Anchored = true
	aura.CanCollide = false
	aura.CanQuery = false
	aura.CanTouch = false
	aura.CastShadow = false
	aura.Material = Enum.Material.Neon
	aura.Color = Color3.fromRGB(255, 190, 90)
	aura.Transparency = 0.82
	aura.Parent = fxFolder
	Debris:AddItem(aura, 300)
	return true
end

grantActions["PRODUCT_STARTER"] = function(player)
	local sp = SP[player]
	if not sp then return false end
	awardMinerals(player, 400)
	Data.addRevive(player, 2)
	player:SetAttribute("ReviveStock", math.min(3, (player:GetAttribute("ReviveStock") or 0) + 2))
	local free = freeSlots(sp.lane, player)
	if #free > 0 then
		installTurret(free[math.random(1, #free)], 4, math.random(1, 2), 0, sp.lane)
	end
	RD.State:FireClient(player, {
		event = "toast",
		title = "🚀 스타터팩 도착!",
		sub = "보석 300 + 미네랄 400 + 전설 1 + 부활권 2",
	})
	return true
end

grantActions["PRODUCT_LUCK10"] = function(player)
	return drawFor(player, { count = 10, free = true, guaranteedRare = true }) > 0
end

grantActions["PRODUCT_LEGEND"] = function(player)
	local sp = SP[player]
	if not sp then return false end
	local free = freeSlots(sp.lane, player)
	if #free > 0 then
		installTurret(free[math.random(1, #free)], 4, math.random(1, 2), 0, sp.lane)
		RD.State:FireClient(player, { event = "toast", title = "🌟 전설 터렛 배치!", sub = "전설 확정 뽑기" })
	else
		awardMinerals(player, 250)
		RD.State:FireClient(player, { event = "toast", title = "빈 패드가 없습니다", sub = "미네랄 250으로 대체 지급" })
	end
	return true
end

function announceGift(sender, text, color)
	for _, p in ipairs(Players:GetPlayers()) do
		RD.State:FireClient(p, {
			event = "gift",
			title = text,
			by = sender and sender.DisplayName or "",
		})
		RD.FX:FireClient(p, { kind = "flash", color = color or Color3.fromRGB(255, 210, 120) })
	end
end

if bus then
	bus.Call.OnInvoke = function(player, action, payload)
		if action == "product" then
			local fn = grantActions[payload]
			if not fn then return false end
			local ok, res = pcall(fn, player)
			if not ok then
				warn("[TD] 상품 지급 오류: " .. tostring(res))
				return false
			end
			return res == true
		elseif action == "reward" then
			if type(payload) ~= "table" then return false end
			local sp = SP[player]
			if not sp then return false end
			if payload.minerals and payload.minerals > 0 then
				awardMinerals(player, payload.minerals)
			end
			if payload.revive and payload.revive > 0 then
				Data.addRevive(player, payload.revive)
				player:SetAttribute("ReviveStock", math.min(3, (player:GetAttribute("ReviveStock") or 0) + payload.revive))
			end
			if payload.boostDmg then
				sp.boostDmgUntil = math.max(sp.boostDmgUntil, now()) + payload.boostDmg
			end
			return true
		elseif action == "refresh" then
			-- 영구 강화(보석 상점)를 산 직후: 이번 판에도 바로 반영
			local profile = Data.get(player)
			local sp = SP[player]
			if profile and sp and profile.upgrades then
				sp.permAtk = (profile.upgrades.permAtk or 0) * 0.03
			end
			return true
		elseif action == "ping" then
			return true
		end
		return false
	end
end

-- ===============================================================
-- 11. 클라이언트 요청
-- ===============================================================
RD.Draw.OnServerEvent:Connect(function(player)
	if Game.over or Game.downed then return end
	drawFor(player, { count = 1 })
	if player:GetAttribute("PassAuto") then
		mergeAllFor(player)
		local sp = SP[player]
		if sp and sp.minerals >= COST_DRAW then
			local free = freeSlots(sp.lane, player)
			if #free > 0 then drawFor(player, { count = 1 }) end
		end
	end
end)

RD.Merge.OnServerEvent:Connect(function(player)
	mergeAllFor(player)
end)

RD.Upgrade.OnServerEvent:Connect(function(player, which)
	local sp = SP[player]
	if not sp then return end
	if which == "atk" then
		local cost = 25 + Game.atkLv * 12
		if Game.gas >= cost then
			Game.gas = Game.gas - cost
			Game.atkLv = Game.atkLv + 1
		end
	elseif which == "spd" then
		local cost = 30 + Game.spdLv * 14
		if Game.gas >= cost then
			Game.gas = Game.gas - cost
			Game.spdLv = Game.spdLv + 1
		end
	end
end)

RD.Support.OnServerEvent:Connect(function(player, which)
	local sp = SP[player]
	if not sp then return end
	if which == "strike" then
		if sp.minerals < 120 then return end
		sp.minerals = sp.minerals - 120
		for _, e in ipairs(enemies) do
			if e.alive then damageEnemy(e, e.maxHp * 0.45, player, false) end
		end
		for l = 1, 4 do
			ringFX(Vector3.new(LANE_X[l] + ENEMY_X_OFF, 1, 0), Color3.fromRGB(255, 200, 80), 10)
		end
	elseif which == "repair" then
		if sp.minerals < 90 then return end
		sp.minerals = sp.minerals - 90
		Game.core = math.min(Game.coreMax, Game.core + 5)
	end
end)

RD.PickRelic.OnServerEvent:Connect(function(player, index)
	if not Game.relicPending then return end
	if not Game.relicChoices[index] then return end
	applyRelic(Game.relicChoices[index].key)
end)

-- 부활 버튼(보관 부활권 사용) · 혜택 요청 공통 창구
RD.Prompt.OnServerEvent:Connect(function(player, action, arg)
	if action == "revive_use" then
		if not Game.downed then return end
		if consumeRevive(player) then
			reviveNow(player, true)
		else
			RD.State:FireClient(player, { event = "toast", title = "부활권 없음", sub = "상점에서 부활권을 구매할 수 있습니다" })
		end
	elseif action == "auto_merge_toggle" then
		-- (자동 합성은 패스 소유자에게 서버가 자동 실행)
	end
end)

-- ===============================================================
-- 12. 참가/퇴장
-- ===============================================================
local function onPlayerAdded(player)
	task.spawn(function()
		setupPlayer(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	local lane = SP[player] and SP[player].lane
	if lane and laneOwner[lane] == player then
		laneOwner[lane] = nil
	end
	SP[player] = nil
	if #Players:GetPlayers() <= 1 then
		-- 마지막 즐기는 사람이 나가면 매치를 초기화 (다음 사람은 새 판)
		if not Game.over then
			resetMatch()
		end
	end
end)

-- ===============================================================
-- 13. 메인 루프
-- ===============================================================
local autoMergeAcc = {}
local fxAcc = 0

RunService.Heartbeat:Connect(function(dt)
	-- 넥서스 링 회전
	for _, p in ipairs(nexus:GetChildren()) do
		local spin = p:GetAttribute("Spin")
		if spin then
			p.CFrame = p.CFrame * CFrame.Angles(0, spin * dt, 0)
		end
	end

	if not Game.over and not Game.downed and anyPlayers() then
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

	-- 부활 창구 만료
	if Game.downed and now() > Game.reviveEnds then
		endMatch(false)
	end

	-- 승패 후 자동 재시작
	if Game.over and now() >= Game.restartAt and anyPlayers() then
		resetMatch()
	end

	-- 콤보 감쇠
	if Game.comboT > 0 and now() > Game.comboT then
		Game.combo = 0
		Game.comboT = 0
	end

	-- 적 이동
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		if not e.alive then
			table.remove(enemies, i)
		else
			local total = totalLen(e.lane)
			if not Game.downed then
				if e.dist < total then
					e.dist = math.min(total, e.dist + e.speed * dt * (e.air and 1.15 or 1))
				end
			end
			local pos
			if e.air then
				local t = math.clamp(e.dist / total, 0, 1)
				local sx = LANE_X[e.lane] + ENEMY_X_OFF
				pos = Vector3.new(sx * (1 - t), 7 + math.sin(os.clock() * 3) * 0.4, PATH_Z0 + t * (NEXUS_POS.Z - PATH_Z0))
			else
				pos = posAt(e.lane, e.dist)
			end
			local ahead = posAt(e.lane, math.min(total, e.dist + 1))
			local look = ahead - pos
			if look.Magnitude > 0.01 then
				e.model:PivotTo(CFrame.lookAt(pos, pos + look))
			else
				e.model:PivotTo(CFrame.new(pos))
			end

			if e.hpFill then
				local frac = math.clamp(e.hp / math.max(1, e.maxHp), 0, 1)
				e.hpFill.Size = UDim2.fromScale(frac, 0.7)
				e.hpFill.BackgroundColor3 = frac > 0.5 and Color3.fromRGB(120, 255, 160)
					or (frac > 0.25 and Color3.fromRGB(255, 215, 106) or Color3.fromRGB(255, 90, 105))
			end

			if not Game.downed and e.dist >= total - 0.5 then
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
					if e.model then e.model:Destroy() end
					table.remove(enemies, i)
				end
			end
		end
	end

	-- 터렛
	for _, rec in ipairs(padList) do
		updateTurret(rec, dt)
	end

	-- 자동 합성 (패스 · 0.5초마다. 매 프레임 실행 금지)
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("PassAuto") then
			autoMergeAcc[player] = (autoMergeAcc[player] or 0) + dt
			if autoMergeAcc[player] >= AUTO_MERGE_TICK then
				autoMergeAcc[player] = 0
				mergeAllFor(player)
			end
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
			if p.target and p.target.alive and p.target.model and p.target.model.PrimaryPart then
				tp = p.target.model.PrimaryPart.Position
			else
				tp = p.part.Position + p.part.CFrame.LookVector * 6
			end
			local dir = tp - p.part.Position
			local dist = dir.Magnitude
			local step = (p.speed or 100) * dt
			if dist <= math.max(1.2, step) then
				if p.target and p.target.alive then
					damageEnemy(p.target, p.dmg, p.owner, (Game.relics.boom or 0) > 0)
					if (p.splash or 0) > 0 then
						for _, other in ipairs(enemies) do
							if other ~= p.target and other.alive and other.model and other.model.PrimaryPart then
								if (other.model.PrimaryPart.Position - tp).Magnitude < p.splash then
									damageEnemy(other, p.dmg * 0.4, p.owner, false)
								end
							end
						end
					end
					burst(tp, TIER_COLORS[p.tier], 5, 0.6)
					ringFX(tp, TIER_COLORS[p.tier], p.splash > 0 and 5 or 2)
				end
				p.part:Destroy()
				table.remove(projectiles, i)
			elseif dist > 0.01 then
				p.part.CFrame = CFrame.lookAt(p.part.Position, tp) * CFrame.new(0, 0, -math.min(step, dist) / 2)
				p.part.Position = p.part.Position + dir.Unit * math.min(step, dist)
			end
		end
	end

	-- 웨이브 종료 판정
	if Game.waveActive and not Game.over and not Game.downed and #spawnQueue == 0 and #enemies == 0 then
		clearWaveReward()
	end

	-- 데미지 숫자 (0.25초마다 적별로 합산해 1번만 전송)
	fxAcc = fxAcc + dt
	if fxAcc >= 0.25 then
		fxAcc = 0
		for _, e in ipairs(enemies) do
			if e.alive and (e.dmgAcc or 0) > 0 and e.model and e.model.PrimaryPart then
				RD.FX:FireAllClients({
					kind = "dmg",
					pos = e.model.PrimaryPart.Position + Vector3.new(math.random(-2, 2), 3, math.random(-2, 2)),
					amount = math.floor(e.dmgAcc),
					boss = e.boss and true or false,
				})
				e.dmgAcc = 0
			end
		end
	end

	-- 넥서스 HP 표시(3D)
	if nexusFill then
		local frac = math.clamp(Game.core / math.max(1, Game.coreMax), 0, 1)
		nexusFill.Size = UDim2.fromScale(frac, 0.72)
		if nexusText then
			nexusText.Text = "NEXUS " .. Game.core .. " / " .. Game.coreMax
		end
	end
end)

-- ===============================================================
-- 14. 상태 동기화 (4Hz)
-- ===============================================================
task.spawn(function()
	while true do
		task.wait(0.25)
		local players = Players:GetPlayers()
		if #players > 0 then
			local party = {}
			for lane = 1, 4 do
				local owner = laneOwner[lane]
				local count, dps = 0, 0
				for slot = 1, #SLOT_Z do
					local rec = pads[lane] and pads[lane][slot]
					if rec and rec.tier > 0 then
						count = count + 1
						local st = statsFor(rec)
						if st then dps = dps + st.dps end
					end
				end
				table.insert(party, {
					lane = lane,
					name = owner and owner.DisplayName or "AI",
					ai = owner == nil,
					turrets = count,
					dps = math.floor(dps),
				})
			end

			for _, player in ipairs(players) do
				local sp = SP[player]
				local lane = sp and sp.lane or 0
				local myPads = {}
				local mergeable = 0
				if lane > 0 then
					local copy = {}
					for slot = 1, #SLOT_Z do
						local rec = pads[lane] and pads[lane][slot]
						if rec then
							table.insert(myPads, {
								slot = slot,
								tier = rec.tier,
								kind = rec.kind,
								star = rec.star,
								locked = (slot > GEO.FREE_SLOTS) and not slotUnlocked(player, slot),
							})
							if rec.tier > 0 then
								table.insert(copy, { t = rec.tier, k = rec.kind, s = rec.star })
							end
						end
					end
					for a = 1, #copy do
						for b = a + 1, #copy do
							if copy[a].t == copy[b].t and copy[a].k == copy[b].k and copy[a].s == copy[b].s then
								mergeable = mergeable + 1
							end
						end
					end
				end

				if sp then
					player:SetAttribute("Minerals", sp.minerals)
					player:SetAttribute("M_kills", sp.metrics.kills)
					player:SetAttribute("M_merges", sp.metrics.merges)
					player:SetAttribute("M_draws", sp.metrics.draws)
					player:SetAttribute("M_wave", sp.metrics.wave)
					player:SetAttribute("M_bossKills", sp.metrics.bossKills)
					player:SetAttribute("M_revives", sp.metrics.revives)
				end

				RD.State:FireClient(player, {
					event = "state",
					wave = Game.wave,
					waveActive = Game.waveActive,
					timer = math.max(0, math.floor(Game.timer)),
					core = Game.core,
					coreMax = Game.coreMax,
					gas = Game.gas,
					atkLv = Game.atkLv,
					spdLv = Game.spdLv,
					minerals = sp and sp.minerals or 0,
					pity = sp and sp.pity or 0,
					lane = lane,
					party = party,
					pads = myPads,
					mergeable = mergeable,
					relics = Game.relics,
					kills = Game.kills,
					combo = Game.combo,
					phase = Game.over and "over" or (Game.downed and "downed" or (Game.waveActive and "wave" or "ready")),
					downed = Game.downed,
					reviveSeconds = Game.downed and math.max(0, math.floor(Game.reviveEnds - now())) or 0,
					reviveStock = player:GetAttribute("ReviveStock") or 0,
					boss = Game.boss and {
						hp = math.floor(Game.boss.hp),
						maxHp = math.floor(Game.boss.maxHp),
						lane = Game.boss.lane,
					} or nil,
					boostDmg = sp and math.max(0, math.floor(sp.boostDmgUntil - now())) or 0,
					boostGold = sp and math.max(0, math.floor(sp.boostGoldUntil - now())) or 0,
					teamSpeed = math.max(0, math.floor(Game.teamSpeedUntil - now())),
					passes = {
						vip = player:GetAttribute("PassVip") == true,
						auto = player:GetAttribute("PassAuto") == true,
						bonus = player:GetAttribute("PassBonus") == true,
						slots = player:GetAttribute("PassSlots") == true,
						luck = player:GetAttribute("PassLuck") == true,
						twoX = player:GetAttribute("Pass2x") == true,
					},
				})
			end
		end
	end
end)

print("[TD] 02_WaveGachaMerge 시작 — 4인 협동 · " .. MAX_WAVE .. "웨이브 · 부활/부스트/팀버프 · v" .. Shared.VERSION)
