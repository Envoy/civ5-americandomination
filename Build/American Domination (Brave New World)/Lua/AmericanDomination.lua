-- AmericanDomination
-- Author: Envoy
-- DateCreated: 4/18/2013 6:02:48 PM
--------------------------------------------------------------
include( "SaveUtils.lua" ); MY_MOD_NAME = "AmericanDomination";
--include( "CustomNotification.lua" );
--LuaEvents.NotificationAddin({ name = "UnitedPatriotism", type = "CNOTIFICATION_UNITED_PATRIOTISM"});
--------------------------------------------------------------

-- OK TO MODIFY
gWeLoveTheKingTurns = 20;

-- DO NOT MODIFY
gDataLoaded = false;
gAmericanPlayer = nil;
gAmericanTeamWarAttackerList = {};
gAmericanTeamWarDefenderList = {};

print("Initted.");

function AmericanDominationInit()
	if not gDataLoaded then
		print("Loading data...");	
		local americanPlayer = GetAmericanPlayer();
		if americanPlayer == nil then
			return;
		end
		
		gAmericanTeamWarAttackerList = load(americanPlayer, "gAmericanTeamWarAttackerList") or {};
		gAmericanTeamWarDefenderList = load(americanPlayer, "gAmericanTeamWarDefenderList") or {};
		PrintWarState();
		print("Data loaded.");
		gDataLoaded = true;
	end
end
Events.SequenceGameInitComplete.Add( AmericanDominationInit );

function WarStateChangedHandler( iTeam1, iTeam2, bWar )
	local americanPlayer = GetAmericanPlayer();
	if americanPlayer == nil then
		return;
	end
	local americanTeamId = americanPlayer:GetTeam();

	-- skip if America is not involved in this war state change
	if iTeam1 ~= americanTeamId and iTeam2 ~= americanTeamId then	
		return;
	end
	
	local team1 = Teams[iTeam1];
	local team2 = Teams[iTeam2];
	--print("team 1", iTeam1);
	--print("team 1", team1:GetName());
	--print("team 2", iTeam2);
	--print("team 2", team2:GetName());
	--print("war?", bWar);
	
	-- peace, clear war flags, do we love the king day
	if not bWar then
		if iTeam1 == americanTeamId and IsAmericaAtWarAgainst(iTeam2) then
			gAmericanTeamWarAttackerList[iTeam2] = nil;
			gAmericanTeamWarDefenderList[iTeam2] = nil;			
			SaveWarState();
			DoWeLoveTheKingDay();			
			print("america at peace with", iTeam2);
		elseif iTeam2 == americanTeamId and IsAmericaAtWarAgainst(iTeam1) then
			gAmericanTeamWarAttackerList[iTeam1] = nil;
			gAmericanTeamWarDefenderList[iTeam1] = nil;			
			SaveWarState();
			DoWeLoveTheKingDay();
			print("america at peace with", iTeam1);
		end				
		return;
	end
	
	-- war
	local declaredOn = false;
	
	if iTeam1 == americanTeamId then
		local atWar = gAmericanTeamWarDefenderList[iTeam2] ~= nil;
		if not atWar then
			gAmericanTeamWarAttackerList[iTeam2] = true;
			SaveWarState();
		end
	elseif iTeam2 == americanTeamId then	
		-- already at war?
		local atWar = gAmericanTeamWarAttackerList[iTeam1] ~= nil;
		if not atWar then
			-- we got declared on
			declaredOn = true;
			gAmericanTeamWarDefenderList[iTeam1] = true;
			SaveWarState();
			print("american declared on");
		end		
	end		
		
	-- if declared on, do golden age
	if declaredOn then
		local header = 'The American people rise and unite to defend their Empire!';
		local message = 'The American Empire has entered a special double-length [ICON_GOLDEN_AGE] Golden Age.';		
		local notificationTable = {{"Civ1", americanPlayer:GetID(), 80, false, 0}};
		americanPlayer:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, message, header);
		--CustomNotification("UnitedPatriotism", header, message, 0, 0, 0, notificationTable);		
		DoGoldenAge();
	end	
		
end
Events.WarStateChanged.Add( WarStateChangedHandler );

-- Clear dead teams from the list of teams that America is at war with
function ClearDeadTeams(iPlayer)	
	local americanPlayer = GetAmericanPlayer();
	if americanPlayer == nil then
		return;
	end
		
	if americanPlayer:GetID() == iPlayer then
		print("ClearDeadTeams");		
		for teamNum = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
			local team = Teams[teamNum];
			if team ~= nil then
				--print("team", team:GetName());
				--print("team id", team:GetID());
				--print("alive?", team:IsAlive());
				
				-- Eliminated a team that had declared war on America
				if not team:IsAlive() and IsAmericaDefendingAtWarAgainst(team:GetID()) then
					gAmericanTeamWarDefenderList[team:GetID()] = nil;					
					--print("cleared team america was defending against", team:GetID());
					SaveWarState();
					DoWeLoveTheKingDay();
				-- Eliminated a team that America had declared war on
				elseif not team:IsAlive() and IsAmericaAttackingAtWarAgainst(team:GetID()) then
					gAmericanTeamWarAttackerList[team:GetID()] = nil;
					--print("cleared team america was attacking", team:GetID());					
					SaveWarState();
					DoWeLoveTheKingDay();
				end
			end
		end
	end
	
