-- {steamID, points, source}
local players = {}

-- {steamID}
local waiting = {}

-- {steamID}
local connecting = {}

-- Points initiaux (prioritaires ou négatifs)
local prePoints = Config.Points;

-- Emojis pour la loterie
local EmojiList = Config.EmojiList

local pCards = {}
local buttonCreate = {}

local IdentifierTables = {
    {table = "users", column = "identifier"},
    {table = "user_accounts", column = "identifier"},
    {table = "user_inventory", column = "identifier"},
    {table = "user_licenses", column = "owner"},
    {table = "characters", column = "identifier"},
    {table = "billing", column = "identifier"},
    {table = "rented_vehicles", column = "owner"},
    {table = "addon_account_data", column = "owner"},
    {table = "addon_inventory_items", column = "owner"},
    {table = "datastore_data", column = "owner"}, 
    {table = "society_moneywash", column = "identifier"},
    {table = "lspd_user_judgments", column = "userId"},
    {table = "lspd_mdc_user_notes", column = "userId"},
    {table = "owned_vehicles", column = "owner"}, 
    {table = "owned_properties", column = "owner"}, 
    {table = "user_inventory", column = "identifier"},
    {table = "phone_calls", column = "owner"}, 
    --{table = "phone_messages", column = "owner"}, 
    {table = "playersTattoos", column = "identifier"},     
    {table = "d_user_peds", column = "identifier"},  
}


local not_found = {
    ["type"] = "AdaptiveCard",
    ["minHeight"] = "auto",
    ["body"] = {
            {
                    ["type"] = "ColumnSet",
                    ["columns"] = {
                            {
                                    ["type"] = "Column",
                                    ["items"] = {
                                            {
                                                    ["type"] = "TextBlock",
                                                    ["text"] = "Nie posiadasz konta!\nPołącz się aby stworzyć postać.",
                                                    ["size"] = "small",
                                                    ["horizontalAlignment"] = "left"
                                            },
                                    }
                            },
                    }
            }
    },
    ["actions"] = {},
    ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
    ["version"] = "1.0"
}

StopResource('hardcap')

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if GetResourceState('hardcap') == 'stopped' then
			StartResource('hardcap')
		end
	end
end)

-- Connexion d'un client
AddEventHandler("playerConnecting", function(name, reject, def)
	local source	= source
	local steamID = GetSteamID(source)

	-- pas de steam ? ciao
	if not steamID then
		reject(Config.NoSteam)
		CancelEvent()
		return
	end

	-- Lancement de la rocade, 
	-- si cancel du client : CancelEvent() pour ne pas tenter de co.
	if not Rocade(steamID, def, source) then
		CancelEvent()
	end
end)

