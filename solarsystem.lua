-- ─────────────────────────────────────────────
--  Services
-- ─────────────────────────────────────────────
local RunService  = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ─────────────────────────────────────────────
--  Constants
-- ─────────────────────────────────────────────
local WORKSPACE   = workspace
local UPDATE_RATE = 1 / 60          -- target ~60 Hz physics updates
local STAR_SIZE   = 14              -- studs diameter for the sun

-- ─────────────────────────────────────────────
--  Utility helpers
-- ─────────────────────────────────────────────

--- Converts polar orbital coordinates to a world-space CFrame.
--- @param angle   number  Current orbital angle in radians
--- @param radius  number  Semi-major axis (studs)
--- @param tilt    number  Axial tilt of the orbital plane (radians)
--- @param origin  CFrame  Centre of the orbit (parent body position)
--- @return CFrame         World CFrame for the orbiting body
local function polarToCFrame(angle: number, radius: number, tilt: number, origin: CFrame): CFrame
	-- Flat orbit position
	local x = radius * math.cos(angle)
	local z = radius * math.sin(angle)

	-- Apply axial tilt around the X-axis using CFrame rotation
	local orbitCF = CFrame.new(x, 0, z)
	local tiltCF  = CFrame.Angles(tilt, 0, 0)

	-- Combine: origin → tilt rotation → flat offset
	return origin * tiltCF * orbitCF
end

--- Creates a coloured part with no collision (used for planets / moons).
--- @param name    string
--- @param size    number   Diameter (studs)
--- @param colour  Color3
--- @param parent  Instance
--- @return BasePart
local function makePart(name: string, size: number, colour: Color3, parent: Instance): BasePart
	local part       = Instance.new("Part")
	part.Name        = name
	part.Shape       = Enum.PartType.Ball
	part.Size        = Vector3.new(size, size, size)
	part.Color       = colour
	part.Material    = Enum.Material.Neon
	part.Anchored    = true
	part.CanCollide  = false
	part.CastShadow  = false
	part.Parent      = parent
	return part
end

--- Attaches a Roblox Trail to a part for a comet-tail effect.
--- @param part    BasePart   The moving part
--- @param colour  Color3     Trail colour
local function attachTrail(part: BasePart, colour: Color3)
	local a0 = Instance.new("Attachment", part)
	a0.Position = Vector3.new( part.Size.X / 2, 0, 0)
	local a1 = Instance.new("Attachment", part)
	a1.Position = Vector3.new(-part.Size.X / 2, 0, 0)

	local trail           = Instance.new("Trail", part)
	trail.Attachment0     = a0
	trail.Attachment1     = a1
	trail.Lifetime        = 2.5
	trail.MinLength       = 0
	trail.FaceCamera      = true
	trail.Color           = ColorSequence.new(colour, Color3.new(1, 1, 1))
	trail.Transparency    = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.0),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.WidthScale      = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
end

-- ─────────────────────────────────────────────
--  Planet class (metatable OOP)
-- ─────────────────────────────────────────────

--- @class Planet
local Planet = {}
Planet.__index = Planet

--- Constructor – creates a new Planet instance.
--- @param cfg table  Configuration table (see fields below)
--- @return Planet
function Planet.new(cfg: {
	name:       string,
	radius:     number,   -- orbital radius in studs
	size:       number,   -- visual diameter in studs
	speed:      number,   -- orbital angular speed (rad/s)
	tilt:       number,   -- orbital-plane tilt (radians)
	colour:     Color3,
	origin:     CFrame,   -- centre body CFrame
	hasMoon:    boolean?,
	moonSize:   number?,
	moonRadius: number?,
	moonSpeed:  number?,
	moonColour: Color3?,
	}): Planet

	local self = setmetatable({}, Planet)

	-- Store config
	self.name       = cfg.name
	self.radius     = cfg.radius
	self.speed      = cfg.speed
	self.tilt       = cfg.tilt
	self.origin     = cfg.origin
	self.angle      = math.random() * (math.pi * 2)   -- random start angle (full circle)

	-- Build the planet part
	self.part = makePart(cfg.name, cfg.size, cfg.colour, WORKSPACE)
	attachTrail(self.part, cfg.colour)

	-- Optionally build a moon
	self.moon       = nil
	self.moonAngle  = 0
	self.moonRadius = cfg.moonRadius or 6
	self.moonSpeed  = cfg.moonSpeed  or 1.5

	if cfg.hasMoon then
		self.moon = makePart(cfg.name .. "_Moon", cfg.moonSize or 1.5,
			cfg.moonColour or Color3.new(0.8, 0.8, 0.8), WORKSPACE)
		attachTrail(self.moon, cfg.moonColour or Color3.new(0.8, 0.8, 0.8))
	end

	return self
end

--- Updates the planet (and its moon) position each frame.
--- @param dt number  Delta time in seconds
function Planet:update(dt: number)
	-- Advance orbital angle using angular speed × delta time
	self.angle += self.speed * dt

	-- Convert polar angle → world CFrame using our utility function
	local planetCF    = polarToCFrame(self.angle, self.radius, self.tilt, self.origin)
	self.part.CFrame  = planetCF

	-- If this planet has a moon, orbit it around the planet's current position
	if self.moon then
		self.moonAngle       += self.moonSpeed * dt
		local moonCF          = polarToCFrame(self.moonAngle, self.moonRadius, 0, planetCF)
		self.moon.CFrame      = moonCF
	end
