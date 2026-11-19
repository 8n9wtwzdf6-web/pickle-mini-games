--[[
  build_layout.lua  ·  로켓 타이쿤 기지 3D 구조 자동 생성기
  ------------------------------------------------------------------
  사용법 (Studio 편집 모드에서 한 번만):
    1. Roblox Studio 상단 메뉴 View > Command Bar 를 켭니다.
    2. 이 파일 내용을 전부 복사해 Command Bar 입력창에 붙여넣고 Enter.
    3. Explorer 의 Workspace 아래에 'TycoonPlot' 모델이 생깁니다.
  ※ 이미 TycoonPlot 이 있으면 아무것도 지우지 않고 그냥 종료합니다.
  ※ 이 스크립트는 3D 구조만 만듭니다. 실제 동작 스크립트 3개는
     README 4장 순서대로 직접 붙여넣어 주세요.
]]

local Workspace = game:GetService("Workspace")

if Workspace:FindFirstChild("TycoonPlot") ~= nil then
	print("[RocketTycoon] 'TycoonPlot' 이 이미 있어서 아무것도 만들지 않았습니다. 기존 기지를 지우고 다시 실행하면 새로 만듭니다.")
	return
end

local function makePart(parent, name, size, position, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color or Color3.fromRGB(160, 160, 172)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local plot = Instance.new("Model")
plot.Name = "TycoonPlot"

makePart(plot, "Base", Vector3.new(70, 1, 70), Vector3.new(0, 0.5, 0), Color3.fromRGB(52, 58, 76), Enum.Material.Concrete, true)

local spawnPoint = Workspace:FindFirstChildOfClass("SpawnLocation")
if spawnPoint ~= nil then
	spawnPoint.Anchored = true
	spawnPoint.Size = Vector3.new(10, 0.4, 10)
	spawnPoint.Position = Vector3.new(26, 1.2, 26)
else
	local newSpawn = Instance.new("SpawnLocation")
	newSpawn.Name = "SpawnLocation"
	newSpawn.Anchored = true
	newSpawn.Size = Vector3.new(10, 0.4, 10)
	newSpawn.Position = Vector3.new(26, 1.2, 26)
	newSpawn.Neutral = true
	newSpawn.Parent = plot
end

local claimPad = makePart(plot, "ClaimPad", Vector3.new(10, 1, 10), Vector3.new(10, 1.5, 6), Color3.fromRGB(60, 220, 120), Enum.Material.Neon, true)
claimPad.Name = "ClaimPad"

local conveyor = makePart(plot, "Conveyor", Vector3.new(8, 1, 40), Vector3.new(-16, 1.6, -13), Color3.fromRGB(70, 74, 86), Enum.Material.DiamondPlate, true)
conveyor.Name = "Conveyor"

local collector = makePart(plot, "Collector", Vector3.new(10, 8, 10), Vector3.new(-16, 5, 11), Color3.fromRGB(220, 180, 70), Enum.Material.Metal, true)
collector.Name = "Collector"

local dropper = makePart(plot, "Dropper1", Vector3.new(5, 5, 5), Vector3.new(-16, 8, -33), Color3.fromRGB(255, 138, 60), Enum.Material.Metal, false)
dropper.Name = "Dropper1"

local buttonsFolder = Instance.new("Folder")
buttonsFolder.Name = "Buttons"
buttonsFolder.Parent = plot

local buttonNames = {
	"Button_Drill1",
	"Button_Speed1",
	"Button_Drill2",
	"Button_Dropper2",
	"Button_Speed2",
	"Button_Drill3",
	"Button_Dropper3",
	"Button_LaunchUpgrade",
}

local buttonX = { -21, -15, -9, -3, 3, 9, 15, 21 }
for index = 1, #buttonNames do
	makePart(buttonsFolder, buttonNames[index], Vector3.new(5, 1, 5), Vector3.new(buttonX[index], 1.5, 22), Color3.fromRGB(70, 90, 130), Enum.Material.SmoothPlastic, true)
end

local launchButton = makePart(plot, "LaunchButton", Vector3.new(8, 1, 8), Vector3.new(18, 1.5, 3), Color3.fromRGB(230, 70, 70), Enum.Material.Neon, true)
launchButton.Name = "LaunchButton"

local rocket = Instance.new("Model")
rocket.Name = "RocketModel"

local body = makePart(rocket, "Body", Vector3.new(6, 18, 6), Vector3.new(18, 11, -13), Color3.fromRGB(238, 240, 248), Enum.Material.SmoothPlastic, true)
rocket.PrimaryPart = body

local nose = makePart(rocket, "Nose", Vector3.new(5, 5, 5), Vector3.new(18, 21.5, -13), Color3.fromRGB(230, 70, 70), Enum.Material.SmoothPlastic, true)
nose.Shape = Enum.PartType.Ball

local window = makePart(rocket, "Window", Vector3.new(2.6, 2.6, 0.6), Vector3.new(18, 16, -16.2), Color3.fromRGB(80, 170, 255), Enum.Material.Neon, true)

makePart(rocket, "FinLeft", Vector3.new(1.2, 7, 4), Vector3.new(14.6, 5, -13), Color3.fromRGB(230, 70, 70), Enum.Material.SmoothPlastic, true)
makePart(rocket, "FinRight", Vector3.new(1.2, 7, 4), Vector3.new(21.4, 5, -13), Color3.fromRGB(230, 70, 70), Enum.Material.SmoothPlastic, true)
makePart(rocket, "FinFront", Vector3.new(4, 7, 1.2), Vector3.new(18, 5, -16.4), Color3.fromRGB(230, 70, 70), Enum.Material.SmoothPlastic, true)
makePart(rocket, "FinBack", Vector3.new(4, 7, 1.2), Vector3.new(18, 5, -9.6), Color3.fromRGB(230, 70, 70), Enum.Material.SmoothPlastic, true)

rocket.Parent = plot

plot.Parent = Workspace

print("[RocketTycoon] TycoonPlot 생성 완료! README 4장 순서대로 스크립트 3개를 붙여넣으세요.")
