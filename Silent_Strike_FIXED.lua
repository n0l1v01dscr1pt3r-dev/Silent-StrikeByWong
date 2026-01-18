-- Silent Strike (FIXED)
-- Subtitle: <>

--========================
-- Rayfield UI
--========================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "VoidStrike",
	LoadingTitle = "VoidStrike⭐",
	LoadingSubtitle = "<🌕>",
	Theme = "Dark",
	ConfigurationSaving = { Enabled = false }
})

--========================
-- Services
--========================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

--========================
-- State / Config
--========================
local Enabled = false
local MaxDistance = 20
local FOVRadius = 220
local FireCooldown = 0.15
local lastFire = 0

local TeamCheck = true
local WallCheck = true
local PredictionMode = "Normal" -- Normal | Velocity | Facing | More Predict

-- Desync beside target
local DesyncStrength = 1
local SideOffset = 2.5
local MaxDesyncDistance = 4

-- Visuals
local HighlightColor = Color3.fromRGB(255,0,0)
local Highlight, Target
local Blacklist = {}

-- ESP toggles
local ESPEnabled = true
local ESP_Name = true
local ESP_Distance = true
local ESP_Line = true
local ESP_Box = true
local ESP_OutlineColor = Color3.fromRGB(0,0,0)
local ESP_FillColor = Color3.fromRGB(255,255,255)

--========================
-- Helpers
--========================
local function now()
	return os.clock()
end

local function worldToScreen(pos)
	local v, on = Camera:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), on
end

local function inFOV(pos)
	local s, on = worldToScreen(pos)
	if not on then return false end
	return (s - (Camera.ViewportSize/2)).Magnitude <= FOVRadius
end

local function visible(char)
	if not WallCheck then return true end
	if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {LP.Character, char}
	return Workspace:Raycast(
		LP.Character.HumanoidRootPart.Position,
		char.HumanoidRootPart.Position - LP.Character.HumanoidRootPart.Position,
		params
	) == nil
end

--========================
-- Prediction
--========================
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

--========================
-- Target Finder (FOV-based)
--========================
local function getTarget()
	if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return nil end
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
			if dist <= closest and inFOV(pos) and visible(plr.Character) then
				closest = dist
				best = plr
			end
		end
	end
	return best
end

--========================
-- Highlight
--========================
local function applyHighlight(char)
	if Highlight then Highlight:Destroy() end
	Highlight = Instance.new("Highlight")
	Highlight.FillColor = HighlightColor
	Highlight.OutlineColor = HighlightColor
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Adornee = char
	Highlight.Parent = char
end

--========================
-- Velocity Desync (beside)
--========================
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
	local offset = (side * SideOffset) + (dir * 1.2) + velOffset
	if offset.Magnitude > MaxDesyncDistance then
		offset = offset.Unit * MaxDesyncDistance
	end

	hrp.CFrame = hrp.CFrame + offset
	-- fire during desync
	RS.Remotes.Swing:FireServer()
	hrp.CFrame = originalCF
end

--========================
-- MAIN LOOP (FIXED FIRE)
--========================
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
		if now() - lastFire >= FireCooldown then
			lastFire = now()
			velocityDesyncBeside(t.Character)
		end
	else
		if Highlight then Highlight:Destroy() Highlight = nil end
		Target = nil
	end
end)

--========================
-- ESP (Drawing API)
--========================
local drawings = {}

local function newDrawing(class, props)
	local d = Drawing.new(class)
	for k,v in pairs(props) do d[k] = v end
	return d
end

local function clearESP(plr)
	if drawings[plr] then
		for _,d in pairs(drawings[plr]) do pcall(function() d:Remove() end) end
		drawings[plr] = nil
	end
end