-- Fonction principale, utilise l'objet "deferrals" transmis par l'evenement "playerConnecting"
function Rocade(steamID, def, source)
	-- retarder la connexion
	def.defer()

	-- faire patienter un peu pour laisser le temps aux listes de s'actualiser
	AntiSpam(def)

	-- retirer notre ami d'une éventuelle liste d'attente ou connexion
	Purge(steamID)

	-- l'ajouter aux players
	-- ou actualiser la source
	AddPlayer(steamID, source)

	-- le mettre en file d'attente
	table.insert(waiting, steamID)

	-- tant que le steamID n'est pas en connexion
	local stop = false
	repeat

		for i,p in ipairs(connecting) do
			if p == steamID then
				stop = true
				break
			end
		end

	-- Hypothèse: Quand un joueur en file d'attente a un ping = 0, ça signifie que la source est perdue

	-- Détecter si l'user clique sur "cancel"
	-- Le retirer de la liste d'attente / connexion
	-- Le message d'accident ne devrait j'amais s'afficher
		for j,sid in ipairs(waiting) do
			for i,p in ipairs(players) do
				-- Si un joueur en file d'attente a un ping = 0
				if sid == p[1] and p[1] == steamID and (GetPlayerPing(p[3]) == 0) then
					-- le purger
					Purge(steamID)
					-- comme il a annulé, def.done ne sert qu'à identifier un cas non géré
					def.done(Config.Accident)

					return false
				end
			end
		end

		-- Mettre à jour le message d'attente
		def.update(GetMessage(steamID))

		Citizen.Wait(Config.TimerRefreshClient * 1000)

	until stop
	local player = source
    def.update("Sprawdzanie konta...")
    Citizen.Wait(600)
    local LastCharId = GetLastCharacter(player)
    SetIdentifierToChar(GetPlayerIdentifiers(player)[1], LastCharId)
    local steamid = GetPlayerIdentifiers(player)[1]
    local id = string.gsub(steamid, "steam", "")
    pCards[steamid] = {}
    MySQL.Async.fetchAll("SELECT * FROM `users` WHERE `identifier` LIKE '%"..id.."%'", {
    }, function(result)
        MySQL.Async.fetchAll("SELECT * FROM `neey_chars` WHERE `identifier` = @identifier",  {
            ['@identifier'] = steamid
        }, function(result2)
            if result2[1] ~= nil then
                return
            else
                MySQL.Async.execute(
                    'INSERT INTO `neey_chars`(`identifier`) VALUES (@identifier)',
                    {
                        ['@identifier'] = GetPlayerIdentifiers(player)[1]
                    }
                )
            end
        end)
        if (result[1] ~= nil) then
            if #result[1] < 2 then
                MySQL.Async.execute(
                    'UPDATE `user_lastcharacter` SET `charid`= 1 WHERE `steamid` = @identifier',
                    {
                        ['@identifier'] = GetPlayerIdentifiers(player)[1]
                    }
                )      
            end
            local Characters = GetPlayerCharacters(player)
            pCards[steamid] = {
                ["type"] = "AdaptiveCard",
                ["minHeight"] = "auto",
                --["backgroundImage"] = "https://i.imgur.com/WTun0SK.png",
                ["body"] = {
                        {
                                ["type"] = "ColumnSet",
                                ["columns"] = {
                                        {
                                                ["type"] = "Column",
                                                ["items"] = {
                                                        {
                                                                ["type"] = "TextBlock",
                                                                ["text"] = "Imię i nazwisko postaci",
                                                                ["size"] = "small",
                                                                ["horizontalAlignment"] = "left"
                                                        },
                                                        {
                                                                ["type"] = "Input.ChoiceSet",
                                                                ["choices"] = {},
                                                                ["style"] = "expanded",
                                                                ["id"] = "char_id",
                                                                ["value"] = "char1"
                                                        }
                                                }
                                        },
                                        {
                                                ["type"] = "Column",
                                                ["items"] = {
                                                {
                                                        ["type"] = "TextBlock",
                                                        ["text"] = "Pozycja",
                                                        ["size"] = "small",
                                                        ["horizontalAlignment"] = "left"
                                                },
                                                {
                                                        ["type"] = "Input.ChoiceSet",
                                                        ["choices"] = {
                                                                {
                                                                        ["title"] = "Ostatnia pozycja",
                                                                        ["value"] = "lastPosition"
                                                                },
                                                        },
                                                        ["style"] = "expanded",
                                                        ["id"] = "spawnPoint",
                                                        ["value"] = "lastPosition"
                                                }
                                                }
                                        }
                                }
                        }
                },
                ["actions"] = {},
                ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
                ["version"] = "1.0"
            }
            local limit = MySQLAsyncExecute("SELECT * FROM `neey_chars` WHERE `identifier` = '"..GetPlayerIdentifiers(player)[1].."'")
            if limit[1].limit > 1 then
                if #result < 2 then
                    buttonCreate = {
                        {
                            ["type"] = "Action.Submit",
                            ["title"] = "Połącz"
                        },
                        {
                            ["type"] = "Action.Submit",
                            ["title"] = "Stwórz postać",
                            ["data"] = {
                                ["x"] = "setupChar"
                            }
                        },
                    }
                else
                    buttonCreate = {
                        {
                                ["type"] = "Action.Submit",
                                ["title"] = "Połącz"
                        },
                    }
                end
            else 
                buttonCreate = {
                    {
                            ["type"] = "Action.Submit",
                            ["title"] = "Połącz"
                    },
                }
            end
            for k,v in ipairs(Characters) do
                if result[k].firstname ~= '' then
                    local data = {
                            ["title"] = result[k].firstname .. ' ' .. result[k].lastname,
                            ["value"] = "char"..k,
                    }
                    pCards[steamid].body[1].columns[1].items[2].choices[k] = data
                else
                    local data = {
                        ["title"] = 'Dokończ rejestrację postaci!',
                        ["value"] = "char"..k,
                    }
                pCards[steamid].body[1].columns[1].items[2].choices[k] = data
                end
            end
            pCards[steamid].actions = buttonCreate
            def.presentCard(pCards[steamid], function(submittedData, rawData)
                if submittedData.x ~= nil then
                    local idc = string.gsub(steamid, "steam", "Char2")
                    MySQL.Async.execute('INSERT INTO users (`identifier`, `money`, `bank`, `group`, `permission_level`, `license`) VALUES ("'..idc..'", 0, 100000, "user", 0, "'..GetPlayerIdentifiers(player)[2]..'")')
                    TriggerEvent("neey_characters:chosen", player, '2')
                    pCards[steamid] = 0
                    def.done()
                else
                    local char_id = submittedData.char_id
                    local char = string.gsub(char_id, "char", "")
                    TriggerEvent("neey_characters:chosen", player, char)
                    pCards[steamid] = 0
                    def.done()
                end
            end)
        else
            local buttonCreate = {
                {
                        ["type"] = "Action.Submit",
                        ["title"] = "Połącz"
                },
            }
            not_found.actions = buttonCreate
            def.presentCard(not_found, function(submittedData, rawData)
                def.done()
            end)
        end
    end)
	return true
