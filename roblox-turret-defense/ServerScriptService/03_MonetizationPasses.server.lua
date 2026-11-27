--[[ ============================================================
  03_MonetizationPasses.server.lua
  🍀 운빨·조합 터렛 디펜스 — 수익화 (게임패스 6종 · 개발자 상품 14종)
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService (일반 Script)
  준비물 : ReplicatedStorage 의 "TDShared" (ID는 그 파일의 Shared.IDS 한 곳)
  ------------------------------------------------------------
  이 파일이 하는 일
    1) 게임패스 소유 확인(UserOwnsGamePassAsync) → 플레이어 속성으로 게임에 알림
    2) 구매 창구(PromptPass / PromptProduct) — 클라이언트는 "키"만 보내고 ID는 서버가 압니다
    3) ProcessReceipt — 영수증 1건당 정확히 1번 지급 (중복 지급 방지 장부)
    4) 스타터팩 1회 제한 · 보석 팩 지급 · 팀 선물 상품
  ★ ProcessReceipt 는 서버 전체에서 이 파일 하나만 설정해야 합니다.
  ============================================================ ]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage:WaitForChild("TDShared"))
local Data = require(script.Parent:WaitForChild("TDData"))
local bus = Shared.bus()
local remotes = Shared.remotes()

local RD_State = remotes.TD_State
local RD_Prompt = remotes.TD_Prompt

local STARTER_GEMS = 300

local function toast(player, title, sub)
	if RD_State then
		RD_State:FireClient(player, { event = "toast", title = title, sub = sub })
	end
end

local function banner(player, title, sub)
	if RD_State then
		RD_State:FireClient(player, { event = "banner", title = title, sub = sub })
	end
end

-- ---------------------------------------------------------------
-- 1. 게임패스 소유 확인
-- ---------------------------------------------------------------
local function ownsPass(player, passId)
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then return owns == true end
	warn("[TD][Shop] 패스 확인 실패(" .. tostring(passId) .. "): " .. tostring(owns))
	return nil
end

local function refreshPasses(player)
	if not player.Parent then return end
	local profile = Data.waitFor(player, 15)
	for _, pass in ipairs(Shared.PASSES) do
		if pass.id and pass.id > 0 then
			local owns = ownsPass(player, pass.id)
			if owns ~= nil then
				player:SetAttribute(pass.attr, owns)
				if profile then Data.setPass(player, pass.key, owns) end
				if owns and pass.key == "PASS_VIP" then
					-- VIP 는 이름 앞 태그로도 표시 (HUD 가 읽습니다)
					player:SetAttribute("VipTag", true)
				end
			end
		end
	end
	if profile then Data.save(player, false) end
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("OfferEnds", os.time() + 300)  -- 스타터팩 5분 한정 표시용
	task.delay(2, function()
		refreshPasses(player)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		refreshPasses(player)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	for _, pass in ipairs(Shared.PASSES) do
		if pass.id == passId and pass.id > 0 then
			player:SetAttribute(pass.attr, true)
			if pass.key == "PASS_VIP" then player:SetAttribute("VipTag", true) end
			Data.setPass(player, pass.key, true)
			Data.save(player, false)
			banner(player, "👑 " .. pass.name .. " 활성화", pass.desc)
			toast(player, "구매 완료", pass.name .. " 효과가 바로 적용됩니다")
			return
		end
	end
end)

-- ---------------------------------------------------------------
-- 2. 구매 창구 (클라이언트 → 서버)
-- ---------------------------------------------------------------
local function findPass(key)
	for _, pass in ipairs(Shared.PASSES) do
		if pass.key == key then return pass end
	end
	return nil
end

local function findProduct(key)
	for _, product in ipairs(Shared.PRODUCTS) do
		if product.key == key then return product end
	end
	return nil
end

local function promptPass(player, pass)
	if not pass then return end
	if (pass.id or 0) <= 0 then
		toast(player, "준비 중", "게임패스 ID가 아직 등록되지 않았습니다")
		return
	end
	if player:GetAttribute(pass.attr) then
		toast(player, "이미 보유 중", pass.name)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
end

local function promptProduct(player, product)
	if not product then return end
	if (product.id or 0) <= 0 then
		toast(player, "준비 중", "개발자 상품 ID가 아직 등록되지 않았습니다")
		return
	end
	local profile = Data.waitFor(player, 10)
	if product.oncePerPlayer and profile and profile.starterPurchased then
		toast(player, "이미 구매한 상품", "스타터팩은 1인 1회입니다")
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