end
GameEvents.PlayerDoTurn.Add( ClearDeadTeams );

--
-- HELPER FUNCTIONS
--

-- Save war state for compatibiility across saved games
function SaveWarState()
	local americanPlayer = GetAmericanPlayer();
	if americanPlayer == nil then
		return;
	end
	print("SaveWarState");
	
	--PrintWarState();
	save(americanPlayer, "gAmericanTeamWarAttackerList", gAmericanTeamWarAttackerList);
	save(americanPlayer, "gAmericanTeamWarDefenderList", gAmericanTeamWarDefenderList);
end

-- Start double-length golden age for America
function DoGoldenAge()
	local americanPlayer = GetAmericanPlayer();
	if americanPlayer == nil then
		return;
	end
	
	print("DoGoldenAge");
	-- grant double-length golden age
	local goldenAgeLength = americanPlayer:GetGoldenAgeLength();		
	americanPlayer:ChangeGoldenAgeTurns(2 * goldenAgeLength);
end

-- Start we love the king day in all American cities. War WLTKD do not stack.
function DoWeLoveTheKingDay() 
	local americanPlayer = GetAmericanPlayer();
	if americanPlayer == nil then
		return;
	end
	print("DoWeLoveTheKingDay");
	
	for city in americanPlayer:Cities() do
		local kingTurnsToAward = gWeLoveTheKingTurns;
		local currentWeLoveTheKingTurns = city:GetWeLoveTheKingDayCounter();		
		if currentWeLoveTheKingTurns < kingTurnsToAward then
			city:ChangeWeLoveTheKingDayCounter(kingTurnsToAward - currentWeLoveTheKingTurns);
			city:SetResourceDemanded(-1);
		end
	end
	
	-- send notification	
	local header = 'The American people celebrate the end of the war!';
	local message = 'The ending of the war causes all of your cities to enter "We Love the King Day", giving them a [ICON_FOOD] growth bonus!';	
	local notificationTable = {{"Civ1", americanPlayer:GetID(), 80, false, 0}};
	americanPlayer:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, message, header);
	--CustomNotification("UnitedPatriotism", header, message, 0, 0, 0, notificationTable);		
end

-- Is America in any wars?
function IsAmericaAtWar()
	return IsAmericaDefendingAtWar() or IsAmericaAttackingAtWar();
end

-- Is America in any wars against a certain team?
function IsAmericaAtWarAgainst(teamId)
	return IsAmericaDefendingAtWarAgainst(teamId) or IsAmericaAttackingAtWarAgainst(teamId);
end

-- Is America at war against an agressor?
function IsAmericaDefendingAtWar() 
	--print("IsAmericaDefendingAtWar");
	for teamNum = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
		local team = Teams[teamNum];
		if team ~= nil then
			if IsAmericaDefendingAtWarAgainst(team:GetID()) then
				return true;
			end		
		end
	end
	
	return false;
end

-- Is America at war against a specific agressor?
function IsAmericaDefendingAtWarAgainst(teamId)
	--print("IsAmericaDefendingAtWarAgainst");
	return gAmericanTeamWarDefenderList[teamId] ~= nil;
end

-- Is America at war against someone they attacked?
function IsAmericaAttackingAtWar() 
	--print("IsAmericaAtWar");
	for teamNum = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
		local team = Teams[teamNum];
		if team ~= nil then
			--print("team", team:GetName());
			--print("team id", team:GetID());
			if IsAmericaAttackingAtWarAgainst(team:GetID()) then
				return true;
			end		
		end
	end
	
	return false;
end

-- Is America at war against a specific team they attacked?
function IsAmericaAttackingAtWarAgainst(teamId)
	--print("IsAmericaAtWarAgainst");
	return gAmericanTeamWarAttackerList[teamId] ~= nil;
end

-- Retrieve the American player and store it as a global
function GetAmericanPlayer()
	if gAmericanPlayer == nil then	
		for playerNum = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
			local player = Players[playerNum];			
			if player ~= nil and player:GetCivilizationShortDescriptionKey() == "TXT_KEY_CIV_AMERICA_SHORT_DESC" then
				gAmericanPlayer = player;
				break;
			end
		end
	end
	
	return gAmericanPlayer;
end

-- Print the stored war states for America
function PrintWarState()
	for teamNum = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
		local team = Teams[teamNum];
		if team ~= nil then			
			print("Team " .. team:GetID() .. " - " .. team:GetName() .. ": Attacking? " .. tostring(IsAmericaAttackingAtWarAgainst(team:GetID())) .. ", Defender? " .. tostring(IsAmericaDefendingAtWarAgainst(team:GetID())))
		end
	end
end