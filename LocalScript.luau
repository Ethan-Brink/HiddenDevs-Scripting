local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local player           = Players.LocalPlayer
local camera           = workspace.CurrentCamera
local mouse            = player:GetMouse()

local timeScale        = 1.0
local lockedPlanet     = nil
local UPDATE_RATE      = 1 / 60
local accumulator      = 0

local camYaw           = 0                
local camPitch         = math.rad(20)     
local camDist          = 30               
local camDragging      = false
local lastMousePos     = Vector2.new(0, 0)
local CAM_SENSITIVITY  = 0.004           
local CAM_PITCH_MIN    = math.rad(-80)
local CAM_PITCH_MAX    = math.rad(80)
local CAM_DIST_MIN     = 8
local CAM_DIST_MAX     = 140

local STAR_SIZE        = 16
local STAR_CF          = CFrame.new(0, 60, 0)
local SCI_FI_DARK      = Color3.fromRGB(5, 10, 25)
local SCI_FI_ACCENT    = Color3.fromRGB(0, 200, 255)
local SCI_FI_TEXT      = Color3.fromRGB(180, 240, 255)

local ASTEROID_MIN_R   = 70
local ASTEROID_MAX_R   = 90
local ASTEROID_COUNT   = 200

local function polarToCFrame(angle: number, radius: number, tilt: number, origin: CFrame): CFrame
	local x      = radius * math.cos(angle)
	local z      = radius * math.sin(angle)
	local tiltCF = CFrame.Angles(tilt, 0, 0)
	return origin * tiltCF * CFrame.new(x, 0, z)
end

local function makePart(name: string, size: number, colour: Color3, parent: Instance): BasePart
	local part          = Instance.new("Part")
	part.Name           = name
	part.Shape          = Enum.PartType.Ball
	part.Size           = Vector3.new(size, size, size)
	part.Color          = colour
	part.Material       = Enum.Material.Neon
	part.Anchored       = true
	part.CanCollide     = false
	part.CastShadow     = false
	part.Parent         = parent
	return part
end

local function attachTrail(part: BasePart, colour: Color3)
	local a0            = Instance.new("Attachment", part)
	a0.Position         = Vector3.new(part.Size.X / 2, 0, 0)
	local a1            = Instance.new("Attachment", part)
	a1.Position         = Vector3.new(-part.Size.X / 2, 0, 0)
	local trail         = Instance.new("Trail", part)
	trail.Attachment0   = a0
	trail.Attachment1   = a1
	trail.Lifetime      = 3
	trail.MinLength     = 0
	trail.FaceCamera    = true
	trail.Color         = ColorSequence.new(colour, Color3.new(1, 1, 1))
	trail.Transparency  = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.0),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.WidthScale    = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
end

local Planet   = {}
Planet.__index = Planet

function Planet.new(cfg): Planet
	local self          = setmetatable({}, Planet)
	self.name           = cfg.name
	self.radius         = cfg.radius
	self.speed          = cfg.speed
	self.tilt           = cfg.tilt
	self.origin         = cfg.origin
	self.angle          = math.random() * (math.pi * 2)
	self.info           = cfg.info
	self.spinAngle      = 0                        
	self.spinSpeed      = cfg.spinSpeed or (1.5 + math.random() * 2.5)  

	self.part           = makePart(cfg.name, cfg.size, cfg.colour, workspace)
	attachTrail(self.part, cfg.colour)

	local light         = Instance.new("PointLight", self.part)
	light.Brightness    = 0.4
	light.Range         = cfg.size * 4
	light.Color         = cfg.colour

	self.moon           = nil
	self.moonAngle      = 0
	self.moonRadius     = cfg.moonRadius or 6
	self.moonSpeed      = cfg.moonSpeed  or 1.5

	if cfg.hasMoon then
		self.moon = makePart(cfg.name .. "_Moon",
			cfg.moonSize   or 1.5,
			cfg.moonColour or Color3.new(0.8, 0.8, 0.8),
			workspace)
		attachTrail(self.moon, cfg.moonColour or Color3.new(0.8, 0.8, 0.8))
	end

	return self
end