end

-- Vérifier si une place se libère pour le premier de la file
Citizen.CreateThread(function()
	local maxServerSlots = GetConvarInt('sv_maxclients', 100)
	
	while true do
		Citizen.Wait(Config.TimerCheckPlaces * 1000)

		CheckConnecting()

		-- si une place est demandée et disponible
		if #waiting > 0 and #connecting + #GetPlayers() < maxServerSlots then
			ConnectFirst()
		end
	end
end)


Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5000)
		SetHttpHandler(function(req, res)
			local path = req.path
			if req.path == '/count' then
				res.send(json.encode({
					count = #waiting
				}))
				return
			end
		
		end)
	end
end)
-- Mettre régulièrement les points à jour
Citizen.CreateThread(function()
	while true do
		UpdatePoints()

		Citizen.Wait(Config.TimerUpdatePoints * 1000)
	end
end)

-- Lorsqu'un joueur est kick
-- lui retirer le nombre de points fourni en argument
RegisterServerEvent("rocademption:playerKicked")
AddEventHandler("rocademption:playerKicked", function(src, points)
	local sid = GetSteamID(src)

	Purge(sid)

	for i,p in ipairs(prePoints) do
		if p[1] == sid then
			p[2] = p[2] - points
			return
		end
	end

	local initialPoints = GetInitialPoints(sid)

	table.insert(prePoints, {sid, initialPoints - points})
end)

-- Quand un joueur spawn, le purger
RegisterServerEvent("rocademption:playerConnected")
AddEventHandler("rocademption:playerConnected", function()
	local sid = GetSteamID(source)

	Purge(sid)
end)

-- Quand un joueur drop, le purger
AddEventHandler("playerDropped", function(reason)
	local steamID = GetSteamID(source)

	Purge(steamID)
end)

-- si le ping d'un joueur en connexion semble partir en couille, le retirer de la file
-- Pour éviter un fantome en connexion
function CheckConnecting()
	for i,sid in ipairs(connecting) do
		for j,p in ipairs(players) do
			if p[1] == sid and (GetPlayerPing(p[3]) == 500) then
				table.remove(connecting, i)
				break
			end
		end
	end
end

