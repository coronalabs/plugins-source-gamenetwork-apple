display.setStatusBar(display.HiddenStatusBar)

print('[main] Game Center Bugs')
print('...')

-- you need 2 game center working sandbox playerIDs
local playerOneID = 'G:1212836931' -- need valid playerID
local playerTwoID = 'G:1187401733' -- need valid playerID

local isGameNetworkLoggedIn = false
local gameNetwork = require('gameNetwork')


local function initGameCenterEventHandler(e)
    if(e.data == true) then
        isGameNetworkLoggedIn = true
    else
        isGameNetworkLoggedIn = false
    end
end

local function onSystemEvent(e)
    print('[main] e.type = ' .. tostring(e.type))
    if(e.type == 'applicationStart') then
        print('[main] onSystemEvent = applicationStart')
        gameNetwork.init('gamecenter', initGameCenterEventHandler) -- log into iOS game center
    end
    return true
end

Runtime:addEventListener('system', onSystemEvent)

local function requestloadLocalPlayerEventHandler(e)
    print('[main] requestloadLocalPlayerEventHandler()')
    print('[main] local player alias = ' .. tostring(e.data.alias))
    print('[main] local player playerID = ' .. tostring(e.data.playerID))
end

-- Show Matches below
local function onTouchShowMatchesNoCallbackBtn(e)
    if(e.phase == 'began') then
        display.getCurrentStage():setFocus(e.target)
        e.target:setButtonPhase(e.phase)
    elseif(e.phase == 'ended') then
        print('[main] show matches no callback button released')
        e.target:setButtonPhase(e.phase)
        display.getCurrentStage():setFocus(nil)
        if(isGameNetworkLoggedIn == true) then
            gameNetwork.request('loadLocalPlayer', {listener=requestloadLocalPlayerEventHandler}) -- get local player
            gameNetwork.show('matches', {minPlayers=2, maxPlayers=2}) -- show matches with no callback
        else
            native.showAlert('Game Center', 'Game Center is not logged in.', {"OK"})
        end
    end
    return true
end

local showMatchesNoCallbackBtn = require('SquareButton').new('Show GC Matches UI No Callback', 300, 44, 18)
showMatchesNoCallbackBtn.x = display.contentCenterX
showMatchesNoCallbackBtn.y = display.contentCenterY - 125
showMatchesNoCallbackBtn:addEventListener('touch', onTouchShowMatchesNoCallbackBtn)


--!!!!!!!!!!!!!!!!!!!!!  CRASHES WITH CALLBACK !!!!!!!!!!!!!!!!!!!
local function showMatchesEventHandler(e)
    print('[main] showMatchesEventHandler()')
    
    for k, v in pairs(e.data) do
        print('[main] e.data = ' .. tostring(k) .. ' = ' .. tostring(v))
    end
end

local function onTouchsShowMatchesCallbackBtn(e)
    if(e.phase == 'began') then
        display.getCurrentStage():setFocus(e.target)
        e.target:setButtonPhase(e.phase)
    elseif(e.phase == 'ended') then
        print('[main] show matches WITH callback button released')
        e.target:setButtonPhase(e.phase)
        display.getCurrentStage():setFocus(nil)
        if(isGameNetworkLoggedIn == true) then
            gameNetwork.show('matches', {minPlayers=2, maxPlayers=2, listener=showMatchesEventHandler})
        else
            native.showAlert('Game Center', 'Game Center is not logged in.', {"OK"})
        end
    end
    return true
end

local showMatchesCallbackBtn = require('SquareButton').new('Show GC Matches UI Callback', 300, 44, 18)
showMatchesCallbackBtn.x = display.contentCenterX
showMatchesCallbackBtn.y = display.contentCenterY - 40
showMatchesCallbackBtn:addEventListener('touch', onTouchsShowMatchesCallbackBtn)

