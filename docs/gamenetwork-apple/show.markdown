
# gameNetwork.show()

> --------------------- ------------------------------------------------------------------------------------------
> __Type__              [Function][api.type.Function]
> __Library__           [gameNetwork.*][api.library.gameNetwork]
> __Revision__          [REVISION_LABEL](REVISION_URL)
> __Keywords__          gameNetwork, Game Center
> __See also__          [gameNetwork.init()][plugin.gamenetwork-apple.init]
>								[gameNetwork.request()][plugin.gamenetwork-apple.request]
> --------------------- ------------------------------------------------------------------------------------------


## Overview

Displays the requested game network information to the user.


## Syntax

	gameNetwork.show( command [, params ] )

##### command ~^(required)^~
_[String][api.type.String]._ String value as supported by Game Center.

* `"leaderboards"`
* `"achievements"`
* `"friendRequest"`
* `"matches"`
* `"createMatch"`

##### params ~^(optional)^~
_[Table][api.type.Table]._ Table of parameters allowed by Game Center — see the next section for details.


## Parameter Reference

Depending on the specified `command` parameter, the contents of the `params` table will vary.

#### Listener Function

For all calls to `gameNetwork.show()`, the `params` table supports a `listener` key with its value as a callback function to monitor the call result, for example:

``````lua
gameNetwork.show( "achievements", { listener=showAchievements } )
``````

#### Leaderboards

For the `command` parameter of `"leaderboards"`, `"leaderboard"` is an optional key in the `params` table which in turn accepts another table. This table has key/value pairs which mimic the `GKLeaderboard` and `GKLeaderboardViewController` objects. The key `"timeScope"` accepts a string value of either `"Today"`, `"Week"`, or `"AllTime"`.

``````lua
gameNetwork.show( "leaderboards", { leaderboard={ timeScope="Week" }, listener=showLeaders } )
``````

#### Friend Request

For the `command` parameter of `"friendRequest"`, the `params` table may contain the following optional keys:

* `message` — String value which pre-populates the message field with custom text.

* `playerIDs` — Array of strings of Game Center player IDs representing the players you want to send a friend request to.

* `emailAddresses` — Array of strings representing email addresses of players you want to send a friend request to.

``````lua
local parameters = {
	message = "Be my friend please",
	playerIDs = { "G:194669300", "G:1435127232" },
	emailAddresses = { "me@me.com" },
	listener = requestFriends
}
gameNetwork.show( "friendRequest", parameters )
``````

Note that the total number of player IDs and email addresses must not exceed the Game Center maximum limit or the OS will throw an exception. You can read this limit by calling `gameNetwork.request( "loadFriendRequestMaxNumberOfRecipients" )`.

#### Matches

For the `command` parameter of `"matches"`, the required keys in the `params` table are:

* `minPlayers` — Number which specifies the minimum number of players in a multiplayer game.

* `maxPlayers` — Number which specifies the maximum number of players in a multiplayer game.

* `playerGroup` — The game type that will be shown, according to the type created for the match (see&nbsp;next&nbsp;section).

``````lua
local parameters = {
	minPlayers = 2,   --minimum number of players is 2
	maxPlayers = 3,   --this number be greater than or equal to 'minPlayers'
	playerGroup = 2,  --the game type that will be shown
	listener = showMatches
}
gameNetwork.show( "matches", parameters )
``````

#### Create Match

For the `command` parameter of `"createMatch"`, this function shows the Game Center match creation screen which allows players to manage their match. The following keys listed below are accepted in the `params` table:

* `playerIDs` — Optional array of strings representing the player IDs of people to invite to the match.

* `minPlayers` — Optional value for the minimum number of players required in the match.

* `maxPlayers` — Optional value for the maximum number of players allowed in the match.

* `playerGroup` — The game type which will be created, for example a quick game or long game. Only players whose requests share the same `playerGroup` value are <nobr>auto-matched</nobr> by Game Center.

* `playerAttributes` — Mask that specifies the role that the local player would like to play in the game.

* `inviteMessage` — Custom invitation message for the match.

``````lua
local parameters = {
	playerIDs = { "w4o98y3498hg349h", "wrighfq547hg543" },  --required
	minPlayers = 2,
	maxPlayers = 3,
	playerGroup = 1,
	playerAttributes = { 1, 4, 6 },
	inviteMessage = "Hi, please join our match!",
	listener = createNewMatch
}
gameNetwork.show( "createMatch", parameters )
``````


## Example

`````lua
local function onGameNetworkPopupDismissed( event )
	-- Game Center popup was closed
	for k,v in pairs( event ) do
		print( k,v )
	end
end


-- Display a leaderboard
gameNetwork.show( "leaderboards", { leaderboard={ timeScope="Week" }, listener=onGameNetworkPopupDismissed } )


-- Display the player's achievements
gameNetwork.show( "achievements", { listener=onGameNetworkPopupDismissed } )


-- Display a friend request popup
local friendRequestParams = {
	message = "Let's match up in GameCenter!",
	playerIDs = { "G:194669300", "G:1435127232" },
	emailAddresses = { "me@me.com" },
	listener = onGameNetworkPopupDismissed
}
gameNetwork.show( "friendRequest", friendRequestParams )


-- Display a popup which shows the current matches and also allows the user to create matches
local matchesParams = {
	minPlayers = 2,   --minimum number of players is 2
	maxPlayers = 3,   --this number be greater than or equal to 'minPlayers'
	playerGroup = 2,  --the game type that will be shown
	listener = onGameNetworkPopupDismissed
}
gameNetwork.show( "matches", matchesParams )


-- Display a popup which lets the user invite other players to a game
local createMatchParams = {
	playerIDs = { "w4o98y3498hg349h", "wrighfq547hg543" },
	minPlayers = 2,
	maxPlayers = 3,
	playerGroup = 1,
	playerAttributes = { 1, 4, 6 },
	inviteMessage = "Hi, please join our match!",
	listener=requestCallback
}
gameNetwork.show( "createMatch", createMatchParams )
`````