function Planet:update(dt: number)
	self.angle       += self.speed * dt
	local orbitCF     = polarToCFrame(self.angle, self.radius, self.tilt, self.origin)

	self.spinAngle   += self.spinSpeed * dt
	self.part.CFrame  = orbitCF * CFrame.Angles(0, self.spinAngle, 0)

	if self.moon then
		self.moonAngle   += self.moonSpeed * dt
		self.moon.CFrame  = polarToCFrame(self.moonAngle, self.moonRadius, 0, orbitCF)
	end
end


function Planet:getPosition(): Vector3
	return self.part.Position
end

function Planet:destroy()
	self.part:Destroy()
	if self.moon then self.moon:Destroy() end
end

local starPart       = makePart("Sun", STAR_SIZE, Color3.fromRGB(255, 220, 50), workspace)
starPart.CFrame      = STAR_CF

local starLight      = Instance.new("PointLight", starPart)
starLight.Brightness = 6
starLight.Range      = 200
starLight.Color      = Color3.fromRGB(255, 240, 180)

TweenService:Create(starLight,
	TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Brightness = 10, Range = 240 }):Play()

local asteroids      = {}
local asteroidFolder = Instance.new("Folder", workspace)
asteroidFolder.Name  = "AsteroidBelt"

for i = 1, ASTEROID_COUNT do
	
	local radius  = ASTEROID_MIN_R + math.random() * (ASTEROID_MAX_R - ASTEROID_MIN_R)
	local angle   = math.random() * (math.pi * 2)
	local tilt    = math.rad(math.random(-12, 12))  
	local speed   = 0.5 + math.random() * 0.25       
	local sz      = 0.3 + math.random() * 0.5

	
	local g       = 0.35 + math.random() * 0.25
	local colour  = Color3.new(g, g * 0.9, g * 0.8)

	local part    = Instance.new("Part")
	part.Name     = "Asteroid_" .. i
	
	part.Size     = Vector3.new(sz, sz * (0.6 + math.random() * 0.8), sz * (0.6 + math.random() * 0.8))
	part.Color    = colour
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent   = asteroidFolder

	local randRot = CFrame.Angles(
		math.random() * math.pi * 2,
		math.random() * math.pi * 2,
		math.random() * math.pi * 2
	)

	table.insert(asteroids, {
		part    = part,
		radius  = radius,
		angle   = angle,
		tilt    = tilt,
		speed   = speed,
		randRot = randRot,
	})
end

local function updateAsteroids(dt: number)
	for _, ast in ipairs(asteroids) do
		ast.angle      += ast.speed * dt
		local orbitCF   = polarToCFrame(ast.angle, ast.radius, ast.tilt, STAR_CF)
		ast.part.CFrame = orbitCF * ast.randRot
	end
end