--!!!!!!!!!!!!!!!!!!!!!  CRASHES WITH CALLBACK !!!!!!!!!!!!!!!!!!!
-- Show Create Match below
local function showCreateMatchEventHandler(e)
    print('[main] showCreateMatcheEventHandler()')
    print('[main] matchID = ' .. tostring(e.data.matchID))
    print('[main] status = ' .. tostring(e.data.status))
    print('...')
    print('[main] participants[1].status = ' .. tostring(e.data.participants[1].status))
    print('[main] participants[1].index = ' .. tostring(e.data.participants[1].index))
    print('[main] participants[1].playerID = ' .. tostring(e.data.participants[1].playerID))
    print('[main] participants[1].outcome = ' .. tostring(e.data.participants[1].outcome))
    print('...')
    print('[main] participants[2].status = ' .. tostring(e.data.participants[2].status))
    print('[main] participants[2].index = ' .. tostring(e.data.participants[2].index))
    print('[main] participants[2].playerID = ' .. tostring(e.data.participants[2].playerID))
    print('[main] participants[2].outcome = ' .. tostring(e.data.participants[2].outcome))
    print('...')
    print('[main] currentParticipant.status = ' .. tostring(e.data.currentParticipant.status))
    print('[main] currentParticipant.playerID = ' .. tostring(e.data.currentParticipant.playerID))
    print('[main] currentParticipant.outcome = ' .. tostring(e.data.currentParticipant.outcome))
    print('...')
    
    for k, v in pairs(e.data) do
        print('[main] e.data = ' .. tostring(k) .. ' = ' .. tostring(v))
    end
end

local function onTouchShowCreateMatchCallbackBtn(e)
    if(e.phase == 'began') then
        display.getCurrentStage():setFocus(e.target)
        e.target:setButtonPhase(e.phase)
    elseif(e.phase == 'ended') then
        print('[main] show create match button with callback released') 
        e.target:setButtonPhase(e.phase)
        display.getCurrentStage():setFocus(nil)
        if(isGameNetworkLoggedIn == true) then
            gameNetwork.show('createMatch', {playerIDs={playerOneID}, minPlayers=2, maxPlayers=2,
            inviteMessage='Its rematch time!', listener=showCreateMatchEventHandler})
        else
            native.showAlert('Game Center', 'Game Center is not logged in.', {"OK"})
        end
    end
    return true
end

local showCreateMatchCallbackBtn = require('SquareButton').new('Show GC Create Match UI Cb', 300, 44, 18)
showCreateMatchCallbackBtn.x = display.contentCenterX
showCreateMatchCallbackBtn.y = display.contentCenterY + 40
showCreateMatchCallbackBtn:addEventListener('touch', onTouchShowCreateMatchCallbackBtn)


-- ******* REQUEST CREATE MATCH BUG DOES NOT CREATE MATCH *******
-- Request Create Match below
local function requestCreateMatchEventHandler(e)
    print('[main] requestCreateMatcheEventHandler()')
    print('[main] matchID = ' .. tostring(e.data.matchID))
    print('[main] status = ' .. tostring(e.data.status))
    
    for k, v in pairs(e.data) do
        print('[main] e.data = ' .. tostring(k) .. ' = ' .. tostring(v))
    end
end


local function onTouchRequestCreateMatchCallbackBtn(e)
    if(e.phase == 'began') then
        display.getCurrentStage():setFocus(e.target)
        e.target:setButtonPhase(e.phase)
    elseif(e.phase == 'ended') then
        print('[main] request create match button with callback released') 
        e.target:setButtonPhase(e.phase)
        display.getCurrentStage():setFocus(nil)
        if(isGameNetworkLoggedIn == true) then
            -- request below with playerIDs does NOT create a new match on Game Center
            gameNetwork.request('createMatch', {playerIDs={playerOneID}, minPlayers=2, maxPlayers=2,
            listener=requestCreateMatchEventHandler})
            
    --        request below without playerIDs creates a new auto-match on Game Center
    --        gameNetwork.request('createMatch', {minPlayers=2, maxPlayers=2, listener=requestCreateMatchEventHandler})
        else
            native.showAlert('Game Center', 'Game Center is not logged in.', {"OK"})
        end
    end
    return true
end

local requestCreateMatchCallbackBtn = require('SquareButton').new('Request Create Match No GC UI', 300, 44, 18)
requestCreateMatchCallbackBtn.x = display.contentCenterX
requestCreateMatchCallbackBtn.y = display.contentCenterY + 125
requestCreateMatchCallbackBtn:addEventListener('touch', onTouchRequestCreateMatchCallbackBtn)
