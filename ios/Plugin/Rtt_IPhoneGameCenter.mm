//
// Rtt_IPhoneGameCenter.mm
// Copyright (c) 2011 Ansca, Inc. All rights reserved.
//
// Reviewers:
// 		Eric Wing
//
// ----------------------------------------------------------------------------

#include "Rtt_IPhoneGameCenter.h"
#include "Rtt_IPhoneGameCenterEvent.h"
#include "CoronaLua.h"

#import <GameKit/GameKit.h>

// ----------------------------------------------------------------------------


static  __attribute__((ns_returns_autoreleased)) NSDictionary* GameCenter_NSDictionaryFromGKAchievement( GKAchievement* achievement )
{
	// Not using dictionaryWithObjectsAndKeys because of nil value paranoia due to 4.3 bug with fields returning nil.
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:6];
	[dictionary setValue:[achievement identifier] forKey:@"identifier"];
	[dictionary setValue:[NSNumber numberWithDouble:[achievement percentComplete]] forKey:@"percentComplete"];
	[dictionary setValue:[NSNumber numberWithBool:[achievement isCompleted]] forKey:@"isCompleted"];
	[dictionary setValue:[NSNumber numberWithBool:[achievement isHidden]] forKey:@"isHidden"];
	[dictionary setValue:[[achievement lastReportedDate] descriptionWithLocale:[NSLocale currentLocale]] forKey:@"lastReportedDate"];
	
	// Special case for showsCompletionBanner which is iOS 5+ only.
	if ( [achievement respondsToSelector:@selector(showsCompletionBanner)] )
	{
		[dictionary setObject:[NSNumber numberWithBool:[achievement showsCompletionBanner]] forKey:@"showsCompletionBanner"];
	}
	
	// Workaround for 4.3.
	// Since we pass through tables as stand-ins for objects, sometimes we need to pass an object that is not actually sync'd to the network.
	// When we unlock an achievement, we set the percent to 100, but the completed property is read-only.
	// On the callback, we return an achievement object constructed from a Lua table (not returned from the network).
	// On iOS 5, it seems setting percentComplete to 100 automatically sets isCompleted to YES.
	// But on iOS 4.3, this is being left as NO.
	if ( [achievement percentComplete] >= 100.0 )
	{
		[dictionary setValue:[NSNumber numberWithBool:YES] forKey:@"isCompleted"];
	}
	
	return dictionary;
}

static  __attribute__((ns_returns_autoreleased)) GKAchievement* GameCenter_GKAchievementFromLuaTable( lua_State* L, int index )
{
	if ( lua_type( L, index ) != LUA_TTABLE )
	{
		return nil;
	}
	
	lua_getfield( L, index, "identifier" );
	if ( lua_type( L, -1 ) != LUA_TSTRING )
	{
		lua_pop( L , 1 );
		// I don't really want to trigger a lua error in a helper function because control will immediately return back to Lua
		// and any memory cleanup we need to do might get skipped.
		// But we should let the user know of the problem.
		// This will only happen on device, so we need Rtt_LogException.
		NSLog(@"Error: gameNetwork/Game Center achievement must have a string for the key 'identifier'\n");
		return nil;
	}
	GKAchievement* achievement = [[[GKAchievement alloc] initWithIdentifier:[NSString stringWithUTF8String:lua_tostring( L, -1 )]] autorelease];
	lua_pop( L, 1 );
	
	
	// All other fields are optional. Remember some fields in GKAchievement are read-only.
	// We intentionally ignore extra fields as a convenience to users that might pass the original table we created for loadAchievements which contains all
	
	lua_getfield( L, index, "percentComplete" );
	if ( lua_type( L, -1 ) == LUA_TNUMBER )
	{
		[achievement setPercentComplete:lua_tonumber( L , -1 )];
	}
	lua_pop( L, 1 );
	
	// Special case for showsCompletionBanner which is iOS 5+ only.
	if ( [achievement respondsToSelector:@selector(showsCompletionBanner)] )
	{
		lua_getfield( L, index, "showsCompletionBanner" );
		if ( lua_type( L, -1 ) == LUA_TBOOLEAN )
		{
			[achievement setShowsCompletionBanner:lua_toboolean( L , -1 )];
		}
		lua_pop( L, 1 );
	}
	
	return achievement;
}

static  __attribute__((ns_returns_autoreleased)) NSDictionary* GameCenter_NSDictionaryFromGKScore( GKScore* score )
{
	// Looks like a 4.3 bug which is (sometimes) returning nil for some fields in a GKScore object.
	// This will break dictionaryWithObjectsAndKeys because any nil value will act like a terminator.
	
	// Using setValue instead of setObject to avoid problems with nil values.
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:9];
	[dictionary setValue:[score category] forKey:@"category"];
	[dictionary setValue:[NSNumber numberWithDouble:[score value]] forKey:@"value"];
	[dictionary setValue:[[score date] descriptionWithLocale:[NSLocale currentLocale]] forKey:@"date"];
	[dictionary setValue:[score formattedValue] forKey:@"formattedValue"];
	[dictionary setValue:[score playerID] forKey:@"playerID"];
	[dictionary setValue:[NSNumber numberWithInteger:[score rank]] forKey:@"rank"];
	
	// Special case for context which is iOS 5+ only.
	if ( [score respondsToSelector:@selector(context)] )
	{
		// WARNING: context is a uint64_t, but we currently can't pass 64-bit values through the bridge.
		[dictionary setObject:[NSNumber numberWithDouble:[score context]] forKey:@"context"];
	}
	// Special case for shouldSetDefaultLeaderboard which is iOS 5+ only.
	if ( [score respondsToSelector:@selector(shouldSetDefaultLeaderboard)] )
	{
		[dictionary setObject:[NSNumber numberWithBool:[score shouldSetDefaultLeaderboard]] forKey:@"shouldSetDefaultLeaderboard"];
	}
	
	//Store the unix time (strip off decimal point)
	NSNumber *unixTime = [NSNumber numberWithInt:([[score date] timeIntervalSince1970])];
	[dictionary setValue:unixTime forKey:@"unixTime"];
	
	return dictionary;
}


static  __attribute__((ns_returns_autoreleased)) GKScore* GameCenter_GKScoreFromLuaTable( lua_State* L, int index )
{
	if ( lua_type( L, index ) != LUA_TTABLE )
	{
		return nil;
	}
	
	// Category is required
	lua_getfield( L, index, "category" );
	if ( lua_type( L, -1 ) != LUA_TSTRING )
	{
		lua_pop( L , 1 );
		// I don't really want to trigger a lua error in a helper function because control will immediately return back to Lua
		// and any memory cleanup we need to do might get skipped.
		// But we should let the user know of the problem.
		// This will only happen on device, so we need Rtt_LogException.
		NSLog(@"Error: gameNetwork/Game Center score must have a string for the key 'category'\n");
		return nil;
	}
	GKScore* score = [[[GKScore alloc] initWithCategory:[NSString stringWithUTF8String:lua_tostring( L, -1 )]] autorelease];
	lua_pop( L, 1 );
	
	
	// All other fields are optional. Remember some fields in GKScore are read-only.
	// We intentionally ignore extra fields as a convenience to users that might pass the original table we created for loadScores which contains all
	
	lua_getfield( L, index, "value" );
	if ( lua_type( L, -1 ) == LUA_TNUMBER )
	{
		// WARNING: value is a int64_t, but we currently can't pass 64-bit values through the bridge.
		[score setValue:lua_tonumber( L , -1 )];
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "context" );
	if ( lua_type( L, -1 ) == LUA_TNUMBER )
	{
		// Special case for context which is iOS 5+ only.
		if ( [score respondsToSelector:@selector(setContext:)] )
		{
			// WARNING: context is a uint64_t, but we currently can't pass 64-bit values through the bridge.
			[score setContext:lua_tonumber( L , -1 )];
		}
		
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "shouldSetDefaultLeaderboard" );
	if ( lua_type( L, -1 ) == LUA_TBOOLEAN )
	{
		// Special case for context which is iOS 5+ only.
		if ( [score respondsToSelector:@selector(setShouldSetDefaultLeaderboard:)] )
		{
			[score setShouldSetDefaultLeaderboard:lua_toboolean( L , -1 )];
		}
	}
	lua_pop( L, 1 );
	
	return score;
}



static  __attribute__((ns_returns_autoreleased)) NSDictionary* GameCenter_NSDictionaryScoreFromLuaTable( lua_State* L, int index )
{
	if ( lua_type( L, index ) != LUA_TTABLE )
	{
		return nil;
	}
	
	// Category is required
	lua_getfield( L, index, "category" );
	if ( lua_type( L, -1 ) != LUA_TSTRING )
	{
		lua_pop( L , 1 );
		// I don't really want to trigger a lua error in a helper function because control will immediately return back to Lua
		// and any memory cleanup we need to do might get skipped.
		// But we should let the user know of the problem.
		// This will only happen on device, so we need Rtt_LogException.
		NSLog(@"Error: gameNetwork/Game Center score must have a string for the key 'category'\n");
		return nil;
	}
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
	[dictionary setObject:[NSString stringWithUTF8String:lua_tostring( L, -1 )] forKey:@"category"];
	lua_pop( L, 1 );
	
	
	// All other fields are optional. Remember some fields in GKScore are read-only.
	// We intentionally ignore extra fields as a convenience to users that might pass the original table we created for loadScores which contains all
	
	lua_getfield( L, index, "value" );
	if ( lua_type( L, -1 ) == LUA_TNUMBER )
	{
		// WARNING: value is a int64_t, but we currently can't pass 64-bit values through the bridge.
		[dictionary setObject:[NSNumber numberWithDouble:lua_tonumber( L, -1 )] forKey:@"value"];
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "context" );
	if ( lua_type( L, -1 ) == LUA_TNUMBER )
	{
		// Technically iOS 5 only but I don't think anybody will care if the Lua table preserves the field.
		[dictionary setObject:[NSNumber numberWithDouble:lua_tonumber( L, -1 )] forKey:@"context"];
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "shouldSetDefaultLeaderboard" );
	if ( lua_type( L, -1 ) == LUA_TBOOLEAN )
	{
		// Technically iOS 5 only but I don't think anybody will care if the Lua table preserves the field.
		[dictionary setObject:[NSNumber numberWithBool:lua_toboolean( L, -1 )] forKey:@"shouldSetDefaultLeaderboard"];
	}
	lua_pop( L, 1 );
	
	
	lua_getfield( L, index, "date" );
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		// WARNING: value is a int64_t, but we currently can't pass 64-bit values through the bridge.
		[dictionary setObject:[NSString stringWithUTF8String:lua_tostring( L, -1 )] forKey:@"date"];
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "formattedValue" );
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		// WARNING: value is a int64_t, but we currently can't pass 64-bit values through the bridge.
		[dictionary setObject:[NSString stringWithUTF8String:lua_tostring( L, -1 )] forKey:@"formattedValue"];
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "playerID" );
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		[dictionary setObject:[NSString stringWithUTF8String:lua_tostring( L, -1 )] forKey:@"playerID"];
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "rank" );
	if ( lua_type( L, -1 ) == LUA_TNUMBER )
	{
		[dictionary setObject:[NSNumber numberWithInteger:lua_tointeger(L, -1 )] forKey:@"rank"];
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "unixTime" );
	if ( lua_type( L, -1 ) == LUA_TNUMBER )
	{
		[dictionary setObject:[NSNumber numberWithInteger:lua_tointeger( L, -1 )] forKey:@"unixTime"];
	}
	lua_pop( L, 1 );
	
	return dictionary;
}



