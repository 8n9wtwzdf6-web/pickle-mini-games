--=============================================================================
-- 01_PlayerDataAndPasses.server.lua
-- 위치 : ServerScriptService
-- 타입 : Script  (서버 스크립트, LocalScript 아님)
-- 역할 : leaderstats(Cash, Launches) 생성 / DataStore 자동 저장·불러오기 /
--        Game Pass(2배 수익, 자동 수거) 보유 여부 확인
--
-- ※ 아래 CONFIG 표의 게임패스 ID 두 개만 바꾸면 됩니다.
--    (ID 0 = 아직 게임패스 미설정 → 해당 기능만 꺼진 상태로 정상 동작)
--=============================================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--=============================================================================
-- [1] 설정  --- 여기만 수정 ---
--=============================================================================
local CONFIG = {
	-- Roblox 웹 > Create > (내 체험) > Associated Items > Passes 에서 만든 ID
	DOUBLE_CASH_PASS_ID = 0,   -- 예: 1234567890  (2배 수익)
	AUTO_COLLECT_PASS_ID = 0,  -- 예: 1234567890  (자동 수거)

	START_CASH = 100,          -- 신규 플레이어 시작 금액
	START_LAUNCHES = 0,        -- 신규 플레이어 시작 발사 횟수
	AUTOSAVE_SECONDS = 60,     -- 자동 저장 주기(초)
	DATASTORE_NAME = "RocketTycoon_Save_v1",  -- 저장소 이름(바꾸면 기존 데이터와 분리됨)
	LOG_ENABLED = true,        -- Studio 테스트 중 로그 보기
}

local function log(...)
	if CONFIG.LOG_ENABLED then
		print("[RocketTycoon:Data]", ...)
	end
end

--=============================================================================
-- [2] 다른 스크립트와 공유하는 객체 만들기
--      - ReplicatedStorage.RocketTycoonConfig : 게임패스 ID / 시작 금액 속성
--      - ReplicatedStorage.RocketTycoonNotify : 서버 → 화면 알림용 RemoteEvent
--=============================================================================
local configFolder = ReplicatedStorage:FindFirstChild("RocketTycoonConfig")
if configFolder == nil then
	configFolder = Instance.new("Folder")
	configFolder.Name = "RocketTycoonConfig"
	configFolder.Parent = ReplicatedStorage
end
configFolder:SetAttribute("DoubleCashPassId", CONFIG.DOUBLE_CASH_PASS_ID)
configFolder:SetAttribute("AutoCollectPassId", CONFIG.AUTO_COLLECT_PASS_ID)
configFolder:SetAttribute("StartCash", CONFIG.START_CASH)

local notifyEvent = ReplicatedStorage:FindFirstChild("RocketTycoonNotify")
if notifyEvent == nil then
	notifyEvent = Instance.new("RemoteEvent")
	notifyEvent.Name = "RocketTycoonNotify"
	notifyEvent.Parent = ReplicatedStorage
end

--=============================================================================
-- [3] DataStore 준비
--=============================================================================
local dataStore = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
	end)
	if ok then
		dataStore = result
	else
		warn("[RocketTycoon:Data] DataStore를 열 수 없습니다. 저장 기능 없이 실행합니다: " .. tostring(result))
	end
end

--=============================================================================
-- [4] 데이터 불러오기 / 저장하기 (재시도 포함, 실패해도 게임은 계속 진행)
--=============================================================================
local function keyFor(player)
	return "Player_" .. tostring(player.UserId)
end

local function loadData(player)
	if dataStore == nil then
		return nil
	end
	local key = keyFor(player)
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if ok then
			return result
		end
		warn(string.format("[RocketTycoon:Data] 불러오기 실패 %d/3 (%s): %s", attempt, player.Name, tostring(result)))
		task.wait(attempt)
	end
	return nil
end

