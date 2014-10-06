//
//  IOSGameCenterProvider.h
//  GameNetworkProvider Plugin
//
//  Copyright (c) 2013 Corona Labs. All rights reserved.
//

// TODO: Move GameCenter implementation into a plugin (gameNetwork provider)

// This is a wrapper around the GameCenter implementation. The real solution
// is to move the entire implementation into a plugin but there are too many
// internal headers used in the existing implementation, so we're doing this
// stopgap which basically adapts Rtt::IPhoneGameCenter to be a gameNetwork provider.

#ifndef _IOSGameCenterProvider_H__
#define _IOSGameCenterProvider_H__

#include "CoronaLua.h"

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_CoronaProvider_gameNetwork_gamecenter( lua_State *L );

// ----------------------------------------------------------------------------

@protocol CoronaRuntime;

// ----------------------------------------------------------------------------

namespace Rtt
{

class IPhoneGameCenter;

}

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

class IOSGameCenterProvider
{
	public:
		typedef IOSGameCenterProvider Self;

	public:
		static const char kName[];
		static const char kProviderName[];

	public:
		static int Open( lua_State *L );

	protected:
		static int Finalizer( lua_State *L );

	protected:
		static Self *GetSelf( lua_State *L );
		static int Init( lua_State *L );
		static int Show( lua_State *L );
		static int Request( lua_State *L );

	public:
		IOSGameCenterProvider( id<CoronaRuntime> runtime );
		virtual ~IOSGameCenterProvider();

	protected:
		Rtt::IPhoneGameCenter *GetGameCenter() const { return fGameCenter; }

	public:
		void DispatchEvent( bool isError ) const;

	protected:
		Rtt::IPhoneGameCenter *fGameCenter;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

#endif // _IOSGameCenterProvider_H__