static  __attribute__((ns_returns_autoreleased)) GKLeaderboard* GameCenter_GKLeaderboardFromLuaTable( lua_State* L, int index )
{
	// Since there are no required values for a GKLeaderboard, we can return a default object if there is no Lua table
	if ( lua_type( L, index ) != LUA_TTABLE )
	{
		return [[[GKLeaderboard alloc] init] autorelease];
	}
	GKLeaderboard* leaderboard = nil;
	// There are two ways to initialize a GKLeaderboard: with or without an array of playerIDs (strings).
	// So if there is an array of PlayerIDs, then we initialize with the playerIDs.
	lua_getfield( L, index, "playerIDs" );
	if ( lua_type( L, -1 ) == LUA_TTABLE )
	{
		// Must be a convential array or things won't work right.
		int number_of_elements = (int)lua_objlen(L, -1);  /* get length of array */
		if ( 0 == number_of_elements )
		{
			leaderboard = [[[GKLeaderboard alloc] init] autorelease];
		}
		else
		{
			NSMutableArray* playerids = [NSMutableArray arrayWithCapacity:number_of_elements];
			
			for ( int i=1; i<=number_of_elements; i++ )
			{
				lua_rawgeti(L, -1, i);  /* array is at -1, pushes value at array[i] onto top of stack */
				if ( lua_type( L, -1 ) == LUA_TSTRING )
				{
					[playerids addObject:[NSString stringWithUTF8String:lua_tostring( L, -1 )]];
				}
				else
				{
					NSLog(@"Error: gameNetwork/Game Center Leaderboard properties for the key 'playerIDs' must be an array of strings. The element at index=%d is not a string.\n", i);
				}
				lua_pop( L, 1 ); // pop array[i] off the top of the stack. array is now on top of stack again.
			}
			leaderboard = [[[GKLeaderboard alloc] initWithPlayerIDs:playerids] autorelease];
		}
	}
	else
	{
		leaderboard = [[[GKLeaderboard alloc] init] autorelease];
	}
	lua_pop( L, 1 );
	
	// All other fields are optional. Remember some fields are read-only.
	// We intentionally ignore extra fields as a convenience to users that might pass the original table we created for loadScores which contains all
	
	lua_getfield( L, index, "category" );
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		[leaderboard setCategory:[NSString stringWithUTF8String:lua_tostring( L, -1 )]];
	}
	lua_pop( L, 1 );
	
	
	
	lua_getfield( L, index, "playerScope" );
	// Apple uses numbers here, but we're using strings.
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		const char* scopestring = lua_tostring(L, -1);
		if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValuePlayerScopeGlobal, scopestring) )
		{
			[leaderboard setPlayerScope:GKLeaderboardPlayerScopeGlobal];
		}
		else if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValuePlayerScopeFriendsOnly, scopestring) )
		{
			[leaderboard setPlayerScope:GKLeaderboardPlayerScopeFriendsOnly];
		}
		else
		{
			NSLog(@"Error: gameNetwork/Game Center Leaderboard has specified an invalid string value of: %s, for key 'playerScope' \n", scopestring);
		}
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "timeScope" );
	// Apple uses numbers here, but we're using strings.
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		const char* scopestring = lua_tostring(L, -1);
		if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValueTimeScopeAllTime, scopestring) )
		{
			[leaderboard setTimeScope:GKLeaderboardTimeScopeAllTime];
		}
		else if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValueTimeScopeWeek, scopestring) )
		{
			[leaderboard setTimeScope:GKLeaderboardTimeScopeWeek];
		}
		else if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValueTimeScopeToday, scopestring) )
		{
			[leaderboard setTimeScope:GKLeaderboardTimeScopeToday];
		}
		else
		{
			NSLog(@"Error: gameNetwork/Game Center Leaderboard has specified an invalid string value of: %s, for key 'timeScope' \n", scopestring);
		}
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "range" );
	if ( lua_type( L, -1 ) == LUA_TTABLE )
	{
		// Must be a convential array of 2 elements or things won't work right.
		int number_of_elements = (int)lua_objlen(L, -1);  /* get length of array */
		if ( 2 != number_of_elements )
		{
			NSLog(@"Error: gameNetwork/Game Center Leaderboard must have an array of exactly 2 elements for the key 'range' \n");
		}
		else
		{
			lua_rawgeti(L, -1, 1);  /* array is at -1, pushes value at array[1] onto top of stack */
			NSUInteger min = lua_tointeger(L, -1);
			lua_pop(L, 1);
			
			lua_rawgeti(L, -1, 2);  /* array is at -1, pushes value at array[2] onto top of stack */
			NSUInteger max = lua_tointeger(L, -1);
			lua_pop(L, 1);
			
			[leaderboard setRange:NSMakeRange(min, max)];
		}
	}
	lua_pop( L, 1 );
	
	return leaderboard;
}


static  __attribute__((ns_returns_autoreleased)) GKLeaderboardViewController* GameCenter_GKLeaderboardViewControllerFromLuaTable( lua_State* L, int index )
{
	// Since there are no required values for a GKLeaderboardViewController, we can return a default object if there is no Lua table
	GKLeaderboardViewController* leaderboard = [[[GKLeaderboardViewController alloc] init] autorelease];
	
	if ( lua_type( L, index ) != LUA_TTABLE )
	{
		return leaderboard;
	}
	
	lua_getfield( L, index, "category" );
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		[leaderboard setCategory:[NSString stringWithUTF8String:lua_tostring( L, -1 )]];
	}
	lua_pop( L, 1 );
	
	
	lua_getfield( L, index, "timeScope" );
	// Apple uses numbers here, but we're using strings.
	if ( lua_type( L, -1 ) == LUA_TSTRING )
	{
		const char* scopestring = lua_tostring(L, -1);
		if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValueTimeScopeAllTime, scopestring) )
		{
			[leaderboard setTimeScope:GKLeaderboardTimeScopeAllTime];
		}
		else if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValueTimeScopeWeek, scopestring) )
		{
			[leaderboard setTimeScope:GKLeaderboardTimeScopeWeek];
		}
		else if ( 0 == strcasecmp(Rtt::IPhoneGameCenter::kValueTimeScopeToday, scopestring) )
		{
			[leaderboard setTimeScope:GKLeaderboardTimeScopeToday];
		}
		else
		{
			NSLog(@"Error: gameNetwork/Game Center Leaderboard has specified an invalid string value of: %s, for key 'timeScope' \n", scopestring);
		}
	}
	lua_pop( L, 1 );
	
	return leaderboard;
}



static  __attribute__((ns_returns_autoreleased)) NSMutableArray* GameCenter_NSArrayFromCategoriesAndTitles( NSArray* categories, NSArray* titles )
{
	// Assumption: categories and titles are the same length and each entry corresponds to the other.
	if ( [categories count] == 0 )
	{
		return [NSMutableArray array];
	}
	
	NSMutableArray* array = [NSMutableArray arrayWithCapacity:[categories count]];
	NSUInteger index = 0;
	for ( NSString* category in categories )
	{
		// Not using dictionaryWithObjectsAndKeys because of nil value paranoia due to 4.3 bug with fields returning nil.
		NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:2];
		[dictionary setValue:category forKey:@"category"];
		[dictionary setValue:[titles objectAtIndex:index] forKey:@"title"];
		
		[array addObject:dictionary];
		index++;
	}
	
	return array;
}

static  __attribute__((ns_returns_autoreleased)) NSDictionary* GameCenter_NSDictionaryFromGKAchievementDescription( GKAchievementDescription* description )
{
	// UIImage stuff omitted here for performance at least for now. It should be done in an explicit request anyway since it may not be available or wanted.
	
	// Not using dictionaryWithObjectsAndKeys because of nil value paranoia due to 4.3 bug with fields returning nil.
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:6];
	[dictionary setValue:[description achievedDescription] forKey:@"achievedDescription"];
	[dictionary setValue:[description unachievedDescription] forKey:@"unachievedDescription"];
	[dictionary setValue:[description title] forKey:@"title"];
	[dictionary setValue:[description identifier] forKey:@"identifier"];
	[dictionary setValue:[NSNumber numberWithInteger:[description maximumPoints]] forKey:@"maximumPoints"];
	[dictionary setValue:[NSNumber numberWithBool:[description isHidden]] forKey:@"isHidden"];
	
	return dictionary;
}

static  __attribute__((ns_returns_autoreleased)) NSArray* GameCenter_NSArrayOfStringsFromLuaTable( lua_State* L, int index )
{
	//	NSLog(@"gettop: %d", lua_gettop(L));
	
	// If not a table, return nil
	if ( lua_type( L, index ) != LUA_TTABLE )
	{
		return nil;
	}
	
	// We will allow an array with 0 elements just in case the user really means it.
	int number_of_elements = (int)lua_objlen(L, index);  /* get length of array */
	
	NSMutableArray* strings = [NSMutableArray arrayWithCapacity:number_of_elements];
	
	for ( int i=1; i<=number_of_elements; i++ )
	{
		lua_rawgeti(L, index, i);  /* array is at -1, pushes value at array[i] onto top of stack */
		if ( lua_type( L, -1 ) == LUA_TSTRING )
		{
			[strings addObject:[NSString stringWithUTF8String:lua_tostring( L, -1 )]];
		}
		else
		{
			NSLog(@"Error: gameNetwork/Game Center expecting an array of strings. The element at index=%d is not a string.\n", i);
		}
		lua_pop( L, 1 ); // pop array[i] off the top of the stack. array is now on top of stack again.
	}
	
	//	NSLog(@"strings: %@", strings);
	//	NSLog(@"gettop: %d", lua_gettop(L));
	
	return strings;
}


static  __attribute__((ns_returns_autoreleased)) NSDictionary* GameCenter_NSDictionaryFromGKLocalPlayer( GKLocalPlayer* player )
{
	// Not using dictionaryWithObjectsAndKeys because of nil value paranoia due to 4.3 bug with fields returning nil.
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:6];
	[dictionary setValue:[player alias] forKey:@"alias"];
	[dictionary setValue:[player playerID] forKey:@"playerID"];
	[dictionary setValue:[NSNumber numberWithBool:[player isFriend]] forKey:@"isFriend"];
	[dictionary setValue:[NSNumber numberWithBool:[player isAuthenticated]] forKey:@"isAuthenticated"];
	[dictionary setValue:[NSNumber numberWithBool:[player isUnderage]] forKey:@"isUnderage"];
	[dictionary setValue:[player friends] forKey:@"friends"];
	
	return dictionary;
}

static  __attribute__((ns_returns_autoreleased)) NSDictionary* GameCenter_NSDictionaryFromGKPlayer( GKPlayer* player )
{
	if ( [[player playerID] isEqualToString:[[GKLocalPlayer localPlayer] playerID]] )
	{
		return GameCenter_NSDictionaryFromGKLocalPlayer([GKLocalPlayer localPlayer]);
	}
	
	// Not using dictionaryWithObjectsAndKeys because of nil value paranoia due to 4.3 bug with fields returning nil.
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:3];
	[dictionary setValue:[player alias] forKey:@"alias"];
	[dictionary setValue:[player playerID] forKey:@"playerID"];
	[dictionary setValue:[NSNumber numberWithBool:[player isFriend]] forKey:@"isFriend"];
	
	return dictionary;
}

static  __attribute__((ns_returns_autoreleased)) NSMutableDictionary* GameCenter_NSDictionaryFromGKTurnBasedParticipant( GKTurnBasedParticipant* participant )
{
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:3];
	[dictionary setValue:[participant playerID] forKey:@"playerID"];
	[dictionary setValue:Rtt::IPhoneGameCenter::nsstringFromOutcome([participant matchOutcome]) forKey:@"outcome"];
	[dictionary setValue:Rtt::IPhoneGameCenter::nsstringFromStatus([participant status]) forKey:@"status"];
	return dictionary;
}