local planetConfigs = {
	{
		name = "Mercury", radius = 24, size = 2.2, speed = 1.6, tilt = math.rad(7),
		colour = Color3.fromRGB(153, 140, 130), origin = STAR_CF,
		info = { Type="Terrestrial", Distance="57.9M km", OrbitalPeriod="88 days",
			Temperature="430°C / -180°C", Moons="0", Fact="Smallest planet." },
	},
	{
		name = "Venus", radius = 34, size = 3.4, speed = 1.17, tilt = math.rad(3.4),
		colour = Color3.fromRGB(230, 190, 100), origin = STAR_CF,
		info = { Type="Terrestrial", Distance="108.2M km", OrbitalPeriod="225 days",
			Temperature="465°C avg", Moons="0", Fact="Hottest planet in the solar system." },
	},
	{
		name = "Earth", radius = 46, size = 3.6, speed = 1.0, tilt = math.rad(23.4),
		colour = Color3.fromRGB(50, 140, 220), origin = STAR_CF,
		hasMoon=true, moonSize=1.2, moonRadius=7, moonSpeed=3.0,
		moonColour=Color3.fromRGB(210,210,210),
		info = { Type="Terrestrial", Distance="149.6M km", OrbitalPeriod="365.25 days",
			Temperature="15°C avg", Moons="1 (The Moon)", Fact="Only known planet with life." },
	},
	{
		name = "Mars", radius = 60, size = 2.9, speed = 0.80, tilt = math.rad(25),
		colour = Color3.fromRGB(200, 75, 35), origin = STAR_CF,
		hasMoon=true, moonSize=0.8, moonRadius=6, moonSpeed=4.0,
		moonColour=Color3.fromRGB(150,120,110),
		info = { Type="Terrestrial", Distance="227.9M km", OrbitalPeriod="687 days",
			Temperature="-60°C avg", Moons="2 (Phobos & Deimos)", Fact="Home to Olympus Mons." },
	},
	{
		name = "Jupiter", radius = 82, size = 8, speed = 0.43, tilt = math.rad(3.1),
		colour = Color3.fromRGB(200, 158, 100), origin = STAR_CF,
		hasMoon=true, moonSize=2, moonRadius=13, moonSpeed=2.5,
		moonColour=Color3.fromRGB(230,200,150),
		info = { Type="Gas Giant", Distance="778.5M km", OrbitalPeriod="11.9 years",
			Temperature="-110°C", Moons="95", Fact="1,300 Earths fit inside Jupiter." },
	},
	{
		name = "Saturn", radius = 106, size = 7, speed = 0.32, tilt = math.rad(26.7),
		colour = Color3.fromRGB(224, 198, 140), origin = STAR_CF,
		hasMoon=true, moonSize=1.6, moonRadius=12, moonSpeed=2.2,
		moonColour=Color3.fromRGB(190,178,160),
		info = { Type="Gas Giant", Distance="1.43B km", OrbitalPeriod="29.5 years",
			Temperature="-140°C avg", Moons="146", Fact="Rings made of ice and rock." },
	},
	{
		name = "Uranus", radius = 130, size = 5.2, speed = 0.22, tilt = math.rad(97.8),
		colour = Color3.fromRGB(135, 206, 225), origin = STAR_CF,
		info = { Type="Ice Giant", Distance="2.87B km", OrbitalPeriod="84 years",
			Temperature="-195°C avg", Moons="28", Fact="Rotates on its side at 97.8°." },
	},
	{
		name = "Neptune", radius = 154, size = 5, speed = 0.18, tilt = math.rad(28.3),
		colour = Color3.fromRGB(50, 90, 220), origin = STAR_CF,
		info = { Type="Ice Giant", Distance="4.5B km", OrbitalPeriod="165 years",
			Temperature="-200°C avg", Moons="16", Fact="Fastest winds at 2,100 km/h." },
	},
}

local planets: {Planet} = {}
for _, cfg in ipairs(planetConfigs) do
	table.insert(planets, Planet.new(cfg))
end

local screenGui          = Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name           = "SolarSimGUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling


local infoPanel          = Instance.new("Frame", screenGui)
infoPanel.Size           = UDim2.new(0, 280, 0, 340)
infoPanel.Position       = UDim2.new(1, -300, 0.5, -170)
infoPanel.BackgroundColor3 = SCI_FI_DARK
infoPanel.BorderSizePixel  = 0
infoPanel.Visible          = false
local s1 = Instance.new("UIStroke", infoPanel); s1.Color = SCI_FI_ACCENT; s1.Thickness = 2
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 8)

local panelTitle         = Instance.new("TextLabel", infoPanel)
panelTitle.Size          = UDim2.new(1, -20, 0, 36)
panelTitle.Position      = UDim2.new(0, 10, 0, 8)
panelTitle.BackgroundTransparency = 1
panelTitle.TextColor3    = SCI_FI_ACCENT
panelTitle.TextSize      = 20
panelTitle.Font          = Enum.Font.GothamBold
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.Text          = "— PLANET DATA —"

local div = Instance.new("Frame", infoPanel)
div.Size  = UDim2.new(1,-20,0,1); div.Position = UDim2.new(0,10,0,48)
div.BackgroundColor3 = SCI_FI_ACCENT; div.BorderSizePixel = 0

local infoContent        = Instance.new("TextLabel", infoPanel)
infoContent.Size         = UDim2.new(1, -20, 1, -70)
infoContent.Position     = UDim2.new(0, 10, 0, 58)
infoContent.BackgroundTransparency = 1
infoContent.TextColor3   = SCI_FI_TEXT
infoContent.TextSize     = 13
infoContent.Font         = Enum.Font.Gotham
infoContent.TextXAlignment = Enum.TextXAlignment.Left
infoContent.TextYAlignment = Enum.TextYAlignment.Top
infoContent.TextWrapped  = true
infoContent.Text         = ""

