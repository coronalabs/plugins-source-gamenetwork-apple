#!/bin/bash -e

PLUGIN="CoronaProvider.gameNetwork.apple"
PUBLISHER="com.coronalabs"

path=$(cd "$(dirname "$0")"; pwd)
repoRoot=$(cd "$path/.."; pwd)

(
	set -e
	cd "$path"

	./build.sh
	cd BuiltPlugin

	# Copy Lua files into each platform directory before packaging
	for platform in *
	do
	    if [ "$platform" != "universal" ] && [ -d "$platform" ]
	    then
	        cp "$repoRoot/Corona/gameNetwork.lua" "$platform/gameNetwork.lua"
	        mkdir -p "$platform/CoronaProvider"
	        cp "$repoRoot/Corona/CoronaProvider/gameNetwork.lua" "$platform/CoronaProvider/gameNetwork.lua"
	    fi
	done

	for platform in *
	do
	    if [ "$platform" != "universal" ] && [ -d "$platform" ]
	    then
	    (
	        cd "$platform"
	        tarPath="$HOME/Solar2DPlugins/$PUBLISHER/$PLUGIN/$platform"
	        rm -rf "$tarPath"
	        mkdir -p "$tarPath"
	        COPYFILE_DISABLE=1 tar -czvf "$tarPath/data.tgz" -- * || echo "Errored on $PUBLISHER/$PLUGIN/$platform"
	    )
		fi
	done
)

echo
echo '== Deploy Complete =='
echo "Installed to: ~/Solar2DPlugins/$PUBLISHER/$PLUGIN"
echo
echo '== !!! IMPORTANT !!! =='
echo "Make sure to delete plugin when done: ~/Solar2DPlugins/$PUBLISHER/$PLUGIN"
echo "This plugin will override any Solar2D plugin from any other source"
echo