static  __attribute__((ns_returns_autoreleased)) NSDictionary* GameCenter_NSDictionaryFromGKTurnBasedMatch( GKTurnBasedMatch* match )
{
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithCapacity:5];
	
	if (match == nil)
	{
		return dictionary;
	}
	
	[dictionary setValue:[match matchID] forKey:@"matchID"];
	[dictionary setValue:[[NSString alloc] initWithData:[match matchData] encoding:NSUTF8StringEncoding] forKey:@"data"];
	
	NSArray* participants = [match participants];
	NSMutableArray* participantData = [NSMutableArray arrayWithCapacity:[participants count]];
	
	for (uint i = 0; i < [participants count]; i++)
	{
		NSMutableDictionary* dictionary = GameCenter_NSDictionaryFromGKTurnBasedParticipant([participants objectAtIndex:i]);
		[dictionary setValue:[NSString stringWithFormat:@"%d", i] forKey:@"index"];
		[participantData addObject:dictionary];
	}
	
	[dictionary setValue:participantData forKey:@"participants"];
	[dictionary setValue:GameCenter_NSDictionaryFromGKTurnBasedParticipant([match currentParticipant]) forKey:@"currentParticipant"];
	
	NSString* currentState;
	
	GKTurnBasedMatchStatus status = [match status];
	if ( status == GKTurnBasedMatchStatusUnknown )
	{
		currentState = [NSString stringWithUTF8String:"unknown"];
	}
	else if ( status == GKTurnBasedMatchStatusOpen )
	{
		currentState = [NSString stringWithUTF8String:"open"];
	}
	else if ( status == GKTurnBasedMatchStatusEnded )
	{
		currentState = [NSString stringWithUTF8String:"ended"];
	}
	else if ( status == GKTurnBasedMatchStatusMatching )
	{
		currentState = [NSString stringWithUTF8String:"matching"];
	}
	
	[dictionary setValue:currentState forKey:@"status"];
	
	return dictionary;
}

static  __attribute__((ns_returns_autoreleased)) GKMatchRequest* GameCenter_GKMatchRequestFromLuaTable( lua_State* L, int index )
{
    GKMatchRequest* matchRequest = [[[GKMatchRequest alloc] init] autorelease];
    matchRequest.minPlayers = 2;
    matchRequest.maxPlayers = 2;
    
    lua_getfield( L, index, "playerIDs" );
    matchRequest.playersToInvite = GameCenter_NSArrayOfStringsFromLuaTable( L, -1 );
    lua_pop( L, 1 );
    
    lua_getfield( L, index, "minPlayers" );
    if ( lua_isnumber( L, -1 ) )
    {
        matchRequest.minPlayers = lua_tonumber( L , -1 );
    }
    lua_pop( L, 1 );
    
    lua_getfield( L, index, "maxPlayers" );
    if ( lua_isnumber( L, -1 ) )
    {
        matchRequest.maxPlayers = lua_tonumber( L , -1 );
    }
    lua_pop( L, 1 );
    
    lua_getfield(L, index, "playerGroup" );
    if ( lua_isnumber( L, -1 ) )
    {
        matchRequest.playerGroup = lua_tonumber( L , -1 );
    }
    lua_pop( L, 1 );
    
    lua_getfield( L, index, "inviteMessage" );
    if (lua_isstring( L, -1 ) && [matchRequest respondsToSelector:@selector(inviteMessage)])
    {
        matchRequest.inviteMessage = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
    }
    lua_pop( L, 1 );
    
    /*
     This is a table with the bits that should be set.  For example {1,5,8} would translate to 0x00000091
     */
    lua_getfield( L, index, "playerAttributes" );
    if ( lua_istable( L, -1 ) )
    {
        uint32_t attributes = (0x0);
        
        lua_pushnil( L );
        while ( lua_next( L, -2 ) != 0 )
        {
            int bit = (int)lua_tonumber( L, -1 );
            if (bit < 33)
            {
                attributes = attributes | ( 1 << ( bit - 1 ) );
            }
            
            lua_pop( L, 1 );
        }
        lua_pop( L, 1 );
        
        matchRequest.playerAttributes = attributes;
    }
    lua_pop( L, 1 );
    
    return matchRequest;
}

@implementation GameCenterDelegate

@synthesize luaResourceForLeaderboard;
@synthesize luaResourceForAchievement;
@synthesize luaResourceForFriendRequest;

- (void) dealloc
{
	// Make sure to delete resource if it still exists.
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForFriendRequest]);
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForAchievement]);
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForLeaderboard]);
	[super dealloc];
}

- (void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController*)viewcontroller
{
	using namespace Rtt;
	[viewcontroller dismissViewControllerAnimated:YES completion:NULL];
	
	if ( [self luaResourceForLeaderboard] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kDashboardLeaderboards, nil, nil );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForLeaderboard, 0);
	}
	
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForLeaderboard]);
	// set to nil to avoid double delete in dealloc
	[self setLuaResourceForLeaderboard:nil];
}

- (void)achievementViewControllerDidFinish:(GKAchievementViewController*)viewcontroller;
{
	using namespace Rtt;
	[viewcontroller dismissViewControllerAnimated:YES completion:NULL];
	
	if ( [self luaResourceForAchievement] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kDashboardAchievements, nil, nil );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForAchievement, 0);
	}
	
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForAchievement]);
	// set to nil to avoid double delete in dealloc
	[self setLuaResourceForAchievement:nil];
	
}

- (void)friendRequestComposeViewControllerDidFinish:(GKFriendRequestComposeViewController*)viewcontroller;
{
	using namespace Rtt;
	[viewcontroller dismissViewControllerAnimated:YES completion:NULL];
	
	if ( [self luaResourceForFriendRequest] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kDashboardFriendRequest, nil, nil );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForFriendRequest, 0);
	}
	
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForFriendRequest]);
	// set to nil to avoid double delete in dealloc
	[self setLuaResourceForFriendRequest:nil];
	
}


@end

@implementation TurnBasedMatchMakerDelegate

@synthesize luaResourceForMatchMaker;
@synthesize fMatchesDictionary;

- (void) dealloc
{
	// Make sure to delete resource if it still exists.
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForMatchMaker]);
	[super dealloc];
}

// This is called when the selection of a match was cancelled
- (void)turnBasedMatchmakerViewControllerWasCancelled:(GKTurnBasedMatchmakerViewController *)viewcontroller;
{
	using namespace Rtt;
	[viewcontroller dismissViewControllerAnimated:YES completion:nil];
	[viewcontroller release];
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForMatchMaker]);
	[self setLuaResourceForMatchMaker:nil];
}

// This is called when the selection there was some sort of error
- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)viewcontroller didFailWithError:(NSError *)error;
{
	using namespace Rtt;
	[viewcontroller dismissViewControllerAnimated:YES completion:nil];
	[viewcontroller release];
	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForMatchMaker]);
	[self setLuaResourceForMatchMaker:nil];
}

// This is called when there was a selection of a match and the user wants to take their turn
- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)viewcontroller didFindMatch:(GKTurnBasedMatch *)match;
{
	using namespace Rtt;
	[viewcontroller dismissViewControllerAnimated:YES completion:nil];
	[viewcontroller release];
	
	if ( match )
	{
		[fMatchesDictionary setValue:match forKey:[match matchID]];
	}
	
	if ( [self luaResourceForMatchMaker] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kDashboardMatches, nil, GameCenter_NSDictionaryFromGKTurnBasedMatch(match) );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForMatchMaker, 0);
	}
	
   	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForMatchMaker]);
	[self setLuaResourceForMatchMaker:nil];
}

// This is called when there was a selection of a match but the user want to quit it instead of playing their turn
- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)viewcontroller playerQuitForMatch:(GKTurnBasedMatch *)match;
{
	using namespace Rtt;
	[viewcontroller dismissViewControllerAnimated:YES completion:nil];
	[viewcontroller release];
	
   	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForMatchMaker]);
   	[self setLuaResourceForMatchMaker:nil];
}
@end

@implementation TurnBasedEventHandlerDelegate

@synthesize luaResourceForEventHandler;
@synthesize fMatchesDictionary;

- (void) dealloc
{
	// Make sure to delete resource if it still exists.
   	CoronaLuaDeleteRef([[self runtime] L], [self luaResourceForEventHandler]);
	[super dealloc];
}

- (void)handleInviteFromGameCenter:(NSArray *) playersToInvite;
{
	using namespace Rtt;
	if ( [self luaResourceForEventHandler] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kValueInvitationReceived, nil, playersToInvite );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForEventHandler, 0);
	}
}

- (void)handleMatchEnded:(GKTurnBasedMatch *) match;
{
	using namespace Rtt;
	if ( [self luaResourceForEventHandler] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kValueMatchEnded, nil, GameCenter_NSDictionaryFromGKTurnBasedMatch(match) );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForEventHandler, 0);
	}
}

- (void)handleTurnEventForMatch:(GKTurnBasedMatch *) match;
{
	using namespace Rtt;
	
	if ( match )
	{
		[fMatchesDictionary setValue:match forKey:[match matchID]];
	}
	
	if ( [self luaResourceForEventHandler] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kValuePlayerTurn, nil, GameCenter_NSDictionaryFromGKTurnBasedMatch(match) );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForEventHandler, 0);
	}
}

- (void)handleTurnEventForMatch:(GKTurnBasedMatch *) match didBecomeActive:(BOOL)didBecomeActive;
{
	using namespace Rtt;
	
	if ( match )
	{
		[fMatchesDictionary setValue:match forKey:[match matchID]];
	}
	
	if ( [self luaResourceForEventHandler] )
	{
		IPhoneGameCenterEvent e( IPhoneGameCenter::kValuePlayerTurn, nil, GameCenter_NSDictionaryFromGKTurnBasedMatch(match) );
		e.Push([[self runtime] L]);
		CoronaLuaDispatchEvent([[self runtime] L], luaResourceForEventHandler, 0);
	}
}
@end

