
# gameNetwork.*

> --------------------- ------------------------------------------------------------------------------------------
> __Type__              [Library][api.type.Library]
> __Revision__          [REVISION_LABEL](REVISION_URL)
> __Keywords__          gameNetwork, Game Center
> __Availability__      Starter, Basic, Pro, Enterprise
> __Platforms__			iOS
> --------------------- ------------------------------------------------------------------------------------------

## Overview

Corona's `gameNetwork` library provides access to social gaming features such as public leaderboards and achievements.

### Game Center

[Game Center](https://developer.apple.com/game-center/) (iOS) lets friends in on the action with leaderboards and achievements. For more information on Game Center integration, read our [tutorial](http://www.coronalabs.com/blog/2012/01/17/tutorial-game-center-integration-ios/) or the [Game&nbsp;Center&nbsp;Programming&nbsp;Guide](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/GameKit_Guide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008304). Note that the nomenclature used in the Corona APIs for Game Center attempt to match the official Game Center APIs as much as possible, allowing you to <nobr>cross-reference</nobr> with official Game Center documentation. Note that Game Center is not supported in the Corona Simulator.

## Functions

#### [gameNetwork.init()][plugin.gamenetwork-apple.init]

#### [gameNetwork.request()][plugin.gamenetwork-apple.request]

#### [gameNetwork.show()][plugin.gamenetwork-apple.show]

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