RD_Prompt.OnServerEvent:Connect(function(player, action, key)
	if action == "pass" then
		promptPass(player, findPass(key))
	elseif action == "product" then
		promptProduct(player, findProduct(key))
	elseif action == "pass_info" then
		-- 상점 목록을 열 때 최신 보유 상태를 다시 확인 (부하 적음 · 3초에 1회)
		local last = player:GetAttribute("_passRefresh") or 0
		if os.clock() - last > 3 then
			player:SetAttribute("_passRefresh", os.clock())
			task.spawn(function() refreshPasses(player) end)
		end
	end
end)

-- ---------------------------------------------------------------
-- 3. 상품 지급
-- ---------------------------------------------------------------
local function grantByBus(player, action, payload)
	if not bus then return false end
	local ok, result = pcall(function()
		return bus.Call:Invoke(player, action, payload)
	end)
	if not ok then
		warn("[TD][Shop] Bus 호출 실패(" .. tostring(payload) .. "): " .. tostring(result))
		return false
	end
	return result == true
end

local function grantProduct(player, product)
	local profile = Data.waitFor(player, 10)
	if not profile then return false end

	-- ① 보석 팩은 저장 데이터에 직접 지급
	local gemAmount = Shared.GEM_PACKS[product.key]
	if gemAmount then
		Data.addGems(player, gemAmount)
		player:SetAttribute("Gems", profile.gems)
		Data.save(player, true)
		toast(player, "💠 보석 +" .. Shared.comma(gemAmount), "보유 " .. Shared.comma(profile.gems))
		if RD_State then
			RD_State:FireClient(player, { event = "metaDirty" })
		end
		return true
	end

	-- ② 스타터팩: 게임 안 지급(부스터/전설/미네랄)을 먼저 시도하고, 성공하면 보석 지급
	if product.key == "PRODUCT_STARTER" then
		if not grantByBus(player, "product", product.key) then return false end
		Data.addGems(player, STARTER_GEMS)
		player:SetAttribute("Gems", profile.gems)
		profile.starterPurchased = true
		Data.markDirty(player)
		Data.save(player, true)
		if RD_State then
			RD_State:FireClient(player, { event = "metaDirty" })
		end
		return true
	end

	-- ③ 나머지는 게임 서버(02)가 처리
	return grantByBus(player, "product", product.key)
end

-- ---------------------------------------------------------------
-- 4. 영수증 처리 (중복 지급 방지)
-- ---------------------------------------------------------------
local unknownLogged = {}

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- 아직 서버에 없으면 나중에 다시 시도 (로블록스가 재호출)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 이미 처리한 영수증이면 그대로 승인 (지급 X)
	if Data.hasReceipt(player, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = tostring(receiptInfo.ProductId)
	local product = Shared.PRODUCT_BY_ID[key]
	if not product then
		if not unknownLogged[key] then
			unknownLogged[key] = true
			warn("[TD][Shop] 등록되지 않은 상품 ID: " .. key .. " — TDShared.IDS 를 확인하세요")
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = Data.waitFor(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 스타터팩 1인 1회 (스토어에서 중복 구매된 경우: 소모 처리 + 안내)
	if product.oncePerPlayer and profile.starterPurchased then
		Data.markReceipt(player, receiptInfo.PurchaseId)
		toast(player, "이미 구매한 상품", "스타터팩은 1인 1회 · 고객센터에 문의해 주세요")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, granted = pcall(grantProduct, player, product)
	if not ok then
		warn("[TD][Shop] 지급 오류(" .. product.key .. "): " .. tostring(granted))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted ~= true then
		-- 게임 서버가 아직 준비되지 않음 → 나중에 재시도 (돈은 아직 소모되지 않음)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if product.oncePerPlayer then
		profile.starterPurchased = true
		Data.markDirty(player)
	end
	Data.markReceipt(player, receiptInfo.PurchaseId)
	Data.save(player, true)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("[TD] 03_MonetizationPasses 로드 — 패스 " .. #Shared.PASSES .. "종 · 상품 " .. #Shared.PRODUCTS .. "종 (ID 미입력 시 구매만 비활성)")
