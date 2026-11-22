--[[
  01_DataAndMonetization.server.lua
  ------------------------------------------------------------------
  붙여넣는 위치 : ServerScriptService  (일반 Script)
  하는 일
    · 플레이어 데이터(코인·보유 요정·친밀도·레벨·하우스·꾸미기) 저장/복원 (DataStore)
    · 리더보드(leaderstats: Coins, Fairies) 생성
    · 모든 스크립트가 함께 쓰는 RemoteEvent / 요정 도감 목록 생성
    · Game Pass 3종 확인 + Developer Product(코인 팩) 결제 처리

  ※ 아래 CONFIG 의 ID 는 0 으로 두면 "아직 미연동" 상태입니다.
     게임을 Publish 한 뒤 create.roblox.com > Monetization 에서
     Pass / Product 를 만들고 ID 를 넣으면 바로 동작합니다.
  ※ Studio 에서는 데이터가 저장되지 않습니다(정상).
     Publish 후 Game Settings > Security >
     'Enable Studio Access to API Services' 를 켜면 Studio 에서도 저장됩니다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

-- ==============================================================
-- 1. 설정 (여기만 고치면 됩니다)
-- ==============================================================
local CONFIG = {
	-- Game Pass ID (create.roblox.com > 내 체험 > Monetization > Passes)
	GAMEPASS_GOLDEN_COMPACT = 0,  -- 황금 콤팩트 : 포획 코인 2배
	GAMEPASS_EXTRA_SLOTS = 0,     -- 하우스 슬롯 +3
	GAMEPASS_LEGEND_EGG = 0,      -- 전설의 요정 알 (1회)

	-- Developer Product ID (Monetization > Developer Products)
	PRODUCT_COINS_SMALL = 0,      -- 500 코인
	PRODUCT_COINS_MEDIUM = 0,     -- 2,000 코인
	PRODUCT_COINS_LARGE = 0,      -- 8,000 코인

	START_COINS = 300,
	BASE_SLOTS = 4,
	MAX_SLOTS = 8,
	AUTOSAVE_SECONDS = 60,
	DATABASE_NAME = "FairyCatchData_v1",
}

local COIN_PRODUCT_AMOUNT = {
	[CONFIG.PRODUCT_COINS_SMALL] = 500,
	[CONFIG.PRODUCT_COINS_MEDIUM] = 2000,
	[CONFIG.PRODUCT_COINS_LARGE] = 8000,
}

-- ==============================================================
-- 2. 요정 도감 목록 (클라이언트와 공유)
-- ==============================================================
local FAIRY_LIST = {
	{ id = "ruby",    name = "루비하트핑", rarity = "common",    zone = "grass",  color = Color3.fromRGB(255, 140, 175) },
	{ id = "sugar",   name = "슈가핑",     rarity = "common",    zone = "cafe",   color = Color3.fromRGB(255, 180, 220) },
	{ id = "flower",  name = "플라워핑",   rarity = "common",    zone = "flower", color = Color3.fromRGB(140, 220, 165) },
	{ id = "starbell",name = "스타벨핑",   rarity = "common",    zone = "plaza",  color = Color3.fromRGB(255, 210, 130) },
	{ id = "cloud",   name = "클라우드핑", rarity = "uncommon",  zone = "cloud",  color = Color3.fromRGB(150, 205, 255) },
	{ id = "jelly",   name = "젤리팝핑",   rarity = "uncommon",  zone = "cafe",   color = Color3.fromRGB(180, 150, 250) },
	{ id = "sunshine",name = "선샤인핑",   rarity = "uncommon",  zone = "cloud",  color = Color3.fromRGB(255, 180, 100) },
	{ id = "rainbow", name = "레인보우핑", rarity = "rare",      zone = "flower", color = Color3.fromRGB(255, 170, 210) },
	{ id = "moon",    name = "문라이트핑", rarity = "rare",      zone = "cave",   color = Color3.fromRGB(150, 155, 235) },
	{ id = "crystal", name = "크리스탈핑", rarity = "epic",      zone = "cave",   color = Color3.fromRGB(110, 235, 230) },
	{ id = "dream",   name = "드림핑",     rarity = "epic",      zone = "cloud",  color = Color3.fromRGB(215, 175, 255) },
	{ id = "galaxy",  name = "갤럭시핑",   rarity = "legendary", zone = "cave",   color = Color3.fromRGB(200, 170, 255) },
}

-- ===== 요정 옷 / 악세사리 카탈로그 (12종 가구와 함께 확장) =====
local DRESSES = {
	{ id = "princess", name = "프린세스 드레스", price = 900, color = Color3.fromRGB(255, 194, 224), trim = Color3.fromRGB(255, 209, 102) },
	{ id = "cloak",    name = "별빛 망토",       price = 1050, color = Color3.fromRGB(215, 220, 255), trim = Color3.fromRGB(143, 107, 240) },
	{ id = "apron",    name = "달콤 에이프런",   price = 700, color = Color3.fromRGB(255, 240, 214), trim = Color3.fromRGB(255, 143, 194) },
	{ id = "tutu",     name = "파티 튜튜",       price = 820, color = Color3.fromRGB(255, 217, 236), trim = Color3.fromRGB(183, 156, 255) },
	{ id = "pajama",   name = "구름 파자마",     price = 650, color = Color3.fromRGB(207, 230, 255), trim = Color3.fromRGB(143, 214, 255) },
	{ id = "galaxy",   name = "갤럭시 슈트",     price = 1400, color = Color3.fromRGB(59, 47, 107), trim = Color3.fromRGB(143, 240, 255) },
	{ id = "ladybug",  name = "레이디버그 원피스", price = 740, color = Color3.fromRGB(255, 107, 107), trim = Color3.fromRGB(40, 30, 50) },
}
local HEADS = {
	{ id = "tiara",      name = "티아라",     price = 480, color = Color3.fromRGB(255, 209, 102) },
	{ id = "ribbon",     name = "빅리본",     price = 320, color = Color3.fromRGB(255, 95, 168) },
	{ id = "beret",      name = "베레모",     price = 360, color = Color3.fromRGB(183, 156, 255) },
	{ id = "flowercrown",name = "꽃화관",     price = 420, color = Color3.fromRGB(255, 158, 203) },
}
local ACCS = {
	{ id = "sunglasses", name = "하트 선글라스", price = 400, color = Color3.fromRGB(45, 25, 55) },
	{ id = "wand",       name = "별빛 지팡이",   price = 560, color = Color3.fromRGB(255, 224, 138) },
	{ id = "angelwing",  name = "천사 날개",     price = 900, color = Color3.fromRGB(255, 255, 255) },
	{ id = "bell",       name = "방울 목걸이",   price = 300, color = Color3.fromRGB(255, 209, 102) },
	{ id = "umbrella",   name = "무지개 우산",   price = 460, color = Color3.fromRGB(255, 158, 203) },
}

local RARITY = {
	common = { label = "일반", coins = 18, arc = 70, speed = 150, hits = 3, template = "Fairy_Common" },
	uncommon = { label = "고급", coins = 32, arc = 56, speed = 166, hits = 3, template = "Fairy_Common" },
	rare = { label = "희귀", coins = 55, arc = 42, speed = 182, hits = 3, template = "Fairy_Rare" },
	epic = { label = "영웅", coins = 90, arc = 32, speed = 200, hits = 4, template = "Fairy_Rare" },
	legendary = { label = "전설", coins = 160, arc = 22, speed = 220, hits = 4, template = "Fairy_Legend" },
}

local catalogFolder = ReplicatedStorage:FindFirstChild("FairyCatalog")
if catalogFolder == nil then
	catalogFolder = Instance.new("Folder")
	catalogFolder.Name = "FairyCatalog"
	catalogFolder.Parent = ReplicatedStorage
end
catalogFolder:ClearAllChildren()

for _, info in ipairs(FAIRY_LIST) do
	local f = Instance.new("Configuration")
	f.Name = info.id
	f:SetAttribute("DisplayName", info.name)
	f:SetAttribute("Rarity", info.rarity)
	f:SetAttribute("Zone", info.zone)
	f:SetAttribute("Color", info.color)
	f.Parent = catalogFolder
end

-- ==============================================================
-- 3. RemoteEvent 만들기
-- ==============================================================
local net = ReplicatedStorage:FindFirstChild("FairyNet")
if net == nil then
	net = Instance.new("Folder")
	net.Name = "FairyNet"
	net.Parent = ReplicatedStorage
end

local function getRemote(name)
	local remote = net:FindFirstChild(name)
	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = net
	end
	return remote
end

local remotes = {
	CatchStart = getRemote("CatchStart"),   -- 서버 -> 클라이언트 (미니게임 시작)
	CatchTap = getRemote("CatchTap"),       -- 클라이언트 -> 서버 (탭했다)
	CatchResult = getRemote("CatchResult"), -- 서버 -> 클라이언트 (결과)
	RequestHouse = getRemote("RequestHouse"),
	HouseData = getRemote("HouseData"),     -- 서버 -> 클라이언트 (하우스 상태)
	FairyAction = getRemote("FairyAction"), -- 밥/놀기/쓰다듬기
	Harvest = getRemote("Harvest"),
	BuyDecor = getRemote("BuyDecor"),
	BuyWear = getRemote("BuyWear"),     -- 클라이언트 -> 서버 (옷·악세사리 구매)
	SetWear = getRemote("SetWear"),     -- 클라이언트 -> 서버 (요정별 코디 입기/벗기)
	Notify = getRemote("Notify"),
	-- 요정 타운 (학업 · 땅 · 건물 · 장사 · 병원/마트/장비점)
	RequestTown = getRemote("RequestTown"),       -- 클라이언트 -> 서버 (타운 창 열기)
	TownData = getRemote("TownData"),             -- 서버 -> 클라이언트 (타운 전체 상태)
	BuyPlot = getRemote("BuyPlot"),               -- 클라이언트 -> 서버 (땅 매입)
	UpgradeBuilding = getRemote("UpgradeBuilding"),-- 클라이언트 -> 서버 (건설/증축)
	CollectBusiness = getRemote("CollectBusiness"),-- 클라이언트 -> 서버 (매출 수거)
	SetFairyMode = getRemote("SetFairyMode"),     -- 자유/공부/장사
	CareFairy = getRemote("CareFairy"),           -- 간식/치료/반지/부적 선물
}

-- ==============================================================
-- 4. 데이터
-- ==============================================================
local store = DataStoreService:GetDataStore(CONFIG.DATABASE_NAME)
local PlayerData = {}
shared.FairyData = PlayerData
shared.FairyRemotes = remotes
shared.FairyConfig = { CONFIG = CONFIG, RARITY = RARITY, FAIRY_LIST = FAIRY_LIST,
	DRESSES = DRESSES, HEADS = HEADS, ACCS = ACCS, TOWN = TOWN_FACILITIES }

-- 코디 카탈로그도 ReplicatedStorage 에 올려 HUD 가 읽을 수 있게 합니다
local wearFolder = ReplicatedStorage:FindFirstChild("FairyWearCatalog")
if wearFolder == nil then
	wearFolder = Instance.new("Folder")
	wearFolder.Name = "FairyWearCatalog"
	wearFolder.Parent = ReplicatedStorage
end
wearFolder:ClearAllChildren()
for _, group in ipairs({ { kind = "dress", list = DRESSES }, { kind = "head", list = HEADS }, { kind = "acc", list = ACCS } }) do
	for _, item in ipairs(group.list) do
		local conf = Instance.new("Configuration")
		conf.Name = item.id
		conf:SetAttribute("Kind", group.kind)
		conf:SetAttribute("DisplayName", item.name)
		conf:SetAttribute("Price", item.price)
		conf:SetAttribute("Color", item.color)
		conf.Parent = wearFolder
	end
end

-- 요정 타운: 7개 경제 거점 (땅 매입 -> 건설 -> 증축, 학업 Lv·장비로 매출 상승)
local TOWN_FACILITIES = {
	{ slot = 1, id = "bakery",   name = "달콤 베이커리",  icon = "🥐", kind = "shop",     major = "pastry",   land = 160, build = 300, base = 0.9  },
	{ slot = 2, id = "mart",     name = "해피 마트",      icon = "🛒", kind = "mart",     major = nil,        land = 240, build = 420, base = 1.1  },
	{ slot = 3, id = "hospital", name = "요정 병원",      icon = "🏥", kind = "hospital", major = nil,        land = 320, build = 560, base = 1.25 },
	{ slot = 4, id = "cafe",     name = "무지개 포션카페", icon = "🧪", kind = "shop",     major = "barista",  land = 300, build = 520, base = 1.35 },
	{ slot = 5, id = "gear",     name = "마법 잡화·장비점", icon = "💍", kind = "gear",     major = nil,        land = 380, build = 640, base = 1.5  },
	{ slot = 6, id = "boutique", name = "별빛 부티크",    icon = "👗", kind = "shop",     major = "designer", land = 420, build = 740, base = 1.15 },
	{ slot = 7, id = "jewel",    name = "크리스탈 보석상", icon = "💎", kind = "shop",     major = "jeweler",  land = 460, build = 820, base = 1.6  },
}
local townFolder = ReplicatedStorage:FindFirstChild("FairyTownCatalog")
if townFolder == nil then
	townFolder = Instance.new("Folder")
	townFolder.Name = "FairyTownCatalog"
	townFolder.Parent = ReplicatedStorage
end
townFolder:ClearAllChildren()
for _, fac in ipairs(TOWN_FACILITIES) do
	local conf = Instance.new("Configuration")
	conf.Name = fac.id
	conf:SetAttribute("Slot", fac.slot)
	conf:SetAttribute("DisplayName", fac.name)
	conf:SetAttribute("Icon", fac.icon)
	conf:SetAttribute("Kind", fac.kind)
	conf:SetAttribute("Major", fac.major or "")
	conf:SetAttribute("Land", fac.land)
	conf:SetAttribute("Build", fac.build)
	conf:SetAttribute("Base", fac.base)
	conf.Parent = townFolder
end

local function defaultData()
	return {
		Coins = CONFIG.START_COINS,
		Fairies = {},      -- [id] = { count, aff, level }
		House = {},        -- { "ruby", "cloud", ... } 최대 8
		Slots = CONFIG.BASE_SLOTS,
		Decor = {},        -- [decorId] = true
		Owned = {},        -- [wearId] = true (옷·악세사리 보유)
		Wear = {},         -- [fairyId] = { dress = id, head = id, acc = id }
		Pending = 0,
		Total = 0,
		-- 요정 타운
		Study = {},        -- [fairyId] = { lv = 1..5, xp = 0, major = "pastry" }
		Mode = {},         -- [fairyId] = "auto" | "study" | "work"
		Care = {},         -- [fairyId] = { hp = 100, wallet = 40, ring = false, charm = false }
		Plots = {},        -- [slot] = { owned = false, bld = 0, income = 0, worker = nil }
		TownSeen = false,
		FirstPlay = os.time(),
	}
end

local function addCoins(player, amount)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	data.Coins = math.max(0, data.Coins + amount)
	local stats = player:FindFirstChild("leaderstats")
	if stats ~= nil then
		local coins = stats:FindFirstChild("Coins")
		if coins ~= nil then
			coins.Value = data.Coins
		end
	end
end

local function fairyCount(data)
	local n = 0
	for _, _ in pairs(data.Fairies) do
		n = n + 1
	end
	return n
end

local function savePlayer(player)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, data)
	end)
	if not ok then
		warn("[FairyCatch] 저장 실패: " .. tostring(err))
	end
