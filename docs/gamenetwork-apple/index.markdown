# admob.*

> --------------------- ------------------------------------------------------------------------------------------
> __Type__              [CoronaProvider][api.type.CoronaProvider]
> __Library__           [ads.*][api.library.ads]
> __Revision__          [REVISION_LABEL](REVISION_URL)
> __Keywords__          ads, advertising, admob
> __Availability__		Starter, Basic, Pro, Enterprise
> __Platforms__			Android, iOS
> --------------------- ------------------------------------------------------------------------------------------


## Overview

The AdMob plugin offers easy integration of AdMob ads using the [ads][api.library.ads] library and [ads.init()][plugin.ads-admob.init].


## Functions

#### [ads.init()][plugin.ads-admob.init]

#### [ads.show()][plugin.ads-admob.show]

#### [ads.hide()][plugin.ads-admob.hide]


## Project Settings

To use this plugin, add an entry into the `plugins` table of `build.settings`. When added, the build server will integrate the plugin during the build phase.

``````lua
settings =
{
	plugins =
	{
		["CoronaProvider.ads.admob"] =
		{
			publisherId = "com.coronalabs"
		},
	},		
}
``````

### Android

For Android, include the following in the `android` table of `build.settings`:

``````lua
	android =
	{
		usesPermissions =
		{
			"android.permission.INTERNET",
			"android.permission.ACCESS_NETWORK_STATE",
		},
	},
``````


## Sample

[https://github.com/coronalabs/plugins-sample-ads-admob/](https://github.com/coronalabs/plugins-sample-ads-admob)


## Support

* [http://www.google.com/ads/admob/](http://www.google.com/ads/admob/)
* [Corona Forums](http://forums.coronalabs.com/forum/545-monetization-in-app-purchases-ads-etc/)
