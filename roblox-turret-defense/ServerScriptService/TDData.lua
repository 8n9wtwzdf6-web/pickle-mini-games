--[[ ============================================================
  TDData  (ModuleScript)
  붙여넣는 곳 : ServerScriptService  →  ModuleScript, 이름을 정확히 "TDData"
  ------------------------------------------------------------
  플레이어 저장 데이터(DataStore) 한 곳.
     · 보석 · 최고 웨이브 · 누적 킬 · 출석 · 일일 퀘스트 · 체류 보상
     · 구매한 패스/스타터팩 · 영구 강화 · 보관 부활권 · 천장 카운터
     · 영수증(PurchaseId) 장부 → ProcessReceipt 중복 지급 방지
  안전장치
     · 모든 호출 pcall + 3회 재시도
     · BindToClose 에서 전원 저장 (서버 종료 시 유실 방지)
     · 90초 자동 저장 (변경이 있을 때만)
  ============================================================ ]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PROFILE_STORE = DataStoreService:GetDataStore("TD_Profile_v2")
local RECEIPT_STORE = DataStoreService:GetDataStore("TD_Receipt_v2")
local KEY_PREFIX = "p_"

local Data = {}
Data.loaded = {}      -- [player] = profile
Data.loading = {}     -- [player] = true
Data.dirty = {}       -- [player] = true
Data.lastSave = {}    -- [player] = os.clock()
Data.receipts = {}    -- [player] = { [purchaseId] = true } (메모리 캐시)
Data.failed = {}      -- [player] = true (저장 실패한 프로필)

local SAVE_INTERVAL = 90      -- 초
local SAVE_MIN_GAP = 8        -- 초 (한 플레이어 저장 최소 간격)
local RECEIPT_KEEP = 80       -- 프로필에 남길 최근 영수증 수

-- ---------------------------------------------------------------
-- 날짜 키 (한국 시간 자정 기준)
-- ---------------------------------------------------------------
function Data.dayKey(offsetDays)
	local t = os.time() + (offsetDays or 0) * 86400
	local kst = t + 9 * 3600
	return os.date("!%Y-%m-%d", kst)
end

-- ---------------------------------------------------------------
-- 기본 프로필
-- ---------------------------------------------------------------
local function defaultProfile()
	return {
		v = 2,
		gems = 0,
		bestWave = 0,
		totalWaves = 0,
		totalKills = 0,
		runs = 0,
		wins = 0,
		playSeconds = 0,
		starterPurchased = false,
		passes = {},
		upgrades = { startMinerals = 0, startGas = 0, permAtk = 0 },
		daily = { day = "", streak = 0, index = 0, claimed = false },
		quests = { day = "", list = {} },
		playtime = { day = "", claimed = {} },
		reviveStock = 0,
		pity = 0,
		receipts = {},
	}
end

-- 저장된 값에 빠진 칸이 있어도 안전하게 채웁니다
local function migrate(raw)
	local p = defaultProfile()
	if type(raw) == "table" then
		for k, v in pairs(raw) do
			if type(v) == "table" and type(p[k]) == "table" then
				for k2, v2 in pairs(v) do p[k][k2] = v2 end
			else
				p[k] = v
			end
		end
	end
	if type(p.upgrades) ~= "table" then p.upgrades = { startMinerals = 0, startGas = 0, permAtk = 0 } end
	if type(p.daily) ~= "table" then p.daily = { day = "", streak = 0, index = 0, claimed = false } end
	if type(p.quests) ~= "table" then p.quests = { day = "", list = {} } end
	if type(p.playtime) ~= "table" then p.playtime = { day = "", claimed = {} } end
	if type(p.receipts) ~= "table" then p.receipts = {} end
	if type(p.passes) ~= "table" then p.passes = {} end
	return p
end

local function retry(fn, attempts)
	local lastErr
	for i = 1, (attempts or 3) do
		local ok, res = pcall(fn)
		if ok then return true, res end
		lastErr = res
		task.wait(1.2 * i)
	end
	return false, lastErr
end

-- ---------------------------------------------------------------
-- 로드 / 저장
-- ---------------------------------------------------------------
function Data.load(player)
	if Data.loaded[player] then return Data.loaded[player] end
	if Data.loading[player] then
		local t0 = os.clock()
		while Data.loading[player] and os.clock() - t0 < 20 do
			task.wait(0.1)
		end
		return Data.loaded[player]
	end
	Data.loading[player] = true

	local key = KEY_PREFIX .. tostring(player.UserId)
	local ok, raw = retry(function() return PROFILE_STORE:GetAsync(key) end, 3)
	local profile
	if ok and type(raw) == "table" then
		profile = migrate(raw)
		profile.loadedExisting = true
	else
		profile = defaultProfile()
		profile.loadedExisting = false
		if not ok then
			warn("[TD][Data] " .. player.Name .. " 프로필 로드 실패 — 임시 세션으로 진행: " .. tostring(raw))
			Data.failed[player] = true
		end
	end

	-- 영수증 장부(별도 키 · 최근 구매 기록)
	local rok, rlist = retry(function() return RECEIPT_STORE:GetAsync(key) end, 2)
	if rok and type(rlist) == "table" then
		Data.receipts[player] = {}
		for _, id in ipairs(rlist) do
			Data.receipts[player][tostring(id)] = true
		end
	else
		Data.receipts[player] = {}
	end
	-- 프로필에 남은 최근 영수증도 합칩니다
	for _, id in ipairs(profile.receipts or {}) do
		Data.receipts[player][tostring(id)] = true
	end

	Data.loaded[player] = profile
	Data.loading[player] = nil
	return profile
end

function Data.get(player)
	return Data.loaded[player]
end

function Data.waitFor(player, timeout)
	-- 아직 로드를 시작하지 않았다면 여기서 시작합니다
	if not Data.loaded[player] and not Data.loading[player] then
		task.spawn(function()
			Data.load(player)
		end)
	end
	local t0 = os.clock()
	while not Data.loaded[player] and os.clock() - t0 < (timeout or 15) do
		task.wait(0.1)
	end
	return Data.loaded[player]
end

function Data.save(player, force)
	local profile = Data.loaded[player]
	if not profile then return false end
	local now = os.clock()
	if not force and (now - (Data.lastSave[player] or 0)) < SAVE_MIN_GAP then
		Data.dirty[player] = true
		return true
	end
	local ok = retry(function()
		PROFILE_STORE:SetAsync(KEY_PREFIX .. tostring(player.UserId), profile)
	end, 3)
	Data.lastSave[player] = os.clock()
	if ok then
		Data.dirty[player] = nil
		Data.failed[player] = nil
	else
		Data.dirty[player] = true
		Data.failed[player] = true
		warn("[TD][Data] " .. player.Name .. " 저장 실패(다음 주기에 재시도)")
	end
	return ok
end

function Data.release(player)
	Data.save(player, true)
	Data.loaded[player] = nil
	Data.loading[player] = nil
	Data.dirty[player] = nil
	Data.lastSave[player] = nil
	Data.receipts[player] = nil
	Data.failed[player] = nil
end

function Data.markDirty(player)
	Data.dirty[player] = true
end

-- ---------------------------------------------------------------
-- 영수증 (중복 지급 방지)
-- ---------------------------------------------------------------
function Data.hasReceipt(player, purchaseId)
	local set = Data.receipts[player]
	if not set then return false end
	return set[tostring(purchaseId)] == true
end

function Data.markReceipt(player, purchaseId)
	local id = tostring(purchaseId)
	Data.receipts[player] = Data.receipts[player] or {}
	Data.receipts[player][id] = true
	local profile = Data.loaded[player]
	if profile then
		table.insert(profile.receipts, id)
		while #profile.receipts > RECEIPT_KEEP do
			table.remove(profile.receipts, 1)
		end
	end
	-- 장부는 즉시 별도 키에 기록 (지급 결정 전에 남깁니다)
	local list = {}
	for k in pairs(Data.receipts[player]) do
		table.insert(list, k)
	end
	local ok = retry(function()
		RECEIPT_STORE:SetAsync(KEY_PREFIX .. tostring(player.UserId), list)
	end, 2)
	if profile then Data.markDirty(player) end
	return ok
end

-- ---------------------------------------------------------------
-- 자주 쓰는 조작
-- ---------------------------------------------------------------
function Data.addGems(player, amount)
	local profile = Data.loaded[player]
	if not profile or not amount then return 0 end
	profile.gems = math.max(0, (profile.gems or 0) + amount)
	Data.markDirty(player)
	return profile.gems
end

function Data.addRevive(player, amount)
	local profile = Data.loaded[player]
	if not profile then return 0 end
	profile.reviveStock = math.max(0, math.min(3, (profile.reviveStock or 0) + (amount or 1)))
	Data.markDirty(player)
	return profile.reviveStock
end

function Data.getPass(player, key)
	local profile = Data.loaded[player]
	if not profile then return false end
	return profile.passes and profile.passes[key] == true
end

function Data.setPass(player, key, owned)
	local profile = Data.loaded[player]
	if not profile then return end
	profile.passes = profile.passes or {}
	if owned then
		profile.passes[key] = true
	else
		profile.passes[key] = nil
	end
	Data.markDirty(player)
end

-- ---------------------------------------------------------------
-- 자동 저장 + 종료 저장
-- ---------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			if Data.loaded[player] and Data.dirty[player] then
				Data.save(player)
			end
		end
	end
end)

game:BindToClose(function()
	local pending = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if Data.loaded[player] then
			table.insert(pending, task.spawn(function()
				Data.save(player, true)
			end))
		end
	end
	local t0 = os.clock()
	while os.clock() - t0 < 25 do
		local working = false
		for _, thread in ipairs(pending) do
			if coroutine.status(thread) ~= "dead" then working = true end
		end
		if not working then break end
		task.wait(0.2)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Data.release(player)
end)

-- 들어오는 즉시 비동기 로드 (다른 스크립트는 Data.waitFor 로 기다립니다)
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		Data.load(player)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		Data.load(player)
	end)
end

if RunService:IsStudio() then
	print("[TD][Data] 스튜디오 감지 — Studio에서는 DataStore가 'API Services' 꺼짐이면 저장이 생략됩니다.")
end

print("[TD] TDData 준비 — DataStore(" .. (RunService:IsStudio() and "Studio" or "Live") .. ") 프로필 v2")

return Data