end

shared.FairyAddCoins = addCoins
shared.FairySave = savePlayer
shared.FairyNotify = function(player, text)
	remotes.Notify:FireClient(player, text)
end

local function pushHouse(player)
	local data = PlayerData[player]
	if data == nil then
		return
	end
	remotes.HouseData:FireClient(player, {
		coins = data.Coins,
		fairies = data.Fairies,
		house = data.House,
		slots = data.Slots,
		decor = data.Decor,
		owned = data.Owned,
		wear = data.Wear,
		pending = data.Pending,
		study = data.Study,
		mode = data.Mode,
		care = data.Care,
		plots = data.Plots,
	})
end
shared.FairyPush = pushHouse

-- ==============================================================
-- 5. 접속 / 종료
-- ==============================================================
local function loadData(player)
	local ok, result = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if ok and type(result) == "table" then
		local data = defaultData()
		for key, value in pairs(result) do
			data[key] = value
		end
		if type(data.Fairies) ~= "table" then
			data.Fairies = {}
		end
		if type(data.House) ~= "table" then
			data.House = {}
		end
		if type(data.Decor) ~= "table" then
			data.Decor = {}
		end
		if type(data.Owned) ~= "table" then
			data.Owned = {}
		end
		if type(data.Wear) ~= "table" then
			data.Wear = {}
		end
		data.Slots = math.clamp(data.Slots or CONFIG.BASE_SLOTS, CONFIG.BASE_SLOTS, CONFIG.MAX_SLOTS)
		if type(data.Study) ~= "table" then data.Study = {} end
		if type(data.Mode) ~= "table" then data.Mode = {} end
		if type(data.Care) ~= "table" then data.Care = {} end
		if type(data.Plots) ~= "table" then data.Plots = {} end
		return data
	end
	return defaultData()