local lockBtn            = Instance.new("TextButton", infoPanel)
lockBtn.Size             = UDim2.new(1, -20, 0, 32)
lockBtn.Position         = UDim2.new(0, 10, 1, -42)
lockBtn.BackgroundColor3 = SCI_FI_ACCENT
lockBtn.TextColor3       = SCI_FI_DARK
lockBtn.TextSize         = 13
lockBtn.Font             = Enum.Font.GothamBold
lockBtn.Text             = "??  LOCK CAMERA"
lockBtn.BorderSizePixel  = 0
Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(0, 6)

local timePanel          = Instance.new("Frame", screenGui)
timePanel.Size           = UDim2.new(0, 340, 0, 90)
timePanel.Position       = UDim2.new(0.5, -170, 1, -106)
timePanel.BackgroundColor3 = SCI_FI_DARK
timePanel.BorderSizePixel  = 0
Instance.new("UICorner", timePanel).CornerRadius = UDim.new(0, 8)
local s2 = Instance.new("UIStroke", timePanel); s2.Color = SCI_FI_ACCENT; s2.Thickness = 2

local timeLabel          = Instance.new("TextLabel", timePanel)
timeLabel.Size           = UDim2.new(1, 0, 0, 24)
timeLabel.Position       = UDim2.new(0, 0, 0, 6)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3     = SCI_FI_ACCENT
timeLabel.TextSize       = 13
timeLabel.Font           = Enum.Font.GothamBold
timeLabel.Text           = "TIME SCALE: 1.0x"

local sliderTrack        = Instance.new("Frame", timePanel)
sliderTrack.Size         = UDim2.new(1, -40, 0, 6)
sliderTrack.Position     = UDim2.new(0, 20, 0, 38)
sliderTrack.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
sliderTrack.BorderSizePixel  = 0
Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

local sliderFill         = Instance.new("Frame", sliderTrack)
sliderFill.Size          = UDim2.new(0.25, 0, 1, 0)
sliderFill.BackgroundColor3 = SCI_FI_ACCENT
sliderFill.BorderSizePixel  = 0
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

local sliderKnob         = Instance.new("Frame", sliderTrack)
sliderKnob.Size          = UDim2.new(0, 28, 0, 28)    
sliderKnob.Position      = UDim2.new(0.25, -14, 0.5, -14)
sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderKnob.BorderSizePixel  = 0
Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

local pauseBtn           = Instance.new("TextButton", timePanel)
pauseBtn.Size            = UDim2.new(0, 80, 0, 28)
pauseBtn.Position        = UDim2.new(0.5, -40, 1, -36)
pauseBtn.BackgroundColor3 = SCI_FI_ACCENT
pauseBtn.TextColor3      = SCI_FI_DARK
pauseBtn.TextSize        = 13
pauseBtn.Font            = Enum.Font.GothamBold
pauseBtn.Text            = "?  PAUSE"
pauseBtn.BorderSizePixel = 0
Instance.new("UICorner", pauseBtn).CornerRadius = UDim.new(0, 6)

local hintLabel          = Instance.new("TextLabel", screenGui)
hintLabel.Size           = UDim2.new(0, 300, 0, 60)
hintLabel.Position       = UDim2.new(0, 16, 0, 16)
hintLabel.BackgroundColor3 = SCI_FI_DARK
hintLabel.BackgroundTransparency = 0.3
hintLabel.TextColor3     = SCI_FI_TEXT
hintLabel.TextSize       = 12
hintLabel.Font           = Enum.Font.Gotham
hintLabel.TextWrapped    = true
hintLabel.Text           = "??  Click a planet to view its data\n??  Lock camera ? RMB drag to orbit freely\n??  Scroll wheel to zoom in / out"
hintLabel.BorderSizePixel = 0
Instance.new("UICorner", hintLabel).CornerRadius = UDim.new(0, 8)

local currentInfoPlanet = nil

local function showPlanetInfo(planet)
	panelTitle.Text = "— " .. string.upper(planet.name) .. " —"
	local lines = {}
	for k, v in pairs(planet.info) do
		table.insert(lines, string.format("%-14s %s", k .. ":", v))
	end
	infoContent.Text = table.concat(lines, "\n")
	infoPanel.Visible  = true
	infoPanel.Position = UDim2.new(1, 20, 0.5, -170)
	TweenService:Create(infoPanel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -300, 0.5, -170) }):Play()
