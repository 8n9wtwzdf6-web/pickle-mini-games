--[[ ============================================================
  TDShared  (ModuleScript)  —  v3.0 "우주 5아레나 · 5종족 · 딜량 레이드"
  붙여넣는 곳 : ReplicatedStorage  →  ModuleScript, 이름을 정확히 "TDShared"
  ------------------------------------------------------------
  서버(01·02·03·05)와 클라이언트(04·06·07)가 함께 읽는 "설정 한 곳".
    · 우주 5아레나 좌표 · 자유 건설 그리드 · 종족/모드/융합 · 적 40단계
    · 가챠 확률 · 게임패스/상품 가격표 · 리텐션 보상 · 리모트 도우미
  ★ 상품·패스 ID는 아래 Shared.IDS 표에서만 고치면 됩니다.
  ============================================================ ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Shared = {}
Shared.VERSION = "3.0"

-- ===============================================================
-- ★★ 여기만 고치면 됩니다 — 스튜디오에서 발급받은 ID ★★
--    아직 없으면 0으로 두세요. 0이면 "준비 중"으로 표시되고 구매만 꺼집니다.
-- ===============================================================
Shared.IDS = {
	-- 게임패스 6종 (한 번 구매 · 영구)
	PASS_VIP = 0,        -- 👑 VIP          399 : 5종족 전체 해금 · 보상 +25% · 왕관
	PASS_FUSION = 0,     -- 🧬 융합 마스터   249 : 융합 3+1 · 융합 유닛 +20%
	PASS_ARENA = 0,      -- 🏗️ 아레나 확장   199 : 건설 그리드 6×6 → 8×8
	PASS_2X = 0,         -- ⚡ 2배속         149 : 스폰 2배 · 대기 -30%
	PASS_AUTO = 0,       -- 🤖 자동합치기    199 : 자동 합성 · 자동 배치
	PASS_LUCK = 0,       -- 🍀 러키 뽑기     299 : 전설+ ×1.8 · 천장 8회

	-- 개발자 상품 (반복 구매)
	PRODUCT_OVERCHARGE = 0,   -- ⚡ 딜량 2배 과충전 3분     29
	PRODUCT_SUMMON = 0,       -- 🌀 타 종족 지원 소환권     39
	PRODUCT_SABOTAGE = 0,     -- ☠ 경쟁 1위 팀 방해 몬스터  49
	PRODUCT_MODE_RESET = 0,   -- 🔄 모드전환 쿨초기화       25
	PRODUCT_REVIVE = 0,       -- 💖 12초 긴급 부활          25
	PRODUCT_TEAM_BOOST = 0,   -- 🎁 팀 전체 과충전 선물      79
	PRODUCT_STARTER = 0,      -- 🚀 1회 한정 스타터팩        79
	PRODUCT_GEMS_S = 0,       -- 💠 보석 150                99
	PRODUCT_GEMS_M = 0,       -- 💠 보석 540               199
	PRODUCT_GEMS_L = 0,       -- 💠 보석 1,320             399
	PRODUCT_GEMS_XL = 0,      -- 💠 보석 3,450             799
}

-- ===============================================================
-- 1. 우주 · 5개 부유 아레나 · 자유 건설 그리드
--    아레나 로컬 좌표 : +Z = 우주 정중앙(넥서스) 방향, -Z = 바깥(스폰)
-- ===============================================================
Shared.UNIVERSE = {
	ARENA_RADIUS = 150,     -- 우주 중심 → 아레나 중심 거리
	ARENA_Y = 0,
	PLATE = 68,             -- 아레나 판 크기(정사각)
	GRID_N = 8,             -- 8×8 타일 (기본 사용 6×6 = 안쪽, 확장 패스 = 8×8 전체)
	FREE_N = 6,             -- 확장 패스 없이 쓸 수 있는 안쪽 6×6
	CELL = 7,               -- 타일 한 칸 = 7 studs
	NEXUS_LOCAL = Vector3.new(0, 0, 31),
	SPAWN_LOCAL = Vector3.new(-3.5, 0, -38),
	START_CELL = { col = 4, row = 1 },   -- 몬스터 진입 타일
	GOAL_CELL = { col = 5, row = 8 },    -- 넥서스 직전 타일
	CORE_MAX = 30,
	BOSS_CENTER = Vector3.new(0, 0, 0),
	RAID_TIME = 150,        -- 최종 보스 레이드 제한(초)
}

Shared.THEME_ORDER = { "sf", "fantasy", "cyber" }
Shared.THEMES = {
	sf = {
		key = "sf", name = "🌌 우주 요새", sub = "ORBITAL FORTRESS",
		plate = Color3.fromRGB(43, 56, 67),
		plate2 = Color3.fromRGB(24, 34, 42),
		trim = Color3.fromRGB(43, 182, 216),
		glow = Color3.fromRGB(84, 232, 255),
		decor = Color3.fromRGB(96, 128, 148),
		lighting = { ambient = Color3.fromRGB(46, 66, 82), outdoor = Color3.fromRGB(58, 92, 120), fog = Color3.fromRGB(6, 13, 20), fogEnd = 900 },
	},
	fantasy = {
		key = "fantasy", name = "🏰 판타지 성채", sub = "FORTRESS GORGE",
		plate = Color3.fromRGB(64, 55, 46),
		plate2 = Color3.fromRGB(38, 30, 24),
		trim = Color3.fromRGB(184, 134, 63),
		glow = Color3.fromRGB(255, 179, 71),
		decor = Color3.fromRGB(124, 108, 88),
		lighting = { ambient = Color3.fromRGB(74, 44, 42), outdoor = Color3.fromRGB(120, 74, 56), fog = Color3.fromRGB(23, 13, 23), fogEnd = 820 },
	},
	cyber = {
		key = "cyber", name = "🏙️ 사이버펑크 도시", sub = "NEON CROSSING",
		plate = Color3.fromRGB(27, 31, 44),
		plate2 = Color3.fromRGB(12, 15, 22),
		trim = Color3.fromRGB(255, 46, 151),
		glow = Color3.fromRGB(0, 229, 255),
		decor = Color3.fromRGB(78, 86, 112),
		lighting = { ambient = Color3.fromRGB(52, 40, 72), outdoor = Color3.fromRGB(64, 44, 96), fog = Color3.fromRGB(11, 7, 20), fogEnd = 780 },
	},
}

-- 아레나 배치 : 5개 팀이 정오각형으로 우주 공간에 떠 있습니다.
function Shared.arenaCFrame(slot)
	local R = Shared.UNIVERSE.ARENA_RADIUS
	local ang = math.rad((slot - 1) * 72)
	local pos = Vector3.new(math.sin(ang) * R, Shared.UNIVERSE.ARENA_Y, -math.cos(ang) * R)
	-- lookAt(pos, center) 는 -Z 가 중심을 봄 → 180° 돌려서 로컬 +Z 가 중심을 보게 합니다
	return CFrame.lookAt(pos, Vector3.new(0, Shared.UNIVERSE.ARENA_Y, 0)) * CFrame.Angles(0, math.pi, 0)
end

-- 타일 중심 (아레나 로컬 좌표). col/row = 1..N
function Shared.cellLocal(col, row, n)
	local N = n or Shared.UNIVERSE.GRID_N
	local half = (N + 1) / 2
	local C = Shared.UNIVERSE.CELL
	return Vector3.new((col - half) * C, 0.35, (row - half) * C)
end

function Shared.cellKey(col, row)
	return tostring(col) .. ":" .. tostring(row)
end

-- 확장 패스 없이 지을 수 있는 타일인가 (안쪽 FREE_N × FREE_N)
function Shared.isFreeCell(col, row)
	local N = Shared.UNIVERSE.GRID_N
	local pad = math.floor((N - Shared.UNIVERSE.FREE_N) / 2)
	return col > pad and col <= N - pad and row > pad and row <= N - pad
end

-- ===============================================================
-- 2. 5대 종족 · 종족별 2모드(변형) · 이종족 융합
-- ===============================================================
Shared.FACTIONS = {
	{
		key = "human", name = "휴먼", icon = "👤", tag = "밸런스 · 자원 효율",
		perk = "미네랄 +10% · 가스 +10%",
		color = Color3.fromRGB(111, 184, 255),
		accent = Color3.fromRGB(79, 155, 255),
		hull = Color3.fromRGB(51, 70, 90),
		minMul = 1.10, gasMul = 1.10, atk = 1.00, spd = 1.00, range = 1.00, splash = 1.00,
		nexus = "command",
		forms = {
			{
				key = "troops", name = "병력", icon = "👤", tag = "빠른 연사 · 스팀팩",
				dmg = 0.90, cd = 0.55, range = 0.96, splash = 0.65, shots = 1, proj = "bullet",
				skill = "전술 스팀팩", skillDesc = "8초간 공속 +100%", skillCd = 14, skillKind = "rush",
			},
			{
				key = "bunker", name = "벙커", icon = "🏰", tag = "광역 박격포 · 감속",
				dmg = 1.55, cd = 1.60, range = 1.20, splash = 1.90, shots = 1, proj = "shell",
				skill = "강화 포격", skillDesc = "광역 폭발 · 이동 -50%", skillCd = 16, skillKind = "quake",
			},
		},
	},
	{
		key = "mecha", name = "메카", icon = "🛡️", tag = "폭발 · 단일 폭딜",
		perk = "공격력 +15% · 폭발 범위 +25%",
		color = Color3.fromRGB(255, 154, 58),
		accent = Color3.fromRGB(255, 138, 42),
		hull = Color3.fromRGB(74, 58, 44),
		minMul = 1.00, gasMul = 1.00, atk = 1.15, spd = 0.95, range = 1.00, splash = 1.25,
		nexus = "bunker",
		forms = {
			{
				key = "walker", name = "워커", icon = "🦿", tag = "미사일 다연발",
				dmg = 0.95, cd = 0.72, range = 1.00, splash = 0.90, shots = 2, proj = "missile",
				skill = "미사일 연사", skillDesc = "5연발 집중 폭격", skillCd = 15, skillKind = "barrage",
			},
			{
				key = "siege", name = "시즈", icon = "🏰", tag = "장거리 포격 · 충격파",
				dmg = 1.75, cd = 1.55, range = 1.25, splash = 1.60, shots = 1, proj = "shell",
				skill = "시즈 포격", skillDesc = "장거리 대형 폭발", skillCd = 17, skillKind = "quake",
			},
		},
	},
	{
		key = "arcane", name = "아케인", icon = "🔮", tag = "광역 · 마법 연쇄",
		perk = "25% 연쇄 번개 · 광역 +20%",
		color = Color3.fromRGB(176, 123, 255),
		accent = Color3.fromRGB(176, 123, 255),
		hull = Color3.fromRGB(58, 42, 85),
		minMul = 1.00, gasMul = 1.00, atk = 1.00, spd = 1.00, range = 1.05, splash = 1.20,
		nexus = "crystal",
		forms = {
			{
				key = "tower", name = "타워", icon = "🔮", tag = "체인 라이트닝",
				dmg = 1.00, cd = 0.90, range = 1.05, splash = 1.15, shots = 1, proj = "psi",
				skill = "연쇄 번개", skillDesc = "5기 연쇄 감전", skillCd = 14, skillKind = "chain",
			},
			{
				key = "guardian", name = "수호자", icon = "🛡️", tag = "집중 레이저 · 관통",
				dmg = 1.50, cd = 1.25, range = 1.15, splash = 0.60, shots = 1, proj = "beam",
				skill = "공허 레이저", skillDesc = "직선 관통 · 최대 6기", skillCd = 16, skillKind = "pierce",
			},
		},
	},
	{
		key = "bio", name = "바이오", icon = "🧬", tag = "도트 · 슬로우",
		perk = "피격 적 이동 -35% (1.5초)",
		color = Color3.fromRGB(123, 255, 158),
		accent = Color3.fromRGB(110, 240, 140),
		hull = Color3.fromRGB(39, 64, 44),
		minMul = 1.05, gasMul = 1.00, atk = 0.95, spd = 1.05, range = 1.00, splash = 1.00,
		nexus = "hive",
		forms = {
			{
				key = "spire", name = "스파이어", icon = "🌵", tag = "산성 도트",
				dmg = 1.00, cd = 0.85, range = 1.00, splash = 0.90, shots = 1, proj = "acid",
				skill = "산성 분사", skillDesc = "4초 지속 독 피해", skillCd = 13, skillKind = "acid",
			},
			{
				key = "beast", name = "괴수", icon = "👹", tag = "독성 폭발 · 슬로우",
				dmg = 1.45, cd = 1.45, range = 0.95, splash = 1.80, shots = 1, proj = "acid",
				skill = "독성 폭발", skillDesc = "광역 폭발 · 이동 -45%", skillCd = 16, skillKind = "quake",
			},
		},
	},
	{
		key = "drone", name = "드론", icon = "🛸", tag = "다수 · 추격 타격",
		perk = "공속 +20% · 사거리 +8%",
		color = Color3.fromRGB(79, 230, 255),
		accent = Color3.fromRGB(79, 230, 255),
		hull = Color3.fromRGB(36, 64, 74),
		minMul = 1.00, gasMul = 1.00, atk = 0.95, spd = 1.20, range = 1.08, splash = 1.00,
		nexus = "carrier",
		forms = {
			{
				key = "robot", name = "로봇", icon = "🤖", tag = "중화기 펄스 · 단일 폭딜",
				dmg = 1.65, cd = 1.35, range = 1.00, splash = 0.50, shots = 1, proj = "beam",
				skill = "펄스 집중", skillDesc = "단일 대상 6배 피해", skillCd = 13, skillKind = "pulse",
			},
			{
				key = "swarm", name = "드론편대", icon = "🛸", tag = "편대 추적 · 다수 타격",
				dmg = 0.72, cd = 0.55, range = 1.10, splash = 0.80, shots = 3, proj = "bullet",
				skill = "편대 소환", skillDesc = "최대 6기 동시 타격", skillCd = 15, skillKind = "swarm",
			},
		},
	},
}

Shared.FACTION_BY_KEY = {}
for i, f in ipairs(Shared.FACTIONS) do
	f.index = i
	Shared.FACTION_BY_KEY[f.key] = f
end

-- 아레나 슬롯(1~5) = 종족 순서 (01 이 이 순서로 5개 아레나를 만듭니다)
function Shared.factionOfSlot(slot)
	return Shared.FACTIONS[math.clamp(slot, 1, #Shared.FACTIONS)]
end

-- ---------- 이종족 융합 (서로 다른 종족 3 + 2 → 고유 융합 유닛) ----------
Shared.FUSIONS = {
	{
		key = "human+bio", name = "감염 전술 코만도", icon = "🦠", a = "human", b = "bio",
		desc = "연사 + 독 도트 · 아군 공격력 +12%",
		dmg = 3200, cd = 0.20, range = 26, splash = 1.4, shots = 1, proj = "acid",
		skill = "감염 폭풍", skillDesc = "광역 독 + 감속", skillCd = 16, skillKind = "acid",
		buff = "atk", buffValue = 0.12,
	},
	{
		key = "mecha+arcane", name = "아크 레일건 타이탄", icon = "⚡", a = "mecha", b = "arcane",
		desc = "폭발 + 체인 번개 · 폭발 범위 +25%",
		dmg = 5200, cd = 0.35, range = 30, splash = 2.6, shots = 1, proj = "psi",
		skill = "아크 방전", skillDesc = "8기 연쇄 폭발", skillCd = 18, skillKind = "chain",
		buff = "splash", buffValue = 0.25,
	},
	{
		key = "drone+arcane", name = "프리즘 오비탈 캐리어", icon = "🔮", a = "drone", b = "arcane",
		desc = "추적 드론 + 레이저 · 공속 +15%",
		dmg = 1500, cd = 0.16, range = 34, splash = 0.9, shots = 2, proj = "beam",
		skill = "프리즘 폭격", skillDesc = "화면 전체 레이저", skillCd = 20, skillKind = "swarm",
		buff = "spd", buffValue = 0.15,
	},
	{
		key = "human+mecha", name = "강습 기갑 사령부", icon = "🛡️", a = "human", b = "mecha",
		desc = "고연사 + 중장갑 폭격 · 공격력 +10%",
		dmg = 2600, cd = 0.26, range = 28, splash = 1.8, shots = 2, proj = "missile",
		skill = "기갑 강습", skillDesc = "전방위 미사일 폭격", skillCd = 17, skillKind = "barrage",
		buff = "atk", buffValue = 0.10,
	},
	{
		key = "bio+drone", name = "군체 정찰체", icon = "🧬", a = "bio", b = "drone",
		desc = "독성 확산 + 편대 추적 · 사거리 +12%",
		dmg = 3200, cd = 0.24, range = 32, splash = 1.5, shots = 1, proj = "acid",
		skill = "군체 확산", skillDesc = "독 구름 확산", skillCd = 15, skillKind = "acid",
		buff = "range", buffValue = 0.12,
	},
}

Shared.FUSION_BY_KEY = {}
Shared.FUSION_BY_PAIR = {}
for _, f in ipairs(Shared.FUSIONS) do
	Shared.FUSION_BY_KEY[f.key] = f
	Shared.FUSION_BY_PAIR[f.a .. "+" .. f.b] = f
	Shared.FUSION_BY_PAIR[f.b .. "+" .. f.a] = f
end

function Shared.fusionNeed(passFusion)
	if passFusion then return 2, 1 end
	return 3, 2
end

function Shared.fusionStats(def, opts)
	opts = opts or {}
	local atkMul = (opts.atkMul or 1) * (1 + (opts.fusionMaster and 0.20 or 0))
	local spdMul = (opts.spdMul or 1)
	local cd = math.max(0.05, def.cd / spdMul)
	local dmg = def.dmg * atkMul
	return {
		def = def,
		dmg = dmg,
		cd = cd,
		range = def.range * (opts.rangeMul or 1),
		splash = def.splash * (opts.splashMul or 1),
		shots = def.shots or 1,
		proj = def.proj or "beam",
		speed = def.speed or 0,
		dps = dmg * (def.shots or 1) / cd,
		fusion = true,
	}
end

-- ===============================================================
-- 3. 등급 · 뽑기 확률
-- ===============================================================
Shared.TIER_NAMES = { "일반", "희귀", "영웅", "전설", "신화" }
Shared.TIER_COLORS = {
	Color3.fromRGB(184, 198, 210),
	Color3.fromRGB(62, 155, 255),
	Color3.fromRGB(169, 115, 255),
	Color3.fromRGB(255, 194, 77),
	Color3.fromRGB(255, 91, 209),
}
Shared.TIER_PREFIX = { "정찰", "강화", "정예", "전설", "신화" }

-- 등급별 기본 스탯 (종족·모드 배율이 곱해집니다)
Shared.TIER_STATS = {
	{ dmg = 30,   cd = 0.55, range = 20, shots = 1, proj = "bullet", speed = 150, splash = 0 },
	{ dmg = 82,   cd = 0.50, range = 21, shots = 1, proj = "bullet", speed = 155, splash = 0 },
	{ dmg = 245,  cd = 0.44, range = 23, shots = 1, proj = "missile", speed = 120, splash = 2.0 },
	{ dmg = 700,  cd = 0.40, range = 25, shots = 1, proj = "shell", speed = 140, splash = 3.0 },
	{ dmg = 1900, cd = 0.34, range = 27, shots = 1, proj = "beam", speed = 0, splash = 3.4 },
}

Shared.GACHA_COST = 15
Shared.PITY_BASE = 10
Shared.PITY_PASS = 8
Shared.LUCK_MUL = 1.8
Shared.MERGE_STAR_BONUS = 0.35

local ODD_NORMAL = { 62, 27, 8, 2.5, 0.5 }
local ODD_PITY = { 0, 70, 24, 5, 1 }

function Shared.tierOdds(luckPass, pity)
	local w
	if pity then
		w = { ODD_PITY[1], ODD_PITY[2], ODD_PITY[3], ODD_PITY[4], ODD_PITY[5] }
	else
		w = { ODD_NORMAL[1], ODD_NORMAL[2], ODD_NORMAL[3], ODD_NORMAL[4], ODD_NORMAL[5] }
	end
	if luckPass then
		w[4] = w[4] * Shared.LUCK_MUL
		w[5] = w[5] * Shared.LUCK_MUL
	end
	local sum = 0
	for i = 1, 5 do sum = sum + w[i] end
	local pct = {}
	for i = 1, 5 do pct[i] = (sum > 0) and (w[i] / sum * 100) or 0 end
	return w, sum, pct
end

function Shared.oddsText(luckPass, pity)
	local _, _, pct = Shared.tierOdds(luckPass, pity)
	local out = {}
	for i = 1, 5 do
		out[i] = string.format("%s %.2f%%", Shared.TIER_NAMES[i], pct[i])
	end
	return table.concat(out, "  ·  ")
end

local function pickWeighted(w, sum)
	local r = math.random() * sum
	local acc = 0
	for i = 1, #w do
		acc = acc + w[i]
		if r <= acc then return i end
	end
	return 1
end

function Shared.rollTier(luckPass, pity)
	local w, sum = Shared.tierOdds(luckPass, pity)
	return pickWeighted(w, sum)
end

-- ---------- 유닛 스탯 계산 (서버·클라이언트 공용) ----------
-- opts = { faction=, form=1|2, tier=, star=, atkMul=, spdMul=, rangeMul=, splashMul= }
function Shared.unitStats(opts)
	opts = opts or {}
	local faction = Shared.FACTION_BY_KEY[opts.faction or "human"] or Shared.FACTIONS[1]
	local form = faction.forms[math.clamp(opts.form or 1, 1, 2)]
	local tier = math.clamp(opts.tier or 1, 1, #Shared.TIER_STATS)
	local t = Shared.TIER_STATS[tier]
	local star = opts.star or 0
	local starMul = 1 + Shared.MERGE_STAR_BONUS * star
	local atkMul = (opts.atkMul or 1) * faction.atk * form.dmg * starMul
	local spdMul = (opts.spdMul or 1) * faction.spd
	local cd = math.max(0.05, (t.cd * form.cd) / spdMul)
	local dmg = t.dmg * atkMul
	local shots = t.shots or 1
	return {
		def = t,
		faction = faction.key,
		form = opts.form or 1,
		tier = tier,
		dmg = dmg,
		cd = cd,
		shots = shots,
		range = t.range * form.range * faction.range * (opts.rangeMul or 1),
		splash = (t.splash or 0) * form.splash * faction.splash * (opts.splashMul or 1),
		proj = form.proj,
		speed = t.speed or 120,
		dps = dmg * shots / cd,
	}
end

-- ===============================================================
-- 4. 적 8종 + 영웅 + 40단계 + 최종 보스
-- ===============================================================
Shared.ENEMIES = {
	-- 1~10 경량 물량형
	slime =    { name = "스카우트 슬라임", model = "slime",    hp = 0.55, speed = 1.16, size = 0.60, reward = 2, core = 1 },
	goblin =   { name = "고블린 약탈자",   model = "goblin",   hp = 0.72, speed = 1.10, size = 0.66, reward = 2, core = 1 },
	-- 11~20 기갑 돌진형
	golem =    { name = "아머 골렘",       model = "golem",    hp = 1.85, speed = 0.76, size = 0.92, reward = 4, core = 2, armor = 0.18 },
	hound =    { name = "사이버 하운드",   model = "hound",    hp = 1.25, speed = 1.34, size = 0.78, reward = 4, core = 1, armor = 0.06 },
	-- 21~30 정예 공허형
	voidling = { name = "공허 레이스",     model = "voidling", hp = 1.60, speed = 1.04, size = 0.80, reward = 6, core = 2, armor = 0.10, air = true },
	beast =    { name = "마력 야수",       model = "beast",    hp = 2.25, speed = 0.92, size = 0.98, reward = 6, core = 2, armor = 0.14 },
	-- 31~40 최종 군단형
	titan =    { name = "지옥 타이탄",     model = "titan",    hp = 3.30, speed = 0.72, size = 1.22, reward = 9, core = 3, armor = 0.22 },
	dragon =   { name = "크리스탈 드래곤", model = "dragon",   hp = 3.00, speed = 0.90, size = 1.26, reward = 9, core = 3, armor = 0.16, air = true },
}

Shared.STAGE_TIERS = {
	{ from = 1,  to = 10, name = "경량 물량형", types = { "slime", "goblin" },     hero = "slime", heroName = "슬라임 킹",    tint = Color3.fromRGB(107, 208, 107) },
	{ from = 11, to = 20, name = "기갑 돌진형", types = { "golem", "hound" },      hero = "golem", heroName = "강철 군주",    tint = Color3.fromRGB(127, 168, 200) },
	{ from = 21, to = 30, name = "정예 공허형", types = { "voidling", "beast" },   hero = "beast", heroName = "공허 야수왕",  tint = Color3.fromRGB(176, 123, 255) },
	{ from = 31, to = 40, name = "최종 군단형", types = { "titan", "dragon" },     hero = "titan", heroName = "지옥 군단장",  tint = Color3.fromRGB(255, 106, 106) },
}

Shared.MAX_STAGE = 40
Shared.STAGE_MOBS = 100
Shared.STAGE_HEROES = 1
Shared.STAGE_HP_BASE = 26
Shared.STAGE_HP_GROWTH = 1.135
Shared.HERO_HP_MUL = 22

function Shared.stageTier(stage)
	for _, t in ipairs(Shared.STAGE_TIERS) do
		if stage >= t.from and stage <= t.to then return t end
	end
	return Shared.STAGE_TIERS[#Shared.STAGE_TIERS]
end

function Shared.stageHp(stage)
	return Shared.STAGE_HP_BASE * (Shared.STAGE_HP_GROWTH ^ math.max(0, stage - 1))
end

-- ---------- 우주 정중앙 최종 보스 ----------
Shared.FINAL_BOSS = {
	name = "오메가 파괴신",
	icon = "👁️",
	hpBase = 2400000,
	hpPerPlayer = 900000,
	scale = 4.2,
	coreDamage = 3,
	shockwaveEvery = 9,      -- 초마다 전 아레나 넥서스 타격
	shockwaveDamage = 1,
	addEvery = 22,           -- 초마다 다른 아레나에 소환수
	addCount = 6,
	enrageAt = 0.0,
}

-- ===============================================================
-- 5. 유물 (스테이지 5·10·15 … 클리어마다 3~4지선다)
-- ===============================================================
Shared.RELICS = {
	{ key = "atk", name = "🔥 화력 증폭", desc = "모든 터렛 공격력 +25%" },
	{ key = "spd", name = "⚡ 초전도 장전", desc = "모든 터렛 공격속도 +20%" },
	{ key = "range", name = "🎯 정밀 조준", desc = "사거리 +18%" },
	{ key = "minerals", name = "💎 미네랄 채굴기", desc = "미네랄 획득 +35%" },
	{ key = "gas", name = "⛽ 가스 정제소", desc = "가스 획득 +40%, 즉시 +20" },
	{ key = "luck", name = "🍀 행운의 뽑기", desc = "희귀 이상 확률 ×1.6" },
	{ key = "boom", name = "💥 폭발 탄두", desc = "30% 확률로 범위 폭발" },
	{ key = "shield", name = "🛡 코어 실드", desc = "넥서스 최대 HP +6 · 전체 회복" },
	{ key = "bounty", name = "💰 전리품 사냥", desc = "적 처치 미네랄 +2" },
	{ key = "combo", name = "🔗 연쇄 처치", desc = "콤보 보너스 2배" },
}

-- ===============================================================
-- 6. 게임패스 6종 · 개발자 상품 11종
-- ===============================================================
Shared.PASSES = {
	{
		key = "PASS_VIP", attr = "PassVip", name = "👑 VIP", price = 399,
		desc = "5대 종족 전체 해금 · 보상 +25% · 순위표 황금 왕관",
	},
	{
		key = "PASS_FUSION", attr = "PassFusion", name = "🧬 융합 마스터", price = 249,
		desc = "이종족 융합 3+2 → 2+1 · 융합 유닛 공격력 +20%",
	},
	{
		key = "PASS_ARENA", attr = "PassArena", name = "🏗️ 아레나 확장", price = 199,
		desc = "건설 그리드 6×6 → 8×8 (테두리 28칸 추가 해금)",
	},
	{
		key = "PASS_2X", attr = "Pass2x", name = "⚡ 2배속", price = 149,
		desc = "몬스터 스폰 2배 · 스테이지 대기 -30%",
	},
	{
		key = "PASS_AUTO", attr = "PassAuto", name = "🤖 자동합치기", price = 199,
		desc = "합성 가능 시 자동 진화 · 빈 타일 자동 건설",
	},
	{
		key = "PASS_LUCK", attr = "PassLuck", name = "🍀 러키 뽑기", price = 299,
		desc = "전설·신화 확률 ×1.8 · 천장 10회 → 8회",
	},
}

Shared.PRODUCTS = {
	-- 1위 역전 · 충동구매
	{
		key = "PRODUCT_OVERCHARGE", group = "impulse", name = "⚡ 딜량 2배 과충전 (3분)", price = 29,
		desc = "내 아레나 모든 터렛 공격력 2배 · 3분",
		badge = "역전 한 방",
	},
	{
		key = "PRODUCT_REVIVE", group = "impulse", name = "💖 12초 긴급 부활", price = 25,
		desc = "넥서스 붕괴 순간 즉시 부활 · 60% HP 복구",
		badge = "패배 직전 1탭",
	},
	{
		key = "PRODUCT_MODE_RESET", group = "impulse", name = "🔄 모드전환 쿨초기화", price = 25,
		desc = "모든 유닛의 모드 전환 쿨타임 즉시 초기화",
	},
	{
		key = "PRODUCT_SUMMON", group = "impulse", name = "🌀 타 종족 지원 소환권", price = 39,
		desc = "다른 종족 유닛 1기 즉시 소환 → 이종족 융합 재료",
		badge = "융합 필수템",
	},
	{
		key = "PRODUCT_SABOTAGE", group = "social", name = "☠ 경쟁 1위 팀 방해 투하", price = 49,
		desc = "현재 1위 팀 아레나에 정예 몬스터 5마리 투하",
		badge = "경쟁전 핵심",
	},
	{
		key = "PRODUCT_TEAM_BOOST", group = "social", name = "🎁 팀 전체 과충전 선물", price = 79,
		desc = "서버 전원 공격력 +30% 3분 · 전원 배너 공지",
		badge = "친구에게 선물",
	},
	{
		key = "PRODUCT_STARTER", group = "bundle", name = "🚀 스타터팩 (1회 한정)", price = 79,
		desc = "보석 300 + 긴급 부활 1 + 과충전 5분 + 지원 소환 1",
		badge = "1인 1회 · 초가성비",
		oncePerPlayer = true,
	},
	{
		key = "PRODUCT_GEMS_S", group = "bundle", name = "💠 보석 150", price = 99,
		desc = "영구 강화(시작 미네랄·가스·공격력)에 사용",
	},
	{
		key = "PRODUCT_GEMS_M", group = "bundle", name = "💠 보석 540", price = 199,
		desc = "+8% 보너스 포함",
	},
	{
		key = "PRODUCT_GEMS_L", group = "bundle", name = "💠 보석 1,320", price = 399,
		desc = "+10% 보너스 포함",
	},
	{
		key = "PRODUCT_GEMS_XL", group = "bundle", name = "💠 보석 3,450", price = 799,
		desc = "+15% 보너스 포함",
	},
}

Shared.PRODUCT_BY_ID = {}
for _, p in ipairs(Shared.PRODUCTS) do
	p.id = Shared.IDS[p.key] or 0
	if p.id > 0 then
		Shared.PRODUCT_BY_ID[tostring(p.id)] = p
	end
end
for _, p in ipairs(Shared.PASSES) do
	p.id = Shared.IDS[p.key] or 0
end
Shared.PASS_BY_ID = {}
for _, p in ipairs(Shared.PASSES) do
	if p.id > 0 then Shared.PASS_BY_ID[tostring(p.id)] = p end
end

Shared.GEM_PACKS = {
	PRODUCT_GEMS_S = 150,
	PRODUCT_GEMS_M = 540,
	PRODUCT_GEMS_L = 1320,
	PRODUCT_GEMS_XL = 3450,
}

Shared.VIP_BONUS = 0.25
Shared.PREMIUM_BONUS = 0.15
Shared.OVERCHARGE_SECONDS = 180
Shared.OVERCHARGE_MUL = 2.0
Shared.TEAM_BOOST_SECONDS = 180
Shared.TEAM_BOOST_MUL = 1.30
Shared.MODE_COOLDOWN = 6

-- ===============================================================
-- 7. 리텐션 — 출석 7일 · 체류 · 일일 퀘스트 · 영구 강화
-- ===============================================================
Shared.DAILY = {
	{ minerals = 120, gems = 10, label = "미네랄 120 + 보석 10" },
	{ gems = 25, label = "보석 25" },
	{ minerals = 250, gems = 15, label = "미네랄 250 + 보석 15" },
	{ revive = 1, gems = 20, label = "부활권 1 + 보석 20" },
	{ gems = 40, label = "보석 40" },
	{ minerals = 400, gems = 30, label = "미네랄 400 + 보석 30" },
	{ gems = 90, revive = 1, label = "보석 90 + 부활권 1 (7일 완주)" },
}

Shared.PLAYTIME = {
	{ at = 300, label = "5분", minerals = 80 },
	{ at = 600, label = "10분", gems = 15 },
	{ at = 900, label = "15분", minerals = 200 },
	{ at = 1800, label = "30분", gems = 40 },
	{ at = 3600, label = "60분", gems = 100, revive = 1 },
}

Shared.QUESTS = {
	{ key = "kills", text = "적 300마리 처치", goal = 300, gems = 25, metric = "kills" },
	{ key = "stage", text = "스테이지 10 도달", goal = 10, gems = 30, metric = "stage" },
	{ key = "merges", text = "터렛 10회 합성", goal = 10, gems = 20, metric = "merges" },
	{ key = "fusions", text = "이종족 융합 1회", goal = 1, gems = 35, metric = "fusions" },
	{ key = "draws", text = "뽑기 20회", goal = 20, gems = 20, metric = "draws" },
	{ key = "bossKills", text = "영웅 몬스터 1회 처치", goal = 1, gems = 25, metric = "bossKills" },
	{ key = "modes", text = "모드 전환 6회", goal = 6, gems = 20, metric = "modes" },
	{ key = "revives", text = "부활 1회 사용", goal = 1, gems = 25, metric = "revives" },
}
Shared.QUEST_COUNT = 3

Shared.UPGRADES = {
	{ key = "startMinerals", name = "💎 시작 미네랄", desc = "판 시작 시 미네랄 +40", max = 10, baseCost = 60, step = 40 },
	{ key = "startGas", name = "⛽ 시작 가스", desc = "판 시작 시 가스 +25", max = 6, baseCost = 80, step = 25 },
	{ key = "permAtk", name = "⚔ 영구 공격력", desc = "모든 터렛 공격력 +3%", max = 10, baseCost = 100, step = 0.03 },
}

function Shared.upgradeCost(def, level)
	return math.floor(def.baseCost * (level + 1) * (1 + level * 0.15))
end

-- ===============================================================
-- 8. 리모트 · 서버 버스
-- ===============================================================
Shared.REMOTE_NAMES = {
	"TD_State",      -- 서버 → 클라 : 상태/배너/토스트/유물/순위
	"TD_FX",         -- 서버 → 클라 : 데미지 숫자·화면 연출
	"TD_Meta",       -- 서버 → 클라 : 출석·퀘스트·체류·영구강화
	"TD_Draw", "TD_Merge", "TD_Upgrade", "TD_Support",
	"TD_PickRelic", "TD_Prompt", "TD_MetaAction", "TD_Build",
}

function Shared.remotes()
	local folder = ReplicatedStorage:FindFirstChild("TD_Remotes")
	if not folder then
		if RunService:IsServer() then
			folder = Instance.new("Folder")
			folder.Name = "TD_Remotes"
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild("TD_Remotes", 30)
			if not folder then return nil end
		end
	end
	if RunService:IsServer() then
		for _, name in ipairs(Shared.REMOTE_NAMES) do
			if not folder:FindFirstChild(name) then
				local r = Instance.new("RemoteEvent")
				r.Name = name
				r.Parent = folder
			end
		end
	end
	return folder
end

function Shared.remote(name, timeout)
	local folder = Shared.remotes()
	if not folder then return nil end
	return folder:WaitForChild(name, timeout or 30)
end

-- 서버 전용 통신 버스 (ServerScriptService.TD_Bus)
--   Bus.Event : BindableEvent  (02 → 03/05 알림: 킬·스테이지·보스·부활)
--   Bus.Call  : BindableFunction (03/05 → 02 요청: 지급·소환·리셋, 결과 boolean)
function Shared.bus()
	if not RunService:IsServer() then return nil end
	local folder = ServerScriptService:FindFirstChild("TD_Bus")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TD_Bus"
		folder.Parent = ServerScriptService
	end
	local ev = folder:FindFirstChild("Event")
	if not ev then
		ev = Instance.new("BindableEvent")
		ev.Name = "Event"
		ev.Parent = folder
	end
	local call = folder:FindFirstChild("Call")
	if not call then
		call = Instance.new("BindableFunction")
		call.Name = "Call"
		call.Parent = folder
	end
	return folder
end

-- ===============================================================
-- 9. 잔손질 도우미
-- ===============================================================
function Shared.comma(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then
		sign = "-"
		s = string.sub(s, 2)
	end
	local out = s
	while true do
		local replaced
		out, replaced = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then break end
	end
	return sign .. out
end

function Shared.short(n)
	n = math.floor(tonumber(n) or 0)
	if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
	if n >= 10000 then return string.format("%.1fK", n / 1000) end
	return tostring(n)
end

function Shared.tierColor(tier)
	return Shared.TIER_COLORS[math.clamp(tier or 1, 1, 5)]
end

function Shared.now()
	return os.time()
end

return Shared