end

local function makeLeaderstats(player, data)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = stats

	local fairies = Instance.new("IntValue")
	fairies.Name = "Fairies"
	fairies.Value = fairyCount(data)
	fairies.Parent = stats
end

Players.PlayerAdded:Connect(function(player)
	local data = loadData(player)
	PlayerData[player] = data
	makeLeaderstats(player, data)

	-- Game Pass 확인
	local function ownsPass(passId)
		if passId == 0 then
			return false
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		return ok and owns == true
	end

	data.HasGoldenCompact = ownsPass(CONFIG.GAMEPASS_GOLDEN_COMPACT)
	if ownsPass(CONFIG.GAMEPASS_EXTRA_SLOTS) then
		data.Slots = math.min(CONFIG.MAX_SLOTS, math.max(data.Slots, CONFIG.BASE_SLOTS + 3))
	end
	if ownsPass(CONFIG.GAMEPASS_LEGEND_EGG) and not data.GotLegendEgg then
		data.GotLegendEgg = true
		data.Fairies.galaxy = data.Fairies.galaxy or { count = 1, aff = 0, level = 1 }
		shared.FairyNotify(player, "🥚 전설의 요정 알이 부화했어요! 갤럭시핑 획득")
	end

	wait(0.6)
	pushHouse(player)
	shared.FairyNotify(player, "🧚 마법 마을에 오신 것을 환영해요! 반짝이는 요정을 찾아보세요")
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	PlayerData[player] = nil
end)

game:BindToClose(function()
	for player, _ in pairs(PlayerData) do
		savePlayer(player)
	end
	task.wait(2)
end)

-- 자동 저장
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTOSAVE_SECONDS)
		for player, _ in pairs(PlayerData) do
			savePlayer(player)
		end
	end
end)

-- ==============================================================
-- 6. Developer Product (코인 팩)
-- ==============================================================
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local amount = COIN_PRODUCT_AMOUNT[receiptInfo.ProductId]
	if amount == nil then
		warn("[FairyCatch] 알 수 없는 상품 ID: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	addCoins(player, amount)
	savePlayer(player)
	pushHouse(player)
	shared.FairyNotify(player, "🪙 코인 " .. tostring(amount) .. "개가 도착했어요!")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("[FairyCatch] 데이터/수익화 스크립트 준비 완료 (가구 12종 · 옷/악세사리 16종)")
