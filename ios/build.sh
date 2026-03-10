#!/bin/bash -e

path=$(cd "$(dirname "$0")"; pwd)

TARGET_NAME=gameNetwork-apple
OUTPUT_SUFFIX=a
CONFIG=Release


# Clean
rm -rf "$path/BuiltPlugin" "$path/build"
xcodebuild -project "$path/Plugin.xcodeproj" -configuration $CONFIG clean

# iOS (arm64)
xcodebuild -project "$path/Plugin.xcodeproj" -configuration $CONFIG -sdk iphoneos SYMROOT="$path/build"

# iOS-sim (arm64 + x86_64)
xcodebuild -project "$path/Plugin.xcodeproj" -configuration $CONFIG -sdk iphonesimulator SYMROOT="$path/build"


# copy corona plugin structure

build_plugin_structure() {

	PLUGIN_DEST=$1
	mkdir -p "$PLUGIN_DEST"
	PLATFORM=$2

	cp "$path/build/$CONFIG-$PLATFORM/lib$TARGET_NAME.$OUTPUT_SUFFIX" "$PLUGIN_DEST/"
	cp "$path"/metadata.lua "$PLUGIN_DEST/"

	for f in "$path"/EmbeddedFrameworks/*.framework  "$path/build/$CONFIG-$PLATFORM/"*.framework
	do
		if [ ! -d "$f" ]
		then
			continue
		fi
		FRAMEWORK_NAME=$(basename "$f")
		BIN_NAME=${FRAMEWORK_NAME%.framework}
		SRC_BIN="$f"/$BIN_NAME

		if [[ $(file "$SRC_BIN" | grep -c "ar archive") -ne 0 ]]; then
			echo " - $FRAMEWORK_NAME: is a static Framework, extracting."
			DEST_DIR="$PLUGIN_DEST"
		else
			echo " + $FRAMEWORK_NAME: embedding"
			DEST_DIR="$PLUGIN_DEST"/resources/Frameworks
		fi

		DEST_BIN="$DEST_DIR/$FRAMEWORK_NAME/$BIN_NAME"
		mkdir -p "$DEST_DIR"
		"$(xcrun -f rsync)" --links --exclude '*.xcconfig' --exclude _CodeSignature --exclude .DS_Store --exclude CVS --exclude .svn --exclude .git --exclude .hg --exclude Headers --exclude PrivateHeaders --exclude Modules -resolve-src-symlinks "$f"  "$DEST_DIR"
	done
}


build_plugin_structure "$path/BuiltPlugin/iphone" iphoneos

build_plugin_structure "$path/BuiltPlugin/iphone-sim" iphonesimulator
