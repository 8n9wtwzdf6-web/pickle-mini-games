--[[ ============================================================
  02_ArenaBattle.server.lua  —  v3.0
  🌌 5개 팀 부유 아레나 · 자유 건설 그리드 · 40단계 × 100마리 ·
     이종족 융합 · 우주 정중앙 최종 보스 DPS 레이드
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService (일반 Script)
  먼저 준비 : ReplicatedStorage "TDShared",
              ServerScriptService "TDData",
              01_WorldAndUnits 가 한 번이라도 실행되어 TDWorld 가 있어야 합니다.
  담당
    · 팀(아레나) 배정 · 자유 타일 건설/이동 · 모드 전환 · 스킬 · 합성 · 융합
    · 40단계(일반 99 + 영웅 1) 웨이브 · 4구간 몬스터 · 유물
    · 최종 보스 레이드 + 5팀 실시간 딜량 순위
    · 부스트/부활 · 상품 지급 창구(Bus.Call) — 03·05 가 여기로 요청
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local Data = require(script.Parent:WaitForChild("TDData"))
local bus = Shared.bus()
local remotes = Shared.remotes()

local U = Shared.UNIVERSE
local GRID_N = U.GRID_N
local CELL = U.CELL
local COST_DRAW = Shared.GACHA_COST
local MAX_STAGE = Shared.MAX_STAGE
local STAGE_MOBS = Shared.STAGE_MOBS

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
	Build = remotes.TD_Build,
}

local REVIVE_WINDOW = 12
local RESTART_DELAY = 20
local MAX_LIVE = 30
local AUTO_MERGE_TICK = 0.7

Players.CharacterAutoLoads = false

-- ---------------------------------------------------------------
-- 월드 참조
-- ---------------------------------------------------------------
local world = Workspace:WaitForChild("TDWorld", 30)
if not world then
	warn("[TD] TDWorld 가 없습니다. 01_WorldAndUnits 를 ServerScriptService 에 넣고 한 번 실행하세요.")
	world = Workspace:WaitForChild("TDWorld")
end
local arenasFolder = world:WaitForChild("Arenas")
local centerFolder = world:WaitForChild("Center")

-- 01 이 5개 아레나(타일 64 + 넥서스)를 다 만들 때까지 기다립니다 (서버 시작 경합 방지)
do
	local t0 = os.clock()
	while os.clock() - t0 < 40 do
		local ready = true
		for slot = 1, 5 do
			local a = arenasFolder:FindFirstChild("Arena_" .. slot)
			if not a then ready = false break end
			local cells = a:FindFirstChild("Cells")
			if not cells or #cells:GetChildren() < 60 or not a:FindFirstChild("Nexus") then ready = false break end
		end
		if ready then break end
		task.wait(0.25)
	end
end

local enemyTemplates = ReplicatedStorage:WaitForChild("TD_Enemies")
local unitTemplates = ReplicatedStorage:WaitForChild("TD_Units")

local enemyFolder = Instance.new("Folder")
enemyFolder.Name = "TD_EnemiesLive"
enemyFolder.Parent = Workspace
local fxFolder = Instance.new("Folder")
fxFolder.Name = "TD_FXLive"
fxFolder.Parent = Workspace

-- ---------------------------------------------------------------
-- 상태
-- ---------------------------------------------------------------
local Game = {
	theme = "sf",
	phase = "stage",       -- stage | boss | over
	startedAt = os.clock(),
	bossHp = 0,
	bossMax = 0,
	bossModel = nil,
	bossAlive = false,
	bossShockT = 0,
	bossAddT = 0,
	bossStartedAt = 0,
	bossDamageTotal = 0,
	over = false,
	won = false,
	restartAt = 0,
	elapsed = 0,
}

local Teams = {}
local teamByPlayer = {}

-- 앞으로 정의될 함수들 (먼저 이름을 잡아 두어야 아래에서 부를 수 있습니다)
local damageCore, endMatch, reviveNow, openRelicPick, autoPlaceHand, clearStageReward

local function now()
	return os.clock()
end

local function humanTeams()
	local out = {}
	for slot = 1, 5 do
		local t = Teams[slot]
		if t and t.owner then table.insert(out, t) end
	end
	return out
end

local function anyPlayers()
	return #Players:GetPlayers() > 0
end

local function sendState(team, data)
	if team and team.owner and team.owner.Parent then
		RD.State:FireClient(team.owner, data)
	end
end

local function sendFX(team, data)
	if team and team.owner and team.owner.Parent then
		RD.FX:FireClient(team.owner, data)
	end
end

local function toast(team, title, sub, extra)
	local data = { event = "toast", title = title, sub = sub }
	if extra then
		for k, v in pairs(extra) do data[k] = v end
	end
	sendState(team, data)
end

local function banner(team, title, sub)
	sendState(team, { event = "banner", title = title, sub = sub })
end

local function bannerAll(title, sub, color)
	for _, p in ipairs(Players:GetPlayers()) do
		RD.State:FireClient(p, { event = "banner", title = title, sub = sub, color = color })
	end
end

local function isPremium(player)
	local ok, mt = pcall(function() return player.MembershipType end)
	return ok and mt == Enum.MembershipType.Premium
end

local function rewardMultiplier(team)
	local mul = 1
	if team.owner and team.owner:GetAttribute("PassVip") then mul = mul + Shared.VIP_BONUS end
	if team.owner and isPremium(team.owner) then mul = mul + Shared.PREMIUM_BONUS end
	return mul
end

-- ===============================================================
-- 1. 팀 초기화
-- ===============================================================
local function cellKey(col, row)
	return Shared.cellKey(col, row)
end

local function canBuildCell(team, col, row)
	local cell = team.cells[cellKey(col, row)]
	if not cell then return false end
	if cell:GetAttribute("Free") == true then return true end
	return team.expanded == true
end

local function newTeamState(slot, arena)
	local team = {
		slot = slot,
		arena = arena,
		cf = arena:GetPivot(),
		faction = arena:GetAttribute("Faction") or "human",
		name = arena:GetAttribute("TeamName") or "TEAM",
		owner = nil,
		ai = true,
		cells = {},
		units = {},
		unitList = {},
		hand = {},
		minerals = 150,
		gas = 30,
		atkLv = 0,
		spdLv = 0,
		relics = {},
		relicPending = false,
		relicChoices = {},
		permAtk = 0,
		stage = 0,
		waveActive = false,
		waveTimer = 14,
		spawned = 0,
		killed = 0,
		spawnQueue = {},
		spawnClock = 0,
		core = U.CORE_MAX,
		coreMax = U.CORE_MAX,
		downed = false,
		reviveEnds = 0,
		enemies = {},
		boostDmgUntil = 0,
		teamBoostUntil = 0,
		expanded = false,
		fusionBuffs = { atk = 0, spd = 0, range = 0, splash = 0 },
		bossDamage = 0,
		bossDpsShown = 0,
		dpsCache = 0,
		dpsCacheAt = 0,
		metrics = { kills = 0, stage = 0, merges = 0, draws = 0, fusions = 0, modes = 0, bossKills = 0, revives = 0 },
		aiBuildT = 2,
		aiStageT = 20,
		finished = false,
		pathVersion = 0,
		pathPts = {},
		cum = { 0 },
		pathLen = 0,
		nexusCore = nil,
		hpFill = nil,
		hpText = nil,
		beacon = arena:FindFirstChild("WarnBeacon"),
		aiLight = arena:FindFirstChild("AILight"),
	}
	team.yaw = select(2, team.cf:ToEulerAnglesYXZ()) or 0
	team.origin = team.cf.Position

	local cellsFolder = arena:FindFirstChild("Cells")
	if cellsFolder then
		for _, cell in ipairs(cellsFolder:GetChildren()) do
			local col = cell:GetAttribute("Col")
			local row = cell:GetAttribute("Row")
			if col and row then
				team.cells[cellKey(col, row)] = cell
			end
		end
	end

	local nexus = arena:FindFirstChild("Nexus")
	if nexus then
		team.nexusCore = nexus:FindFirstChild("Core") or nexus:FindFirstChild("Hull")
		local gui = team.nexusCore and team.nexusCore:FindFirstChild("NexusHP")
		if gui then
			local back = gui:FindFirstChildOfClass("Frame")
			team.hpFill = back and back:FindFirstChild("Fill")
			team.hpText = back and back:FindFirstChild("Label")
		end
	end
	return team
end

for slot = 1, 5 do
	local arena = arenasFolder:FindFirstChild("Arena_" .. slot)
	if arena then
		Teams[slot] = newTeamState(slot, arena)
	end
end

-- ---------------------------------------------------------------
-- 도우미 : 이펙트
-- ---------------------------------------------------------------
local function burst(pos, color, count, size)
	if not pos then return end
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
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5).Unit
		TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = pos + dir * math.random(4, 11),
			Transparency = 1,
			Size = Vector3.new(size * 0.2, size * 0.2, size * 0.2),
		}):Play()
		Debris:AddItem(p, 0.6)
	end
end

