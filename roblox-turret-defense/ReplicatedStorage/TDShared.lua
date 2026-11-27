--[[ ============================================================
  TDShared  (ModuleScript)
  붙여넣는 곳 : ReplicatedStorage  →  ModuleScript, 이름을 정확히 "TDShared"
  ------------------------------------------------------------
  서버(01·02·03·05)와 클라이언트(04·06·07)가 함께 읽는 "설정 한 곳".
    · 맵 좌표 · 터렛/적 밸런스 · 유물 · 확률 · 상품/패스 가격표
    · 리모트(RemoteEvent) 생성/검색 도우미
  ★ 상품·패스 ID는 아래 Shared.IDS 표에서만 고치면 됩니다.
  ============================================================ ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Shared = {}
Shared.VERSION = "2.0"

-- ===============================================================
-- ★★ 여기만 고치면 됩니다 — 스튜디오에서 발급받은 ID ★★
--    아직 없으면 0으로 두세요. 0이면 "준비 중"으로 표시되고 구매만 꺼집니다.
-- ===============================================================
Shared.IDS = {
	-- 게임패스 (한 번 구매 · 영구)
	PASS_VIP = 0,         -- 👑 VIP          : 보상 +20%, VIP 태그
	PASS_2X = 0,          -- ⚡ 2배속        : 공속 +25%, 웨이브 대기 -30%
	PASS_AUTO = 0,        -- 🧲 자동 합성    : 자동 병합 + 자동 배치
	PASS_SLOTS = 0,       -- 🎰 추가 슬롯    : 5·6번 패드 해금
	PASS_LUCK = 0,        -- 🍀 럭키 뽑기    : 전설+ ×1.8, 천장 8회
	PASS_BONUS = 0,       -- 💰 웨이브 보너스: 보상 +30%, 유물 4지선다

	-- 개발자 상품 (반복 구매)
	PRODUCT_REVIVE = 0,       -- 💖 부활권           25 R$
	PRODUCT_BOOST_DMG = 0,    -- 🔥 2배 데미지 10분  35 R$
	PRODUCT_BOOST_GOLD = 0,   -- 💎 미네랄 2배 10분  35 R$
	PRODUCT_REROLL = 0,       -- 🎲 즉시 리롤        39 R$
	PRODUCT_WAVE_SKIP = 0,    -- ⏭ 웨이브 정리      49 R$
	PRODUCT_TEAM_SPEED = 0,   -- 🎁 팀 전체 공속 버프 79 R$
	PRODUCT_TEAM_GOLD = 0,    -- 🎁 팀 전체 미네랄   49 R$
	PRODUCT_STARTER = 0,      -- 🚀 스타터팩 (1회)   79 R$
	PRODUCT_GEMS_S = 0,       -- 💠 보석 150         99 R$
	PRODUCT_GEMS_M = 0,       -- 💠 보석 500        249 R$
	PRODUCT_GEMS_L = 0,       -- 💠 보석 1,200      449 R$
	PRODUCT_GEMS_XL = 0,      -- 💠 보석 3,000      799 R$
	PRODUCT_LUCK10 = 0,       -- 🎯 럭키 10연차     149 R$
	PRODUCT_LEGEND = 0,       -- 🌟 전설 확정 뽑기  199 R$
}

-- ===============================================================
-- 1. 맵 좌표 (01 과 02 가 같은 값을 씁니다 — 여기 한 곳만)
-- ===============================================================
Shared.GEO = {
	LANE_X = { -13.5, -4.5, 4.5, 13.5 },
	LANE_NAMES = { "P1", "P2", "P3", "P4" },
	LANE_COLORS = {
		Color3.fromRGB(79, 216, 255),
		Color3.fromRGB(92, 255, 176),
		Color3.fromRGB(176, 123, 255),
		Color3.fromRGB(255, 194, 77),
	},
	-- 패드 6칸: 1~4 무료, 5~6 = 추가 슬롯 패스
	SLOT_Z = { -24, -14.4, -4.8, 4.8, 14.4, 24 },
	FREE_SLOTS = 4,
	SLOT_X_OFF = -2.3,
	ENEMY_X_OFF = 2.3,
	NEXUS_POS = Vector3.new(0, 0, 32),
	PATH_Z0 = -31,
	PATH_Z1 = 27,
	ARENA_W = 40,
	ARENA_D = 74,
}

-- ===============================================================
-- 2. 등급 · 확률
-- ===============================================================
Shared.TIER_NAMES = { "일반", "희귀", "영웅", "전설", "신화" }
Shared.TIER_COLORS = {
	Color3.fromRGB(184, 198, 210),
	Color3.fromRGB(62, 155, 255),
	Color3.fromRGB(169, 115, 255),
	Color3.fromRGB(255, 194, 77),
	Color3.fromRGB(255, 91, 209),
}

Shared.GACHA_COST = 18
Shared.PITY_BASE = 10      -- 무료: 10회째 희귀 이상 확정
Shared.PITY_PASS = 8       -- 럭키 뽑기 패스: 8회째 확정
Shared.LUCK_MUL = 1.8      -- 럭키 뽑기 패스: 전설·신화 가중치 배수

-- 가중치 표 (합 100 기준 · 실제 %는 tierOdds()가 계산)
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

-- 확률 공개용 문자열 (상점 UI)
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

-- ===============================================================
-- 3. 터렛 10종 · 적 5종 (밸런스는 여기 숫자만)
-- ===============================================================
Shared.TURRETS = {
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

-- 서버가 쓰는 적 배율 (모델 속성은 01이 넣고, 체력 배율은 여기서)
Shared.ENEMIES = {
	zergling = { model = "zergling", hp = 1.00, weight = 1 },
	hydra = { model = "hydra", hp = 1.80, weight = 1 },
	roach = { model = "roach", hp = 3.00, weight = 1 },
	mutalisk = { model = "mutalisk", hp = 1.60, weight = 1 },
	boss = { model = "boss", hp = 15.0, weight = 0 },
}

Shared.MAX_WAVE = 20
Shared.CORE_MAX = 30
Shared.WAVE_HP_BASE = 60
Shared.WAVE_HP_GROWTH = 1.262

-- ===============================================================
-- 4. 유물 (보스 처치마다 3~4지선다)
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
	{ key = "auto", name = "🧲 자동 합성 장치", desc = "합성 가능 시 자동 진화" },
	{ key = "combo", name = "🔗 연쇄 처치", desc = "콤보 보너스 2배" },
}

-- ===============================================================
-- 5. 게임패스 6종
-- ===============================================================
Shared.PASSES = {
	{
		key = "PASS_VIP", attr = "PassVip", name = "👑 VIP", price = 399,
		desc = "모든 미네랄·보석 보상 +20% · 이름 옆 VIP 태그",
	},
	{
		key = "PASS_2X", attr = "Pass2x", name = "⚡ 2배속", price = 149,
		desc = "내 터렛 공격속도 +25% · 웨이브 대기시간 -30%",
	},
	{
		key = "PASS_AUTO", attr = "PassAuto", name = "🧲 자동 합성·자동 배치", price = 199,
		desc = "합성 가능하면 자동 진화 · 빈 패드에 자동 배치",
	},
	{
		key = "PASS_SLOTS", attr = "PassSlots", name = "🎰 추가 덱 슬롯", price = 249,
		desc = "내 라인 5·6번 패드 영구 해금 (터렛 2기 추가)",
	},
	{
		key = "PASS_LUCK", attr = "PassLuck", name = "🍀 럭키 뽑기", price = 299,
		desc = "전설·신화 확률 ×1.8 · 천장 10회 → 8회",
	},
	{
		key = "PASS_BONUS", attr = "PassBonus", name = "💰 웨이브 보너스", price = 349,
		desc = "웨이브 클리어 보상 +30% · 보스 유물 4지선다",
	},
}

-- ===============================================================
-- 6. 개발자 상품 14종 (반복 구매 · 가격대 25~799 R$)
--    tier : shop 정렬용 그룹 (impulse/social/bundle)
-- ===============================================================
Shared.PRODUCTS = {
	-- 저가 충동구매
	{
		key = "PRODUCT_REVIVE", group = "impulse", name = "💖 부활권", price = 25,
		desc = "넥서스 붕괴 순간 즉시 부활 (보관 최대 3장)",
		badge = "패배 직전 1탭",
	},
	{
		key = "PRODUCT_BOOST_DMG", group = "impulse", name = "🔥 2배 데미지 10분", price = 35,
		desc = "내 터렛 전체 공격력 2배 · 10분",
	},
	{
		key = "PRODUCT_BOOST_GOLD", group = "impulse", name = "💎 미네랄 2배 10분", price = 35,
		desc = "내 라인 미네랄 획득 2배 · 10분",
	},
	{
		key = "PRODUCT_REROLL", group = "impulse", name = "🎲 즉시 리롤", price = 39,
		desc = "내 라인 터렛 전부 재뽑기 (25% 확률로 등급 UP)",
	},
	{
		key = "PRODUCT_WAVE_SKIP", group = "impulse", name = "⏭ 웨이브 정리", price = 49,
		desc = "남은 잡몹 즉시 제거 · 보스 체력 50% 피해",
		badge = "막힌 웨이브 탈출",
	},
	-- 소셜 과금 (팀 선물)
	{
		key = "PRODUCT_TEAM_GOLD", group = "social", name = "🎁 팀 전체 미네랄 +150", price = 49,
		desc = "4인 전원에게 즉시 미네랄 150 · 서버 전체 공지",
		badge = "친구에게 선물",
	},
	{
		key = "PRODUCT_TEAM_SPEED", group = "social", name = "🎁 팀 전체 공속 +50% 5분", price = 79,
		desc = "4인 모든 터렛 공격속도 +50% 5분 · 감사 이펙트 + 공지",
		badge = "가장 인기",
	},
	-- 중고가 패키지
	{
		key = "PRODUCT_STARTER", group = "bundle", name = "🚀 스타터팩 (1회 한정)", price = 79,
		desc = "보석 300 + 미네랄 400 + 전설 확정 1 + 부활권 2",
		badge = "1인 1회 · 초가성비",
		oncePerPlayer = true,
	},
	{
		key = "PRODUCT_GEMS_S", group = "bundle", name = "💠 보석 150", price = 99,
		desc = "영구 강화(시작 미네랄·공격력)에 사용",
	},
	{
		key = "PRODUCT_GEMS_M", group = "bundle", name = "💠 보석 500", price = 249,
		desc = "+8% 보너스 포함 (총 540)",
	},
	{
		key = "PRODUCT_GEMS_L", group = "bundle", name = "💠 보석 1,200", price = 449,
		desc = "+10% 보너스 포함 (총 1,320)",
	},
	{
		key = "PRODUCT_GEMS_XL", group = "bundle", name = "💠 보석 3,000", price = 799,
		desc = "+15% 보너스 포함 (총 3,450)",
	},
	{
		key = "PRODUCT_LUCK10", group = "bundle", name = "🎯 럭키 10연차", price = 149,
		desc = "즉시 10회 뽑기 · 희귀 이상 최소 1개 보장",
	},
	{
		key = "PRODUCT_LEGEND", group = "bundle", name = "🌟 전설 확정 뽑기", price = 199,
		desc = "전설 터렛 1기 즉시 배치",
	},
}

-- ID → 상품 표 (03 이 영수증 처리할 때 사용)
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

-- 보석 지급량 (상품별)
Shared.GEM_PACKS = {
	PRODUCT_GEMS_S = 150,
	PRODUCT_GEMS_M = 540,
	PRODUCT_GEMS_L = 1320,
	PRODUCT_GEMS_XL = 3450,
}

-- ===============================================================
-- 7. 리텐션 — 출석 7일 · 체류 보상 · 일일 퀘스트 · 영구 강화
-- ===============================================================
Shared.DAILY = {
	{ minerals = 120, gems = 10, label = "미네랄 120 + 보석 10" },
	{ gems = 25, label = "보석 25" },
	{ minerals = 250, gems = 15, label = "미네랄 250 + 보석 15" },
	{ revive = 1, gems = 20, label = "부활권 1 + 보석 20" },
	{ gems = 40, label = "보석 40" },
	{ minerals = 400, label = "미네랄 400 + 보석 30", gems = 30 },
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
	{ key = "kills", text = "적 100마리 처치", goal = 100, gems = 25, metric = "kills" },
	{ key = "wave", text = "웨이브 10 도달", goal = 10, gems = 30, metric = "wave" },
	{ key = "merges", text = "터렛 10회 합성", goal = 10, gems = 20, metric = "merges" },
	{ key = "boss", text = "보스 1회 처치", goal = 1, gems = 35, metric = "bossKills" },
	{ key = "draws", text = "뽑기 20회", goal = 20, gems = 20, metric = "draws" },
	{ key = "revives", text = "부활 1회 사용", goal = 1, gems = 25, metric = "revives" },
}
Shared.QUEST_COUNT = 3   -- 하루 3개

-- 영구 강화 (보석 사용처)
Shared.UPGRADES = {
	{ key = "startMinerals", name = "💎 시작 미네랄", desc = "판 시작 시 미네랄 +40", max = 10, baseCost = 60, step = 40 },
	{ key = "startGas", name = "⛽ 시작 가스", desc = "판 시작 시 가스 +25", max = 6, baseCost = 80, step = 25 },
	{ key = "permAtk", name = "⚔ 영구 공격력", desc = "모든 터렛 공격력 +3%", max = 10, baseCost = 100, step = 0.03 },
}

function Shared.upgradeCost(def, level)
	return math.floor(def.baseCost * (level + 1) * (1 + level * 0.15))
end

-- ===============================================================
-- 8. 보상 배율 도우미
-- ===============================================================
Shared.VIP_BONUS = 0.20
Shared.PREMIUM_BONUS = 0.15
Shared.BONUS_PASS_REWARD = 0.30

-- ===============================================================
-- 9. 리모트 · 서버 버스
-- ===============================================================
Shared.REMOTE_NAMES = {
	"TD_State",      -- 서버 → 클라 : 상태/배너/토스트/유물/승패
	"TD_FX",         -- 서버 → 클라 : 데미지 숫자·화면 연출
	"TD_Meta",       -- 서버 → 클라 : 출석·퀘스트·체류·영구강화
	"TD_Draw", "TD_Merge", "TD_Upgrade", "TD_Support",
	"TD_PickRelic", "TD_Prompt", "TD_MetaAction",
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
--   Bus.Event : BindableEvent  (02 → 03/05 알림: 킬·웨이브·보스·부활)
--   Bus.Call  : BindableFunction (03/05 → 02 요청: 지급·스킵·리롤, 결과 boolean)
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
-- 10. 잔손질 도우미
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

function Shared.tierColor(tier)
	return Shared.TIER_COLORS[math.clamp(tier or 1, 1, 5)]
end

function Shared.now()
	return os.time()
end

return Shared