end

local function unlockCamera()
	lockedPlanet             = nil
	camera.CameraType        = Enum.CameraType.Custom
	lockBtn.Text             = "??  LOCK CAMERA"
	lockBtn.BackgroundColor3 = SCI_FI_ACCENT
end

lockBtn.MouseButton1Click:Connect(function()
	if not currentInfoPlanet then return end
	if lockedPlanet == currentInfoPlanet then
		unlockCamera()
	else
		lockedPlanet             = currentInfoPlanet
		camera.CameraType        = Enum.CameraType.Scriptable
	
		camYaw                   = 0
		camPitch                 = math.rad(20)
		camDist                  = math.max(lockedPlanet.part.Size.X * 5, 20)
		lockBtn.Text             = "??  UNLOCK CAMERA"
		lockBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 and lockedPlanet then
		camDragging  = true
		lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		camDragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if camDragging and input.UserInputType == Enum.UserInputType.MouseMovement and lockedPlanet then
		local pos   = Vector2.new(input.Position.X, input.Position.Y)
		local delta = pos - lastMousePos
		lastMousePos = pos
		camYaw   -= delta.X * CAM_SENSITIVITY
		camPitch  = math.clamp(camPitch - delta.Y * CAM_SENSITIVITY, CAM_PITCH_MIN, CAM_PITCH_MAX)
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel and lockedPlanet then
		camDist = math.clamp(camDist - input.Position.Z * 8, CAM_DIST_MIN, CAM_DIST_MAX)
	end
end)

local sliderDragging = false
local isPaused       = false
local preStopScale   = 1.0

local function setSliderNorm(norm: number)
	norm            = math.clamp(norm, 0, 1)
	timeScale       = norm * 4
	sliderFill.Size      = UDim2.new(norm, 0, 1, 0)
	sliderKnob.Position  = UDim2.new(norm, -8, 0.5, -8)
	timeLabel.Text       = string.format("TIME SCALE:  %.1fx", timeScale)
end

local function normFromInput(input)
	return (input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X
end

sliderKnob.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = true
	end
end)

sliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = true
		setSliderNorm(normFromInput(input))
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		sliderDragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if sliderDragging and (
		input.UserInputType == Enum.UserInputType.MouseMovement or
			input.UserInputType == Enum.UserInputType.Touch
		) then
		setSliderNorm(normFromInput(input))
	end
end)

pauseBtn.MouseButton1Click:Connect(function()
	if isPaused then
		isPaused      = false
		timeScale     = preStopScale
		pauseBtn.Text = "?  PAUSE"
		setSliderNorm(timeScale / 4)
	else
		isPaused      = true
		preStopScale  = timeScale
		timeScale     = 0
		pauseBtn.Text = "?  PLAY"
	end
end)

mouse.Button1Down:Connect(function()
	local target = mouse.Target
	if not target then return end
	for _, planet in ipairs(planets) do
		if target == planet.part or target == planet.moon then
			currentInfoPlanet = planet
			showPlanetInfo(planet)
			return
		end
	end
	infoPanel.Visible = false
	unlockCamera()
end)

local function computeOrbitCFrame(target: Vector3): CFrame
	local rotCF  = CFrame.Angles(0, camYaw, 0) * CFrame.Angles(camPitch, 0, 0)
	local offset = rotCF * Vector3.new(0, 0, camDist)
	return CFrame.new(target + offset, target)
end

RunService.Heartbeat:Connect(function(dt: number)
	local scaledDt = dt * timeScale
	accumulator   += scaledDt

	while accumulator >= UPDATE_RATE do
		for _, planet in ipairs(planets) do
			planet:update(UPDATE_RATE)
		end
		updateAsteroids(UPDATE_RATE)
		accumulator -= UPDATE_RATE
	end

	if lockedPlanet and camera.CameraType == Enum.CameraType.Scriptable then
		camera.CFrame = computeOrbitCFrame(lockedPlanet:getPosition())
	end
end)

print(string.format("[SolarSimulation] Loaded — %d planets, %d asteroids.", #planets, ASTEROID_COUNT))
print("  Click planet ? Lock Camera ? RMB drag to orbit, scroll to zoom.")