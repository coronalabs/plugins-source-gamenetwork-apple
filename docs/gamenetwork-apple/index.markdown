
# Apple Game Center

> --------------------- ------------------------------------------------------------------------------------------
> __Type__              [Library][api.type.Library]
> __Revision__          [REVISION_LABEL](REVISION_URL)
> __Keywords__          gameNetwork, Game Center
> __Availability__      Starter, Basic, Pro, Enterprise
> __Platforms__			iOS
> --------------------- ------------------------------------------------------------------------------------------

## Overview

[Game Center](https://developer.apple.com/game-center/) lets friends in on the action with leaderboards and achievements. The nomenclature used in the Corona APIs for Game Center attempt to match the official Game Center APIs as much as possible, allowing you to <nobr>cross-reference</nobr> with official Game Center documentation.

## Gotchas

Game Center is not supported in the Corona Simulator.

## Syntax

	local gameNetwork = require( "gameNetwork" )

## Functions

#### [gameNetwork.init()][plugin.gameNetwork-apple.init]

#### [gameNetwork.request()][plugin.gameNetwork-apple.request]

#### [gameNetwork.show()][plugin.gameNetwork-apple.show]

## Project Settings

To use this plugin, add an entry into the `plugins` table of `build.settings`. When added, the build server will integrate the plugin during the build phase.

``````lua
settings =
{
	plugins =
	{
		["CoronaProvider.gameNetwork.apple"] =
		{
			publisherId = "com.coronalabs",
			supportedPlatforms = { iphone=true, ["iphone-sim"]=true },
		},
	},
}
``````

## Sample Code

Game Center turn-based multiplayer sample code can be found [here](https://github.com/coronalabs/gameNetwork-iOS-turnbased-multiplayer).

## Support

* [https://developer.apple.com/game-center/](https://developer.apple.com/game-center/)
* [Corona Forums](http://forums.coronalabs.com/forum/621-game-networking/)