local function saveData(player, cash, launches)
	if dataStore == nil then
		return false
	end
	local key = keyFor(player)
	local payload = {
		Cash = math.max(0, math.floor(cash)),
		Launches = math.max(0, math.floor(launches)),
		UpdatedAt = os.time(),
	}
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key, function()
				return payload
			end)
		end)
		if ok then
			return true
		end
		warn(string.format("[RocketTycoon:Data] 저장 실패 %d/3 (%s): %s", attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
	return false
end

--=============================================================================
-- [5] leaderstats 생성 (02, 03 스크립트가 이 값을 그대로 읽고 씁니다)
--=============================================================================
local function setupLeaderstats(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = CONFIG.START_CASH
	cash.Parent = folder

	local launches = Instance.new("NumberValue")
	launches.Name = "Launches"
	launches.Value = CONFIG.START_LAUNCHES
	launches.Parent = folder

	folder.Parent = player

	-- 음수 금액 방지(다른 스크립트가 잘못 계산해도 안전하게)
	cash:GetPropertyChangedSignal("Value"):Connect(function()
		if cash.Value < 0 then
			cash.Value = 0
		end
	end)
	launches:GetPropertyChangedSignal("Value"):Connect(function()
		if launches.Value < 0 then
			launches.Value = 0
		end
	end)

	return cash, launches
end

--=============================================================================
-- [6] 게임패스 확인 → 플레이어 속성으로 알려주기
--      HasDoubleCash / HasAutoCollect  (02, 03 스크립트가 이 속성을 읽음)
--=============================================================================
local function ownsPass(player, passId)
	if passId == nil or passId <= 0 then
		return false
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then
		return result == true
	end
	warn("[RocketTycoon:Data] 게임패스 확인 실패 (" .. player.Name .. "): " .. tostring(result))
	return false
end

local function refreshPasses(player)
	if player.Parent == nil then
		return
	end
	local hasDouble = ownsPass(player, CONFIG.DOUBLE_CASH_PASS_ID)
	local hasAuto = ownsPass(player, CONFIG.AUTO_COLLECT_PASS_ID)
	player:SetAttribute("HasDoubleCash", hasDouble)
	player:SetAttribute("HasAutoCollect", hasAuto)
	log(string.format("%s 게임패스 - 2배:%s 자동수거:%s", player.Name, tostring(hasDouble), tostring(hasAuto)))
end

--=============================================================================
-- [7] 플레이어 입장 처리
--=============================================================================
local function onPlayerAdded(player)
	local cash, launches = setupLeaderstats(player)

	local saved = loadData(player)
	if type(saved) == "table" then
		local savedCash = tonumber(saved.Cash)
		local savedLaunches = tonumber(saved.Launches)
		if savedCash ~= nil then
			cash.Value = math.max(0, math.floor(savedCash))
		end
		if savedLaunches ~= nil then
			launches.Value = math.max(0, math.floor(savedLaunches))
		end
		log(player.Name .. " 저장 데이터 불러옴 (Cash " .. tostring(cash.Value) .. ")")
	else
		log(player.Name .. " 신규 플레이어 (기본값으로 시작)")
	end

	-- 화면(HUD)이 시작 금액을 표시하기 전에 데이터 로드가 끝났음을 알림
	player:SetAttribute("DataLoaded", true)

	-- 게임패스 확인은 네트워크를 기다리므로 별도 스레드에서 (게임 진행을 막지 않음)
	task.spawn(function()
		refreshPasses(player)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

--=============================================================================
-- [8] 저장: 나갈 때 / 구매 완료 시 / 주기적 / 서버 종료 시
--=============================================================================
local function saveOne(player)
	if player.Parent == nil then
		return
	end
	local folder = player:FindFirstChild("leaderstats")
	if folder == nil then
		return
	end
	local cash = folder:FindFirstChild("Cash")
	local launches = folder:FindFirstChild("Launches")
	if cash == nil or launches == nil then
		return
	end
	local ok = saveData(player, cash.Value, launches.Value)
	if ok then
		log(player.Name .. " 저장 완료 (Cash " .. tostring(cash.Value) .. ")")
	end
end

Players.PlayerRemoving:Connect(function(player)
	-- 나가기 직후에도 값은 남아 있으므로 객체를 먼저 잡아 둔다
	local folder = player:FindFirstChild("leaderstats")
	local cash = folder and folder:FindFirstChild("Cash")
	local launches = folder and folder:FindFirstChild("Launches")
	if cash == nil or launches == nil then
		return
	end
	-- 02 스크립트가 수거함에 남은 금액을 정산할 시간을 조금 준다
	task.wait(0.25)
	local ok, values = pcall(function()
		return { Cash = cash.Value, Launches = launches.Value }
	end)
	if ok then
		saveData(player, values.Cash, values.Launches)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if wasPurchased then
		task.spawn(function()
			refreshPasses(player)
			if notifyEvent ~= nil and player.Parent ~= nil then
				notifyEvent:FireClient(player, { kind = "toast", text = "게임패스 구매 완료! 효과가 바로 적용됩니다." })
			end
		end)
	end
end)

task.spawn(function()
	while true do
		task.wait(CONFIG.AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveOne, player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(saveOne, player)
	end
	-- 살짝 기다려 저장 요청이 나갈 시간을 준다 (최대 3초)
	task.wait(3)
end)

log("준비 완료. 2배 수익 패스 ID=" .. tostring(CONFIG.DOUBLE_CASH_PASS_ID) .. " / 자동 수거 패스 ID=" .. tostring(CONFIG.AUTO_COLLECT_PASS_ID))
if CONFIG.DOUBLE_CASH_PASS_ID <= 0 or CONFIG.AUTO_COLLECT_PASS_ID <= 0 then
	log("게임패스 ID가 0입니다 → 해당 기능은 꺼진 상태로 동작합니다. (README 5장 참고)")
end