namespace Rtt
{
	
// ----------------------------------------------------------------------------

const char IPhoneGameCenter::kDashboardLeaderboards[] = "leaderboards";
const char IPhoneGameCenter::kDashboardChallenges[] = "challenges";
const char IPhoneGameCenter::kDashboardAchievements[] = "achievements";
const char IPhoneGameCenter::kDashboardFriendRequest[] = "friendRequest";
const char IPhoneGameCenter::kDashboardMatches[] = "matches";
const char IPhoneGameCenter::kValueDashboardCreateMatch[] = "createMatch";
//const char IPhoneGameCenter::kDashboardFriends[] = "friends";
//const char IPhoneGameCenter::kDashboardPlaying[] = "playing";
//const char IPhoneGameCenter::kDashboardHighscore[] = "highscore";
const char IPhoneGameCenter::kValueCurrentPlayer[] = "loadCurrentPlayer";
const char IPhoneGameCenter::kValueQuitMatch[] = "quitMatch";
const char IPhoneGameCenter::kValueEndMatch[] = "endMatch";
const char IPhoneGameCenter::kValueRemoveMatch[] = "removeMatch";
const char IPhoneGameCenter::kValueResetAchievements[] = "resetAchievements";
const char IPhoneGameCenter::kValueLoadAchievements[] = "loadAchievements";
const char IPhoneGameCenter::kValueUnlockAchievement[] = "unlockAchievement";
const char IPhoneGameCenter::kValueLoadScores[] = "loadScores";
const char IPhoneGameCenter::kValueSetHighScore[] = "setHighScore";
const char IPhoneGameCenter::kValueSetEventHandler[] = "setEventListener";
const char IPhoneGameCenter::kValueLoadMatchData[] = "loadMatchData";
const char IPhoneGameCenter::kValuePlayerTurn[] = "playerTurn";
const char IPhoneGameCenter::kValueEndTurn[] = "endTurn";
const char IPhoneGameCenter::kValueMatchEnded[] = "matchEnded";
const char IPhoneGameCenter::kValueInvitationReceived[] = "invitationReceived";
const char IPhoneGameCenter::kValueMaxPlayersAllowedForTurnBased[] = "loadTurnBasedMatchMaxNumberOfParticipants";

const char IPhoneGameCenter::kValueFetchLeaderboardCategories[] = "loadLeaderboardCategories";
const char IPhoneGameCenter::kValueFetchAchievementDescriptions[] = "loadAchievementDescriptions";
const char IPhoneGameCenter::kValueFetchFriends[] = "loadFriends";
const char IPhoneGameCenter::kValueFetchPlayers[] = "loadPlayers";
const char IPhoneGameCenter::kValueFetchLocalPlayer[] = "loadLocalPlayer";
const char IPhoneGameCenter::kValueFetchFriendRequestMaxNumberOfRecipients[] = "loadFriendRequestMaxNumberOfRecipients";

const char IPhoneGameCenter::kValueLoadPlayerPhoto[] = "loadPlayerPhoto";
const char IPhoneGameCenter::kValueLoadAchievementImage[] = "loadAchievementImage";
const char IPhoneGameCenter::kValueLoadMatches[] = "loadMatches";
const char IPhoneGameCenter::kValueLoadPlaceholderCompletedAchievementImage[] = "loadPlaceholderCompletedAchievementImage";
const char IPhoneGameCenter::kValueLoadIncompleteAchievementImage[] = "loadIncompleteAchievementImage";

const char IPhoneGameCenter::kValueInit[] = "init";
const char IPhoneGameCenter::kValueSignIn[] = "showSignIn";

const char IPhoneGameCenter::kValueTimeScopeToday[] = "Today";
const char IPhoneGameCenter::kValueTimeScopeWeek[] = "Week";
const char IPhoneGameCenter::kValueTimeScopeAllTime[] = "AllTime";
const char IPhoneGameCenter::kValuePlayerScopeGlobal[] = "Global";
const char IPhoneGameCenter::kValuePlayerScopeFriendsOnly[] = "FriendsOnly";

const char IPhoneGameCenter::kValuePhotoSizeNormal[] = "Normal";
const char IPhoneGameCenter::kValuePhotoSizeSmall[] = "Small";

const char IPhoneGameCenter::kValueVariablePlayerID[] = "playerID";
	
// ----------------------------------------------------------------------------

IPhoneGameCenter::IPhoneGameCenter(id<CoronaRuntime> runtime)
:	fIsInitialized( false ),
	fGameCenterDelegate( nil ),
	fTurnBasedMatchMakerDelegate( nil ),
	fTurnBasedEventHandlerDelegate( nil ),
	fAuthenticationCallback( NULL ),
	fMatchesDictionary( nil ),
	fRuntime(runtime)
{
}

IPhoneGameCenter::~IPhoneGameCenter()
{
	[fGameCenterDelegate release];
	[fMatchesDictionary release];
	[fTurnBasedMatchMakerDelegate release];
	[fTurnBasedEventHandlerDelegate release];
	CoronaLuaDeleteRef([fRuntime L], fAuthenticationCallback);
}

// Assumes Init() was already called.
// Remember that this call is asynchronous/non-blocking.
void
IPhoneGameCenter::Authenticate( lua_State *L )
{
	if ( ! fIsInitialized )
	{
		return;
	}
	GKLocalPlayer* localplayer = [GKLocalPlayer localPlayer];
	
	[localplayer setAuthenticateHandler:^(UIViewController* viewcontroller, NSError* error)
	 {
		// Implementation detail, the type of viewcontroller is private GKHostedAuthenticateViewController.
		 
		// Apple's GKTapper example warns that GameKit may not perform on the main thread.
		dispatch_async(dispatch_get_main_queue(), ^(void)
		{
			// If there is a viewcontroller, then the Game Center login screen needs to be displayed for the user to login.
			if( nil != viewcontroller )
			{
				UIViewController* rootviewcontroller = [fRuntime appViewController];
				// It looks like modal view controllers are deprecated in iOS 6. Maybe this check isn't a good idea since it is a deprecated API.
				/*
				 if ( [rootviewcontroller modalViewController] )
				 {
				 Rtt_ERROR( ( "ERROR: There is already a native modal interface being displayed. The '%s' popup will not be shown.\n", lua_tostring( L, 1 ) ) );
				 return;
				 }
				 */
				// Give the user a notification that the viewcontroller is about to be displayed.
				// This will allow the user to suspend their game and for the iOS 6 landscape-only orientation bug, remove native display objects.
				if ( fAuthenticationCallback )
				{
					// Potential race condition: block is asynchronous. If the runtime is shutting down, we may have a problem.
					if ( NULL != fRuntime )
					{
						IPhoneGameCenterEvent e( kValueSignIn, error, [NSNumber numberWithBool:[localplayer isAuthenticated]] );
						e.Push([fRuntime L]);
						CoronaLuaDispatchEvent([fRuntime L], fAuthenticationCallback, 0);
					}
				}
				
				// The callback is complete. Now show the view controller.
				[rootviewcontroller presentViewController:viewcontroller animated:YES completion:nil];
				return;
			}
			else // No viewcontroller to show, either the user is logged in or isn't.
			{
				if ( fAuthenticationCallback )
				{
					IPhoneGameCenterEvent e( kValueInit, error, [NSNumber numberWithBool:[localplayer isAuthenticated]] );
					e.Push([fRuntime L]);
					CoronaLuaDispatchEvent([fRuntime L], fAuthenticationCallback, 0);
				}
			}
		});
	 }];
}

// index seems to be the first parameter I'm supposed to look at
bool
IPhoneGameCenter::Init( lua_State *L, int index )
{
	// There are two ways we can do this.
	// We can allow init to be called only once and short circuit.
	// Or we can allow it to be called multiple times to allow users to change the callback.
	// Apple's auto-relogin after resume implies they only expect authenticateWithCompletionHandler to be called once.
	// However, all the stuff about the user being able to sign out while backgrounded suggests maybe not.
	if ( ! fIsInitialized )
	{
		if ( CoronaLuaIsListener( L, index, IPhoneGameCenterEvent::kName ) )
		{
			// Delete the old callback if we allow for multiple init calls.
			// Yes, it is safe to call delete on a NULL pointer.
			CoronaLuaDeleteRef([fRuntime L], fAuthenticationCallback);
			fAuthenticationCallback = CoronaLuaNewRef([fRuntime L], index);
		}
		else if( ( lua_type( L, index ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, index, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				// Delete the old callback if we allow for multiple init calls.
				// Yes, it is safe to call delete on a NULL pointer.
				CoronaLuaDeleteRef([fRuntime L], fAuthenticationCallback);
				fAuthenticationCallback = CoronaLuaNewRef([fRuntime L], -1);
			}
			lua_pop( L, 1 );
		}
		
		fIsInitialized = true;
		fGameCenterDelegate = [[GameCenterDelegate alloc] init];
		fGameCenterDelegate.runtime = fRuntime;
		fTurnBasedMatchMakerDelegate = [[TurnBasedMatchMakerDelegate alloc] init];
		fTurnBasedMatchMakerDelegate.runtime = fRuntime;
		fTurnBasedEventHandlerDelegate = [[TurnBasedEventHandlerDelegate alloc] init];
		fTurnBasedEventHandlerDelegate.runtime = fRuntime;
		[GKTurnBasedEventHandler sharedTurnBasedEventHandler].delegate = fTurnBasedEventHandlerDelegate;
		
		// This is used to store matches so that we can leave them
		fMatchesDictionary = [[NSMutableDictionary alloc] init];
		[fTurnBasedMatchMakerDelegate setFMatchesDictionary:fMatchesDictionary];
		[fTurnBasedEventHandlerDelegate setFMatchesDictionary:fMatchesDictionary];
	}
	
	// If we put this inside the isInitialized check, this can only be run once.
	// If we put this outside, then this allows users to call the login panel again without changing the callback listener.
	// This is useful for the cases where the user never logged in and wants to change their mind
	// or logged out via the main Game Center app.
	Authenticate( L );
	
	// Always returns true because this call is non-blocking.
	return true;
}

bool
IPhoneGameCenter::Show( lua_State* L )
{
	if ( ! fIsInitialized )
	{
		return false;
	}
	UIViewController* viewcontroller = [fRuntime appViewController];
	if ( [viewcontroller presentedViewController] )
	{
		NSLog(@"ERROR: There is already a native modal interface being displayed. The '%s' popup will not be shown.\n", lua_tostring( L, 1 ) ) ;
		return false;
	}
	
	const char* name = luaL_checkstring( L, 1 ); // require string parameter as first parameter
	CoronaLuaRef resource = NULL;
	
	if( ( lua_type( L, 2 ) == LUA_TTABLE ) ) // look for the listener inside the table
	{
		lua_getfield( L, 2, "listener" );
		if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
		{
			resource = CoronaLuaNewRef([fRuntime L], -1);
		}
		lua_pop( L, 1 );
	}
	else if ( CoronaLuaIsListener( L, 2, IPhoneGameCenterEvent::kName ) )
	{
		resource = CoronaLuaNewRef([fRuntime L], 2);
	}
	else if ( CoronaLuaIsListener( L, 3, IPhoneGameCenterEvent::kName ) )
	{
		resource = CoronaLuaNewRef([fRuntime L], 3);
	}
	
	//	gameNetwork.s-how( "leaderboards", { leaderboard = {category="com.appledts.GKTapper.aggregate", timeScope="Week"}, listener=dismissCallback } )
	if ( 0 == strcasecmp( IPhoneGameCenter::kDashboardLeaderboards, name ) )
	{
		GKLeaderboardViewController* leaderboardcontroller = nil;
		if( ( lua_type( L, 2 ) == LUA_TTABLE ) ) // look for the leaderboard inside the table
		{
			// Even though this is a GKLeaderboardViewController and not a GKLeaderboard,
			// the properties we care about are identical so to not overwhelm our users,
			// we will reuse the key name 'leaderboard'.
			lua_getfield( L, 2, "leaderboard" );
			// GameCenter_GKLeaderboardFromLuaTable convenience API will do checking
			leaderboardcontroller = GameCenter_GKLeaderboardViewControllerFromLuaTable( L, -1 );
			lua_pop( L, 1 );
		}
		else if( ( lua_type( L, 2 ) == LUA_TSTRING ) )
		{
			leaderboardcontroller = [[[GKLeaderboardViewController alloc] init] autorelease];
			[leaderboardcontroller setCategory:[NSString stringWithUTF8String:lua_tostring( L, 2 )]];
		}
		else
		{
			leaderboardcontroller = [[[GKLeaderboardViewController alloc] init] autorelease];
		}
		
		[fGameCenterDelegate setLuaResourceForLeaderboard:resource];
		
		leaderboardcontroller.leaderboardDelegate = fGameCenterDelegate;
		[viewcontroller presentViewController:leaderboardcontroller animated:YES completion:NULL];
	}
	
	// gameNetwork.show( "achievements", dismissCallback )
	// or
	// gameNetwork.show( "achievements", { listener = dismissCallback } )
	else if ( 0 == strcasecmp( IPhoneGameCenter::kDashboardAchievements, name ) )
	{
		GKAchievementViewController* achievementcontroller = [[[GKAchievementViewController alloc] init] autorelease];
		
		[fGameCenterDelegate setLuaResourceForAchievement:resource];
		achievementcontroller.achievementDelegate = fGameCenterDelegate;
		
		[viewcontroller presentViewController:achievementcontroller animated:YES completion:NULL];
	}
	// gameNetwork.show( "friendRequest" )
	// or
	//	gameNetwork.show( "friendRequest", { message="By my friend please",  playerIDs={ "G:194669300", "G:1435127232", "G:1187401733" }, listener=requestCallback} )
	// or gameNetwork.show( "friendRequest", { message="By my friend please", emailAddresses={ "me@me.com", "you@you.com" },  listener=requestCallback} )
	// Array must not be longer than max limit specified by OS or it throws an exception.
	// fetchFriendRequestMaxNumberOfRecipients will return this value.
	// TODO: Truncate the array so we don't exceed the limits. Should take into account combined email+playerids if we get around crashing bug.
	else if ( 0 == strcasecmp( IPhoneGameCenter::kDashboardFriendRequest, name ) )
	{
		GKFriendRequestComposeViewController* friendrequestcontroller = [[[GKFriendRequestComposeViewController alloc] init] autorelease];
		/*
		 [friendrequestcontroller addRecipientsWithEmailAddresses:[NSArray arrayWithObjects:@"me@me.com", @"you@you.com", nil]];
		 [friendrequestcontroller addRecipientsWithPlayerIDs:[NSArray arrayWithObjects:@"G:194669300", @"G:1435127232", @"G:1187401733", nil]];
		 */
		// Seem to be trashing memory when I try setting both the addRecipientsWithEmailAddresses and addRecipientsWithPlayerIDs.
		if( ( lua_type( L, 2 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, 2, "playerIDs" );
			if ( lua_type( L, -1 ) == LUA_TTABLE )
			{
				NSArray* array = GameCenter_NSArrayOfStringsFromLuaTable( L, -1 );
				[friendrequestcontroller addRecipientsWithPlayerIDs:array];
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, 2, "emailAddresses" );
			if ( lua_type( L, -1 ) == LUA_TTABLE )
			{
				NSArray* array = GameCenter_NSArrayOfStringsFromLuaTable( L, -1 );
				[friendrequestcontroller addRecipientsWithEmailAddresses:array];
				
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, 2, "message" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				[friendrequestcontroller setMessage:[NSString stringWithUTF8String:lua_tostring( L, -1 )]];
			}
			lua_pop( L, 1 );
			
		}
		
		[fGameCenterDelegate setLuaResourceForFriendRequest:resource];
		[friendrequestcontroller setValue:fGameCenterDelegate forKey:@"composeViewDelegate"];
		
		[viewcontroller presentViewController:friendrequestcontroller animated:YES completion:NULL];
	}
	else if ( 0 == strcasecmp(IPhoneGameCenter::kDashboardMatches, name ) )
	{
		
		GKMatchRequest *request = [[GKMatchRequest alloc] init];
		request.minPlayers = 2;
		request.maxPlayers = 2;
		
		if( ( lua_type( L, 2 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, 2, "minPlayers" );
			if ( lua_type( L, -1 ) == LUA_TNUMBER )
			{
				request.maxPlayers = lua_tonumber( L , -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, 2, "maxPlayers" );
			if ( lua_type( L, -1 ) == LUA_TNUMBER )
			{
				request.maxPlayers = lua_tonumber( L , -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, 2, "playerGroup" );
			if ( lua_type( L, -1 ) == LUA_TNUMBER )
			{
				request.playerGroup = lua_tonumber( L , -1 );
			}
			lua_pop( L, 1 );
		}
		
		[fTurnBasedMatchMakerDelegate setLuaResourceForMatchMaker:resource];
		
		GKTurnBasedMatchmakerViewController *mmvc = [[GKTurnBasedMatchmakerViewController alloc] initWithMatchRequest:request];
		
		mmvc.turnBasedMatchmakerDelegate = fTurnBasedMatchMakerDelegate;
		mmvc.showExistingMatches = YES;
		
		[viewcontroller presentViewController:mmvc animated:YES completion:nil];
		
	}
	else if ( 0 == strcasecmp(kValueDashboardCreateMatch, name ) )
	{
		CoronaLuaRef resource = NULL;
		GKMatchRequest* matchRequest;
		
		if( ( lua_type( L, 2 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, 2, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef([fRuntime L], -1);
			}
			lua_pop( L, 1 );
			
			matchRequest = GameCenter_GKMatchRequestFromLuaTable( L, 2 );
		}
		
		[fTurnBasedMatchMakerDelegate setLuaResourceForMatchMaker:resource];
		
		// We use find a match through the GKMatchmakerViewController instead of the GKTurnBasedMatch because in iOS 5 the playersToInvite field is ignored.
		GKTurnBasedMatchmakerViewController *mmvc = [[GKTurnBasedMatchmakerViewController alloc] initWithMatchRequest:matchRequest];
		mmvc.showExistingMatches = false;
		mmvc.turnBasedMatchmakerDelegate = fTurnBasedMatchMakerDelegate;
		[viewcontroller presentViewController:mmvc animated:YES completion:nil];
	}
	else
	{
		// Unknown mode
		// Free resource that we created earlier
		CoronaLuaDeleteRef([fRuntime L], resource);
		resource = NULL;
		//		luaL_error( L, "Unknown name for gameNetwork.show (Game Center): %s", name);
		NSLog(@"Unknown name for gameNetwork.show (Game Center): %s\n", name);
	}
	return true;
	
}

int
IPhoneGameCenter::Request( lua_State *L )
{
	int result = 1;
	if ( ! fIsInitialized )
	{
		return 0;
	}
	
	int base = 1;
	const char *command = lua_tostring( L, base );
	
	// 	gameNetwork.request( "resetAchievements", requestCallback )
	if ( 0 == strcasecmp(kValueResetAchievements, command ) )
	{
		
		
		CoronaLuaRef resource = NULL;
		
		if ( CoronaLuaIsListener( L, base + 1, IPhoneGameCenterEvent::kName ) )
		{
			resource = CoronaLuaNewRef([fRuntime L], base + 1);
		}
		else if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef([fRuntime L], -1);
			}
			lua_pop( L, 1 );
		}
		
		
		[GKAchievement resetAchievementsWithCompletionHandler:^(NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									IPhoneGameCenterEvent e( kValueResetAchievements, error, nil );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0);
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	//gameNetwork.request("createMatch", {listener = listener, playerIDs = {"id1", "id2"}, minPlayers = 2, maxPlayers = 3})
	else if ( 0 == strcasecmp(kValueDashboardCreateMatch, command ) )
	{
		CoronaLuaRef resource = NULL;
		GKMatchRequest* matchRequest;
		if( ( lua_type( L, 2 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, 2, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			matchRequest = GameCenter_GKMatchRequestFromLuaTable( L, 2 );
		}

		[fTurnBasedMatchMakerDelegate setLuaResourceForMatchMaker:resource];
		
		[GKTurnBasedMatch findMatchForRequest:matchRequest withCompletionHandler:^(GKTurnBasedMatch *match, NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^(void)
						   {
							   if ( resource )
							   {
								   // Potential race condition: block is asynchronous. If the runtime is shutting down, we may have a problem.
								   if ( match )
								   {
									   [fMatchesDictionary setValue:match forKey:[match matchID]];
								   }
								   
								   NSDictionary* matchDetails = nil;
								   matchDetails = GameCenter_NSDictionaryFromGKTurnBasedMatch(match);
								   
								   IPhoneGameCenterEvent e( kValueDashboardCreateMatch, error, matchDetails );
								   e.Push( [fRuntime L] );
								   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
								   
								   CoronaLuaDeleteRef( [fRuntime L], resource );
							   }
						   }
						   );
		}
		 ];
	}
	//gameNetwork.request("removeMatch", {listener = listener, matchID = "34r34wrt"})
	else if ( 0 == strcasecmp(kValueRemoveMatch, command ) )
	{
		CoronaLuaRef resource = NULL;
		NSString* matchID = nil;
		GKTurnBasedMatch* match = nil;
		
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "matchID" );
			matchID = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			lua_pop( L, 1 );
			
			match = [fMatchesDictionary objectForKey:matchID];
		}
		
		if ( match )
		{
			[match removeWithCompletionHandler:^(NSError *error)
			 {
				 dispatch_async(dispatch_get_main_queue(), ^(void)
								{
									if ( resource )
									{
										IPhoneGameCenterEvent e( kValueRemoveMatch, error, nil );
										e.Push( [fRuntime L] );
										CoronaLuaDispatchEvent( [fRuntime L], resource, 0);
										
										CoronaLuaDeleteRef( [fRuntime L], resource );
									}
								}
								);
			 }];
			
		}
	}
	//gameNetwork.request("loadMatches", {listener = listener})
	else if ( 0 == strcasecmp(kValueLoadMatches, command ) )
	{
		CoronaLuaRef resource = NULL;
		
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
		}
		
		[GKTurnBasedMatch loadMatchesWithCompletionHandler:^(NSArray *matches, NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									// For event.data we are going to return a Lua array with elements consisting of Lua tables with fields
									// containing copies the GKAchievement properties.
									// Since this is a copy of the table and not the real object (userdata), the user must be aware that changing fields
									// will have no impact on the real object.
									
									// First, we are going to create a copy of the achievements array, but instead of GKAchievements, each element
									// will be an NSDictionary with key/value pairs that mimic the GKAchievement properties.
									// Getting these elements into an NSDictionary will make it easier to convert to Lua tables later
									// via Lua/Obj-C Bridge mechanisms (since we can't rely on full blown LuaCocoa to do everything for us automatically).
									NSMutableArray* unboxedMatches = nil;
									if ( [matches count] > 0 )
									{
										unboxedMatches = [NSMutableArray arrayWithCapacity:[matches count]];
										for( GKTurnBasedMatch* match in matches )
										{
											NSDictionary* unboxedMatch = GameCenter_NSDictionaryFromGKTurnBasedMatch( match );
											[unboxedMatches addObject:unboxedMatch];
											[fMatchesDictionary setValue:match forKey:[match matchID]];
										}
									}
									
									IPhoneGameCenterEvent e( kValueLoadMatches, error, unboxedMatches );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );

									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
		
	}
	//gameNetwork.request("endmatch", {listener = listener, matchID = "a4fa4g", data = "some data", outcome = { 1 = "lost", "2" = "lost", "someplayerID" = "won"}})
	else if ( 0 == strcasecmp(kValueEndMatch, command ) )
	{
		CoronaLuaRef resource = NULL;
		NSString* matchID = nil;
		GKTurnBasedMatch* match = nil;
		NSData* data = nil;
		
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "matchID" );
			matchID = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "data" );
			NSString* dataAsString = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			data = [dataAsString dataUsingEncoding:NSUTF8StringEncoding];
			lua_pop( L, 1 );
			
			match = [fMatchesDictionary objectForKey:matchID];
		}
		
		if ( match )
		{
			lua_getfield( L, base + 1, "outcome");
			
			// The outcome participant can be from a playerID string or an index
			for (uint i = 0; i < [[match participants] count]; i++ )
			{
				GKTurnBasedParticipant* participant = [[match participants] objectAtIndex:i];
				lua_getfield( L, -1, [[participant playerID] UTF8String]);
				if (lua_isstring( L, -1 ))
				{
					NSString* outcome = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
					[participant setMatchOutcome:outcomeFromNSString(outcome)];
				}
				lua_pop( L, 1 );
				
				lua_getfield( L, -1, [[NSString stringWithFormat:@"%d", i] cStringUsingEncoding:NSUTF8StringEncoding]);
				if (lua_isstring( L, -1 ))
				{
					NSString* outcome = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
					[participant setMatchOutcome:outcomeFromNSString(outcome)];
				}
				lua_pop( L, 1 );
				
				lua_rawgeti( L, -1, i );
				if (lua_isstring( L, -1 ))
				{
					NSString* outcome = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
					[participant setMatchOutcome:outcomeFromNSString(outcome)];
				}
				lua_pop( L, 1 );
			}
			
			lua_pop( L, 1 );
			[match endMatchInTurnWithMatchData:data completionHandler:^(NSError * error)
			 {
				 dispatch_async(dispatch_get_main_queue(), ^(void)
								{
									if ( resource )
									{
										IPhoneGameCenterEvent e( kValueEndMatch, error, nil );
										e.Push( [fRuntime L] );
										CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
										
										CoronaLuaDeleteRef( [fRuntime L], resource );
									}
								}
								);
			 }];
			
		}
	}
	else if ( 0 == strcasecmp(kValueQuitMatch, command ) )
	{
		CoronaLuaRef resource = NULL;
		NSString* matchID = nil;
		NSString* outcome = nil;
		NSString* nextParticipant = nil;
		NSInteger nextParticipantIndex = -1;
		GKTurnBasedMatch* match = nil;
		NSData* data = nil;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "matchID" );
			matchID = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			lua_pop( L, 1 );
			match = [fMatchesDictionary objectForKey:matchID];
			
			lua_getfield( L, base + 1, "data" );
			NSString* dataAsString = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			data = [dataAsString dataUsingEncoding:NSUTF8StringEncoding];
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "outcome" );
			outcome = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			lua_pop( L, 1 );
			
			// We want to have the ability to get the participant based on the index because automatch participants might not have a playerID
			lua_getfield( L, base + 1, "nextParticipant" );
			if ( lua_istable( L, -1) )
			{
				lua_rawgeti( L, -1, 1 );
				if (lua_isnumber( L, -1 ) )
				{
					nextParticipantIndex = lua_tonumber( L, -1 );
				}
				else if ( lua_isstring( L, -1 ) )
				{
					nextParticipant = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
				}
			}
			lua_pop( L, 2 );
		}
		
		if ( match )
		{
			
			void (^callback)(NSError *error) = ^(NSError *error){
				dispatch_async(dispatch_get_main_queue(), ^(void)
							   {
								   if ( resource )
								   {
									   IPhoneGameCenterEvent e( kValueQuitMatch, error, nil );
									   e.Push( [fRuntime L] );
									   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									   
									   CoronaLuaDeleteRef( [fRuntime L], resource );
								   }
							   }
							   );
			};
			
			// If the current participant is the local player then we have to pass on the turn to someone else with some data and set the match outcome
			if ( [[[match currentParticipant] playerID] isEqualToString:[[GKLocalPlayer localPlayer] playerID]] && nextParticipant != nil)
			{
				GKTurnBasedParticipant* participant;
				if ( nextParticipantIndex < 0)
				{
					participant = findParticipantInMatch(match, nextParticipant);
				}
				else
				{
					participant = [[match participants]objectAtIndex:nextParticipantIndex];
				}
				
				[match participantQuitInTurnWithOutcome:outcomeFromNSString(outcome) nextParticipants:[NSArray arrayWithObject:participant] turnTimeout:GKTurnTimeoutDefault matchData:data completionHandler:callback];
			}
			else
			{
				[match participantQuitOutOfTurnWithOutcome:outcomeFromNSString(outcome) withCompletionHandler:callback];
			}
		}
	}
	//gameNetwork.request("endTurn", {listener = listener, nextParticipant = {1}, data = "some data", matchID = "34r34t"})
	else if ( 0 == strcasecmp(kValueEndTurn, command ) )
	{
		CoronaLuaRef resource = NULL;
		NSString* nextParticipant = nil;
		NSInteger nextParticipantIndex = -1;
		NSData* data = nil;
		GKTurnBasedMatch* match = nil;
		
		if ( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			// We want to have the ability to get the participant based on the index because automatch participants might not have a playerID
			lua_getfield( L, base + 1, "nextParticipant" );
			if ( lua_istable( L, -1) )
			{
				lua_rawgeti( L, -1, 1 );
				if (lua_isnumber( L, -1 ) )
				{
					nextParticipantIndex = lua_tonumber( L, -1 );
				}
				else if ( lua_isstring( L, -1 ) )
				{
					nextParticipant = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
				}
			}
			lua_pop( L, 2 );
			
			lua_getfield( L, base + 1, "data" );
			NSString* dataAsString = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			data = [dataAsString dataUsingEncoding:NSUTF8StringEncoding];
			
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "matchID" );
			NSString* matchID = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			lua_pop( L, 1 );
			match = [fMatchesDictionary objectForKey:matchID];
		}
		