local function updateESP()
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr == LP then clearESP(plr) continue end
		if not ESPEnabled then clearESP(plr) continue end
		if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or not plr.Character:FindFirstChild("Humanoid") then
			clearESP(plr); continue
		end
		if TeamCheck and plr.Team == LP.Team then clearESP(plr); continue end

		local hrp = plr.Character.HumanoidRootPart
		local pos2d, on = worldToScreen(hrp.Position)
		if not on then clearESP(plr); continue end

		drawings[plr] = drawings[plr] or {
			name = newDrawing("Text",{Size=13,Center=true,Outline=true,Color=ESP_FillColor,Visible=false}),
			dist = newDrawing("Text",{Size=12,Center=true,Outline=true,Color=ESP_FillColor,Visible=false}),
			line = newDrawing("Line",{Thickness=1,Color=ESP_FillColor,Visible=false}),
			box = newDrawing("Square",{Thickness=1,Filled=false,Color=ESP_FillColor,Visible=false}),
			boxFill = newDrawing("Square",{Thickness=0,Filled=true,Transparency=0.2,Color=ESP_FillColor,Visible=false}),
			boxOutline = newDrawing("Square",{Thickness=2,Filled=false,Color=ESP_OutlineColor,Visible=false})
		}

		local esp = drawings[plr]
		local distance = (hrp.Position - LP.Character.HumanoidRootPart.Position).Magnitude
		local h = math.clamp(2000/(distance+1), 40, 140)
		local w = h/2

		-- Name
		if ESP_Name then
			esp.name.Text = plr.Name
			esp.name.Position = Vector2.new(pos2d.X, pos2d.Y - h/2 - 14)
			esp.name.Color = ESP_FillColor
			esp.name.Visible = true
		else esp.name.Visible = false end

		-- Distance
		if ESP_Distance then
			esp.dist.Text = string.format("%.0f studs", distance)
			esp.dist.Position = Vector2.new(pos2d.X, pos2d.Y + h/2 + 2)
			esp.dist.Color = ESP_FillColor
			esp.dist.Visible = true
		else esp.dist.Visible = false end

		-- Line
		if ESP_Line then
			esp.line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
			esp.line.To = pos2d
			esp.line.Color = ESP_FillColor
			esp.line.Visible = true
		else esp.line.Visible = false end

		-- Box
		if ESP_Box then
			local tl = Vector2.new(pos2d.X - w/2, pos2d.Y - h/2)
			esp.box.Position = tl
			esp.box.Size = Vector2.new(w, h)
			esp.box.Color = ESP_FillColor
			esp.box.Visible = true

			esp.boxFill.Position = tl
			esp.boxFill.Size = Vector2.new(w, h)
			esp.boxFill.Color = ESP_FillColor
			esp.boxFill.Visible = true

			esp.boxOutline.Position = tl
			esp.boxOutline.Size = Vector2.new(w, h)
			esp.boxOutline.Color = ESP_OutlineColor
			esp.boxOutline.Visible = true
		else
			esp.box.Visible = false
			esp.boxFill.Visible = false
			esp.boxOutline.Visible = false
		end
	end
end

RunService.RenderStepped:Connect(updateESP)

Players.PlayerRemoving:Connect(function(p) clearESP(p) end)

--========================
-- UI
--========================
local Main = Window:CreateTab("Main", 4483362458)
local Combat = Window:CreateTab("Combat", 4483362458)
local Visuals = Window:CreateTab("Visuals", 4483362458)
local ESP = Window:CreateTab("ESP", 4483362458)
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
	CurrentValue = FOVRadius,
	Callback = function(v) FOVRadius = v end
})

Combat:CreateDropdown({
	Name = "Prediction Mode",
	Options = {"Normal","Velocity","Facing","More Predict"},
	CurrentOption = PredictionMode,
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

-- ESP controls
ESP:CreateToggle({Name="Enable ESP", CurrentValue=true, Callback=function(v) ESPEnabled=v end})
ESP:CreateToggle({Name="Name", CurrentValue=true, Callback=function(v) ESP_Name=v end})
ESP:CreateToggle({Name="Distance", CurrentValue=true, Callback=function(v) ESP_Distance=v end})
ESP:CreateToggle({Name="Line", CurrentValue=true, Callback=function(v) ESP_Line=v end})
ESP:CreateToggle({Name="2D Box", CurrentValue=true, Callback=function(v) ESP_Box=v end})
ESP:CreateColorPicker({Name="Outline Color", Color=ESP_OutlineColor, Callback=function(c) ESP_OutlineColor=c end})
ESP:CreateColorPicker({Name="Fill Color", Color=ESP_FillColor, Callback=function(c) ESP_FillColor=c end})

-- Theme
UI:CreateDropdown({
	Name = "UI Theme",
	Options = {"Dark", "Light", "Ocean", "Amber"},
	CurrentOption = "Dark",
	Callback = function(t) Rayfield:SetTheme(t) end
})

--========================
-- FLOATING EMERGENCY GIF BUTTON (VISIBLE FIX)
--========================
pcall(function()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SilentStrike_Emergency"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = CoreGui

	local btn = Instance.new("ImageButton")
	btn.Parent = gui
	btn.Size = UDim2.fromOffset(72,72)
	btn.Position = UDim2.fromScale(0.85,0.45)
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
end)