-- ... connecte le premier de la file
function ConnectFirst()
	if #waiting == 0 then return end

	local maxPoint = 0
	local maxSid = waiting[1][1]
	local maxWaitId = 1

	for i,sid in ipairs(waiting) do
		local points = GetPoints(sid)
		if points > maxPoint then
			maxPoint = points
			maxSid = sid
			maxWaitId = i
		end
	end
	
	table.remove(waiting, maxWaitId)
	table.insert(connecting, maxSid)
end

-- retourne le nombre de kilomètres parcourus par un steamID
function GetPoints(steamID)
	for i,p in ipairs(players) do
		if p[1] == steamID then
			return p[2]
		end
	end
end

-- Met à jour les points de tout le monde
function UpdatePoints()
	for i,p in ipairs(players) do

		local found = false

		for j,sid in ipairs(waiting) do
			if p[1] == sid then
				p[2] = p[2] + Config.AddPoints
				found = true
				break
			end
		end

		if not found then
			for j,sid in ipairs(connecting) do
				if p[1] == sid then
					found = true
					break
				end
			end
		
			if not found then
				p[2] = p[2] - Config.RemovePoints
				if p[2] < GetInitialPoints(p[1]) - Config.RemovePoints then
					Purge(p[1])
					table.remove(players, i)
				end
			end
		end

	end
end

function AddPlayer(steamID, source)
	for i,p in ipairs(players) do
		if steamID == p[1] then
			players[i] = {p[1], p[2], source}
			return
		end
	end

	local initialPoints = GetInitialPoints(steamID)
	table.insert(players, {steamID, initialPoints, source})
end

function GetInitialPoints(steamID)
	local points = Config.RemovePoints + 1

	for n,p in ipairs(prePoints) do
		if p[1] == steamID then
			points = p[2]
			break
		end
	end

	return points
end

function GetPlace(steamID)
	local points = GetPoints(steamID)
	local place = 1

	for i,sid in ipairs(waiting) do
		for j,p in ipairs(players) do
			if p[1] == sid and p[2] > points then
				place = place + 1
			end
		end
	end
	
	return place
end

function GetMessage(steamID)
	local msg = ""
	local witam = "NIE" 
	local rodzajbiletu = 'Standard 📜'
	if GetPoints(steamID) ~= nil then
		if GetPoints(steamID) > 1500 then
			rodzajbiletu = 'Bronze ticket 🧹'
		end
		if GetPoints(steamID) > 2500 then
			rodzajbiletu = 'Golden ticket 📀'
		end
		if GetPoints(steamID) > 4200 then
			rodzajbiletu = 'Platinum ticket 💎'
		end
		if GetPoints(steamID) > 5000 then
			rodzajbiletu = 'Kasjan bilet'
		end
		if GetPoints(steamID) > 5500 then
			rodzajbiletu = 'Admin ticket 💣'
		end
		
		msg = '\n\n' .. Config.EnRoute .. " " .. " Rodzaj biletu: " .. rodzajbiletu ..".\n"

		msg = msg .. Config.Position .. GetPlace(steamID) .. "/".. #waiting .. " " .. ".\n"

		msg = msg .. "-- ( " .. Config.EmojiMsg

		local e1 = RandomEmojiList()
		local e2 = RandomEmojiList()
		local e3 = RandomEmojiList()
		local emojis = e1 .. e2 .. e3

		if( e1 == e2 and e2 == e3 ) then
			emojis = emojis .. Config.EmojiBoost
			LoterieBoost(steamID)
		end

		-- avec les jolis emojis
		msg = msg .. emojis .. " ) --"
	else
		msg = Config.Error
	end

	return msg
end

function LoterieBoost(steamID)
	for i,p in ipairs(players) do
		if p[1] == steamID then
			p[2] = p[2] + Config.LoterieBonusPoints
			return
		end
	end
end

function Purge(steamID)
	for n,sid in ipairs(connecting) do
		if sid == steamID then
			table.remove(connecting, n)
		end
	end

	for n,sid in ipairs(waiting) do
		if sid == steamID then
			table.remove(waiting, n)
		end
	end
end

function AntiSpam(def)
	for i=Config.AntiSpamTimer,0,-1 do
		def.update(Config.PleaseWait_1 .. i .. Config.PleaseWait_2)
		Citizen.Wait(1000)
	end
end