		if ( match )
		{
			GKTurnBasedParticipant* participant;
			if ( nextParticipantIndex < 0)
			{
				participant = findParticipantInMatch(match, nextParticipant);
			}
			else
			{
				participant = [[match participants]objectAtIndex:nextParticipantIndex];
			}
			
			void (^callback)(NSError *error) = ^(NSError *error){
				dispatch_async(dispatch_get_main_queue(), ^(void)
							   {
								   if ( resource )
								   {
									   IPhoneGameCenterEvent e( kValueEndTurn, error, nil );
									   e.Push( [fRuntime L] );
									   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									   
									   CoronaLuaDeleteRef( [fRuntime L], resource );
								   }
							   }
							   );
			};
			
			[match endTurnWithNextParticipants:[NSArray arrayWithObject:participant] turnTimeout:GKTurnTimeoutDefault matchData:data completionHandler:callback];
		}
	}
	// gameNetwork.request("setEventListener", {listener = listener})
	else if ( 0 == strcasecmp(kValueSetEventHandler, command ) )
	{
		CoronaLuaRef resource = NULL;
		
		if ( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
		}
		
		// Don't need to do a check for resource because if its null then we're bacially unsetting it
		[fTurnBasedEventHandlerDelegate setLuaResourceForEventHandler:resource];
		
	}
	// 	gameNetwork.request( "loadCurrentPlayer", {listener = listener, matchID = "3482734"} )
	else if ( 0 == strcasecmp(kValueCurrentPlayer, command ) )
	{
		CoronaLuaRef resource = NULL;
		GKTurnBasedMatch* match = nil;
		
		if ( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "matchID" );
			NSString* matchID = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			lua_pop( L, 1 );
			match = [fMatchesDictionary objectForKey:matchID];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void)
					   {
						   if ( resource && match)
						   {
							   
							   // Returns an array of strings
							   IPhoneGameCenterEvent e( kValueCurrentPlayer, nil, GameCenter_NSDictionaryFromGKTurnBasedParticipant( [match currentParticipant] ) );
							   e.Push( [fRuntime L] );
							   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
							   
							   CoronaLuaDeleteRef( [fRuntime L], resource );
						   }
					   }
					   );
	}
	// 	gameNetwork.request( "loadMatchData", {listener = listener, matchID = "3482734"} )
	else if ( 0 == strcasecmp(kValueLoadMatchData, command ) )
	{
		CoronaLuaRef resource = NULL;
		GKTurnBasedMatch* match = nil;
		
		if ( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "matchID" );
			NSString* matchID = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			lua_pop( L, 1 );
			match = [fMatchesDictionary objectForKey:matchID];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void)
					   {
						   if ( resource )
						   {
							   
							   IPhoneGameCenterEvent e( kValueLoadMatchData, nil, GameCenter_NSDictionaryFromGKTurnBasedMatch( match ) );
							   e.Push( [fRuntime L] );
							   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
							   
							   CoronaLuaDeleteRef( [fRuntime L], resource );
						   }
					   }
					   );
	}
	// 	gameNetwork.request( "loadAchievements", requestCallback )
	else if ( 0 == strcasecmp(kValueLoadAchievements, command ) )
	{
		CoronaLuaRef resource = NULL;
		
		if ( CoronaLuaIsListener( L, base + 1, IPhoneGameCenterEvent::kName ) )
		{
			resource = CoronaLuaNewRef( [fRuntime L], base + 1 );
		}
		else if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the options inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
		}
		
		[GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *achievements, NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									// For event.data we are go ing to return a Lua array with elements consisting of Lua tables with fields
									// containing copies the GKAchievement properties.
									// Since this is a copy of the table and not the real object (userdata), the user must be aware that changing fields
									// will have no impact on the real object.
									
									// First, we are going to create a copy of the achievements array, but instead of GKAchievements, each element
									// will be an NSDictionary with key/value pairs that mimic the GKAchievement properties.
									// Getting these elements into an NSDictionary will make it easier to convert to Lua tables later
									// via Lua/Obj-C Bridge mechanisms (since we can't rely on full blown LuaCocoa to do everything for us automatically).
									NSMutableArray* unboxedachievements = nil;
									if ( [achievements count] > 0 )
									{
										unboxedachievements = [NSMutableArray arrayWithCapacity:[achievements count]];
										for( GKAchievement* achievement in achievements )
										{
											NSDictionary* unboxedachievement = GameCenter_NSDictionaryFromGKAchievement( achievement );
											[unboxedachievements addObject:unboxedachievement];
										}
									}
									
									IPhoneGameCenterEvent e( kValueLoadAchievements, error, unboxedachievements );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	else if ( 0 == strcasecmp(kValueMaxPlayersAllowedForTurnBased, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
		}
		
		// This function is iOS6+
		if ([GKMatchRequest respondsToSelector:@selector(maxPlayersAllowedForMatchOfType:)]) {
			dispatch_async(dispatch_get_main_queue(), ^(void)
						   {
							   if ( resource )
							   {
								   
									   // Returns an array of strings
								   IPhoneGameCenterEvent e( kValueMaxPlayersAllowedForTurnBased, nil, [NSNumber numberWithInt:[GKMatchRequest maxPlayersAllowedForMatchOfType:GKMatchTypeTurnBased]] );
								   e.Push( [fRuntime L] );
								   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
								   
								   CoronaLuaDeleteRef( [fRuntime L], resource );								   }
						   }
						   );
			
		}
	}
	
	
	/*
	 gameNetwork.request( "unlockAchievement", "com.appledts.twenty_taps", requestCallback )
	 or
	 gameNetwork.request( "unlockAchievement",
	 {
	 achievement =
	 {
	 identifier="com.appledts.twenty_taps",
	 percentComplete=25,
	 showsCompletionBanner=true,
	 },
	 listener=requestCallback,
	 }
	 )
	 
	 or  (maybe won't officiall support this version)
	 gameNetwork.request( "unlockAchievement",
	 {
	 achievement =
	 {
	 identifier="com.appledts.twenty_taps",
	 percentComplete=25,
	 showsCompletionBanner=true,
	 },
	 },
	 requestCallback
	 )
	 
	 or (maybe won't officiall support this version)
	 gameNetwork.request( "unlockAchievement",
	 {
	 identifier="com.appledts.twenty_taps",
	 percentComplete=25,
	 showsCompletionBanner=true,
	 listener=requestCallback,
	 }
	 )
	 */
	else if ( 0 == strcasecmp(kValueUnlockAchievement, command ) )
	{
		CoronaLuaRef resource = NULL;
		int stacksize = lua_gettop( L );
		GKAchievement* achievement = nil;
		// Ugh. We support too many ways of passing in data.
		if ( stacksize < 2 )
		{
			luaL_error( L, "unlockAchievement requires at least two parameters");
			return 0; // error quits function immediately. This is never called.
		}
		if ( stacksize > 3 )
		{
			luaL_error( L, "unlockAchievement cannot take more than three parameters");
			return 0; // error quits function immediately. This is never called.
		}
		
		// Assume second parameter must be a string or a table
		if ( lua_type( L, base + 1 ) == LUA_TSTRING )
		{
			achievement = [[[GKAchievement alloc] initWithIdentifier:[NSString stringWithUTF8String:lua_tostring( L, base + 1 )]] autorelease];
			[achievement setPercentComplete:100.0];
		}
		else if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) )
		{
			// There are two ways to interpret this table.
			// It could be a table containing two keys, 'achievement' and 'listener', where the achievement is the GKAchievement table.
			// Or it could be a conbined table with all the keys
			// It could be a single table containing all the
			
			int index_of_achievement_table = base + 1;
			
			lua_getfield( L, index_of_achievement_table, "achievement" );
			if ( lua_type( L, -1 ) == LUA_TTABLE )
			{
				// found the achievement table
				achievement = GameCenter_GKAchievementFromLuaTable( L, -1 );
				// We will allow the user to not specify the percentComplete field in the table, in which case we assume 100%.
				// If the field exists, it was set in GameCenter_GKAchievementFromLuaTable.
				// Otherwise, we assume the user wants to set it to 100%.
				lua_getfield( L, -1, "percentComplete" );
				if ( lua_type( L, -1 ) == LUA_TNIL )
				{
					[achievement setPercentComplete:100.0];
				}
				lua_pop( L, 1 ); // pop percentComplete
				
				lua_pop( L, 1 ); // pop the achievement table to get back to the top level table parameter
			}
			else
			{
				// we didn't get what we were looking for, unpop it and assume the table parameter IS the achievement table
				lua_pop( L, 1 ); // get back to the top level table parameter
				// Assuming the top level table parameter is the achievement table
				achievement = GameCenter_GKAchievementFromLuaTable( L, index_of_achievement_table );
				// We will allow the user to not specify the percentComplete field in the table, in which case we assume 100%.
				// If the field exists, it was set in GameCenter_GKAchievementFromLuaTable.
				// Otherwise, we assume the user wants to set it to 100%.
				lua_getfield( L, -1, "percentComplete" );
				if ( lua_type( L, -1 ) == LUA_TNIL )
				{
					[achievement setPercentComplete:100.0];
				}
				lua_pop( L, 1 );
			}
			
			if ( nil == achievement )
			{
				luaL_error( L, "unlockAchievement for gameNetwork/Game Center could not convert your table to a GKAchievement object. Please verify you supplied the correct fields and value types.");
				return 0; // error quits function immediately. This is never called.
			}
			
			
		}
		else
		{
			luaL_error( L, "unlockAchievement second parameter must be the achievement identifier to unlock");
			return 0; // error quits function immediately. This is never called.
		}
		
		// Now allow for a listener. It could be a 3rd parameter or in the table.
		// Or the user could mess up and put it in both.
		if ( 3 == stacksize ) // assuming the listener is in the 3rd position
		{
			if ( CoronaLuaIsListener( L, base + 2, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], base + 2 );
			}
		}
		else if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			// We will allow the user to not specify the percentComplete field in the table, in which case we assume 100%.
			// If the field exists, it was set in GameCenter_GKAchievementFromLuaTable.
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
		}
		
		
		[achievement reportAchievementWithCompletionHandler:^(NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									IPhoneGameCenterEvent e( kValueUnlockAchievement, error, GameCenter_NSDictionaryFromGKAchievement( achievement ) );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	
	
	
	//	gameNetwork.request( "loadScores", { leaderboard={ playerScope="Global", timeScope="AllTime", range={1,3} }, listener=requestCallback } )
	else if ( 0 == strcasecmp(kValueLoadScores, command ) )
	{
		CoronaLuaRef resource = NULL;
		GKLeaderboard* leaderboard = nil;
		// This is a new API. Going to require all parameters to be in table parameter for simplicity.
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "leaderboard" );
			// GameCenter_GKLeaderboardFromLuaTable convenience API will do checking
			leaderboard = GameCenter_GKLeaderboardFromLuaTable( L, -1 );
			lua_pop( L, 1 );
		}
		
		[leaderboard loadScoresWithCompletionHandler:^(NSArray *scores, NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									// For event.data we are going to return a Lua array with elements consisting of Lua tables with fields
									// containing copies the GKAchievement properties.
									// Since this is a copy of the table and not the real object (userdata), the user must be aware that changing fields
									// will have no impact on the real object.
									
									// First, we are going to create a copy of the achievements array, but instead of GKAchievements, each element
									// will be an NSDictionary with key/value pairs that mimic the GKAchievement properties.
									// Getting these elements into an NSDictionary will make it easier to convert to Lua tables later
									// via Lua/Obj-C Bridge mechanisms (since we can't rely on full blown LuaCocoa to do everything for us automatically).
									NSMutableArray* unboxedscores = nil;
									if ( [scores count] > 0 )
									{
										unboxedscores = [NSMutableArray arrayWithCapacity:[scores count]];
										for( GKScore* score in scores )
										{
											NSDictionary* unboxedscore = GameCenter_NSDictionaryFromGKScore( score );
											[unboxedscores addObject:unboxedscore];
										}
										
									}
									
									GKScore* localplayerscore = [leaderboard localPlayerScore];
									NSDictionary* unboxedlocalplayerscore = nil;
									if ( localplayerscore )
									{
										unboxedlocalplayerscore = GameCenter_NSDictionaryFromGKScore( localplayerscore );
									}
									IPhoneGameCenterLoadScoresEvent e( kValueLoadScores, error, unboxedscores, unboxedlocalplayerscore );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	
	
	// 	gameNetwork.request( "setHighScore", { localPlayerScore={ category="com.appledts.GKTapper.aggregate" value=42 }, listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueSetHighScore, command ) )
	{
		CoronaLuaRef resource = NULL;
		GKScore* playerscore = nil;
		NSDictionary* playerdictionary = nil;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, base + 1, "localPlayerScore" );
			// GameCenter_GKLeaderboardFromLuaTable convenience API will do checking
			playerscore = GameCenter_GKScoreFromLuaTable( L, -1 );
			// A little bit of a hack. To give the user more information to distinguish callbacks,
			// I would like to pass the localPlayerScore back to the user.
			// But Apple doesn't return us this info in their callback.
			// Also, GKScore has read-only fields so we can't copy all the properties from the Lua table into the GKScore.
			// So I am creating a dictionary to hold the contents so we can pass them back.
			playerdictionary = GameCenter_NSDictionaryScoreFromLuaTable( L, -1 );
			lua_pop( L, 1 );
			
			if ( nil == playerscore )
			{
				luaL_error( L, "setHighScore for gameNetwork/Game Center could not convert your table to a GKScore object. Please verify you supplied the correct fields and value types.");
				return 0; // error quits function immediately. This is never called.
			}
		}
		
		
		[playerscore reportScoreWithCompletionHandler:^(NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									
									IPhoneGameCenterEvent e( kValueSetHighScore, error, playerdictionary );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	
	
	// 	gameNetwork.request( "loadLeaderboardCategories", { listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueFetchLeaderboardCategories, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
		}
		
		
		[GKLeaderboard loadCategoriesWithCompletionHandler:^(NSArray *categories, NSArray *titles, NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									// Return an array of tables. Each table is has two keys 'category' and 'title'.
									IPhoneGameCenterEvent e( kValueFetchLeaderboardCategories, error, GameCenter_NSArrayFromCategoriesAndTitles( categories, titles ) );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	
	
	// 	gameNetwork.request( "loadAchievementDescriptions", { listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueFetchAchievementDescriptions, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
		}
		
		
		[GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *descriptions, NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									// Returns an array of strings
									NSMutableArray* unboxedachievements = nil;
									if ( [descriptions count] > 0 )
									{
										unboxedachievements = [NSMutableArray arrayWithCapacity:[descriptions count]];
										for( GKAchievementDescription* achievement in descriptions )
										{
											NSDictionary* unboxedachievement = GameCenter_NSDictionaryFromGKAchievementDescription( achievement );
											[unboxedachievements addObject:unboxedachievement];
										}
									}
									IPhoneGameCenterEvent e( kValueFetchAchievementDescriptions, error, unboxedachievements );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	
	
	// 	gameNetwork.request( "loadFriends", { listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueFetchFriends, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
		}
		
		[[GKLocalPlayer localPlayer] loadFriendsWithCompletionHandler:^(NSArray *friends, NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									// Returns an array of strings
									IPhoneGameCenterEvent e( kValueFetchFriends, error, friends );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	
	// gameNetwork.request( "loadPlayers", { playerIDs={ "G:194669300", "G:1435127232", "G:1187401733" }, listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueFetchPlayers, command ) )
	{
		CoronaLuaRef resource = NULL;
		NSArray* identifiers = nil;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			
			lua_getfield( L, base + 1, "playerIDs" );
			identifiers = GameCenter_NSArrayOfStringsFromLuaTable( L, -1 );
			lua_pop( L, 1 );
		}
		
		[GKPlayer loadPlayersForIdentifiers:identifiers withCompletionHandler:^(NSArray *players, NSError *error)
		 {
			 // Apple's GKTapper example warns that GameKit may not perform on the main thread.
			 dispatch_async(dispatch_get_main_queue(), ^(void)
							{
								if ( resource )
								{
									NSMutableArray* unboxedplayers = nil;
									if ( [players count] > 0 )
									{
										unboxedplayers = [NSMutableArray arrayWithCapacity:[players count]];
										for( GKPlayer* player in players )
										{
											NSDictionary* unboxedplayer = GameCenter_NSDictionaryFromGKPlayer( player );
											[unboxedplayers addObject:unboxedplayer];
										}
									}
									
									// Returns an array of strings
									IPhoneGameCenterEvent e( kValueFetchPlayers, error, unboxedplayers );
									e.Push( [fRuntime L] );
									CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
									
									CoronaLuaDeleteRef( [fRuntime L], resource );
								}
							}
							);
		 }
		 ];
	}
	
	// 	gameNetwork.request( "loadLocalPlayer", { listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueFetchLocalPlayer, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
		}
		
		// We're kind of faking things here. Once logged in, we already have the local player inforation so we can just return it.
		// But for consistency, let's do it though a block callback like the others (which may help avoid recursion issues).
		// dispatch_after(DISPATCH_TIME_NOW, ...) may do what we want, but the docs suggest doing dispatch_async is better for that case.
		dispatch_async(dispatch_get_main_queue(), ^(void)
					   {
						   if ( resource )
						   {
							   // Returns an array of strings
							   IPhoneGameCenterEvent e( kValueFetchLocalPlayer, nil, GameCenter_NSDictionaryFromGKLocalPlayer( [GKLocalPlayer localPlayer] ) );
							   e.Push( [fRuntime L] );
							   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
							   
							   CoronaLuaDeleteRef( [fRuntime L], resource );
						   }
					   }
					   );
	}
	
	// 	gameNetwork.request( "loadFriendRequestMaxNumberOfRecipients", { listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueFetchFriendRequestMaxNumberOfRecipients, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
		}
		
		// We're kind of faking things here. Once logged in, we already have the local player inforation so we can just return it.
		// But for consistency, let's do it though a block callback like the others (which may help avoid recursion issues).
		// dispatch_after(DISPATCH_TIME_NOW, ...) may do what we want, but the docs suggest doing dispatch_async is better for that case.
		dispatch_async(dispatch_get_main_queue(), ^(void)
					   {
						   if ( resource )
						   {
							   // Returns an array of strings
							   IPhoneGameCenterEvent e( kValueFetchFriendRequestMaxNumberOfRecipients, nil, [NSNumber numberWithInt:[GKFriendRequestComposeViewController maxNumberOfRecipients]] );
							   e.Push( [fRuntime L] );
							   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
							   
							   CoronaLuaDeleteRef( [fRuntime L], resource );
						   }
					   }
					   );
	}
	
	
	
	// gameNetwork.request( "loadPlayerPhoto", { playerID="G:194669300", size="Normal", listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueLoadPlayerPhoto, command ) )
	{
		CoronaLuaRef resource = NULL;
		NSArray* identifiers = nil;
		GKPhotoSize photosize = GKPhotoSizeSmall;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			NSString* playerid = nil;
			lua_getfield( L, base + 1, "playerID" );
			if( ( lua_type( L, -1 ) == LUA_TSTRING ) )
			{
				playerid = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
				identifiers = [NSArray arrayWithObject:playerid];
			}
			lua_pop( L, 1 );
			
			lua_getfield( L, -1, "size" );
			if( ( lua_type( L, -1 ) == LUA_TSTRING ) )
			{
				if (  0 == strcasecmp(kValuePhotoSizeNormal, lua_tostring( L, -1 ) ) )
				{
					photosize = GKPhotoSizeNormal;
				}
			}
			lua_pop( L, 1 );
		}
		
		// Really stupid. Because we don't have the original GKPlayer object, we have to refetch it, and then do another fetch for the image.
		
		[GKPlayer loadPlayersForIdentifiers:identifiers withCompletionHandler:^(NSArray *players, NSError *error)
		 {
			 if ( nil != error )
			 {
				 dispatch_async(dispatch_get_main_queue(), ^(void)
								{
									if ( resource )
									{
										IPhoneGameCenterLoadPlayerPhotoEvent e( kValueLoadPlayerPhoto, error, nil, nil );
										e.Push( [fRuntime L] );
										CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
										
										CoronaLuaDeleteRef( [fRuntime L], resource );
									}
								}
								);
			 }
			 else
			 {
				 GKPlayer* requestedplayer = [players objectAtIndex:0];
				 if ( [requestedplayer respondsToSelector:@selector(loadPhotoForSize:withCompletionHandler:)] )
				 {
					 [requestedplayer loadPhotoForSize:photosize withCompletionHandler:^(UIImage *image, NSError *error)
					  {
						  // Apple's GKTapper example warns that GameKit may not perform on the main thread.
						  dispatch_async(dispatch_get_main_queue(), ^(void)
										 {
											 if ( resource )
											 {
												 // Returns an array of strings
												 IPhoneGameCenterLoadPlayerPhotoEvent e( kValueLoadPlayerPhoto, error, GameCenter_NSDictionaryFromGKPlayer(requestedplayer), image );
												 e.Push( [fRuntime L] );
												 CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
												 
												 CoronaLuaDeleteRef( [fRuntime L], resource );
											 }
										 }
										 );
					  }
					  ];
				 }
				 else
				 {
					 dispatch_async(dispatch_get_main_queue(), ^(void)
									{
										if ( resource )
										{
											// We have no convention for error codes in Corona. I'm totally making this up to fit with the NSError infrastructure already in place.
											NSMutableDictionary* errordetail = [NSMutableDictionary dictionary];
											[errordetail setValue:NSLocalizedString(@"This API is not available on this version of iOS.", @"This API is not available on this version of iOS.") forKey:NSLocalizedDescriptionKey];
											NSError* error = [NSError errorWithDomain:@"com.ansca.corona.gamenetwork.gamecenter" code:1 userInfo:errordetail];
											
											// Returns an array of strings
											IPhoneGameCenterLoadPlayerPhotoEvent e( kValueLoadPlayerPhoto, error, GameCenter_NSDictionaryFromGKPlayer(requestedplayer), nil );
											e.Push( [fRuntime L] );
											CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
											
											CoronaLuaDeleteRef( [fRuntime L], resource );
										}
									}
									);
				 }
			 }
		 }
		 ];
	}
	
	// 	gameNetwork.request( "loadAchievementImage", { achievementDescription={identifier="com.appledts.twenty_taps"}, listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueLoadAchievementImage, command ) )
	{
		CoronaLuaRef resource = NULL;
		NSString* requested_identifier = nil;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
			
			lua_getfield( L, base + 1, "achievementDescription" );
			if ( lua_type( L, base + 1 ) == LUA_TTABLE )
			{
				lua_getfield( L, -1, "identifier" );
				if ( lua_type( L, -1 ) == LUA_TSTRING )
				{
					requested_identifier = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
				}
				lua_pop( L, 1 );
			}
			lua_pop( L, 1 );
			
		}
		
		
		// Really stupid. Because we don't have the original GKAchievementDescription object,
		// we have to refetch it, and then do another fetch for the image.
		// I considered caching the objects, but the problem is each object retains the image once you fetch it.
		// There is no way to release the image without releasing the entire GKAchievementDescription object.
		// And there is no way for end users to control these objects since we are passing table copies of things
		// and not the actual object.
		[GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *descriptions, NSError *error)
		 {
			 GKAchievementDescription* achievementdescription = nil;
			 if ( nil == error ) // we passed the first network request, so look for the achievement to make sure the user requested a valid identifier
			 {
				 for( achievementdescription in descriptions )
				 {
					 if ( [[achievementdescription identifier] isEqualToString:requested_identifier] )
					 {
						 break;
					 }
				 }
				 if ( nil == achievementdescription )
				 {
					 // We have no convention for error codes in Corona. I'm totally making this up to fit with the NSError infrastructure already in place.
					 NSMutableDictionary* errordetail = [NSMutableDictionary dictionary];
					 [errordetail setValue:NSLocalizedString(@"No GKAchievement exists for requested identifier", @"No GKAchievement exists for requested identifier") forKey:NSLocalizedDescriptionKey];
					 error = [NSError errorWithDomain:@"com.ansca.corona.gamenetwork.gamecenter" code:2 userInfo:errordetail];
				 }
			 }
			 
			 if ( nil != error ) // either a network failure or a bad identifer was used
			 {
				 dispatch_async(dispatch_get_main_queue(), ^(void)
								{
									if ( resource )
									{
										IPhoneGameCenterEvent e( kValueLoadAchievementImage, error, nil );
										e.Push( [fRuntime L] );
										CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
										
										CoronaLuaDeleteRef( [fRuntime L], resource );
									}
								}
								);
			 }
			 else // now load the image
			 {
				 [achievementdescription loadImageWithCompletionHandler:^(UIImage *image, NSError *error)
				  {
					  // Apple's GKTapper example warns that GameKit may not perform on the main thread.
					  dispatch_async(dispatch_get_main_queue(), ^(void)
									 {
										 if ( resource )
										 {
											 NSDictionary* unboxedachievement = GameCenter_NSDictionaryFromGKAchievementDescription( achievementdescription );
											 // Returns an array of strings
											 IPhoneGameCenterLoadAchievementEvent e( kValueLoadAchievementImage, error, unboxedachievement, image );
											 e.Push( [fRuntime L] );
											 CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
											 
											 CoronaLuaDeleteRef( [fRuntime L], resource );
										 }
									 }
									 ); // end dispatch_async
				  }
				  ]; // end loadImageWithCompletionHandler
			 }
		 }
		 ]; // end loadAchievementDescriptionsWithCompletionHandler
		
	}
	
	
	// 	gameNetwork.request( "loadPlaceholderCompletedAchievementImage", { listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueLoadPlaceholderCompletedAchievementImage, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
		}
		
		// We're kind of faking things here. Once logged in, we already have the local player inforation so we can just return it.
		// But for consistency, let's do it though a block callback like the others (which may help avoid recursion issues).
		// dispatch_after(DISPATCH_TIME_NOW, ...) may do what we want, but the docs suggest doing dispatch_async is better for that case.
		dispatch_async(dispatch_get_main_queue(), ^(void)
					   {
						   if ( resource )
						   {
							   // Returns an array of strings
							   IPhoneGameCenterLoadImageEvent e( kValueLoadPlaceholderCompletedAchievementImage, nil, [GKAchievementDescription placeholderCompletedAchievementImage] );
							   e.Push( [fRuntime L] );
							   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
							   
							   CoronaLuaDeleteRef( [fRuntime L], resource );
						   }
					   }
					   );
	}
	
	// 	gameNetwork.request( "loadIncompleteAchievementImage", { listener=requestCallback} )
	else if ( 0 == strcasecmp(kValueLoadIncompleteAchievementImage, command ) )
	{
		CoronaLuaRef resource = NULL;
		if( ( lua_type( L, base + 1 ) == LUA_TTABLE ) ) // look for the listener inside the table
		{
			lua_getfield( L, base + 1, "listener" );
			if ( CoronaLuaIsListener( L, -1, IPhoneGameCenterEvent::kName ) )
			{
				resource = CoronaLuaNewRef( [fRuntime L], -1 );
			}
			lua_pop( L, 1 );
			
		}
		
		// We're kind of faking things here. Once logged in, we already have the local player inforation so we can just return it.
		// But for consistency, let's do it though a block callback like the others (which may help avoid recursion issues).
		// dispatch_after(DISPATCH_TIME_NOW, ...) may do what we want, but the docs suggest doing dispatch_async is better for that case.
		dispatch_async(dispatch_get_main_queue(), ^(void)
					   {
						   if ( resource )
						   {
							   // Returns an array of strings
							   IPhoneGameCenterLoadImageEvent e( kValueLoadIncompleteAchievementImage, nil, [GKAchievementDescription incompleteAchievementImage] );
							   e.Push( [fRuntime L] );
							   CoronaLuaDispatchEvent( [fRuntime L], resource, 0 );
							   
							   CoronaLuaDeleteRef( [fRuntime L], resource );
						   }
					   }
					   );
	}
	return result;
	
}

