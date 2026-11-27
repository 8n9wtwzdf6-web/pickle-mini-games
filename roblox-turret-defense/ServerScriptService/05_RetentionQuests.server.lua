--[[ ============================================================
  05_RetentionQuests.server.lua
  🍀 운빨·조합 터렛 디펜스 — 리텐션 서버
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService (일반 Script)
  준비물 : ReplicatedStorage "TDShared", ServerScriptService "TDData"
  ------------------------------------------------------------
  이 파일이 하는 일
    · 7일 출석(Daily Streak) — 하루 1회, 7일 완주 보상
    · 체류 시간 보상 — 5/10/15/30/60분 버튼
    · 일일 퀘스트 3개 — 적 처치·웨이브·합성·보스·뽑기·부활
    · 영구 강화 상점 (보석 사용)
    · 로블록스 프리미엄 보너스 안내 (+15%)
  ============================================================ ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local Data = require(script.Parent:WaitForChild("TDData"))
local bus = Shared.bus()
local remotes = Shared.remotes()

local RD_Meta = remotes.TD_Meta
local RD_State = remotes.TD_State
local RD_Action = remotes.TD_MetaAction

local session = {}   -- [player] = { joinedAt, playSeconds, lastSeen = {}, lastSync = 0 }

local METRICS = { "kills", "wave", "merges", "draws", "bossKills", "revives" }

-- ---------------------------------------------------------------
-- 도우미
-- ---------------------------------------------------------------
local function dayKey(offset)
	return Data.dayKey(offset)
end

local function hash(text)
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 2147483647
	end
	return h
end

local function toast(player, title, sub)
	if RD_State then
		RD_State:FireClient(player, { event = "toast", title = title, sub = sub })
	end
end

local function addGems(player, amount)
	local profile = Data.get(player)
	if not profile then return 0 end
	profile.gems = math.max(0, (profile.gems or 0) + amount)
	Data.markDirty(player)
	player:SetAttribute("Gems", profile.gems)
	return profile.gems
end

-- ---------------------------------------------------------------
-- 일일 퀘스트 생성 (날짜 기반 고정 → 모든 서버가 같은 퀘스트)
-- ---------------------------------------------------------------
local function buildQuests(day)
	local pool = {}
	for i, q in ipairs(Shared.QUESTS) do
		table.insert(pool, i)
	end
	local picked = {}
	local seed = hash(day)
	for n = 1, math.min(Shared.QUEST_COUNT, #pool) do
		seed = (seed * 1103515245 + 12345) % 2147483647
		local idx = (seed % #pool) + 1
		table.insert(picked, pool[idx])
		table.remove(pool, idx)
	end
	local list = {}
	for _, qi in ipairs(picked) do
		local def = Shared.QUESTS[qi]
		list[def.key] = { progress = 0, goal = def.goal, claimed = false }
	end
	return list
end

local function ensureDaily(profile)
	local today = dayKey(0)
	if profile.daily.day ~= today then
		local yesterday = dayKey(-1)
		if profile.daily.day == yesterday and profile.daily.claimed then
			profile.daily.streak = math.min(999, (profile.daily.streak or 0) + 1)
		elseif profile.daily.day ~= yesterday then
			profile.daily.streak = 1
		end
		if (profile.daily.streak or 0) <= 0 then profile.daily.streak = 1 end
		profile.daily.day = today
		profile.daily.index = ((profile.daily.streak or 1) - 1) % #Shared.DAILY
		profile.daily.claimed = false
	end
	if profile.quests.day ~= today then
		profile.quests.day = today
		profile.quests.list = buildQuests(today)
	end
	if profile.playtime.day ~= today then
		profile.playtime.day = today
		profile.playtime.claimed = {}
	end
end

-- ---------------------------------------------------------------
-- 클라이언트로 혜택 현황 송신
-- ---------------------------------------------------------------
local function upgradeLevels(profile)
	local out = {}
	for _, def in ipairs(Shared.UPGRADES) do
		out[def.key] = (profile.upgrades and profile.upgrades[def.key]) or 0
	end
	return out
end

local function sendMeta(player)
	local profile = Data.get(player)
	if not profile or not RD_Meta or not player.Parent then return end
	local today = dayKey(0)
	local daily = profile.daily
	local play = session[player]

	local quests = {}
	for i, def in ipairs(Shared.QUESTS) do
		local entry = profile.quests.list and profile.quests.list[def.key]
		if entry then
			table.insert(quests, {
				key = def.key,
				text = def.text,
				goal = entry.goal or def.goal,
				progress = math.min(entry.goal or def.goal, entry.progress or 0),
				gems = def.gems,
				claimed = entry.claimed == true,
			})
		end
	end

	local playtime = {}
	local claimedSet = {}
	if profile.playtime.day == today then
		claimedSet = profile.playtime.claimed or {}
	end
	for i, def in ipairs(Shared.PLAYTIME) do
		table.insert(playtime, {
			index = i,
			at = def.at,
			label = def.label,
			minerals = def.minerals or 0,
			gems = def.gems or 0,
			revive = def.revive or 0,
			claimed = claimedSet[tostring(i)] == true,
		})
	end

	RD_Meta:FireClient(player, {
		event = "meta",
		gems = profile.gems or 0,
		bestWave = profile.bestWave or 0,
		runs = profile.runs or 0,
		premium = player:GetAttribute("IsPremium") == true,
		claimedToday = daily.claimed == true,
		daily = {
			day = daily.day,
			streak = daily.streak or 0,
			index = daily.index or 0,
			today = today,
			rewards = Shared.DAILY,
		},
		playtime = {
			seconds = play and play.playSeconds or 0,
			list = playtime,
		},
		quests = quests,
		upgrades = upgradeLevels(profile),
	})
end

-- ---------------------------------------------------------------
-- 보상 지급 (게임 서버에 미네랄/부활 요청)
-- ---------------------------------------------------------------
local function grantInGame(player, minerals, revive, boostDmg)
	if not bus then return false end
	local ok, res = pcall(function()
		return bus.Call:Invoke(player, "reward", { minerals = minerals or 0, revive = revive or 0, boostDmg = boostDmg })
	end)
	return ok and res == true
end

-- ---------------------------------------------------------------
-- 참가
-- ---------------------------------------------------------------
local function onJoin(player)
	local profile = Data.waitFor(player, 20)
	if not profile then return end
	ensureDaily(profile)
	player:SetAttribute("Gems", profile.gems or 0)
	player:SetAttribute("BestWave", profile.bestWave or 0)
	player:SetAttribute("ReviveStock", profile.reviveStock or 0)
	player:SetAttribute("IsPremium", player.MembershipType == Enum.MembershipType.Premium)

	local seen = {}
	for _, m in ipairs(METRICS) do
		seen[m] = player:GetAttribute("M_" .. m) or 0
	end
	session[player] = {
		joinedAt = os.clock(),
		playSeconds = 0,
		lastSeen = seen,
		lastSync = os.clock(),
	}
	Data.markDirty(player)

	task.delay(1.5, function()
		if player.Parent then sendMeta(player) end
	end)

	if player:GetAttribute("IsPremium") then
		task.delay(3, function()
			if player.Parent then
				toast(player, "✨ 로블록스 프리미엄", "미네랄·보석 보상 +15% 자동 적용")
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function() onJoin(player) end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function() onJoin(p) end)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = Data.get(player)
	local s = session[player]
	if profile and s then
		profile.playSeconds = (profile.playSeconds or 0) + math.floor(s.playSeconds)
		Data.markDirty(player)
	end
	session[player] = nil
end)

-- ---------------------------------------------------------------
-- 퀘스트 진행 동기화 (1초) — 02 가 넣은 M_* 속성을 읽어 증가분만 반영
-- ---------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = Data.get(player)
			local s = session[player]
			if profile and s then
				-- 체류 시간
				s.playSeconds = s.playSeconds + 1

				-- 퀘스트 진행
				local changed = false
				for _, metric in ipairs(METRICS) do
					local cur = player:GetAttribute("M_" .. metric) or 0
					local last = s.lastSeen[metric] or 0
					local delta = cur - last
					if delta < 0 then delta = cur end   -- 새 판이 시작됨
					s.lastSeen[metric] = cur
					if delta > 0 then
						for i, def in ipairs(Shared.QUESTS) do
							if def.metric == metric then
								local entry = profile.quests.list and profile.quests.list[def.key]
								if entry and not entry.claimed and (entry.progress or 0) < (entry.goal or def.goal) then
									entry.progress = math.min(entry.goal or def.goal, (entry.progress or 0) + delta)
									changed = true
								end
							end
						end
					end
				end

				-- 60초마다 저장 + UI 갱신
				if os.clock() - s.lastSync > 60 then
					s.lastSync = os.clock()
					if changed then Data.markDirty(player) end
					Data.save(player, false)
					sendMeta(player)
				end
			end
		end
	end
end)

-- ---------------------------------------------------------------
-- 혜택 요청 처리
-- ---------------------------------------------------------------
local function claimDaily(player)
	local profile = Data.get(player)
	if not profile then return end
	ensureDaily(profile)
	if profile.daily.claimed then
		toast(player, "오늘 출석 완료", "내일 또 만나요!")
		return
	end
	local idx = math.clamp((profile.daily.index or 0) + 1, 1, #Shared.DAILY)
	local reward = Shared.DAILY[idx]
	profile.daily.claimed = true
	if reward.gems then addGems(player, reward.gems) end
	if reward.minerals then grantInGame(player, reward.minerals, 0) end
	if reward.revive then
		-- 게임 서버가 지급(속성+저장)을 맡고, 실패했을 때만 여기서 직접 지급
		if not grantInGame(player, 0, reward.revive) then
			Data.addRevive(player, reward.revive)
			player:SetAttribute("ReviveStock", math.min(3, (player:GetAttribute("ReviveStock") or 0) + reward.revive))
		end
	end
	Data.markDirty(player)
	Data.save(player, true)
	toast(player, "📅 출석 " .. (profile.daily.streak or 1) .. "일차", reward.label)
	sendMeta(player)
end

local function claimPlaytime(player, index)
	local profile = Data.get(player)
	local s = session[player]
	if not profile or not s then return end
	local def = Shared.PLAYTIME[index]
	if not def then return end
	ensureDaily(profile)
	if profile.playtime.day ~= dayKey(0) then
		profile.playtime.day = dayKey(0)
		profile.playtime.claimed = {}
	end
	profile.playtime.claimed = profile.playtime.claimed or {}
	if profile.playtime.claimed[tostring(index)] then
		toast(player, "이미 받았습니다", def.label .. " 보상")
		return
	end
	if s.playSeconds < def.at then
		local left = math.ceil((def.at - s.playSeconds) / 60)
		toast(player, "아직 이릅니다", left .. "분 더 플레이하면 받을 수 있어요")
		return
	end
	profile.playtime.claimed[tostring(index)] = true
	if def.gems then addGems(player, def.gems) end
	if def.minerals then grantInGame(player, def.minerals, 0) end
	if def.revive then
		if not grantInGame(player, 0, def.revive) then
			Data.addRevive(player, def.revive)
			player:SetAttribute("ReviveStock", math.min(3, (player:GetAttribute("ReviveStock") or 0) + def.revive))
		end
	end
	Data.markDirty(player)
	Data.save(player, true)
	toast(player, "⏱ 체류 보상 " .. def.label, "획득 완료!")
	sendMeta(player)
end

local function claimQuest(player, key)
	local profile = Data.get(player)
	if not profile then return end
	ensureDaily(profile)
	local entry = profile.quests.list and profile.quests.list[key]
	if not entry then return end
	if entry.claimed then
		toast(player, "이미 완료한 퀘스트", "")
		return
	end
	local def
	for _, q in ipairs(Shared.QUESTS) do
		if q.key == key then def = q end
	end
	if not def then return end
	if (entry.progress or 0) < (entry.goal or def.goal) then
		toast(player, "아직 미완료", (entry.progress or 0) .. " / " .. (entry.goal or def.goal))
		return
	end
	entry.claimed = true
	addGems(player, def.gems)
	Data.markDirty(player)
	Data.save(player, true)
	toast(player, "✅ 퀘스트 완료", def.text .. " · 보석 +" .. def.gems)
	sendMeta(player)
end

local function buyUpgrade(player, key)
	local profile = Data.get(player)
	if not profile then return end
	local def
	for _, u in ipairs(Shared.UPGRADES) do
		if u.key == key then def = u end
	end
	if not def then return end
	profile.upgrades = profile.upgrades or {}
	local level = profile.upgrades[key] or 0
	if level >= def.max then
		toast(player, "최대 레벨", def.name .. " Lv." .. def.max)
		return
	end
	local cost = Shared.upgradeCost(def, level)
	if (profile.gems or 0) < cost then
		toast(player, "보석이 부족합니다", "필요 💠 " .. Shared.comma(cost) .. " (보유 " .. Shared.comma(profile.gems or 0) .. ")")
		return
	end
	profile.gems = profile.gems - cost
	profile.upgrades[key] = level + 1
	Data.markDirty(player)
	Data.save(player, true)
	player:SetAttribute("Gems", profile.gems)
	toast(player, "💠 " .. def.name .. " Lv." .. (level + 1), def.desc)
	-- 게임 서버에 영구 강화 갱신 요청
	if bus then
		pcall(function() bus.Call:Invoke(player, "refresh") end)
	end
	sendMeta(player)
end

RD_Action.OnServerEvent:Connect(function(player, action, arg)
	if action == "daily" then
		claimDaily(player)
	elseif action == "playtime" then
		claimPlaytime(player, tonumber(arg) or 0)
	elseif action == "quest" then
		claimQuest(player, arg)
	elseif action == "upgrade" then
		buyUpgrade(player, arg)
	elseif action == "refresh" then
		sendMeta(player)
	end
end)

print("[TD] 05_RetentionQuests 로드 — 출석 7일 · 체류 보상 5단계 · 일일 퀘스트 " .. Shared.QUEST_COUNT .. "개")
