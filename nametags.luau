local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Teams=game:GetService("Teams")

-- Central runtime state
local State={}
State.Tags={}
State.Settings={}
State.PlayerData={}

-- Global display settings
State.Settings.MaxDistance=120
State.Settings.MinDistance=10
State.Settings.ShowHealth=true
State.Settings.ShowTeam=true
State.Settings.ShowRole=true

-- Role definitions for special players
local Roles={}
Roles.Admin={Text="ADMIN",Color=Color3.fromRGB(255,80,80)}
Roles.VIP={Text="VIP",Color=Color3.fromRGB(255,215,0)}

-- Simple admin check placeholder
local function isAdmin(player)
	return player.UserId%2==0
end

-- Simple VIP check placeholder
local function isVIP(player)
	return player.UserId%5==0
end

-- Creates the BillboardGui and its UI hierarchy
local function createBillboard()
	local gui=Instance.new("BillboardGui")
	gui.Size=UDim2.new(0,200,0,60)
	gui.StudsOffset=Vector3.new(0,3,0)
	gui.AlwaysOnTop=true
	gui.ResetOnSpawn=false

	local frame=Instance.new("Frame")
	frame.BackgroundTransparency=1
	frame.Size=UDim2.new(1,0,1,0)
	frame.Parent=gui

	local name=Instance.new("TextLabel")
	name.Size=UDim2.new(1,0,0.4,0)
	name.Position=UDim2.new(0,0,0,0)
	name.BackgroundTransparency=1
	name.TextScaled=true
	name.Font=Enum.Font.GothamBold
	name.TextColor3=Color3.new(1,1,1)
	name.Parent=frame

	local role=Instance.new("TextLabel")
	role.Size=UDim2.new(1,0,0.3,0)
	role.Position=UDim2.new(0,0,0.4,0)
	role.BackgroundTransparency=1
	role.TextScaled=true
	role.Font=Enum.Font.Gotham
	role.TextColor3=Color3.new(1,1,1)
	role.Parent=frame

	local health=Instance.new("TextLabel")
	health.Size=UDim2.new(1,0,0.3,0)
	health.Position=UDim2.new(0,0,0.7,0)
	health.BackgroundTransparency=1
	health.TextScaled=true
	health.Font=Enum.Font.Gotham
	health.TextColor3=Color3.new(0.4,1,0.4)
	health.Parent=frame

	return gui,name,role,health
end

-- Attaches a nametag to a character’s head
local function attachTag(player,character)
	local head=character:WaitForChild("Head",5)
	if not head then
		return
	end

	local gui,name,role,health=createBillboard()
	gui.Parent=head

	State.Tags[player]={
		Gui=gui,
		Name=name,
		Role=role,
		Health=health,
		Character=character
	}

	name.Text=player.Name

	if player.Team then
		name.TextColor3=player.TeamColor.Color
	end

	if isAdmin(player) then
		role.Text=Roles.Admin.Text
		role.TextColor3=Roles.Admin.Color
	elseif isVIP(player) then
		role.Text=Roles.VIP.Text
		role.TextColor3=Roles.VIP.Color
	else
		role.Text=""
	end
end

-- Removes and cleans up a player’s nametag
local function removeTag(player)
	local tag=State.Tags[player]
	if tag then
		tag.Gui:Destroy()
		State.Tags[player]=nil
	end
end

-- Updates the displayed health text
local function updateHealth(player)
	local tag=State.Tags[player]
	if not tag then
		return
	end

	local hum=tag.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	if State.Settings.ShowHealth then
		tag.Health.Text=tostring(math.floor(hum.Health)).." HP"
	else
		tag.Health.Text=""
	end
end

-- Controls visibility and scale based on viewer distance
local function updateDistance(localPlayer,targetPlayer)
	local tag=State.Tags[targetPlayer]
	if not tag then
		return
	end

	if not localPlayer.Character then
		tag.Gui.Enabled=false
		return
	end

	local root=localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local targetRoot=tag.Character:FindFirstChild("HumanoidRootPart")
	if not root or not targetRoot then
		tag.Gui.Enabled=false
		return
	end

	local dist=(root.Position-targetRoot.Position).Magnitude

	if dist>State.Settings.MaxDistance then
		tag.Gui.Enabled=false
		return
	end

	if dist<State.Settings.MinDistance then
		tag.Gui.Enabled=true
		tag.Gui.Size=UDim2.new(0,220,0,70)
	else
		local alpha=1-(dist/State.Settings.MaxDistance)
		local scale=math.clamp(alpha,0.5,1)
		tag.Gui.Enabled=true
		tag.Gui.Size=UDim2.new(0,200*scale,0,60*scale)
	end
end

-- Applies team coloring to player names
local function updateTeam(player)
	local tag=State.Tags[player]
	if not tag then
		return
	end

	if State.Settings.ShowTeam and player.Team then
		tag.Name.TextColor3=player.TeamColor.Color
	else
		tag.Name.TextColor3=Color3.new(1,1,1)
	end
end

-- Registers a player and hooks character lifecycle
local function registerPlayer(player)
	State.PlayerData[player]={}

	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		attachTag(player,character)
	end)

	player.CharacterRemoving:Connect(function()
		removeTag(player)
	end)
end

-- Cleanup on player removal
local function unregisterPlayer(player)
	removeTag(player)
	State.PlayerData[player]=nil
end

Players.PlayerAdded:Connect(registerPlayer)
Players.PlayerRemoving:Connect(unregisterPlayer)

for _,player in pairs(Players:GetPlayers()) do
	registerPlayer(player)
	if player.Character then
		attachTag(player,player.Character)
	end
end

-- Main update loop for nametag logic
RunService.Heartbeat:Connect(function()
	for _,viewer in pairs(Players:GetPlayers()) do
		for target,_ in pairs(State.Tags) do
			if viewer~=target then
				updateDistance(viewer,target)
				updateHealth(target)
				updateTeam(target)
			end
		end
	end
end)

-- Toggles health visibility globally
local function toggleHealthDisplay(enabled)
	State.Settings.ShowHealth=enabled
end

-- Toggles team coloring globally
local function toggleTeamDisplay(enabled)
	State.Settings.ShowTeam=enabled
end

-- Toggles role display globally
local function toggleRoleDisplay(enabled)
	State.Settings.ShowRole=enabled
	for player,tag in pairs(State.Tags) do
		if enabled then
			if isAdmin(player) then
				tag.Role.Text=Roles.Admin.Text
				tag.Role.TextColor3=Roles.Admin.Color
			elseif isVIP(player) then
				tag.Role.Text=Roles.VIP.Text
				tag.Role.TextColor3=Roles.VIP.Color
			else
				tag.Role.Text=""
			end
		else
			tag.Role.Text=""
		end
	end
end

toggleHealthDisplay(true)
toggleTeamDisplay(true)
toggleRoleDisplay(true)
