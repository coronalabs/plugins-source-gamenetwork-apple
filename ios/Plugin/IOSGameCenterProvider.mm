//
//  IOSGameCenterProvider.mm
//  GameCenterProvider Plugin
//
//  Copyright (c) 2013 Corona Labs. All rights reserved.
//

// TODO: Move GameCenter implementation into a plugin (gameNetwork provider)

// This is a wrapper around the GameCenter implementation. The real solution
// is to move the entire implementation into a plugin but there are too many
// internal headers used in the existing implementation, so we're doing this
// stopgap which basically adapts Rtt::IPhoneGameCenter to be a gameNetwork provider.

#include "IOSGameCenterProvider.h"

#include "CoronaAssert.h"
#include "CoronaEvent.h"
#include "CoronaLibrary.h"

#import "Rtt_IPhoneGameCenter.h"
#import <Foundation/Foundation.h>
#import "CoronaRuntime.h"

// ----------------------------------------------------------------------------

CORONA_EXPORT
int luaopen_CoronaProvider_gameNetwork_gamecenter( lua_State *L )
{
	return Corona::IOSGameCenterProvider::Open( L );
}

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

const char IOSGameCenterProvider::kName[] = "CoronaProvider.gameNetwork.gamecenter";

const char IOSGameCenterProvider::kProviderName[] = "gamecenter";

static const char kPublisherId[] = "com.coronalabs";

int
IOSGameCenterProvider::Open( lua_State *L )
{
	void *platformContext = CoronaLuaGetContext( L ); // lua_touserdata( L, lua_upvalueindex( 1 ) );
	id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;

	const char *name = lua_tostring( L, 1 ); CORONA_ASSERT( 0 == strcmp( name, kName ) );
	int result = CoronaLibraryProviderNew( L, "gameNetwork", name, kPublisherId );

	if ( result )
	{
		const luaL_Reg kFunctions[] =
		{
			{ "init", Self::Init },
			{ "show", Self::Show },
			{ "request", Self::Request },

			{ NULL, NULL }
		};

		CoronaLuaInitializeGCMetatable( L, kName, Finalizer );

		// Use 'provider' in closure for kFunctions
		Self *provider = new Self( runtime );
		CoronaLuaPushUserdata( L, provider, kName );
		luaL_openlib( L, NULL, kFunctions, 1 );
	}

	return result;
}

int
IOSGameCenterProvider::Finalizer( lua_State *L )
{
	Self *provider = (Self *)CoronaLuaToUserdata( L, 1 );
	delete provider;
	return 0;
}

IOSGameCenterProvider *
IOSGameCenterProvider::GetSelf( lua_State *L )
{
	return (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
}

// gameNetwork.init( providerName, ... )
int
IOSGameCenterProvider::Init( lua_State *L )
{
	Self *provider = GetSelf( L );

	CORONA_ASSERT( 0 == strcmp( kProviderName == lua_tostring( L, 1 ) ) );

	bool success = provider->GetGameCenter()->Init( L, 2 );
	lua_pushboolean( L, success );

	return 1;
}

// gameNetwork.show( name [, data] )
int
IOSGameCenterProvider::Show( lua_State *L )
{
	Self *provider = GetSelf( L );

	bool success = provider->GetGameCenter()->Show( L );
	lua_pushboolean( L, success );
	
	return 1;
}

// gameNetwork.request( command [, ...] )
int
IOSGameCenterProvider::Request( lua_State *L )
{
	Self *provider = GetSelf( L );

	provider->GetGameCenter()->Request( L );
	
	return 0;
}

// ----------------------------------------------------------------------------

IOSGameCenterProvider::IOSGameCenterProvider( id<CoronaRuntime> runtime )
:	fGameCenter( new Rtt::IPhoneGameCenter(runtime) )
{
}

IOSGameCenterProvider::~IOSGameCenterProvider()
{
	delete fGameCenter;
}

/*
void
IOSGameCenterProvider::DispatchEvent( bool isError ) const
{
	lua_State *L = fRuntime.L;

	CoronaLuaNewEvent( L, CoronaEventAdsRequestName() );

	lua_pushstring( L, kProviderName );
	lua_setfield( L, -2, CoronaEventProviderKey() );

	lua_pushboolean( L, isError );
	lua_setfield( L, -2, CoronaEventIsErrorKey() );

	CoronaLuaDispatchEvent( L, fListener, 0 );
}
*/

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------
