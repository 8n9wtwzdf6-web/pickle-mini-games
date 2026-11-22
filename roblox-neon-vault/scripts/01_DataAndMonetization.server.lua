--[[
  01_DataAndMonetization.server.lua
  --------------------------------------------------------------------------------
  붙여넣는 위치: ServerScriptService  (일반 Script)
  하는 일:
    · 플레이어 데이터(현금·훔친 횟수·누적 수익·도감·최고 드론) 저장/복원 (DataStore)
    · 리더보드(leaderstats: Cash, Steals) 생성
    · HUD/코어가 함께 쓰는 RemoteEvent / 설정값 폴더 생성
    · Game Pass(2배 수익 / 즉시 잠금 / 해킹 드론 팩) 소유 확인
    · Developer Product(현금 팩) 결제 처리

  ※ 맨 아래 CONFIG 표의 ID를 본인 게임에서 만든 ID로 바꾸면 바로 연동됩니다.
     ID가 0 이면 '아직 미연동' 상태로, 구매 버튼이 안내 문구만 띄웁니다.
  ※ Studio 테스트 시에는 데이터가 저장되지 않습니다(정상). 게임을 Publish 하고
     Game Settings > Security > 'Enable Studio Access to API Services' 를 켜면
     Studio 에서도 테스트 저장이 됩니다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

-- ==============================================================
-- 1. 설정 (여기만 고치면 됩니다)
-- ==============================================================
local CONFIG = {
	-- Game Pass ID (create.roblox.com > 본인 체험 > Monetization > Passes 에서 생성)
	GAMEPASS_2X_CASH = 0,
	GAMEPASS_INSTANT_LOCK = 0,
	GAMEPASS_DRONE_PACK = 0,

	-- Developer Product ID (Monetization > Developer Products)
	PRODUCT_CASH_SMALL = 0,
	PRODUCT_CASH_BIG = 0,
	PRODUCT_CASH_MEGA = 0,

	AUTOSAVE_SECONDS = 60,
	START_CASH = 500,
}

local PRODUCT_CASH_AMOUNT = {
	[CONFIG.PRODUCT_CASH_SMALL] = 2500,
	[CONFIG.PRODUCT_CASH_BIG] = 15000,
	[CONFIG.PRODUCT_CASH_MEGA] = 100000,
}

local DATASTORE_NAME = "NeonVaultData_v1"

local DEFAULT_DATA = {
	Cash = CONFIG.START_CASH,
	Steals = 0,
	TotalEarned = CONFIG.START_CASH,
	Collection = "{}",
	DroneBest = 0,
	DroneCount = 0,
}

-- ==============================================================
-- 2. 공용 폴더 / 리모트 생성
-- ==============================================================
local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local configFolder = getOrCreate(ReplicatedStorage, "Folder", "NeonVaultConfig")
local configNames = {
	"GAMEPASS_2X_CASH",
	"GAMEPASS_INSTANT_LOCK",
	"GAMEPASS_DRONE_PACK",
	"PRODUCT_CASH_SMALL",
	"PRODUCT_CASH_BIG",
	"PRODUCT_CASH_MEGA",
}
for _, key in ipairs(configNames) do
	local value = getOrCreate(configFolder, "NumberValue", key)
	value.Value = CONFIG[key] or 0
end

local remotes = getOrCreate(ReplicatedStorage, "Folder", "NeonVaultRemotes")
local notifyRemote = getOrCreate(remotes, "RemoteEvent", "Notify")
getOrCreate(remotes, "RemoteEvent", "RollFx")
getOrCreate(remotes, "RemoteEvent", "RequestHack")
getOrCreate(remotes, "RemoteEvent", "RequestInstantLock")

-- 뽑기 비용표도 HUD·코어가 함께 봅니다.
local costsFolder = getOrCreate(configFolder, "Folder", "GachaCost")
local GACHA_COST = { gem = 40, egg = 180, monster = 700, drone = 2600 }
for themeId, cost in pairs(GACHA_COST) do
	local value = getOrCreate(costsFolder, "NumberValue", themeId)
	value.Value = cost
end

local function notify(player, text)
	if player ~= nil and player.Parent ~= nil then
		notifyRemote:FireClient(player, text)
	end
end

-- ==============================================================
-- 3. 리더보드
-- ==============================================================
local function setupLeaderstats(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats == nil then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local cash = stats:FindFirstChild("Cash")
	if cash == nil then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = stats
	end
	local steals = stats:FindFirstChild("Steals")
	if steals == nil then
		steals = Instance.new("IntValue")
		steals.Name = "Steals"
		steals.Parent = stats
	end
	return cash, steals
end

local function pushToLeaderstats(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats == nil then
		return
	end
	local cash = stats:FindFirstChild("Cash")
	local steals = stats:FindFirstChild("Steals")
	if cash ~= nil then
		cash.Value = math.floor(player:GetAttribute("Cash") or 0)
	end
	if steals ~= nil then
		steals.Value = math.floor(player:GetAttribute("Steals") or 0)
	end
end

-- ==============================================================
-- 4. 데이터 저장/복원
-- ==============================================================
local dataStore = nil
local function getStore()
	if dataStore ~= nil then
		return dataStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		dataStore = result
	end
	return dataStore
end

local saveQueued = {}

local function readPlayerSnapshot(player)
	local snapshot = {}
	for key, default in pairs(DEFAULT_DATA) do
		local value = player:GetAttribute(key)
		if value == nil then
			value = default
		end
		snapshot[key] = value
	end
	return snapshot
end

local function savePlayer(player, reason)
	local store = getStore()
	if store == nil then
		return false
	end
	local key = "player_" .. tostring(player.UserId)
	local snapshot = readPlayerSnapshot(player)
	local ok = pcall(function()
		store:SetAsync(key, snapshot)
	end)
	if not ok then
		-- 실패하면 조용히 큐에 넣어 나중에 다시 시도합니다.
		saveQueued[key] = true
		warn("[NeonVault] 데이터 저장 실패: " .. tostring(player.Name) .. " (" .. tostring(reason) .. ")")
	end
	return ok
end

local function loadPlayer(player)
	local store = getStore()
	local data = {}
	for key, default in pairs(DEFAULT_DATA) do
		data[key] = default
	end
	if store == nil then
		return data
	end
	local key = "player_" .. tostring(player.UserId)
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	if ok and type(result) == "table" then
		for key2, default2 in pairs(DEFAULT_DATA) do
			if result[key2] ~= nil and type(result[key2]) == type(default2) then
				data[key2] = result[key2]
			end
		end
	elseif not ok then
		warn("[NeonVault] 데이터 불러오기 실패(새 데이터로 시작): " .. tostring(player.Name))
	end
	return data
end

-- ==============================================================
-- 5. Game Pass / Developer Product
-- ==============================================================
local grantedReceipts = {}

local function checkPasses(player)
	if CONFIG.GAMEPASS_2X_CASH ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.GAMEPASS_2X_CASH)
		end)
		player:SetAttribute("Has2xCash", (ok and owns == true))
	end
	if CONFIG.GAMEPASS_INSTANT_LOCK ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.GAMEPASS_INSTANT_LOCK)
		end)
		player:SetAttribute("HasInstantLock", (ok and owns == true))
	end
	if CONFIG.GAMEPASS_DRONE_PACK ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.GAMEPASS_DRONE_PACK)
		end)
		player:SetAttribute("HasDronePack", (ok and owns == true))
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if wasPurchased then
		task.spawn(checkPasses, player)
		notify(player, "✅ 게임 패스가 적용되었습니다!")
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if grantedReceipts[receiptInfo.PurchaseId] == true then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local amount = PRODUCT_CASH_AMOUNT[receiptInfo.ProductId]
	if amount == nil then
		warn("[NeonVault] 알 수 없는 Developer Product ID: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = pcall(function()
		local cash = player:GetAttribute("Cash") or 0
		player:SetAttribute("Cash", cash + amount)
		local earned = player:GetAttribute("TotalEarned") or 0
		player:SetAttribute("TotalEarned", earned + amount)
	end)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantedReceipts[receiptInfo.PurchaseId] = true
	notify(player, "💵 $" .. tostring(amount) .. " 충전 완료!")
	savePlayer(player, "receipt")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ==============================================================
