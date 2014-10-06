# admob.show()

> --------------------- ------------------------------------------------------------------------------------------
> __Type__              [Function][api.type.Function]
> __Return value__      none
> __Revision__          [REVISION_LABEL](REVISION_URL)
> __Keywords__          ads, advertising, admob
> __See also__          [ads.hide()][plugin.ads-admob.hide]
>								[ads.init()][plugin.ads-admob.init]
>								[admob.*][plugin.ads-admob]
> --------------------- ------------------------------------------------------------------------------------------


## Overview

`ads.show()` begins showing ads at the specified screen location.


## Syntax

	ads.show( adUnitType [, params] )

##### adUnitType ~^(required)^~
_[String][api.type.String]._ The type of ad to show. AdMob supports either `"banner"` or `"interstitial"`.

##### params ~^(optional)^~
_[Table][api.type.Table]._ A table that specifies properties for the ad request — see the next section for details.


## Parameter Reference

The `params` table can include properties for the ad request.

##### x ~^(optional)^~
_[Number][api.type.Number]._ The left position of the ad. Defaults to `0`.

##### y ~^(optional)^~
_[Number][api.type.Number]._ The top position of the ad. Defaults to `0`.

##### interval ~^(optional)^~
_[Number][api.type.Number]._ The ad refresh time, in seconds.

##### appId ~^(optional)^~
_[String][api.type.String]._ The app ID. If this is not specified, the value provided to [ads.init()][plugin.ads-admob.init] is used instead.


## Example

``````lua
local ads = require( "ads" )

local function adListener( event )
	if ( event.isError ) then
		--Failed to receive an ad
	end
end
 
ads.init( "admob", "myAppId", adListener )

ads.show( "banner", { x=0, y=0, appId="otherAppId" } )
``````