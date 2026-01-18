-- Silent Strike
-- Subtitle: <>

-- Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Silent Strike",
	LoadingTitle = "Silent Strike",
	LoadingSubtitle = "<>",
	Theme = "Dark",
	ConfigurationSaving = { Enabled = false }
})

-- Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UIS = game:GetService("UserInputService")

local LP = Players.LocalPlayer

-- =====================
-- CONFIG VARIABLES
-- =====================
local Enabled = false
local MaxDistance = 20
local FOVRadius = 200

local TeamCheck = true
local WallCheck = true

local PredictionMode = "Normal" -- Normal | Velocity | Facing | More Predict

-- Desync / Velocity Offset (beside target)
local DesyncStrength = 1
local SideOffset = 2.5
local MaxDesyncDistance = 4

-- Visuals
local HighlightColor = Color3.fromRGB(255,0,0)
local Highlight, Target
local Blacklist = {}

-- =====================
-- UTILS
-- =====================
local function worldToScreen(pos)
	local v, onscreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), onscreen
end

local function inFOV(pos)
	local screenPos, onScreen = worldToScreen(pos)
	if not onScreen then return false end
	return (screenPos - Camera.ViewportSize/2).Magnitude <= FOVRadius
end

local function visible(char)
	if not WallCheck then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {LP.Character, char}

	return not Workspace:Raycast(
		LP.Character.HumanoidRootPart.Position,
		char.HumanoidRootPart.Position - LP.Character.HumanoidRootPart.Position,
		params
	)
end

-- =====================
-- PREDICTION
-- =====================
local function getPredictedPosition(char)
	local hrp = char.HumanoidRootPart
	local vel = hrp.Velocity
	local look = hrp.CFrame.LookVector

	if PredictionMode == "Velocity" then
		return hrp.Position + vel * 0.15
	elseif PredictionMode == "Facing" then
		return hrp.Position + look * 6
	elseif PredictionMode == "More Predict" then
		return hrp.Position + (vel * 0.2) + (look * 6)
	else
		return hrp.Position
	end
end

-- =====================
-- TARGET FINDER (FOV)
-- =====================
local function getTarget()
	if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end

	local best, closest = nil, MaxDistance

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP
		and not table.find(Blacklist, plr.Name)
		and plr.Character
		and plr.Character:FindFirstChild("HumanoidRootPart")
		and plr.Character:FindFirstChild("Humanoid")
		and plr.Character.Humanoid.Health > 0 then

			if TeamCheck and plr.Team == LP.Team then continue end

			local pos = getPredictedPosition(plr.Character)
			local dist = (pos - LP.Character.HumanoidRootPart.Position).Magnitude

			if dist < closest and inFOV(pos) and visible(plr.Character) then
				closest = dist
				best = plr
			end
		end
	end

	return best
end

-- =====================
-- HIGHLIGHT
-- =====================
local function applyHighlight(char)
	if Highlight then Highlight:Destroy() end
	Highlight = Instance.new("Highlight")
	Highlight.FillColor = HighlightColor
	Highlight.OutlineColor = HighlightColor
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Adornee = char
	Highlight.Parent = char
end

-- =====================
-- VELOCITY DESYNC (BESIDE TARGET)
-- =====================
local function velocityDesyncBeside(targetChar)
	if not LP.Character or not targetChar then return end

	local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
	local tHRP = targetChar:FindFirstChild("HumanoidRootPart")
	if not hrp or not tHRP then return end

	local originalCF = hrp.CFrame

	local toTarget = (tHRP.Position - hrp.Position)
	if toTarget.Magnitude == 0 then return end
	local dir = toTarget.Unit

	local side = dir:Cross(Vector3.new(0,1,0)).Unit
	if math.random(1,2) == 1 then side = -side end

	local velOffset = tHRP.Velocity * DesyncStrength * 0.03

	local offset =
		(side * SideOffset) +
		(dir * 1.2) +
		velOffset

	if offset.Magnitude > MaxDesyncDistance then
		offset = offset.Unit * MaxDesyncDistance
	end

	hrp.CFrame = hrp.CFrame + offset
	task.wait()
	RS.Remotes.Swing:FireServer()
	hrp.CFrame = originalCF