function RandomEmojiList()
	randomEmoji = EmojiList[math.random(#EmojiList)]
	return randomEmoji
end

-- Helper pour récupérer le steamID or false
function GetSteamID(src)
	local sid = GetPlayerIdentifiers(src)[1] or false

	if (sid == false or sid:sub(1,5) ~= "steam") then
		return false
	end

	return sid
end

RegisterServerEvent("neey_characters:chosen")
AddEventHandler("neey_characters:chosen", function(source, charid)
    local _source = source
    SetLastCharacter(source, charid)
    SetCharToIdentifier(GetPlayerIdentifiers(source)[1], tonumber(charid))
end)

function GetPlayerCharacters(source)
  local identifier = GetIdentifierWithoutSteam(GetPlayerIdentifiers(source)[1])
  local Chars = MySQLAsyncExecute("SELECT * FROM `users` WHERE identifier LIKE '%"..identifier.."%'")
  for i = 1, #Chars, 1 do
    charJob = MySQLAsyncExecute("SELECT * FROM `jobs` WHERE `name` = '"..Chars[i].job.."'")
    charJobgrade = MySQLAsyncExecute("SELECT * FROM `job_grades` WHERE `grade` = '"..Chars[i].job_grade.."'")
    Chars[i].job = charJob[1].label
    Chars[i].job_grade = charJobgrade[1].label
  end
  return Chars
end

function GetLastCharacter(source)
    local LastChar = MySQLAsyncExecute("SELECT `charid` FROM `user_lastcharacter` WHERE `steamid` = '"..GetPlayerIdentifiers(source)[1].."'")
    if LastChar[1] ~= nil and LastChar[1].charid ~= nil then
        return tonumber(LastChar[1].charid)
    else
        MySQLAsyncExecute("INSERT INTO `user_lastcharacter` (`steamid`, `charid`) VALUES('"..GetPlayerIdentifiers(source)[1].."', 1)")
        return 1
    end
end

function SetLastCharacter(source, charid)
    MySQLAsyncExecute("UPDATE `user_lastcharacter` SET `charid` = '"..charid.."' WHERE `steamid` = '"..GetPlayerIdentifiers(source)[1].."'")
end

function SetIdentifierToChar(identifier, charid)
    for _, itable in pairs(IdentifierTables) do
        MySQLAsyncExecute("UPDATE `"..itable.table.."` SET `"..itable.column.."` = 'Char"..charid..GetIdentifierWithoutSteam(identifier).."' WHERE `"..itable.column.."` = '"..identifier.."'")
    end
end

function SetCharToIdentifier(identifier, charid)
    for _, itable in pairs(IdentifierTables) do
        MySQLAsyncExecute("UPDATE `"..itable.table.."` SET `"..itable.column.."` = '"..identifier.."' WHERE `"..itable.column.."` = 'Char"..charid..GetIdentifierWithoutSteam(identifier).."'")
    end
end

function DeleteCharacter(identifier, charid)
    for _, itable in pairs(IdentifierTables) do
        MySQLAsyncExecute("DELETE FROM `"..itable.table.."` WHERE `"..itable.column.."` = 'Char"..charid..GetIdentifierWithoutSteam(identifier).."'")
    end
end

function GetSpawnPos(source)
    local SpawnPos = MySQLAsyncExecute("SELECT `position` FROM `users` WHERE `identifier` = '"..GetPlayerIdentifiers(source)[1].."'")
    return json.decode(SpawnPos[1].position)
end

function GetIdentifierWithoutSteam(Identifier)
    return string.gsub(Identifier, "steam", "")
end

function MySQLAsyncExecute(query)
    local IsBusy = true
    local result = nil
    MySQL.Async.fetchAll(query, {}, function(data)
        result = data
        IsBusy = false
    end)
    while IsBusy do
        Citizen.Wait(0)
    end
    return result
end

RegisterCommand("deletechar", function(source, args, rawCommand)
    if (source > 0) then
        return
    else
        if args[1] ~= nil then
            if args[2] ~= nil then
                DeleteCharacter(args[1], args[2])
            end
        end
    end
end)