end

--- Cleanly removes this planet (and moon) from the workspace.
function Planet:destroy()
	self.part:Destroy()
	if self.moon then
		self.moon:Destroy()
	end
end

-- ─────────────────────────────────────────────
--  Build the solar system
-- ─────────────────────────────────────────────

-- Create the central star (Sun)
local starPart          = makePart("Sun", STAR_SIZE, Color3.new(1, 0.85, 0.1), WORKSPACE)
starPart.Material       = Enum.Material.Neon
starPart.CFrame         = CFrame.new(0, 50, 0)   -- elevate above baseplate

-- Pulsing glow on the star via TweenService
local pointLight        = Instance.new("PointLight", starPart)
pointLight.Brightness   = 5
pointLight.Range        = 80
pointLight.Color        = Color3.new(1, 0.9, 0.5)

local glowTweenIn  = TweenService:Create(pointLight,
	TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Brightness = 8, Range = 100 })
glowTweenIn:Play()

local STAR_CF = starPart.CFrame   -- fixed reference point for all orbits

-- Planet configuration table
-- Each entry is a cfg table passed directly to Planet.new()
local planetConfigs: { [number]: table } = {
	{
		name       = "Mercury",
		radius     = 22,
		size       = 2,
		speed      = 1.6,
		tilt       = math.rad(7),
		colour     = Color3.new(0.60, 0.55, 0.52),
		origin     = STAR_CF,
		hasMoon    = false,
	},
	{
		name       = "Venus",
		radius     = 32,
		size       = 3.2,
		speed      = 1.17,
		tilt       = math.rad(3.4),
		colour     = Color3.new(0.90, 0.75, 0.45),
		origin     = STAR_CF,
		hasMoon    = false,
	},
	{
		name       = "Earth",
		radius     = 44,
		size       = 3.5,
		speed      = 1.0,
		tilt       = math.rad(23.4),
		colour     = Color3.new(0.20, 0.55, 0.85),
		origin     = STAR_CF,
		hasMoon    = true,
		moonSize   = 1.2,
		moonRadius = 7,
		moonSpeed  = 3.0,
		moonColour = Color3.new(0.85, 0.85, 0.85),
	},
	{
		name       = "Mars",
		radius     = 57,
		size       = 2.8,
		speed      = 0.80,
		tilt       = math.rad(25),
		colour     = Color3.new(0.80, 0.30, 0.15),
		origin     = STAR_CF,
		hasMoon    = true,
		moonSize   = 0.8,
		moonRadius = 6,
		moonSpeed  = 4.0,
		moonColour = Color3.new(0.60, 0.50, 0.45),
	},
	{
		name       = "Jupiter",
		radius     = 78,
		size       = 7.5,
		speed      = 0.43,
		tilt       = math.rad(3.1),
		colour     = Color3.new(0.78, 0.62, 0.45),
		origin     = STAR_CF,
		hasMoon    = true,
		moonSize   = 1.8,
		moonRadius = 12,
		moonSpeed  = 2.5,
		moonColour = Color3.new(0.90, 0.80, 0.60),
	},
	{
		name       = "Saturn",
		radius     = 100,
		size       = 6.5,
		speed      = 0.32,
		tilt       = math.rad(26.7),
		colour     = Color3.new(0.88, 0.78, 0.55),
		origin     = STAR_CF,
		hasMoon    = true,
		moonSize   = 1.5,
		moonRadius = 11,
		moonSpeed  = 2.2,
		moonColour = Color3.new(0.75, 0.70, 0.65),
	},
	{
		name       = "Uranus",
		radius     = 122,
		size       = 5,
		speed      = 0.22,
		tilt       = math.rad(97.8),   -- Uranus has extreme axial tilt
		colour     = Color3.new(0.53, 0.81, 0.88),
		origin     = STAR_CF,
		hasMoon    = false,
	},
	{
		name       = "Neptune",
		radius     = 143,
		size       = 4.8,
		speed      = 0.18,
		tilt       = math.rad(28.3),
		colour     = Color3.new(0.20, 0.35, 0.85),
		origin     = STAR_CF,
		hasMoon    = false,
	},
}

-- Instantiate all planets
local planets: { Planet } = {}
for _, cfg in ipairs(planetConfigs) do
	table.insert(planets, Planet.new(cfg))
end

-- ─────────────────────────────────────────────
--  Main update loop
-- ─────────────────────────────────────────────

local accumulator = 0   -- time accumulator for fixed-step updates

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += dt

	-- Fixed-step update to decouple simulation from frame rate
	while accumulator >= UPDATE_RATE do
		for _, planet in ipairs(planets) do
			planet:update(UPDATE_RATE)
		end
		accumulator -= UPDATE_RATE
	end
end)

-- ─────────────────────────────────────────────
--  Optional: print system info to output
-- ─────────────────────────────────────────────
print(string.format("[SolarSystem] Simulation started — %d bodies loaded.", #planets))
for _, planet in ipairs(planets) do
	print(string.format("  • %-10s | orbit radius: %3d studs | speed: %.2f rad/s | tilt: %.1f°",
		planet.name, planet.radius, planet.speed, math.deg(planet.tilt)))
end