-- 6. 플레이어 입장 처리
-- ==============================================================
local function onPlayerAdded(player)
	local cashValue, stealsValue = setupLeaderstats(player)

	-- 기본값을 먼저 넣어 HUD 가 바로 뜨게 합니다.
	for key, default in pairs(DEFAULT_DATA) do
		if player:GetAttribute(key) == nil then
			player:SetAttribute(key, default)
		end
	end
	player:SetAttribute("DataLoaded", false)
	player:SetAttribute("Pending", 0)
	player:SetAttribute("ShieldOn", true)
	player:SetAttribute("ShieldEnds", 0)
	player:SetAttribute("IncomePerSec", 0)
	player:SetAttribute("VaultIndex", 0)
	player:SetAttribute("HackReadyAt", 0)
	player:SetAttribute("Carrying", "")
	player:SetAttribute("Has2xCash", false)
	player:SetAttribute("HasInstantLock", false)
	player:SetAttribute("HasDronePack", false)

	local data = loadPlayer(player)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Steals", data.Steals)
	player:SetAttribute("TotalEarned", data.TotalEarned)
	player:SetAttribute("Collection", data.Collection)
	player:SetAttribute("DroneBest", data.DroneBest)
	player:SetAttribute("DroneCount", data.DroneCount)
	player:SetAttribute("DataLoaded", true)

	pushToLeaderstats(player)

	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local stats = player:FindFirstChild("leaderstats")
		if stats ~= nil then
			local cash = stats:FindFirstChild("Cash")
			if cash ~= nil then
				cash.Value = math.floor(player:GetAttribute("Cash") or 0)
			end
		end
	end)
	player:GetAttributeChangedSignal("Steals"):Connect(function()
		local stats = player:FindFirstChild("leaderstats")
		if stats ~= nil then
			local steals = stats:FindFirstChild("Steals")
			if steals ~= nil then
				steals.Value = math.floor(player:GetAttribute("Steals") or 0)
			end
		end
	end)

	task.spawn(checkPasses, player)
	task.delay(1, function()
		if player.Parent ~= nil then
			notify(player, "🛸 네온 볼트 약탈자에 오신 것을 환영합니다! 중앙 타워에서 뽑기하세요.")
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player, "leave")
end)

-- ==============================================================
-- 7. 자동 저장 / 종료 저장
-- ==============================================================
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(savePlayer, player, "autosave")
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player, "shutdown")
	end
	task.wait(2)
end)

print("[NeonVault] 데이터/수익화 스크립트 준비 완료 (Game Pass ID를 CONFIG에 입력하세요)")
