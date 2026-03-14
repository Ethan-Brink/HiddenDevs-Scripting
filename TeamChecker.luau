local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local GROUP_ID = 35704376

local function WaitForTeams()
	repeat
		task.wait()
	until Teams:FindFirstChild("Group A") and Teams:FindFirstChild("Group B") 
		and Teams:FindFirstChild("Group C") and Teams:FindFirstChild("Group D")
		and Teams:FindFirstChild("Trainer") and Teams:FindFirstChild("Helper")
		and Teams:FindFirstChild("Host") and Teams:FindFirstChild("Co-Host")
end

WaitForTeams()


local TeamGroupA = Teams:FindFirstChild("Group A")
local TeamGroupB = Teams:FindFirstChild("Group B")
local TeamGroupC = Teams:FindFirstChild("Group C")
local TeamGroupD = Teams:FindFirstChild("Group D")
local TeamTrainer = Teams:FindFirstChild("Trainer")
local TeamHelper = Teams:FindFirstChild("Helper")
local TeamHost = Teams:FindFirstChild("Host")
local TeamCoHost = Teams:FindFirstChild("Co-Host")

local function GetRandomTeam(team1, team2)
	if math.random(1, 2) == 1 then
		return team1
	else
		return team2
	end
end

local function CheckAndTeamPlayer(player)
	
	task.wait(0.5)
	
	local success, rankId = pcall(function()
		return player:GetRankInGroup(GROUP_ID)
	end)

	if not success then
		warn("Failed to get rank for " .. player.Name)
		return
	end

	print("Player: " .. player.Name .. " | Rank ID: " .. rankId .. " | Current Team: " .. (player.Team and player.Team.Name or "None"))


	if rankId == 0 then
		player:Kick("Sunrise Sip Detection - Join the Group to train!")
		return
	end
	if rankId == 12 then
		player:Kick("Sunrise Sip Detection - Rank too high, work hard for a possible promotion.")
		return
	end

	local currentTeam = player.Team
	
	if currentTeam == TeamTrainer or currentTeam == TeamHelper then
		if rankId < 19 then
			if rankId == 1 then
				player.Team = GetRandomTeam(TeamGroupA, TeamGroupB)
				print("Re-teamed " .. player.Name .. " from " .. currentTeam.Name .. " to " .. player.Team.Name)
			elseif rankId == 10 then
				player.Team = GetRandomTeam(TeamGroupC, TeamGroupD)
				print("Re-teamed " .. player.Name .. " from " .. currentTeam.Name .. " to " .. player.Team.Name)
			end
		end
	end
	
	if currentTeam == TeamHost then
		if rankId < 20 then
			if rankId == 1 then
				player.Team = GetRandomTeam(TeamGroupA, TeamGroupB)
				print("Re-teamed " .. player.Name .. " from Host to " .. player.Team.Name)
			elseif rankId == 10 then
				player.Team = GetRandomTeam(TeamGroupC, TeamGroupD)
				print("Re-teamed " .. player.Name .. " from Host to " .. player.Team.Name)
			elseif rankId == 19 then
				player.Team = GetRandomTeam(TeamTrainer, TeamHelper)
				print("Re-teamed " .. player.Name .. " from Host to " .. player.Team.Name)
			end
		end
	end


	if currentTeam == TeamCoHost then
		if rankId == 1 then
			player.Team = GetRandomTeam(TeamGroupA, TeamGroupB)
			print("Re-teamed " .. player.Name .. " from Co-Host to " .. player.Team.Name)
		elseif rankId == 10 then
			player.Team = GetRandomTeam(TeamGroupC, TeamGroupD)
			print("Re-teamed " .. player.Name .. " from Co-Host to " .. player.Team.Name)
		elseif rankId == 19 then
			player.Team = GetRandomTeam(TeamTrainer, TeamHelper)
			print("Re-teamed " .. player.Name .. " from Co-Host to " .. player.Team.Name)
		end
	end
end

local function onPlayerAdded(player)
	CheckAndTeamPlayer(player)

	player:GetPropertyChangedSignal("Team"):Connect(function()
		CheckAndTeamPlayer(player)
	end)
end

for _, player in Players:GetPlayers() do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