local function ringFX(pos, color, radius)
	if not pos then return end
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
	TweenService:Create(ring, TweenInfo.new(0.55), { Size = Vector3.new(0.2, radius * 5, radius * 5), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.6)
end

local function tracer(from, to, color, thick)
	local dist = (to - from).Magnitude
	if dist < 0.5 then return end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(thick or 0.32, thick or 0.32, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Transparency = 0.1
	p.Parent = fxFolder
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.14)
end

-- ===============================================================
-- 2. 그리드 경로 (BFS) — 건물이 길을 막으면 건설 금지
-- ===============================================================
local NEIGHBORS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function findPath(team, extraBlockKey)
	local blocked = {}
	for key in pairs(team.units) do
		blocked[key] = true
	end
	if extraBlockKey then blocked[extraBlockKey] = true end

	local startKey = cellKey(U.START_CELL.col, U.START_CELL.row)
	local goalKey = cellKey(U.GOAL_CELL.col, U.GOAL_CELL.row)
	blocked[startKey] = nil
	blocked[goalKey] = nil

	local queue = { { U.START_CELL.col, U.START_CELL.row } }
	local head = 1
	local prev = {}
	local seen = { [startKey] = true }
	local found = false

	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		if cellKey(cur[1], cur[2]) == goalKey then
			found = true
			break
		end
		for _, d in ipairs(NEIGHBORS) do
			local nc, nr = cur[1] + d[1], cur[2] + d[2]
			if nc >= 1 and nc <= GRID_N and nr >= 1 and nr <= GRID_N then
				local k = cellKey(nc, nr)
				if not seen[k] and not blocked[k] then
					seen[k] = true
					prev[k] = cur
					table.insert(queue, { nc, nr })
				end
			end
		end
	end

	if not found then return nil end

	local path = {}
	local cur = { U.GOAL_CELL.col, U.GOAL_CELL.row }
	while cur do
		table.insert(path, 1, cur)
		local k = cellKey(cur[1], cur[2])
		if k == startKey then break end
		cur = prev[k]
	end
	return path
end

local function rebuildPath(team)
	local path = findPath(team, nil) or { { U.GOAL_CELL.col, U.GOAL_CELL.row } }
	local pts = {}
	for _, c in ipairs(path) do
		local cell = team.cells[cellKey(c[1], c[2])]
		if cell then
			table.insert(pts, cell.Position + Vector3.new(0, 0.1, 0))
		end
	end
	-- 마지막은 넥서스 앞
	local nx = team.cf * CFrame.new(U.NEXUS_LOCAL.X, 0.1, U.NEXUS_LOCAL.Z - 6)
	table.insert(pts, nx.Position)
	local cum = { 0 }
	local total = 0
	for i = 2, #pts do
		total = total + (pts[i] - pts[i - 1]).Magnitude
		cum[i] = total
	end
	team.pathPts = pts
	team.cum = cum
	team.pathLen = total
	team.pathVersion = team.pathVersion + 1
end

local function pathPos(team, dist)
	local pts = team.pathPts
	local cum = team.cum
	if #pts == 0 then return team.origin end
	if #pts == 1 or dist <= 0 then return pts[1] end
	if dist >= team.pathLen then return pts[#pts] end
	local i = 1
	while i < #cum and cum[i + 1] < dist do
		i = i + 1
	end
	local segLen = cum[i + 1] - cum[i]
	local t = (segLen > 0) and ((dist - cum[i]) / segLen) or 0
	return pts[i]:Lerp(pts[i + 1], t)
end

for slot = 1, 5 do
	if Teams[slot] then rebuildPath(Teams[slot]) end
end

-- 회전하는 네온 링(넥서스·제단·포털)을 한 번만 모아 둡니다 (프레임마다 전체 순회 금지)
local spinParts = {}
for slot = 1, 5 do
	local team = Teams[slot]
	if team then
		for _, p in ipairs(team.arena:GetDescendants()) do
			local spin = p:GetAttribute("Spin")
			if spin and p:IsA("BasePart") then
				table.insert(spinParts, { part = p, spin = spin })
			end
		end
	end
end
for _, p in ipairs(centerFolder:GetDescendants()) do
	local spin = p:GetAttribute("Spin")
	if spin and p:IsA("BasePart") then
		table.insert(spinParts, { part = p, spin = spin })
	end
end

-- ===============================================================
-- 3. 유닛 (터렛) 설치 · 스탯
-- ===============================================================
local function unitModelName(rec)
	if rec.fusionKey then
		return "FUSION_" .. rec.fusionKey
	end
	local faction = Shared.FACTION_BY_KEY[rec.faction] or Shared.FACTIONS[1]
	local form = faction.forms[math.clamp(rec.form or 1, 1, 2)]
	return rec.faction .. "_" .. form.key
end

local function unitCF(team, rec)
	local cell = team.cells[cellKey(rec.col, rec.row)]
	local pos = cell and cell.Position or team.origin
	return CFrame.new(pos + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, team.yaw, 0)
end

local function removeUnit(team, key)
	local rec = team.units[key]
	if not rec then return end
	if rec.model then rec.model:Destroy() end
	team.units[key] = nil
	for i = #team.unitList, 1, -1 do
		if team.unitList[i] == rec then table.remove(team.unitList, i) end
	end
	local cell = team.cells[key]
	if cell then
		cell:SetAttribute("Unit", false)
	end
end

local function refreshUnitVisual(team, rec)
	if rec.model then rec.model:Destroy() end
	local template = unitTemplates:FindFirstChild(unitModelName(rec))
	if not template then return end
	local model = template:Clone()
	model.Parent = team.arena
	local base = unitCF(team, rec)
	model:PivotTo(base)
	rec.model = model
	rec.heads = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local n = p.Name
			if string.sub(n, 1, 4) == "Head" then
				table.insert(rec.heads, { part = p, offset = base:ToObjectSpace(p.CFrame) })
			elseif n == "Accent" or n == "AccentRing" or string.sub(n, 1, 6) == "Accent" then
				p.Color = Shared.TIER_COLORS[math.clamp(rec.tier or 1, 1, 5)]
			elseif n == "TierPip" then
				p.Transparency = 1
			end
		end
	end
	-- 등급 표시 : 발치 네온 점
	local pipColor = Shared.TIER_COLORS[math.clamp(rec.tier or 1, 1, 5)]
	for i = 1, math.clamp(rec.tier or 1, 1, 5) do
		local pip = Instance.new("Part")
		pip.Name = "TierPip"
		pip.Shape = Enum.PartType.Ball
		pip.Size = Vector3.new(0.34, 0.34, 0.34)
		pip.Anchored = true
		pip.CanCollide = false
		pip.CanQuery = false
		pip.CanTouch = false
		pip.CastShadow = false
		pip.Material = Enum.Material.Neon
		pip.Color = pipColor
		local a = math.rad(-50 + i * 20)
		pip.CFrame = base * CFrame.new(math.cos(a) * 2.25, 0.9, math.sin(a) * 2.25)
		pip.Parent = model
	end
	if (rec.star or 0) > 0 then
		local star = Instance.new("Part")
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.new(0.6, 0.6, 0.6)
		star.Anchored = true
		star.CanCollide = false
		star.CanQuery = false
		star.CanTouch = false
		star.CastShadow = false
		star.Material = Enum.Material.Neon
		star.Color = Color3.fromRGB(255, 220, 120)
		star.CFrame = base * CFrame.new(0, 4.2, 0)
		star.Parent = model
	end
	model:SetAttribute("Tier", rec.tier)
	model:SetAttribute("Form", rec.form)
	model:SetAttribute("Faction", rec.faction)
end

local function teamMods(team)
	local atk = (1 + 0.12 * team.atkLv) * (1 + 0.25 * (team.relics.atk or 0)) * (1 + (team.permAtk or 0))
	local spd = (1 + 0.08 * team.spdLv) * (1 + 0.20 * (team.relics.spd or 0))
	local range = 1 + 0.18 * (team.relics.range or 0)
	local splash = 1
	atk = atk * (1 + (team.fusionBuffs.atk or 0))
	spd = spd * (1 + (team.fusionBuffs.spd or 0))
	range = range + (team.fusionBuffs.range or 0)
	splash = splash + (team.fusionBuffs.splash or 0)
	if now() < team.boostDmgUntil then atk = atk * Shared.OVERCHARGE_MUL end
	if now() < team.teamBoostUntil then atk = atk * Shared.TEAM_BOOST_MUL end
	if team.owner and team.owner:GetAttribute("Pass2x") then spd = spd * 1.25 end
	return atk, spd, range, splash
end

local function statsFor(team, rec)
	local atk, spd, range, splash = teamMods(team)
	if rec.fusionKey then
		local def = Shared.FUSION_BY_KEY[rec.fusionKey]
		if not def then return nil end
		local s = Shared.fusionStats(def, {
			atkMul = atk,
			spdMul = spd,
			rangeMul = range,
			splashMul = splash,
			fusionMaster = team.owner and team.owner:GetAttribute("PassFusion") == true,
		})
		if now() < (rec.rushUntil or 0) then
			s.cd = math.max(0.05, s.cd * 0.5)
			s.dps = s.dmg * s.shots / s.cd
		end
		return s
	end
	local faction = Shared.FACTION_BY_KEY[rec.faction] or Shared.FACTIONS[1]
	local form = faction.forms[math.clamp(rec.form or 1, 1, 2)]
	local s = Shared.unitStats({
		faction = faction.key,
		form = math.clamp(rec.form or 1, 1, 2),
		tier = rec.tier,
		star = rec.star,
		atkMul = atk,
		spdMul = spd,
		rangeMul = range,
		splashMul = splash,
	})
	if now() < (rec.rushUntil or 0) then
		s.cd = math.max(0.05, s.cd * 0.5)
		s.dps = s.dmg * s.shots / s.cd
	end
	if (team.relics.boom or 0) > 0 then s.boom = true end
	return s
end

local function teamDps(team)
	local t = now()
	if t - (team.dpsCacheAt or 0) < 0.4 then return team.dpsCache end
	local total = 0
	for _, rec in ipairs(team.unitList) do
		local s = statsFor(team, rec)
		if s then total = total + s.dps end
	end
	team.dpsCache = total
	team.dpsCacheAt = t
	return total
end

local function installUnit(team, rec)
	refreshUnitVisual(team, rec)
	rec.cd = math.random() * 0.3
	rec.yaw = 0
	rec.target = nil
	rec.retarget = 0
	rec.skillCdEnd = rec.skillCdEnd or 0
	rec.modeCdEnd = rec.modeCdEnd or 0
	return rec
end

local function placeUnit(team, col, row, def)
	local key = cellKey(col, row)
	if team.units[key] then return false, "이미 유닛이 있습니다" end
	if not canBuildCell(team, col, row) then return false, "잠긴 타일입니다 (아레나 확장 패스)" end
	-- 길이 막히는지 검사
	if not findPath(team, key) then
		return false, "몬스터 길이 완전히 막힙니다"
	end
	local cell = team.cells[key]
	if cell then
		for _, e in ipairs(team.enemies) do
			if e.alive and e.cellKey == key then
				return false, "몬스터가 지나가는 중입니다"
			end
		end
	end

	local rec = {
		col = col, row = row,
		tier = math.clamp(def.tier or 1, 1, 5),
		form = math.clamp(def.form or 1, 1, 2),
		faction = def.faction or team.faction,
		star = def.star or 0,
		fusionKey = def.fusionKey,
		cd = 0, yaw = 0, heads = {}, retarget = 0,
		skillCdEnd = 0, modeCdEnd = 0, rushUntil = 0,
	}
	team.units[key] = rec
	table.insert(team.unitList, rec)
	if cell then cell:SetAttribute("Unit", true) end
	installUnit(team, rec)
	rebuildPath(team)

	local pos = unitCF(team, rec).Position
	ringFX(pos + Vector3.new(0, 1, 0), Shared.TIER_COLORS[rec.tier], 6)
	burst(pos + Vector3.new(0, 2, 0), Shared.TIER_COLORS[rec.tier], rec.tier >= 4 and 16 or 8, 0.8)
	return true
end

local function freeCells(team)
	local out = {}
	for col = 1, GRID_N do
		for row = 1, GRID_N do
			local key = cellKey(col, row)
			if not team.units[key] and canBuildCell(team, col, row) then
				if findPath(team, key) then
					table.insert(out, { col = col, row = row })
				end
			end
		end
	end
	return out
end

-- ===============================================================
-- 4. 적
-- ===============================================================
local function spawnEnemy(team, kind, opts)
	opts = opts or {}
	local info = Shared.ENEMIES[kind]
	if not info then return nil end
	local tpl = enemyTemplates:FindFirstChild(info.model)
	if not tpl then return nil end

	local stage = math.max(1, team.stage)
	local hp = Shared.stageHp(stage) * (info.hp or 1)
	local hero = opts.hero == true
	if hero then hp = hp * Shared.HERO_HP_MUL end
	if opts.elite then hp = hp * 2.2 end

	local model = tpl:Clone()
	model.Parent = enemyFolder
	local scale = (info.size or 1) * (hero and 2.0 or 1.0)
	if math.abs(scale - 1) > 0.01 then
		model:ScaleTo(scale)
	end
	model:PivotTo(CFrame.new(team.pathPts[1] or team.origin))

	local e = {
		team = team,
		kind = kind,
		hero = hero,
		model = model,
		hp = hp,
		maxHp = hp,
		dist = 0,
		speed = 9.4 * (info.speed or 1),
		armor = info.armor or 0,
		reward = info.reward or 2,
		coreDmg = info.core or 1,
		air = info.air or false,
		alive = true,
		dmgAcc = 0,
		slowMul = 1,
		slowUntil = 0,
		cellKey = cellKey(U.START_CELL.col, U.START_CELL.row),
		pos = team.pathPts[1] or team.origin,
	}

	local hpGui = Instance.new("BillboardGui")
	hpGui.Size = UDim2.fromScale(hero and 8 or 3.4, hero and 1.2 or 0.5)
	hpGui.StudsOffset = Vector3.new(0, hero and 7 or 4.2, 0)
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
	fill.BackgroundColor3 = hero and Color3.fromRGB(255, 200, 90) or Color3.fromRGB(120, 255, 160)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	e.hpFill = fill

	table.insert(team.enemies, e)

	if hero then
		local aura = Instance.new("PointLight")
		aura.Color = Color3.fromRGB(255, 170, 80)
		aura.Range = 18
		aura.Brightness = 1.6
		aura.Parent = model.PrimaryPart
		sendFX(team, { kind = "heroWarn", pos = e.pos })
	end
	return e
end

local function awardKill(team, e)
	team.metrics.kills = team.metrics.kills + 1
	if e.hero then team.metrics.bossKills = team.metrics.bossKills + 1 end
	if team.owner and team.owner.Parent then
		local owner = team.owner
		local mul = rewardMultiplier(team)
		local relicMul = 1 + 0.35 * (team.relics.minerals or 0)
		local gain = math.max(1, math.floor(e.reward * relicMul * mul))
		team.minerals = team.minerals + gain
		if e.hero then
			team.minerals = team.minerals + math.floor(30 * mul)
			team.gas = team.gas + 8
			local profile = Data.get(owner)
			if profile then
				profile.bestStage = math.max(profile.bestStage or 0, team.stage)
			end
			-- 영웅 처치 시 30% 확률로 타 종족 지원 유닛(융합 재료)
			if math.random() < 0.30 and #team.hand < 4 then
				local others = {}
				for _, f in ipairs(Shared.FACTIONS) do
					if f.key ~= team.faction then table.insert(others, f) end
				end
				local pick = others[math.random(1, #others)]
				table.insert(team.hand, { tier = math.random(1, 2), form = math.random(1, 2), faction = pick.key, support = true })
				toast(team, "🌀 타 종족 지원 유닛", pick.icon .. " " .. pick.name .. " 유닛이 대기열에 들어왔습니다")
			end
		end
	end
end

local function damageEnemy(team, e, amount, sourceColor)
	if not e or not e.alive then return end
	local dmg = amount * (1 - (e.armor or 0))
	e.hp = e.hp - dmg
	e.dmgAcc = (e.dmgAcc or 0) + dmg
	if e.hp <= 0 then
		local deathPos = e.pos
		e.alive = false
		if e.model then e.model:Destroy() end
		awardKill(team, e)
		burst(deathPos, e.hero and Color3.fromRGB(255, 190, 90) or Color3.fromRGB(255, 120, 60), e.hero and 24 or 6, e.hero and 1.8 or 1.0)
		ringFX(deathPos, e.hero and Color3.fromRGB(255, 210, 120) or Color3.fromRGB(255, 120, 60), e.hero and 16 or 4)
	end
end

local function liveCount(team)
	local n = 0
	for _, e in ipairs(team.enemies) do
		if e.alive then n = n + 1 end
	end
	return n
end

-- ===============================================================
-- 5. 40단계 · 100마리
-- ===============================================================
local function buildStageQueue(team, stage)
	local tier = Shared.stageTier(stage)
	local q = {}
	local heroAt = math.random(math.floor(STAGE_MOBS * 0.45), math.floor(STAGE_MOBS * 0.85))
	for i = 1, STAGE_MOBS do
		local kind
		if i == heroAt then
			kind = tier.hero
		else
			kind = tier.types[math.random(1, #tier.types)]
		end
		table.insert(q, { kind = kind, hero = (i == heroAt) })
	end
	return q, tier
end

local function startStage(team)
	if team.stage >= MAX_STAGE then
		team.finished = true
		return
	end
	team.stage = team.stage + 1
	team.metrics.stage = math.max(team.metrics.stage, team.stage)
	team.waveActive = true
	team.spawned = 0
	team.killed = 0
	team.spawnClock = 0
	team.spawnQueue, team.stageTier = buildStageQueue(team, team.stage)
	local tier = team.stageTier
	local prefix = (team.stage % 10 == 1 and team.stage > 1) and "⚠ " or ""
	banner(team, prefix .. "STAGE " .. team.stage .. " / " .. MAX_STAGE, tier.name .. " · 100기 (영웅 1)")
	sendFX(team, { kind = "stageStart", stage = team.stage, tier = tier.name })
	if bus then
		bus.Event:Fire({ type = "stageStart", stage = team.stage, player = team.owner })
	end
end

local function clearStageReward(team)
	team.waveActive = false
	local stage = team.stage
	local minGain = math.floor((110 + stage * 30) * rewardMultiplier(team))
	local gasGain = 10 + math.floor(stage * 0.6)
	team.minerals = team.minerals + minGain
	team.gas = team.gas + gasGain
	if stage % 10 == 0 then
		local profile = team.owner and Data.get(team.owner)
		if profile then
			profile.gems = (profile.gems or 0) + 5
			profile.bestStage = math.max(profile.bestStage or 0, stage)
			Data.markDirty(team.owner)
			if team.owner then team.owner:SetAttribute("Gems", profile.gems) end
		end
	end
	toast(team, "STAGE " .. stage .. " 클리어", "💎 +" .. Shared.comma(minGain) .. "  ⛽ +" .. gasGain, { tier = 4 })
	ringFX((team.nexusCore and team.nexusCore.Position) or team.origin, Color3.fromRGB(120, 235, 255), 16)
	team.waveTimer = 5.5
	if team.owner and team.owner:GetAttribute("Pass2x") then
		team.waveTimer = team.waveTimer * 0.7
	end
	if stage % 5 == 0 then
		openRelicPick(team)
	end
	if stage >= MAX_STAGE then
		team.finished = true
		team.minerals = team.minerals + 500
		toast(team, "🏁 40단계 완주!", "우주 정중앙 최종 보스가 깨어납니다", { tier = 5 })
	end
	if bus then
		bus.Event:Fire({ type = "stageClear", stage = stage, player = team.owner })
	end
end

-- ===============================================================
-- 6. 유물
-- ===============================================================
function openRelicPick(team)
	if team.relicPending then return end
	team.relicPending = true
	local pool = {}
	for _, r in ipairs(Shared.RELICS) do
		table.insert(pool, r)
	end
	local picks = {}
	local want = (team.owner and team.owner:GetAttribute("PassVip")) and 4 or 3
	for i = 1, want do
		if #pool == 0 then break end
		local idx = math.random(1, #pool)
		table.insert(picks, pool[idx])
		table.remove(pool, idx)
	end
	team.relicChoices = picks
	sendState(team, { event = "relic", picks = picks })
end

local function applyRelic(team, key)
	team.relics[key] = (team.relics[key] or 0) + 1
	if key == "shield" then
		team.coreMax = team.coreMax + 6
		team.core = team.coreMax
	elseif key == "gas" then
		team.gas = team.gas + 20
	end
	team.relicPending = false
	team.relicChoices = {}
	team.dpsCacheAt = 0
	sendState(team, { event = "relicDone", relic = key })
end

-- ===============================================================
-- 7. 뽑기 · 합성 · 모드 · 스킬 · 융합
-- ===============================================================
local function rollTierFor(team)
	local luckPass = team.owner and team.owner:GetAttribute("PassLuck") == true
	local pityGoal = luckPass and Shared.PITY_PASS or Shared.PITY_BASE
	team.pity = (team.pity or 0) + 1
	local tier
	if team.pity >= pityGoal then
		tier = Shared.rollTier(luckPass, true)
		team.pity = 0
	else
		tier = Shared.rollTier(luckPass, false)
		if tier >= 2 then team.pity = 0 end
	end
	return tier
end

local function drawToHand(team, count, free, guaranteedRare)
	local added = 0
	for i = 1, count do
		if #team.hand >= 4 then
			if added == 0 then toast(team, "대기열이 가득 찼습니다", "배치하고 다시 뽑으세요") end
			break
		end
		if not free then
			if team.minerals < COST_DRAW then break end
			team.minerals = team.minerals - COST_DRAW
		end
		local tier = rollTierFor(team)
		if guaranteedRare and i == count and tier < 2 then tier = 2 end
		local form = math.random(1, 2)
		table.insert(team.hand, { tier = tier, form = form, faction = team.faction })
		team.metrics.draws = team.metrics.draws + 1
		added = added + 1
		if tier >= 4 and not free then
			toast(team, Shared.TIER_NAMES[tier] .. " · " .. (Shared.FACTION_BY_KEY[team.faction].forms[form].name), "LEGENDARY PULL!", { tier = tier })
		end
	end
	if added > 0 then
		sendState(team, { event = "drawn", count = added })
		if team.owner and team.owner:GetAttribute("PassAuto") then
			autoPlaceHand(team)
		end
	end
	return added
end

function autoPlaceHand(team)
	local guard = 0
	while #team.hand > 0 and guard < 4 do
		guard = guard + 1
		local cells = freeCells(team)
		if #cells == 0 then break end
		local c = cells[math.random(1, #cells)]
		local item = table.remove(team.hand, 1)
		if not placeUnit(team, c.col, c.row, item) then
			table.insert(team.hand, item)
			break
		end
	end
end

local function mergeAll(team)
	local merges = 0
	for pass = 1, 60 do
		local found = false
		local list = team.unitList
		for a = 1, #list do
			local ua = list[a]
			if ua and not ua.fusionKey and not (ua.tier >= 5 and (ua.star or 0) >= 3) then
				for b = a + 1, #list do
					local ub = list[b]
					if ub and not ub.fusionKey and ub.tier == ua.tier and ub.form == ua.form
						and ub.faction == ua.faction and (ub.star or 0) == (ua.star or 0)
						and not (ub.tier >= 5 and (ub.star or 0) >= 3) then
						-- 합성
						local newTier = math.min(5, ua.tier + 1)
						local newStar = ua.tier >= 5 and math.min(3, (ua.star or 0) + 1) or (ua.star or 0)
						ua.tier = newTier
						ua.star = newStar
						removeUnit(team, cellKey(ub.col, ub.row))
						refreshUnitVisual(team, ua)
						local pos = unitCF(team, ua).Position
						ringFX(pos + Vector3.new(0, 1, 0), Shared.TIER_COLORS[newTier], 8)
						burst(pos + Vector3.new(0, 3, 0), Shared.TIER_COLORS[newTier], newTier >= 4 and 22 or 12, 0.8)
						team.metrics.merges = team.metrics.merges + 1
						merges = merges + 1
						found = true
						break
					end
				end
			end
			if found then break end
		end
		if not found then break end
	end
	if merges > 0 then
		team.dpsCacheAt = 0
		toast(team, "합성 진화! ×" .. merges, "같은 종족·모드 터렛이 한 단계 상승", { tier = 4 })
	end
	return merges
end

local function switchMode(team, rec)
	if rec.fusionKey then
		toast(team, "융합 유닛은 모드 전환이 없습니다", "대신 강력한 스킬을 씁니다")
		return false
	end
	if now() < (rec.modeCdEnd or 0) then
		toast(team, "모드 전환 대기", math.ceil(rec.modeCdEnd - now()) .. "초 남음")
		return false
	end
	rec.form = (rec.form == 1) and 2 or 1
	rec.modeCdEnd = now() + Shared.MODE_COOLDOWN
	rec.skillCdEnd = 0
	refreshUnitVisual(team, rec)
	team.metrics.modes = team.metrics.modes + 1
	team.dpsCacheAt = 0
	local faction = Shared.FACTION_BY_KEY[rec.faction] or Shared.FACTIONS[1]
	local form = faction.forms[rec.form]
	local pos = unitCF(team, rec).Position
	ringFX(pos + Vector3.new(0, 1, 0), faction.color, 9)
	burst(pos + Vector3.new(0, 3, 0), faction.color, 10, 0.7)
	toast(team, "🔄 " .. form.icon .. " " .. form.name .. " 모드", form.tag .. " · " .. form.skill .. " 사용 가능", { tier = rec.tier })
	sendFX(team, { kind = "modeSwitch", pos = pos })
	return true
end

local function enemiesInRange(team, pos, radius)
	local out = {}
	for _, e in ipairs(team.enemies) do
		if e.alive and (e.pos - pos).Magnitude <= radius then
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		return a.dist > b.dist
	end)
	return out
end

local function castSkill(team, rec)
	if now() < (rec.skillCdEnd or 0) then
		toast(team, "스킬 쿨타임", math.ceil(rec.skillCdEnd - now()) .. "초 남음")
		return false
	end
	local s = statsFor(team, rec)
	if not s then return false end
	local def
	local kind
	local name
	local cd
	if rec.fusionKey then
		def = Shared.FUSION_BY_KEY[rec.fusionKey]
		kind = def.skillKind
		name = def.skill
		cd = def.skillCd or 18
	else
		local faction = Shared.FACTION_BY_KEY[rec.faction] or Shared.FACTIONS[1]
		def = faction.forms[rec.form]
		kind = def.skillKind
		name = def.skill
		cd = def.skillCd or 15
	end

	local pos = unitCF(team, rec).Position
	local targets = enemiesInRange(team, pos, s.range * 1.25)
	local dealt = 0

	if kind == "rush" then
		rec.rushUntil = now() + 8
		team.dpsCacheAt = 0
		toast(team, "⚡ " .. name, "8초간 공속 2배")
	elseif kind == "quake" then
		if targets[1] then
			local center = targets[1].pos
			ringFX(center, Color3.fromRGB(255, 170, 70), 12)
			for _, e in ipairs(enemiesInRange(team, center, 13)) do
				damageEnemy(team, e, s.dmg * 2.6, nil)
				e.slowUntil = now() + 4
				e.slowMul = 0.5
				dealt = dealt + 1
			end
		end
		toast(team, "💥 " .. name, "광역 폭발 · 이동 -50% (4초)")
	elseif kind == "barrage" then
		for i = 1, math.min(5, #targets) do
			damageEnemy(team, targets[i], s.dmg * 2.2, nil)
			dealt = dealt + 1
		end
		toast(team, "🚀 " .. name, "5연발 집중 폭격")
	elseif kind == "chain" then
		local hit = math.min(5, #targets)
		for i = 1, hit do
			damageEnemy(team, targets[i], s.dmg * (1.9 - i * 0.12), nil)
			if targets[i].pos then
				tracer(pos, targets[i].pos, Color3.fromRGB(190, 140, 255), 0.4)
			end
			dealt = dealt + 1
		end
		toast(team, "⚡ " .. name, hit .. "기 연쇄 감전")
	elseif kind == "pierce" then
		local hit = math.min(6, #targets)
		for i = 1, hit do
			damageEnemy(team, targets[i], s.dmg * 2.0, nil)
			dealt = dealt + 1
		end
		toast(team, "🔮 " .. name, hit .. "기 관통")
	elseif kind == "swarm" then
		local hit = math.min(6, #targets)
		for i = 1, hit do
			damageEnemy(team, targets[i], s.dmg * 1.4, nil)
			dealt = dealt + 1
		end
		toast(team, "🛸 " .. name, hit .. "기 동시 타격")
	elseif kind == "acid" then
		local hit = math.min(5, #targets)
		for i = 1, hit do
			damageEnemy(team, targets[i], s.dmg * 1.2, nil)
			targets[i].slowUntil = now() + 4
			targets[i].slowMul = 0.55
			dealt = dealt + 1
		end
		ringFX(pos, Color3.fromRGB(140, 255, 160), 10)
		toast(team, "🧬 " .. name, "광역 독 · 이동 -45%")
	elseif kind == "pulse" then
		if targets[1] then
			damageEnemy(team, targets[1], s.dmg * 6, nil)
			dealt = 1
		end
		toast(team, "🎯 " .. name, "단일 대상 6배 피해")
	else
		if targets[1] then
			damageEnemy(team, targets[1], s.dmg * 3, nil)
			dealt = 1
		end
		toast(team, "✨ " .. name, "스킬 발동")
	end

	rec.skillCdEnd = now() + cd
	sendFX(team, { kind = "skill", pos = pos, color = (Shared.FACTION_BY_KEY[rec.faction] or Shared.FACTIONS[1]).color })
	return true
end

local function countBy(team, factionKey)
	local n = 0
	for _, rec in ipairs(team.unitList) do
		if rec.faction == factionKey and not rec.fusionKey then n = n + 1 end
	end
	return n
end

local function tryFusion(team, fusionKey)
	local def = Shared.FUSION_BY_KEY[fusionKey]
	if not def then return false, "없는 융합입니다" end
	if def.a ~= team.faction and def.b ~= team.faction then
		return false, "내 종족이 포함된 융합만 가능합니다"
	end
	local needA, needB = Shared.fusionNeed(team.owner and team.owner:GetAttribute("PassFusion") == true)
	if countBy(team, def.a) < needA or countBy(team, def.b) < needB then
		return false, def.a .. " " .. needA .. "기 + " .. def.b .. " " .. needB .. "기가 필요합니다"
	end

	local consumed = {}
	local function grab(factionKey, count)
		local picked = 0
		for _, rec in ipairs(team.unitList) do
			if picked >= count then break end
			if rec.faction == factionKey and not rec.fusionKey and not rec.consumed then
				rec.consumed = true
				table.insert(consumed, rec)
				picked = picked + 1
			end
		end
		return picked
	end
	grab(def.a, needA)
	grab(def.b, needB)

	if #consumed < needA + needB then
		for _, rec in ipairs(consumed) do rec.consumed = nil end
		return false, "재료 유닛이 부족합니다"
	end

	local host = consumed[1]
	local col, row = host.col, host.row
	for _, rec in ipairs(consumed) do
		removeUnit(team, cellKey(rec.col, rec.row))
	end
	local ok, err = placeUnit(team, col, row, { tier = 5, form = 1, faction = team.faction, fusionKey = def.key })
	if not ok then
		return false, err or "융합 유닛을 배치할 자리가 없습니다"
	end
	team.fusionBuffs[def.buff] = (team.fusionBuffs[def.buff] or 0) + def.buffValue
	team.metrics.fusions = team.metrics.fusions + 1
	team.dpsCacheAt = 0
	banner(team, "🧬 " .. def.icon .. " " .. def.name, def.desc)
	ringFX(unitCF(team, team.units[cellKey(col, row)]).Position, Color3.fromRGB(210, 140, 255), 16)
	return true
end

-- ===============================================================
-- 8. 터렛 사격
-- ===============================================================
local function fireAt(team, rec, stats, target)
	local base = unitCF(team, rec).Position + Vector3.new(0, 2.2, 0)
	local color = Shared.TIER_COLORS[math.clamp(rec.tier or 1, 1, 5)]
	local proj = stats.proj or "bullet"
	local hit = target.pos

	if proj == "beam" or proj == "psi" or proj == "laser" then
		tracer(base, hit, color, 0.42)
	else
		tracer(base, hit, color, 0.22)
	end

	damageEnemy(team, target, stats.dmg, color)
	if (stats.splash or 0) > 0 then
		for _, other in ipairs(team.enemies) do
			if other ~= target and other.alive and (other.pos - hit).Magnitude <= (stats.splash * 1.6 + 2) then
				damageEnemy(team, other, stats.dmg * 0.45, color)
			end
		end
	end
	if (Shared.FACTION_BY_KEY[rec.faction] or Shared.FACTIONS[1]).key == "bio" then
		if target.alive then
			target.slowUntil = math.max(target.slowUntil, now() + 1.5)
			target.slowMul = 0.65
		end
	end
end

local function updateUnit(team, rec, dt)
	if not rec.model then return end
	local stats = statsFor(team, rec)
	if not stats then return end
	local base = unitCF(team, rec).Position

	rec.retarget = (rec.retarget or 0) - dt
	if rec.retarget <= 0 or not (rec.target and rec.target.alive) then
		rec.retarget = 0.16
		local best, bestScore
		local bestDist = -1
		for _, e in ipairs(team.enemies) do
			if e.alive and (e.pos - base).Magnitude <= stats.range then
				local score = e.dist + (e.hero and 40 or 0)
				if score > (bestScore or -1) then
					bestScore = score
					best = e
					bestDist = (e.pos - base).Magnitude
				end
			end
		end
		rec.target = best
	end

	local target = rec.target
	if target and target.alive then
		local localBase = team.cf:PointToObjectSpace(base)
		local localT = team.cf:PointToObjectSpace(target.pos)
		local dx, dz = localT.X - localBase.X, localT.Z - localBase.Z
		local yaw = math.atan2(-dx, -dz)
		local delta = ((yaw - rec.yaw + math.pi * 3) % (math.pi * 2)) - math.pi
		rec.yaw = rec.yaw + delta * math.min(1, dt * 9)
		if #rec.heads > 0 then
			local face = unitCF(team, rec) * CFrame.Angles(0, rec.yaw, 0)
			for _, h in ipairs(rec.heads) do
				if h.part.Parent then
					h.part.CFrame = face * h.offset
				end
			end
		end
	end

	rec.cd = (rec.cd or 0) - dt
	if rec.cd <= 0 and target and target.alive then
		rec.cd = stats.cd
		local shots = stats.shots or 1
		local alive = target
		for i = 1, shots do
			if alive and alive.alive then
				task.delay(i * 0.045, function()
					if alive.alive and rec.model and team.units[cellKey(rec.col, rec.row)] == rec then
						fireAt(team, rec, stats, alive)
					end
				end)
			end
		end
	end
end

-- ===============================================================
-- 9. 최종 보스 레이드
-- ===============================================================
local function bossHpBar(model)
	local root = model.PrimaryPart
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossHP"
	gui.Size = UDim2.fromScale(70, 6)
	gui.StudsOffset = Vector3.new(0, 30, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 900
	gui.Parent = root
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(12, 4, 10)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 0.72)
	fill.Position = UDim2.fromScale(0, 0.14)
	fill.BackgroundColor3 = Color3.fromRGB(255, 70, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "오메가 파괴신"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = back
	return fill, label
end

local function startBoss()
	if Game.phase == "boss" or Game.phase == "over" then return end
	Game.phase = "boss"
	Game.bossAlive = true
	Game.bossStartedAt = now()
	Game.bossShockT = Shared.FINAL_BOSS.shockwaveEvery
	Game.bossAddT = Shared.FINAL_BOSS.addEvery
	Game.bossFxT = 0
	Game.bossMax = Shared.FINAL_BOSS.hpBase + Shared.FINAL_BOSS.hpPerPlayer * math.max(1, #humanTeams())
	Game.bossHp = Game.bossMax
	Game.bossDamageTotal = 0

	local template = enemyTemplates:FindFirstChild("omegaboss")
	if template then
		local model = template:Clone()
		model.Parent = centerFolder
		model:PivotTo(CFrame.new(0, 2, 0))
		Game.bossModel = model
		Game.bossFill, Game.bossLabel = bossHpBar(model)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 80, 120)
		light.Range = 220
		light.Brightness = 4
		light.Parent = model.PrimaryPart
	end

	for slot = 1, 5 do
		local team = Teams[slot]
		if team then
			team.bossDamage = 0
			team.bossDpsShown = 0
			team.spawnQueue = {}
			team.waveActive = false
			for _, e in ipairs(team.enemies) do
				if e.alive then
					e.alive = false
					if e.model then e.model:Destroy() end
				end
			end
			team.enemies = {}
			local beam = world:FindFirstChild("EnergyLink_" .. slot)
			if beam then beam.Transparency = 0.15 end
		end
	end

	bannerAll("⚠ FINAL BOSS", "우주 정중앙 · 오메가 파괴신 출현! (딜량 순위 경쟁)", Color3.fromRGB(255, 90, 110))
	for _, p in ipairs(Players:GetPlayers()) do
		RD.FX:FireClient(p, { kind = "bossWarn" })
	end
	if bus then
		bus.Event:Fire({ type = "bossStart" })
	end
end

local function bossDown(team)
	if not Game.bossAlive then return end
	Game.bossAlive = false
	Game.won = true
	Game.bossHp = 0
	if Game.bossModel then
		local pos = Game.bossModel.PrimaryPart and Game.bossModel.PrimaryPart.Position or Vector3.new(0, 10, 0)
		burst(pos, Color3.fromRGB(255, 200, 120), 40, 3)
		ringFX(Vector3.new(0, 2, 0), Color3.fromRGB(255, 220, 140), 60)
		Game.bossModel:Destroy()
		Game.bossModel = nil
	end
	for slot = 1, 5 do
		local t = Teams[slot]
		if t then
			local beam = world:FindFirstChild("EnergyLink_" .. slot)
			if beam then beam.Transparency = 0.55 end
		end
	end
	bannerAll("🏆 오메가 파괴신 격파!", "5개 팀의 합동 화력 · 보상 지급", Color3.fromRGB(255, 210, 120))
	for _, p in ipairs(Players:GetPlayers()) do
		RD.FX:FireClient(p, { kind = "flash", color = Color3.fromRGB(255, 220, 150) })
	end
	endMatch(true)
	if bus then
		bus.Event:Fire({ type = "bossKill", player = team and team.owner or nil })
	end
end

local function bossTick(dt)
	if Game.phase ~= "boss" or not Game.bossAlive then return end
	local elapsed = now() - Game.bossStartedAt

	-- 모델 회전 · 부유
	if Game.bossModel and Game.bossModel.PrimaryPart then
		Game.bossModel:PivotTo(CFrame.new(0, 2 + math.sin(elapsed * 0.7) * 0.8, 0) * CFrame.Angles(0, elapsed * 0.25, 0))
		for _, p in ipairs(Game.bossModel:GetDescendants()) do
			local spin = p:GetAttribute("Spin")
			if spin and p:IsA("BasePart") then
				p.CFrame = p.CFrame * CFrame.Angles(0, spin * dt, 0)
			end
		end
	end

	-- 5팀 딜량 → 보스 HP
	for slot = 1, 5 do
		local team = Teams[slot]
		if team then
			local dps = teamDps(team)
			local mul = team.owner and 1.0 or 0.45
			local dealt = dps * mul * dt
			if dealt > 0 then
				team.bossDamage = team.bossDamage + dealt
				Game.bossDamageTotal = Game.bossDamageTotal + dealt
			end
		end
	end
	Game.bossHp = math.max(0, Game.bossMax - Game.bossDamageTotal)
	if Game.bossFill then
		Game.bossFill.Size = UDim2.fromScale(math.clamp(Game.bossHp / math.max(1, Game.bossMax), 0, 1), 0.72)
	end
	if Game.bossLabel then
		Game.bossLabel.Text = "오메가 파괴신  " .. Shared.comma(math.floor(Game.bossHp)) .. " / " .. Shared.comma(Game.bossMax)
	end

	-- 5개 아레나 → 중앙 보스로 쏟아지는 화력 연출
	Game.bossFxT = (Game.bossFxT or 0) - dt
	if Game.bossFxT <= 0 and Game.bossModel and Game.bossModel.PrimaryPart then
		Game.bossFxT = 0.7
		local target = Game.bossModel.PrimaryPart.Position + Vector3.new(0, 16, 0)
		for slot = 1, 5 do
			local t = Teams[slot]
			if t and #t.unitList > 0 then
				local color = (Shared.FACTION_BY_KEY[t.faction] or Shared.FACTIONS[1]).color
				for _ = 1, math.min(3, #t.unitList) do
					local rec = t.unitList[math.random(1, #t.unitList)]
					if rec.model then
						local from = unitCF(t, rec).Position + Vector3.new(0, 2.2, 0)
						tracer(from, target, color, 0.55)
					end
				end
			end
		end
	end

	-- 광역 충격파
	Game.bossShockT = Game.bossShockT - dt
	if Game.bossShockT <= 0 then
		Game.bossShockT = Shared.FINAL_BOSS.shockwaveEvery
		for _, team in ipairs(humanTeams()) do
			ringFX(Vector3.new(0, 3, 0), Color3.fromRGB(255, 80, 110), 90)
			damageCore(team, Shared.FINAL_BOSS.shockwaveDamage, true)
			sendFX(team, { kind = "flash", color = Color3.fromRGB(255, 70, 90) })
			sendFX(team, { kind = "shake", strength = 1.2 })
		end
		bannerAll("💥 광역 충격파", "넥서스가 흔들립니다", Color3.fromRGB(255, 120, 120))
	end

	-- 소환수 투하
	Game.bossAddT = Game.bossAddT - dt
	if Game.bossAddT <= 0 then
		Game.bossAddT = Shared.FINAL_BOSS.addEvery
		local list = humanTeams()
		if #list > 0 then
			local team = list[math.random(1, #list)]
			local tier = Shared.stageTier(math.max(1, team.stage))
			for i = 1, Shared.FINAL_BOSS.addCount do
				spawnEnemy(team, tier.types[math.random(1, #tier.types)], {})
			end
			toast(team, "☠ 보스 소환수", "아레나에 정예 몬스터가 투하되었습니다")
		end
	end

	-- 보스전에서도 아레나 몬스터는 계속 넥서스를 노립니다 (위 updateEnemies)
	if elapsed > U.RAID_TIME and Game.bossAlive then
		bannerAll("⏳ 레이드 실패", "오메가 파괴신이 사라지지 않았습니다", Color3.fromRGB(255, 90, 90))
		endMatch(false)
	end
end

-- ===============================================================
-- 10. 넥서스 피해 · 부활 · 종료
-- ===============================================================
function damageCore(team, amount, silent)
	if team.downed or Game.over then return end
	team.core = math.max(0, team.core - amount)
	sendFX(team, { kind = "coreHit" })
	ringFX((team.nexusCore and team.nexusCore.Position) or team.origin, Color3.fromRGB(255, 80, 90), 14)
	if team.core <= 0 then
		team.downed = true
		team.reviveEnds = now() + REVIVE_WINDOW
		team.waveActive = false
		team.spawnQueue = {}
		sendState(team, {
			event = "reviveOffer",
			seconds = REVIVE_WINDOW,
			stock = team.owner and (team.owner:GetAttribute("ReviveStock") or 0) or 0,
			price = 25,
		})
	end
end

local function reviveNow(team, player, paid)
	team.downed = false
	team.core = math.max(8, math.floor(team.coreMax * 0.6))
	team.reviveEnds = 0
	team.waveActive = false
	team.spawnQueue = {}
	for _, e in ipairs(team.enemies) do
		if e.alive then
			burst(e.pos, Color3.fromRGB(120, 235, 255), 6, 0.9)
			e.alive = false
			if e.model then e.model:Destroy() end
		end
	end
	team.enemies = {}
	team.waveTimer = 6
	if team.metrics then team.metrics.revives = team.metrics.revives + 1 end
	if player then
		local stock = (player:GetAttribute("ReviveStock") or 0) - 1
		player:SetAttribute("ReviveStock", math.max(0, stock))
		Data.addRevive(player, -1)
		Data.markDirty(player)
	end
	banner(team, "💖 부활!", (player and player.DisplayName or "용사") .. " 님이 아레나를 되살렸습니다")
	sendFX(team, { kind = "flash", color = Color3.fromRGB(120, 235, 255) })
	if bus then
		bus.Event:Fire({ type = "revive", player = player })
	end
end

function endMatch(won)
	if Game.over then return end
	Game.over = true
	Game.phase = "over"
	Game.won = won
	Game.restartAt = now() + RESTART_DELAY

	for slot = 1, 5 do
		local team = Teams[slot]
		if team then
			team.waveActive = false
			team.spawnQueue = {}
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		local team = teamByPlayer[p]
		local profile = Data.get(p)
		if profile and team then
			profile.runs = (profile.runs or 0) + 1
			profile.wins = (profile.wins or 0) + (won and 1 or 0)
			profile.totalKills = (profile.totalKills or 0) + team.metrics.kills
			profile.bestStage = math.max(profile.bestStage or 0, team.stage)
			profile.bossDamage = (profile.bossDamage or 0) + math.floor(team.bossDamage)
			if won then profile.bossKills = (profile.bossKills or 0) + 1 end
			local gems = math.floor(team.stage * 0.8) + (won and 40 or 0)
			if p:GetAttribute("PassVip") then gems = gems + 8 end
			if isPremium(p) then gems = gems + 5 end
			profile.gems = (profile.gems or 0) + gems
			profile.pity = team.pity
			Data.markDirty(p)
			p:SetAttribute("Gems", profile.gems)
			p:SetAttribute("BestStage", profile.bestStage)
			RD.State:FireClient(p, {
				event = won and "win" or "lose",
				stage = team.stage,
				gems = gems,
				kills = team.metrics.kills,
				best = profile.bestStage,
				bossDamage = math.floor(team.bossDamage),
			})
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		Data.save(p, false)
	end
	if bus then
		bus.Event:Fire({ type = "matchEnd", stage = 0, won = won })
	end
end

local function resetMatch()
	for slot = 1, 5 do
		local team = Teams[slot]
		if team then
			for key in pairs(team.units) do
				removeUnit(team, key)
			end
			team.units = {}
			team.unitList = {}
			for _, e in ipairs(team.enemies) do
				if e.model then e.model:Destroy() end
			end
			team.enemies = {}
			team.hand = {}
			team.stage = 0
			team.waveActive = false
			team.waveTimer = 8
			team.spawnQueue = {}
			team.spawned = 0
			team.killed = 0
			team.coreMax = U.CORE_MAX
			team.core = U.CORE_MAX
			team.gas = 30
			team.atkLv = 0
			team.spdLv = 0
			team.relics = {}
			team.relicPending = false
			team.relicChoices = {}
			team.downed = false
			team.reviveEnds = 0
			team.boostDmgUntil = 0
			team.teamBoostUntil = 0
			team.fusionBuffs = { atk = 0, spd = 0, range = 0, splash = 0 }
			team.bossDamage = 0
			team.metrics = { kills = 0, stage = 0, merges = 0, draws = 0, fusions = 0, modes = 0, bossKills = 0, revives = 0 }
			team.finished = false
			team.dpsCacheAt = 0
			team.aiBuildT = 2
			team.aiStageT = 20
			rebuildPath(team)
			team.minerals = 150
			if team.owner then
				local profile = Data.get(team.owner)
				if profile then
					local up = profile.upgrades or {}
					team.minerals = 150 + (up.startMinerals or 0) * 40
					team.gas = team.gas + (up.startGas or 0) * 25
					team.permAtk = (up.permAtk or 0) * 0.03
					team.pity = profile.pity or 0
				end
			end
			if team.hpFill then
				team.hpFill.Size = UDim2.fromScale(1, 0.7)
				team.hpFill.BackgroundColor3 = Color3.fromRGB(90, 255, 170)
			end
		end
	end
	if Game.bossModel then
		Game.bossModel:Destroy()
		Game.bossModel = nil
	end
	Game.phase = "stage"
	Game.over = false
	Game.won = false
	Game.bossAlive = false
	Game.bossHp = 0
	Game.bossMax = 0
	Game.bossDamageTotal = 0
	Game.startedAt = now()

	for _, p in ipairs(Players:GetPlayers()) do
		RD.State:FireClient(p, { event = "restart" })
		RD.FX:FireClient(p, { kind = "restart" })
	end
end

-- ===============================================================
-- 11. 순위
-- ===============================================================
local function rankData(forTeam)
	local list = {}
	for slot = 1, 5 do
		local team = Teams[slot]
		if team then
			local dps = teamDps(team)
			local entry = {
				slot = slot,
				faction = team.faction,
				name = team.name,
				icon = (Shared.FACTION_BY_KEY[team.faction] or Shared.FACTIONS[1]).icon,
				player = team.owner and team.owner.DisplayName or nil,
				ai = team.owner == nil,
				stage = team.stage,
				dps = math.floor(dps),
				dmg = math.floor(team.bossDamage),
				pct = (Game.bossMax > 0) and (team.bossDamage / Game.bossMax * 100) or 0,
				core = team.core,
				coreMax = team.coreMax,
				isMe = (team == forTeam),
			}
			table.insert(list, entry)
		end
	end
	if Game.phase == "boss" then
		table.sort(list, function(a, b) return a.dmg > b.dmg end)
	else
		table.sort(list, function(a, b)
			if a.stage == b.stage then return a.dps > b.dps end
			return a.stage > b.stage
		end)
	end
	for i, entry in ipairs(list) do
		entry.rank = i
	end
	return list
end

-- ===============================================================
-- 12. 상태 전송 (4Hz)
-- ===============================================================
local function unitPayload(team)
	local out = {}
	for _, rec in ipairs(team.unitList) do
		local s = statsFor(team, rec)
		table.insert(out, {
			col = rec.col, row = rec.row,
			tier = rec.tier, form = rec.form, faction = rec.faction,
			star = rec.star or 0, fusionKey = rec.fusionKey,
			dps = s and math.floor(s.dps) or 0,
			modeCd = math.max(0, math.ceil((rec.modeCdEnd or 0) - now())),
			skillCd = math.max(0, math.ceil((rec.skillCdEnd or 0) - now())),
		})
	end
	return out
end

local function handPayload(team)
	local out = {}
	for i, item in ipairs(team.hand) do
		table.insert(out, {
			index = i, tier = item.tier, form = item.form,
			faction = item.faction, support = item.support == true,
		})
	end
	return out
end

local function fusionPayload(team)
	local out = {}
	local needA, needB = Shared.fusionNeed(team.owner and team.owner:GetAttribute("PassFusion") == true)
	for _, def in ipairs(Shared.FUSIONS) do
		if def.a == team.faction or def.b == team.faction then
			local a = countBy(team, def.a)
			local b = countBy(team, def.b)
			table.insert(out, {
				key = def.key, name = def.name, icon = def.icon, desc = def.desc,
				a = def.a, b = def.b, needA = needA, needB = needB,
				haveA = a, haveB = b,
				ready = (a >= needA and b >= needB),
			})
		end
	end
	return out
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local players = Players:GetPlayers()
		if #players > 0 then
			local baseRank = rankData(nil)
			for _, player in ipairs(players) do
				local team = teamByPlayer[player]
				if team then
					for _, entry in ipairs(baseRank) do
						entry.isMe = (entry.slot == team.slot)
					end
					player:SetAttribute("Minerals", team.minerals)
					player:SetAttribute("M_kills", team.metrics.kills)
					player:SetAttribute("M_stage", team.metrics.stage)
					player:SetAttribute("M_merges", team.metrics.merges)
					player:SetAttribute("M_draws", team.metrics.draws)
					player:SetAttribute("M_fusions", team.metrics.fusions)
					player:SetAttribute("M_modes", team.metrics.modes)
					player:SetAttribute("M_bossKills", team.metrics.bossKills)
					player:SetAttribute("M_revives", team.metrics.revives)

					RD.State:FireClient(player, {
						event = "state",
						phase = Game.phase,
						stage = team.stage,
						maxStage = MAX_STAGE,
						stageActive = team.waveActive,
						stageTimer = math.max(0, math.floor(team.waveTimer)),
						spawned = team.spawned,
						stageTotal = STAGE_MOBS,
						killed = team.killed,
						alive = liveCount(team),
						tierName = team.stageTier and team.stageTier.name or "",
						core = team.core,
						coreMax = team.coreMax,
						minerals = team.minerals,
						gas = team.gas,
						gems = player:GetAttribute("Gems") or 0,
						pity = team.pity or 0,
						atkLv = team.atkLv,
						spdLv = team.spdLv,
						team = team.slot,
						faction = team.faction,
						teamName = team.name,
						theme = Game.theme,
						expanded = team.expanded,
						units = unitPayload(team),
						hand = handPayload(team),
						fusions = fusionPayload(team),
						rank = baseRank,
						boss = (Game.phase == "boss" and Game.bossAlive) and {
							hp = math.floor(Game.bossHp),
							maxHp = math.floor(Game.bossMax),
							dmg = math.floor(Game.bossDamageTotal),
							time = math.max(0, math.floor(U.RAID_TIME - (now() - Game.bossStartedAt))),
						} or nil,
						downed = team.downed,
						reviveSeconds = team.downed and math.max(0, math.floor(team.reviveEnds - now())) or 0,
						reviveStock = player:GetAttribute("ReviveStock") or 0,
						boostDmg = math.max(0, math.floor(team.boostDmgUntil - now())),
						teamBoost = math.max(0, math.floor(team.teamBoostUntil - now())),
						passes = {
							vip = player:GetAttribute("PassVip") == true,
							fusion = player:GetAttribute("PassFusion") == true,
							arena = player:GetAttribute("PassArena") == true,
							twoX = player:GetAttribute("Pass2x") == true,
							auto = player:GetAttribute("PassAuto") == true,
							luck = player:GetAttribute("PassLuck") == true,
						},
						relics = team.relics,
					})
				end
			end
		end
	end
end)

-- ===============================================================
-- 13. 메인 루프
-- ===============================================================
local aiUnitSerial = 0

local function placeBotUnit(team, tier)
	local cells = freeCells(team)
	if #cells == 0 then return end
	local c = cells[math.random(1, #cells)]
	aiUnitSerial = aiUnitSerial + 1
	placeUnit(team, c.col, c.row, {
		tier = math.clamp(tier, 1, 5),
		form = math.random(1, 2),
		faction = team.faction,
	})
end

local function spawnQueueTick(team, dt)
	if not team.waveActive then return end
	team.spawnClock = team.spawnClock + dt
	local interval = (team.owner and team.owner:GetAttribute("Pass2x")) and 0.09 or 0.16
	while team.spawnQueue[1] and team.spawnClock >= interval do
		if liveCount(team) >= MAX_LIVE then break end
		team.spawnClock = team.spawnClock - interval
		local item = table.remove(team.spawnQueue, 1)
		if item then
			spawnEnemy(team, item.kind, { hero = item.hero })
			team.spawned = team.spawned + 1
		end
	end
	if #team.spawnQueue == 0 and liveCount(team) == 0 and team.spawned >= STAGE_MOBS then
		clearStageReward(team)
	end
	if team.spawnClock > interval * 3 then
		team.spawnClock = interval * 3
	end
end

local function updateEnemies(team, dt)
	for i = #team.enemies, 1, -1 do
		local e = team.enemies[i]
		if not e.alive then
			table.remove(team.enemies, i)
		else
			local slow = (now() < (e.slowUntil or 0)) and (e.slowMul or 1) or 1
			e.dist = math.min(team.pathLen, e.dist + e.speed * slow * dt)
			local pos = pathPos(team, e.dist)
			local ahead = pathPos(team, math.min(team.pathLen, e.dist + 1.5))
			local look = ahead - pos
			if look.Magnitude > 0.05 then
				e.model:PivotTo(CFrame.lookAt(pos, pos + look))
			else
				e.model:PivotTo(CFrame.new(pos))
			end
			e.pos = pos
			-- 현재 타일
			local col = math.clamp(math.floor(((team.cf:PointToObjectSpace(pos).X) + (GRID_N * CELL) / 2) / CELL) + 1, 1, GRID_N)
			local row = math.clamp(math.floor(((team.cf:PointToObjectSpace(pos).Z) + (GRID_N * CELL) / 2) / CELL) + 1, 1, GRID_N)
			e.cellKey = cellKey(col, row)

			if e.hpFill then
				local frac = math.clamp(e.hp / math.max(1, e.maxHp), 0, 1)
				e.hpFill.Size = UDim2.fromScale(frac, 0.7)
				e.hpFill.BackgroundColor3 = frac > 0.5 and Color3.fromRGB(120, 255, 160)
					or (frac > 0.25 and Color3.fromRGB(255, 215, 106) or Color3.fromRGB(255, 90, 105))
			end

			if e.dist >= team.pathLen - 0.6 then
				damageCore(team, e.coreDmg)
				burst(e.pos, Color3.fromRGB(255, 90, 80), 8, 0.9)
				e.alive = false
				if e.model then e.model:Destroy() end
				table.remove(team.enemies, i)
			end
		end
	end
end

local fxAcc = 0
local autoAcc = {}

RunService.Heartbeat:Connect(function(dt)
	Game.elapsed = Game.elapsed + dt

	-- 넥서스·제단 링 회전
	for _, rec in ipairs(spinParts) do
		if rec.part.Parent then
			rec.part.CFrame = rec.part.CFrame * CFrame.Angles(0, rec.spin * dt, 0)
		end
	end

	if Game.over then
		if now() >= Game.restartAt and anyPlayers() then
			resetMatch()
		end
		return
	end

	-- 팀별 진행
	for slot = 1, 5 do
		local team = Teams[slot]
		if team then
			if team.owner == nil then
				-- AI 팀 : 유닛을 지어가며 단계 경쟁
				team.aiBuildT = team.aiBuildT - dt
				if team.aiBuildT <= 0 then
					team.aiBuildT = 2.4 + math.random() * 1.8
					if #team.unitList < 18 then
						placeBotUnit(team, 1 + math.floor(team.stage / 12))
					end
				end
				team.aiStageT = team.aiStageT - dt
				if team.aiStageT <= 0 and team.stage < MAX_STAGE then
					team.stage = team.stage + 1
					team.aiStageT = 18 + math.random() * 5
					if team.stage >= MAX_STAGE then
						team.finished = true
						if Game.phase == "stage" then
							bannerAll("🌌 " .. team.name .. " 팀 40단계 완주", "우주 정중앙 최종 보스 레이드 시작", Color3.fromRGB(255, 170, 120))
							startBoss()
						end
					end
				end
			else
				-- 플레이어 팀
				if team.downed then
					if now() > team.reviveEnds then
						endMatch(false)
					end
				elseif Game.phase == "stage" then
					if team.waveActive then
						spawnQueueTick(team, dt)
					else
						team.waveTimer = team.waveTimer - dt
						if team.waveTimer <= 0 then
							if team.stage >= MAX_STAGE then
								team.finished = true
								if Game.phase == "stage" then startBoss() end
							else
								startStage(team)
							end
						end
					end
				end
			end

			updateEnemies(team, dt)
			for _, rec in ipairs(team.unitList) do
				updateUnit(team, rec, dt)
			end

			-- 자동 합성 (패스)
			if team.owner and team.owner:GetAttribute("PassAuto") then
				autoAcc[team] = (autoAcc[team] or 0) + dt
				if autoAcc[team] >= AUTO_MERGE_TICK then
					autoAcc[team] = 0
					mergeAll(team)
					if #team.hand > 0 then autoPlaceHand(team) end
				end
			end

			-- 넥서스 HP 표시
			if team.hpFill then
				local frac = math.clamp(team.core / math.max(1, team.coreMax), 0, 1)
				team.hpFill.Size = UDim2.fromScale(frac, 0.7)
				team.hpFill.BackgroundColor3 = frac > 0.5 and Color3.fromRGB(90, 255, 170)
					or (frac > 0.25 and Color3.fromRGB(255, 201, 77) or Color3.fromRGB(255, 90, 105))
				if team.hpText then
					team.hpText.Text = "NEXUS " .. team.core .. " / " .. team.coreMax
				end
			end

			-- 보스 경고등
			if team.beacon then
				local danger = (Game.phase == "boss")
				team.beacon.Transparency = danger and (0.15 + math.abs(math.sin(now() * 4)) * 0.4) or 0.85
			end
		end
	end

	bossTick(dt)

	-- 데미지 숫자 (0.3초마다 팀별 합산)
	fxAcc = fxAcc + dt
	if fxAcc >= 0.3 then
		fxAcc = 0
		for slot = 1, 5 do
			local team = Teams[slot]
			if team and team.owner then
				local entries = {}
				for _, e in ipairs(team.enemies) do
					if e.alive and (e.dmgAcc or 0) >= 1 and #entries < 5 then
						table.insert(entries, {
							pos = e.pos + Vector3.new(math.random(-2, 2), e.hero and 8 or 4, math.random(-2, 2)),
							amount = math.floor(e.dmgAcc),
							hero = e.hero == true,
						})
						e.dmgAcc = 0
					end
				end
				if #entries > 0 then
					RD.FX:FireClient(team.owner, { kind = "dmg", entries = entries })
				end
			end
		end
	end
end)

-- ===============================================================
-- 14. 상품 지급 창구 (03·05 → 02)
-- ===============================================================
local function profileOf(player)
	return Data.get(player)
end

local grantActions = {}

grantActions["PRODUCT_REVIVE"] = function(player, team)
	Data.addRevive(player, 1)
	local stock = math.min(3, (player:GetAttribute("ReviveStock") or 0) + 1)
	player:SetAttribute("ReviveStock", stock)
	toast(team, "💖 긴급 부활 +1", "보관 " .. stock .. "장 · 붕괴 순간 1탭")
	if team and team.downed then
		reviveNow(team, player, true)
	end
	return true
end

grantActions["PRODUCT_OVERCHARGE"] = function(player, team)
	if not team then return false end
	team.boostDmgUntil = math.max(team.boostDmgUntil, now()) + Shared.OVERCHARGE_SECONDS
	team.dpsCacheAt = 0
	toast(team, "⚡ 딜량 2배 과충전", "3분간 내 아레나 공격력 2배", { tier = 5 })
	sendFX(team, { kind = "flash", color = Color3.fromRGB(255, 210, 120) })
	return true
end

grantActions["PRODUCT_SUMMON"] = function(player, team)
	if not team then return false end
	local others = {}
	for _, f in ipairs(Shared.FACTIONS) do
		if f.key ~= team.faction then table.insert(others, f) end
	end
	local def = others[math.random(1, #others)]
	local item = { tier = math.random(2, 3), form = math.random(1, 2), faction = def.key, support = true }
	if #team.hand >= 4 then
		toast(team, "대기열이 가득 찼습니다", "먼저 배치하고 소환권을 쓰세요")
		return false
	end
	table.insert(team.hand, item)
	toast(team, "🌀 타 종족 지원 소환", def.icon .. " " .. def.name .. " T" .. item.tier .. " → 대기열", { tier = item.tier })
	return true
end

grantActions["PRODUCT_SABOTAGE"] = function(player, team)
	if not team then return false end
	local list = {}
	for slot = 1, 5 do
		local t = Teams[slot]
		if t and t ~= team then table.insert(list, t) end
	end
	if #list == 0 then return false end
	local target = list[1]
	if Game.phase == "boss" then
		local best
		for _, t in ipairs(list) do
			if not best or t.bossDamage > best.bossDamage then best = t end
		end
		target = best or target
	else
		local best
		for _, t in ipairs(list) do
			if not best or t.stage > best.stage then best = t end
		end
		target = best or target
	end
	local tier = Shared.stageTier(math.max(1, target.stage))
	for i = 1, 5 do
		spawnEnemy(target, tier.types[math.random(1, #tier.types)], { elite = true })
	end
	toast(team, "☠ 방해 몬스터 투하", target.name .. " 아레나에 정예 5마리 소환", { tier = 5 })
	toast(target, "☠ 방해 공격!", "정예 몬스터 5마리가 침투했습니다")
	bannerAll("☠ SABOTAGE", (player.DisplayName or "누군가") .. " 님이 " .. target.name .. " 팀을 방해했습니다", Color3.fromRGB(255, 120, 120))
	return true
end

grantActions["PRODUCT_MODE_RESET"] = function(player, team)
	if not team then return false end
	local n = 0
	for _, rec in ipairs(team.unitList) do
		rec.modeCdEnd = 0
		rec.skillCdEnd = 0
		n = n + 1
	end
	toast(team, "🔄 모드전환 쿨초기화", n .. "기 모두 즉시 전환 가능", { tier = 4 })
	sendFX(team, { kind = "flash", color = Color3.fromRGB(120, 220, 255) })
	return true
end

grantActions["PRODUCT_TEAM_BOOST"] = function(player, team)
	local untilT = now() + Shared.TEAM_BOOST_SECONDS
	for _, t in ipairs(humanTeams()) do
		t.teamBoostUntil = untilT
		t.dpsCacheAt = 0
		toast(t, "🎁 팀 전체 과충전", "3분간 공격력 +30% · " .. (player.DisplayName or "용사") .. " 님의 선물", { tier = 5 })
	end
	bannerAll("🎁 TEAM BOOST", (player.DisplayName or "용사") .. " 님이 전원 과충전을 선물했습니다", Color3.fromRGB(255, 210, 120))
	return true
end

grantActions["PRODUCT_STARTER"] = function(player, team)
	if not team then return false end
	team.boostDmgUntil = math.max(team.boostDmgUntil, now()) + 300
	Data.addRevive(player, 1)
	player:SetAttribute("ReviveStock", math.min(3, (player:GetAttribute("ReviveStock") or 0) + 1))
	local others = {}
	for _, f in ipairs(Shared.FACTIONS) do
		if f.key ~= team.faction then table.insert(others, f) end
	end
	if #team.hand < 4 then
		local def = others[math.random(1, #others)]
		table.insert(team.hand, { tier = 3, form = math.random(1, 2), faction = def.key, support = true })
	end
	team.dpsCacheAt = 0
	toast(team, "🚀 스타터팩 도착!", "과충전 5분 + 긴급 부활 1 + 지원 소환 1", { tier = 5 })
	return true
end

if bus then
	bus.Call.OnInvoke = function(player, action, payload)
		local team = teamByPlayer[player]
		if action == "product" then
			local fn = grantActions[payload]
			if not fn then return false end
			local ok, res = pcall(fn, player, team)
			if not ok then
				warn("[TD] 상품 지급 오류: " .. tostring(res))
				return false
			end
			return res == true
		elseif action == "reward" then
			if type(payload) ~= "table" or not team then return false end
			if payload.minerals and payload.minerals > 0 then
				team.minerals = team.minerals + payload.minerals
			end
			if payload.revive and payload.revive > 0 then
				Data.addRevive(player, payload.revive)
				player:SetAttribute("ReviveStock", math.min(3, (player:GetAttribute("ReviveStock") or 0) + payload.revive))
			end
			if payload.boostDmg then
				team.boostDmgUntil = math.max(team.boostDmgUntil, now()) + payload.boostDmg
			end
			return true
		elseif action == "refresh" then
			local profile = profileOf(player)
			if profile and team then
				for _, f in ipairs(Shared.FACTIONS) do
					if f.key == profile.faction then team.faction = f.key end
				end
				if profile.upgrades then
					team.permAtk = (profile.upgrades.permAtk or 0) * 0.03
				end
			end
			return true
		elseif action == "theme" then
			local api = ServerScriptService:FindFirstChild("TD_WorldAPI")
			local fn = api and api:FindFirstChild("Theme")
			if fn then
				pcall(function() fn:Invoke(payload) end)
			end
			Game.theme = payload or "sf"
			local profile = profileOf(player)
			if profile then
				profile.theme = Game.theme
				Data.markDirty(player)
			end
			for _, p in ipairs(Players:GetPlayers()) do
				RD.State:FireClient(p, { event = "theme", theme = Game.theme })
			end
			return true
		elseif action == "ping" then
			return true
		end
		return false
	end
end

-- ===============================================================
-- 15. 클라이언트 요청
-- ===============================================================
RD.Draw.OnServerEvent:Connect(function(player)
	local team = teamByPlayer[player]
	if not team or Game.over or team.downed then return end
	drawToHand(team, 1, false, false)
end)

RD.Merge.OnServerEvent:Connect(function(player)
	local team = teamByPlayer[player]
	if not team then return end
	mergeAll(team)
	if #team.hand > 0 then autoPlaceHand(team) end
end)

RD.Upgrade.OnServerEvent:Connect(function(player, which)
	local team = teamByPlayer[player]
	if not team then return end
	if which == "atk" then
		local cost = 25 + team.atkLv * 12
		if team.gas >= cost then
			team.gas = team.gas - cost
			team.atkLv = team.atkLv + 1
			team.dpsCacheAt = 0
		else
			toast(team, "가스 부족", "⛽ " .. cost .. " 필요")
		end
	elseif which == "spd" then
		local cost = 30 + team.spdLv * 14
		if team.gas >= cost then
			team.gas = team.gas - cost
			team.spdLv = team.spdLv + 1
			team.dpsCacheAt = 0
		else
			toast(team, "가스 부족", "⛽ " .. cost .. " 필요")
		end
	end
end)

RD.Support.OnServerEvent:Connect(function(player, which)
	local team = teamByPlayer[player]
	if not team then return end
	if which == "strike" then
		if team.minerals < 120 then
			toast(team, "미네랄 부족", "💎 120 필요")
			return
		end
		team.minerals = team.minerals - 120
		for _, e in ipairs(team.enemies) do
			if e.alive then damageEnemy(team, e, e.maxHp * 0.45, nil) end
		end
		for _, e in ipairs(team.enemies) do
			if e.alive then ringFX(e.pos, Color3.fromRGB(255, 200, 80), 8) end
		end
		toast(team, "🎯 궤도 폭격", "적 전체 45% 피해")
	elseif which == "repair" then
		if team.minerals < 90 then
			toast(team, "미네랄 부족", "💎 90 필요")
			return
		end
		team.minerals = team.minerals - 90
		team.core = math.min(team.coreMax, team.core + 5)
		toast(team, "🔧 넥서스 수리", "NEXUS +5")
	end
end)

RD.PickRelic.OnServerEvent:Connect(function(player, index)
	local team = teamByPlayer[player]
	if not team or not team.relicPending then return end
	local pick = team.relicChoices[index]
	if pick then applyRelic(team, pick.key) end
end)

RD.Prompt.OnServerEvent:Connect(function(player, action, arg)
	local team = teamByPlayer[player]
	if action == "revive_use" then
		if not team or not team.downed then return end
		local stock = player:GetAttribute("ReviveStock") or 0
		if stock <= 0 then
			toast(team, "부활권 없음", "상점에서 25 R$ 로 즉시 부활할 수 있습니다")
			return
		end
		reviveNow(team, player, true)
	elseif action == "theme" then
		local key = arg
		if not Shared.THEMES[key] then return end
		local api = ServerScriptService:FindFirstChild("TD_WorldAPI")
		local fn = api and api:FindFirstChild("Theme")
		if fn then pcall(function() fn:Invoke(key) end) end
		Game.theme = key
		local profile = profileOf(player)
		if profile then
			profile.theme = key
			Data.markDirty(player)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			RD.State:FireClient(p, { event = "theme", theme = key })
		end
		bannerAll(Shared.THEMES[key].name, "전장 테마 전환", Color3.fromRGB(140, 210, 255))
	end
end)

RD.Build.OnServerEvent:Connect(function(player, action, a, b, c)
	local team = teamByPlayer[player]
	if not team or Game.over then return end
	if action == "place" then
		local index = math.clamp(tonumber(a) or 1, 1, 4)
		local col = tonumber(b)
		local row = tonumber(c)
		local item = team.hand[index]
		if not item then
			toast(team, "배치할 유닛이 없습니다", "🔮 뽑기로 유닛을 먼저 뽑으세요")
			return
		end
		local ok, err = placeUnit(team, col, row, item)
		if ok then
			table.remove(team.hand, index)
			team.dpsCacheAt = 0
			local s = Shared.TIER_NAMES[item.tier]
			toast(team, "🏗️ 건설 완료", s .. " " .. (Shared.FACTION_BY_KEY[item.faction] or Shared.FACTIONS[1]).name .. " 유닛")
		else
			toast(team, "건설할 수 없습니다", err or "")
		end
	elseif action == "mode" then
		local col, row = tonumber(a), tonumber(b)
		local rec = team.units[cellKey(col, row)]
		if rec then switchMode(team, rec) end
	elseif action == "skill" then
		local col, row = tonumber(a), tonumber(b)
		local rec = team.units[cellKey(col, row)]
		if rec then castSkill(team, rec) end
	elseif action == "sell" then
		local col, row = tonumber(a), tonumber(b)
		local rec = team.units[cellKey(col, row)]
		if rec then
			local refund = 10 + (rec.tier or 1) * 8
			removeUnit(team, cellKey(col, row))
			rebuildPath(team)
			team.minerals = team.minerals + refund
			team.dpsCacheAt = 0
			toast(team, "💎 판매", "미네랄 +" .. refund)
		end
	elseif action == "fuse" then
		local key = a
		local ok, err = tryFusion(team, key)
		if not ok then toast(team, "융합 실패", err or "") end
	elseif action == "autoplace" then
		autoPlaceHand(team)
	end
end)

-- move 는 인자가 4개라 별도 RemoteEvent 로 받습니다 (같은 TD_Build, action "move4")
RD.Build.OnServerEvent:Connect(function(player, action, a, b, c, d)
	if action ~= "move4" then return end
	local team = teamByPlayer[player]
	if not team then return end
	local fromC, fromR, toC, toR = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
	local fromKey = cellKey(fromC, fromR)
	local rec = team.units[fromKey]
	if not rec then return end
	if team.units[cellKey(toC, toR)] then
		toast(team, "이동 불가", "목적지에 이미 유닛이 있습니다")
		return
	end
	if not canBuildCell(team, toC, toR) then
		toast(team, "이동 불가", "잠긴 타일입니다")
		return
	end
	team.units[fromKey] = nil
	if not findPath(team, cellKey(toC, toR)) then
		team.units[fromKey] = rec
		toast(team, "이동 불가", "몬스터 길이 막힙니다")
		return
	end
	local cell = team.cells[fromKey]
	if cell then cell:SetAttribute("Unit", false) end
	rec.col, rec.row = toC, toR
	team.units[cellKey(toC, toR)] = rec
	local targetCell = team.cells[cellKey(toC, toR)]
	if targetCell then targetCell:SetAttribute("Unit", true) end
	refreshUnitVisual(team, rec)
	rebuildPath(team)
	toast(team, "↔ 이동 완료", "유닛을 새 위치로 옮겼습니다")
end)

-- ===============================================================
-- 16. 참가 / 퇴장
-- ===============================================================
local function refreshPassAttributes(player)
	local profile = Data.get(player)
	if not profile then return end
	for _, pass in ipairs(Shared.PASSES) do
		if profile.passes and profile.passes[pass.key] == true then
			player:SetAttribute(pass.attr, true)
		end
	end
end

local function applyTeamPasses(team, player)
	if player:GetAttribute("PassArena") and not team.expanded then
		team.expanded = true
		for _, cell in pairs(team.cells) do
			cell:SetAttribute("Free", true)
		end
	end
end

local function setupPlayer(player)
	local profile = Data.waitFor(player, 20)
	if not profile then
		warn("[TD] " .. player.Name .. " 프로필을 불러오지 못했습니다 (임시 진행)")
	end

	local wantedKey = profile and profile.faction or ""
	local team = nil

	-- 원하는 종족의 빈 아레나 → 없으면 빈 아레나 아무거나
	if wantedKey ~= "" and Shared.FACTION_BY_KEY[wantedKey] then
		for slot = 1, 5 do
			local t = Teams[slot]
			if t and t.faction == wantedKey and t.owner == nil then
				team = t
				break
			end
		end
	end
	if not team then
		for slot = 1, 5 do
			local t = Teams[slot]
			if t and t.owner == nil then
				team = t
				break
			end
		end
	end
	if not team then
		player:Kick("이 서버는 5팀 정원이 찼습니다. 다시 접속해 주세요.")
		return
	end

	team.owner = player
	team.ai = false
	teamByPlayer[player] = team
	player:SetAttribute("Team", team.slot)
	player:SetAttribute("Faction", team.faction)
	player:SetAttribute("TeamName", team.name)
	player:SetAttribute("Gems", profile and profile.gems or 0)
	player:SetAttribute("BestStage", profile and profile.bestStage or 0)
	player:SetAttribute("ReviveStock", profile and profile.reviveStock or 0)
	refreshPassAttributes(player)
	applyTeamPasses(team, player)

	if profile then
		profile.faction = team.faction
		local up = profile.upgrades or {}
		team.minerals = 150 + (up.startMinerals or 0) * 40
		team.gas = 30 + (up.startGas or 0) * 25
		team.permAtk = (up.permAtk or 0) * 0.03
		team.pity = profile.pity or 0
		if profile.theme and Shared.THEMES[profile.theme] then
			Game.theme = profile.theme
			local api = ServerScriptService:FindFirstChild("TD_WorldAPI")
			local fn = api and api:FindFirstChild("Theme")
			if fn then pcall(function() fn:Invoke(profile.theme) end) end
		end
		Data.markDirty(player)
	end

	local aiLight = team.arena:FindFirstChild("AILight")
	if aiLight then aiLight.Transparency = 0.9 end
	local bannerBoard = team.arena:FindFirstChild("TeamBanner")
	if bannerBoard then
		local sg = bannerBoard:FindFirstChildOfClass("SurfaceGui")
		if sg then
			local bg = sg:FindFirstChildOfClass("Frame")
			if bg then
				local subs = {}
				for _, l in ipairs(bg:GetChildren()) do
					if l:IsA("TextLabel") then table.insert(subs, l) end
				end
				if subs[2] then
					subs[2].Text = "PLAYER · " .. player.DisplayName
					subs[2].TextColor3 = (Shared.FACTION_BY_KEY[team.faction] or Shared.FACTIONS[1]).color
				end
			end
		end
	end

	-- 아레나 확장 패스를 나중에 샀을 때도 바로 적용
	player:GetAttributeChangedSignal("PassArena"):Connect(function()
		local t = teamByPlayer[player]
		if t and player:GetAttribute("PassArena") then
			applyTeamPasses(t, player)
			toast(t, "🏗️ 아레나 확장", "건설 그리드 6×6 → 8×8 전체 해금")
		end
	end)

	RD.State:FireClient(player, {
		event = "assigned",
		team = team.slot,
		faction = team.faction,
		teamName = team.name,
		theme = Game.theme,
		expanded = team.expanded,
	})
	banner(team, (Shared.FACTION_BY_KEY[team.faction] or Shared.FACTIONS[1]).icon .. " " .. team.name .. " 아레나",
		"타일을 눌러 유닛을 배치하세요 · 40단계 · 중앙 보스 레이드")

	if Game.over and now() >= Game.restartAt then
		resetMatch()
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function() setupPlayer(player) end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function() setupPlayer(p) end)
end

Players.PlayerRemoving:Connect(function(player)
	local team = teamByPlayer[player]
	if team then
		team.owner = nil
		team.ai = true
		team.aiBuildT = 2
		teamByPlayer[player] = nil
		local aiLight = team.arena:FindFirstChild("AILight")
		if aiLight then aiLight.Transparency = 0.2 end
	end
	if #Players:GetPlayers() <= 1 then
		task.delay(1, function()
			if not anyPlayers() and not Game.over then
				resetMatch()
			end
		end)
	end
end)

-- 종족 선택 (인트로 UI) — 플레이어가 원하는 아레나로 이동
RD.Prompt.OnServerEvent:Connect(function(player, action, arg)
	if action ~= "faction" then return end
	local key = arg
	if not Shared.FACTION_BY_KEY[key] then return end
	local current = teamByPlayer[player]
	if not current then return end
	if current.faction == key then
		toast(current, "이미 " .. Shared.FACTION_BY_KEY[key].name .. " 팀입니다", "")
		return
	end
	local target
	for slot = 1, 5 do
		local t = Teams[slot]
		if t and t.faction == key and t.owner == nil then
			target = t
			break
		end
	end
	if not target then
		toast(current, "선택할 수 없습니다", "다른 플레이어가 그 종족을 플레이 중입니다")
		return
	end
	-- 이동
	current.owner = nil
	current.ai = true
	target.owner = player
	target.ai = false
	teamByPlayer[player] = target
	player:SetAttribute("Team", target.slot)
	player:SetAttribute("Faction", target.faction)
	player:SetAttribute("TeamName", target.name)
	local profile = Data.get(player)
	if profile then
		profile.faction = target.faction
		Data.markDirty(player)
	end
	local aiLight = target.arena:FindFirstChild("AILight")
	if aiLight then aiLight.Transparency = 0.9 end
	RD.State:FireClient(player, {
		event = "assigned",
		team = target.slot,
		faction = target.faction,
		teamName = target.name,
		theme = Game.theme,
		expanded = target.expanded,
	})
	banner(target, (Shared.FACTION_BY_KEY[target.faction] or Shared.FACTIONS[1]).icon .. " " .. target.name .. " 팀 합류", "이제 이 아레나에서 싸웁니다")
end)

print("[TD] 02_ArenaBattle 시작 — 5아레나 · " .. MAX_STAGE .. "단계 × " .. STAGE_MOBS .. "마리 · 중앙 보스 딜량 레이드 (v" .. Shared.VERSION .. ")")