GKTurnBasedParticipant*
IPhoneGameCenter::findParticipantInMatch( GKTurnBasedMatch* match, NSString* participantID )
{
	GKTurnBasedParticipant* participant = nil;
	
	for (uint i = 0; i < [[match participants] count]; i++)
	{
		if ( [[[[match participants] objectAtIndex:i] playerID] isEqualToString:participantID] )
		{
			participant = [[match participants] objectAtIndex:i];
			break;
		}
	}
	return participant;
}

NSInteger
IPhoneGameCenter::outcomeFromNSString( NSString* outcomeInput )
{
	NSInteger outcome = GKTurnBasedMatchOutcomeNone;
	if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"first"]] )
	{
		outcome = GKTurnBasedMatchOutcomeFirst;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"second"]] )
	{
		outcome = GKTurnBasedMatchOutcomeSecond;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"third"]] )
	{
		outcome = GKTurnBasedMatchOutcomeThird;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"fourth"]] )
	{
		outcome = GKTurnBasedMatchOutcomeFourth;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"quit"]] )
	{
		outcome = GKTurnBasedMatchOutcomeQuit;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"won"]] )
	{
		outcome = GKTurnBasedMatchOutcomeWon;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"lost"]] )
	{
		outcome = GKTurnBasedMatchOutcomeLost;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"tied"]] )
	{
		outcome = GKTurnBasedMatchOutcomeTied;
	}
	else if ( [outcomeInput isEqualToString:[NSString stringWithUTF8String:"timeExpired"]] )
	{
		outcome = GKTurnBasedMatchOutcomeTimeExpired;
	}
	return outcome;
}

