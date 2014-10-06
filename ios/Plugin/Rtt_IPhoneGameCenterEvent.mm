// ----------------------------------------------------------------------------
// 
// IPhoneGameCenterEvent.mm
// Copyright (c) 2011 Ansca, Inc. All rights reserved.
// 
// Reviewers:
// 		Eric Wing
//
// ----------------------------------------------------------------------------
//

#include "CoronaLua.h"
#include "Rtt_IPhoneGameCenterEvent.h"

#import "CoronaLuaIOS.h"
#import <Foundation/Foundation.h>

const char IPhoneGameCenterEvent::kTypeKey[] = "type";
const char IPhoneGameCenterEvent::kProviderKey[] = "provider";
const char IPhoneGameCenterEvent::kDataKey[] = "data";
const char IPhoneGameCenterEvent::kName[] = "gameNetwork";
	
IPhoneGameCenterEvent::IPhoneGameCenterEvent( const char* type, NSError* error, id data )
{
	fType = type;
	[error localizedDescription];
	fError = [[error localizedDescription] copy];
	fData = [data retain];
	
	SetError( [fError UTF8String], (int)[error code] );
}

IPhoneGameCenterEvent::~IPhoneGameCenterEvent()
{
	[fError release];
	[fData release];
}

const char*
IPhoneGameCenterEvent::Type() const
{
	return fType;
}

static const char kGameCenterProviderString[] = "gamecenter";
static const char kErrorCodeKey[] = "errorCode";
static const char kErrorMessageKey[] = "errorMessage";

const char*
IPhoneGameCenterEvent::Provider() const
{
	return kGameCenterProviderString;
}

int
IPhoneGameCenterEvent::Push( lua_State *L ) const
{
	CoronaLuaNewEvent( L, kName );
	if ( fErrorMsg )
	{
		lua_pushstring( L, fErrorMsg );
		lua_setfield( L, -2, kErrorMessageKey  );
		
		lua_pushinteger( L, fErrorCode );
		lua_setfield( L, -2, kErrorCodeKey );
	}
	
	lua_pushstring( L, Type() );
	lua_setfield( L, -2, kTypeKey  );

	// Provider should probably move to a base class, but don't want to break OpenFeint at the moment.
	lua_pushstring( L, Provider() );
	lua_setfield( L, -2, kProviderKey  );
		
	// If there is no data, no sense pushing.
	if ( fData )
	{
		CoronaLuaPushValue( L, fData );
		lua_setfield( L, -2, kDataKey  );
	}
		
	return 1;
}
	
void
IPhoneGameCenterEvent::SetError( const char *errorMsg, int errorCode )
{
	fErrorMsg = errorMsg;
	fErrorCode = errorCode;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
const char IPhoneGameCenterLoadScoresEvent::kLocalPlayerScoreKey[] = "localPlayerScore";

IPhoneGameCenterLoadScoresEvent::IPhoneGameCenterLoadScoresEvent( const char* type, NSError* error, id data, NSDictionary* localplayerscore )
: 
	IPhoneGameCenterEvent(type, error, data)
{
	fLocalPlayerScore = [localplayerscore retain];
}

IPhoneGameCenterLoadScoresEvent::~IPhoneGameCenterLoadScoresEvent()
{
	[fLocalPlayerScore release];
}

int
IPhoneGameCenterLoadScoresEvent::Push( lua_State *L ) const
{
	IPhoneGameCenterEvent::Push( L );
	
	// If there is no data, no sense pushing.
	if ( fLocalPlayerScore )
	{
		CoronaLuaPushValue( L, fLocalPlayerScore );
		lua_setfield( L, -2, kLocalPlayerScoreKey  );
	}
		
	return 1;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	

IPhoneGameCenterLoadAchievementEvent::IPhoneGameCenterLoadAchievementEvent( const char* type, NSError* error, id data,  UIImage* image )
: 
	IPhoneGameCenterEvent(type, error, data)
{
	fImage = [image retain];
}

IPhoneGameCenterLoadAchievementEvent::~IPhoneGameCenterLoadAchievementEvent()
{
	[fImage release];
}

int
IPhoneGameCenterLoadAchievementEvent::Push( lua_State *L ) const
{
	IPhoneGameCenterEvent::Push( L );
	
	if ( fImage )
	{
			// We want to get the image inside the data table because it both matches the Apple object for documentation simplicity and
			// because it we need additional info so multiple achievement requests at the same time can be identified as which as which in their callback.
			lua_getfield( L, -1, kDataKey );
			CoronaLuaPushImage( L, fImage );
			lua_setfield( L, -2, "image" );
			lua_pop( L, 1 ); // pop the data table.
		
	}
	
	return 1;	
}
	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	

IPhoneGameCenterLoadPlayerPhotoEvent::IPhoneGameCenterLoadPlayerPhotoEvent( const char* type, NSError* error, id data,  UIImage* image )
: 
	IPhoneGameCenterEvent(type, error, data)
{
	fImage = [image retain];
}

IPhoneGameCenterLoadPlayerPhotoEvent::~IPhoneGameCenterLoadPlayerPhotoEvent()
{
	[fImage release];
}

int
IPhoneGameCenterLoadPlayerPhotoEvent::Push( lua_State *L ) const
{
	IPhoneGameCenterEvent::Push( L );
	
	if ( fImage )
	{
		
			// We want to get the image inside the data table because it both matches the Apple object for documentation simplicity and
			// because it we need additional info so multiple achievement requests at the same time can be identified as which as which in their callback.
			lua_getfield( L, -1, kDataKey );
			CoronaLuaPushImage( L, fImage );
			lua_setfield( L, -2, "photo" );
			lua_pop( L, 1 ); // pop the data table.

	}
	
	return 1;	
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	

IPhoneGameCenterLoadImageEvent::IPhoneGameCenterLoadImageEvent( const char* type, NSError* error,  UIImage* image )
: 
	IPhoneGameCenterEvent(type, error, nil)
{
	fImage = [image retain];
}

IPhoneGameCenterLoadImageEvent::~IPhoneGameCenterLoadImageEvent()
{
	[fImage release];
}

int
IPhoneGameCenterLoadImageEvent::Push( lua_State *L ) const
{
	IPhoneGameCenterEvent::Push( L );
	
	if ( fImage )
	{
			// We want to get the image inside the data table because it both matches the Apple object for documentation simplicity and
			// because it we need additional info so multiple achievement requests at the same time can be identified as which as which in their callback.
			CoronaLuaPushImage( L, fImage );
			lua_setfield( L, -2, kDataKey );
	}
	
	return 1;	
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////