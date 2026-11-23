--[[ ============================================================
  03_MonetizationPasses.server.lua
  🍀 운빨·조합 터렛 디펜스 — 수익화 (게임패스 3종 + 개발자 상품 3종)
  ------------------------------------------------------------
  붙여넣는 곳 : ServerScriptService (일반 Script)
  준비
    1) Roblox Studio → Home → Game Passes 에서 게임패스 3개를 만들고 ID를 아래에 붙입니다.
    2) 같은 화면의 Developer Products 에서 상품 3개를 만들고 ID를 붙입니다.
    3) ID를 안 채워도 게임은 정상 동작합니다(구매만 비활성).
  ============================================================ ]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ---------------------------------------------------------------
-- ★ 여기에 실제 ID를 넣으세요 ★
-- ---------------------------------------------------------------
local PASS_2X = 0        -- ⚡ 2배속 패스 (149 R$)
local PASS_AUTO = 0      -- 🧲 자동 합성 패스 (199 R$)
local PASS_VIP = 0       -- 👑 VIP 추가 슬롯 (399 R$)

local PRODUCT_MINERALS = 0   -- 💎 긴급 미네랄 팩 (49 R$)
local PRODUCT_LEGEND = 0     -- 🍀 전설 확정 뽑기권 (199 R$)
local PRODUCT_REVIVE = 0     -- 💖 부활권 (99 R$)

local PASS_INFO = {
	{ id = PASS_2X, attr = "Pass2x", name = "2배속 패스" },
	{ id = PASS_AUTO, attr = "PassAuto", name = "자동 합성 패스" },
	{ id = PASS_VIP, attr = "PassVip", name = "VIP 추가 슬롯" },
}

local remoteFolder = ReplicatedStorage:WaitForChild("TD_Remotes", 30)
local grantEvent = remoteFolder and remoteFolder:WaitForChild("TD_Grant")

local function grant(player, kind)
	if grantEvent then
		grantEvent:Fire(player, kind)
	end
end

local function refreshPasses(player)
	for _, info in ipairs(PASS_INFO) do
		if info.id and info.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.id)
			end)
			if ok and owns then
				player:SetAttribute(info.attr, true)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.delay(3, function()
		if player.Parent then refreshPasses(player) end
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		refreshPasses(player)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		for _, info in ipairs(PASS_INFO) do
			if info.id == passId and passId > 0 then
				player:SetAttribute(info.attr, true)
			end
		end
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local kind = nil
	if receiptInfo.ProductId == PRODUCT_MINERALS then
		kind = "minerals250"
	elseif receiptInfo.ProductId == PRODUCT_LEGEND then
		kind = "legend"
	elseif receiptInfo.ProductId == PRODUCT_REVIVE then
		kind = "revive"
	end

	if kind then
		grant(player, kind)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

print("[TD] 03_MonetizationPasses 로드 — 게임패스 ID를 넣으면 바로 판매 가능")