NSString*
IPhoneGameCenter::nsstringFromOutcome( GKTurnBasedMatchOutcome outcome )
{
	NSString* outcomeOutput;
	if ( outcome == GKTurnBasedMatchOutcomeFirst )
	{
		outcomeOutput = [NSString stringWithUTF8String:"first"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeSecond )
	{
		outcomeOutput = [NSString stringWithUTF8String:"second"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeThird )
	{
		outcomeOutput = [NSString stringWithUTF8String:"third"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeFourth )
	{
		outcomeOutput = [NSString stringWithUTF8String:"fourth"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeQuit )
	{
		outcomeOutput = [NSString stringWithUTF8String:"quit"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeWon )
	{
		outcomeOutput = [NSString stringWithUTF8String:"won"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeLost )
	{
		outcomeOutput = [NSString stringWithUTF8String:"lost"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeTied )
	{
		outcomeOutput = [NSString stringWithUTF8String:"tied"];
	}
	else if ( outcome == GKTurnBasedMatchOutcomeTimeExpired )
	{
		outcomeOutput = [NSString stringWithUTF8String:"timeExpired"];
	}
	else
	{
		outcomeOutput = [NSString stringWithUTF8String:"none"];
	}
	
	return outcomeOutput;
}

NSString*
IPhoneGameCenter::nsstringFromStatus( GKTurnBasedParticipantStatus status )
{
	NSString* statusOutput;
	if ( status == GKTurnBasedParticipantStatusInvited )
	{
		statusOutput = [NSString stringWithUTF8String:"invited"];
	}
	else if ( status == GKTurnBasedParticipantStatusDeclined )
	{
		statusOutput = [NSString stringWithUTF8String:"declined"];
	}
	else if ( status == GKTurnBasedParticipantStatusMatching )
	{
		statusOutput = [NSString stringWithUTF8String:"matching"];
	}
	else if ( status == GKTurnBasedParticipantStatusActive )
	{
		statusOutput = [NSString stringWithUTF8String:"active"];
	}
	else if ( status == GKTurnBasedParticipantStatusDone )
	{
		statusOutput = [NSString stringWithUTF8String:"done"];
	}
	else
	{
		statusOutput = [NSString stringWithUTF8String:"unknown"];
	}
	
	return statusOutput;
}

// TODO:


/*
 GKPlayerAuthenticationDidChangeNotificationName (reuse init callback?)
 
 */

// ----------------------------------------------------------------------------
	
} // namespace Rtt

// ----------------------------------------------------------------------------