end

-- =====================
-- MAIN LOOP
-- =====================
RunService.Heartbeat:Connect(function()
	if not Enabled then
		if Highlight then Highlight:Destroy() Highlight = nil end
		Target = nil
		return
	end

	local t = getTarget()
	if t and t.Character then
		if Target ~= t then
			Target = t
			applyHighlight(t.Character)
		end
		velocityDesyncBeside(t.Character)
	else
		if Highlight then Highlight:Destroy() Highlight = nil end
		Target = nil
	end
end)

-- =====================
-- UI
-- =====================
local Main = Window:CreateTab("Main", 4483362458)
local Combat = Window:CreateTab("Combat", 4483362458)
local Visuals = Window:CreateTab("Visuals", 4483362458)
local UI = Window:CreateTab("UI", 4483362458)

Main:CreateToggle({
	Name = "Enable Silent Strike",
	CurrentValue = false,
	Flag = "SilentStrikeToggle",
	Callback = function(v) Enabled = v end
})

Combat:CreateSlider({
	Name = "FOV Radius",
	Range = {50, 600},
	Increment = 10,
	CurrentValue = 200,
	Callback = function(v) FOVRadius = v end
})

Combat:CreateDropdown({
	Name = "Prediction Mode",
	Options = {"Normal","Velocity","Facing","More Predict"},
	CurrentOption = "Normal",
	Callback = function(v) PredictionMode = v end
})

Combat:CreateInput({
	Name = "Velocity Desync Strength",
	PlaceholderText = "0.5 - 2 recommended",
	RemoveTextAfterFocusLost = false,
	Callback = function(txt)
		local n = tonumber(txt)
		if n then DesyncStrength = math.clamp(n,0,5) end
	end
})

Combat:CreateInput({
	Name = "Side Offset (studs)",
	PlaceholderText = "Default 2.5",
	RemoveTextAfterFocusLost = false,
	Callback = function(txt)
		local n = tonumber(txt)
		if n then SideOffset = math.clamp(n,0,6) end
	end
})

Combat:CreateToggle({
	Name = "Team Check",
	CurrentValue = true,
	Callback = function(v) TeamCheck = v end
})

Combat:CreateToggle({
	Name = "Wall Check",
	CurrentValue = true,
	Callback = function(v) WallCheck = v end
})

Visuals:CreateColorPicker({
	Name = "Highlight Color",
	Color = HighlightColor,
	Callback = function(c) HighlightColor = c end
})

-- Blacklist
local names = {}
for _, p in ipairs(Players:GetPlayers()) do table.insert(names, p.Name) end

Combat:CreateDropdown({
	Name = "Blacklist Players",
	Options = names,
	MultiSelection = true,
	Callback = function(v) Blacklist = v end
})

-- Theme Picker
UI:CreateDropdown({
	Name = "UI Theme",
	Options = {"Dark", "Light", "Ocean", "Amber"},
	CurrentOption = "Dark",
	Callback = function(t) Rayfield:SetTheme(t) end
})

-- =====================
-- FLOATING EMERGENCY BUTTON
-- =====================
local gui = Instance.new("ScreenGui", game.CoreGui)

local btn = Instance.new("ImageButton")
btn.Parent = gui
btn.Size = UDim2.fromOffset(70,70)
btn.Position = UDim2.fromScale(0.85,0.4)
btn.Image = "https://raw.githubusercontent.com/n0l1v01dscr1pt3r-dev/Test/main/Noli_HallucinationLaugh.gif"
btn.ImageTransparency = 0.5
btn.BackgroundTransparency = 1
btn.Active = true
btn.Draggable = true

btn:GetPropertyChangedSignal("Position"):Connect(function()
	local vp = Camera.ViewportSize
	btn.Position = UDim2.new(
		math.clamp(btn.Position.X.Scale,0,1),
		0,
		math.clamp(btn.Position.Y.Offset,0,vp.Y - btn.Size.Y.Offset),
		0
	)
end)

btn.MouseButton1Click:Connect(function()
	Enabled = false
	if Rayfield.Flags["SilentStrikeToggle"] then
		Rayfield.Flags["SilentStrikeToggle"]:Set(false)
	end
end)
