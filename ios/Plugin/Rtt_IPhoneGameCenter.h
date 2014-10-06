// ----------------------------------------------------------------------------
// 
// Rtt_IPhoneGameCenter.h
// Copyright (c) 2011 Ansca, Inc. All rights reserved.
// 
// Reviewers:
// 		Eric Wing
//
// ----------------------------------------------------------------------------

#ifndef _Rtt_PlatformGameCenter_H__
#define _Rtt_PlatformGameCenter_H__

#include "CoronaRuntime.h"
#include "CoronaLua.h"

#import <GameKit/GameKit.h>

// ----------------------------------------------------------------------------

@class GameCenterDelegate;
@class TurnBasedMatchMakerDelegate;
@class TurnBasedEventHandlerDelegate;

struct lua_State;

namespace Rtt
{
	
class LuaResource;

// ----------------------------------------------------------------------------

class IPhoneGameCenter
{
	public:
		static const char kDashboardLeaderboards[];
		static const char kDashboardChallenges[];
		static const char kDashboardAchievements[];
		static const char kDashboardFriendRequest[];
		static const char kDashboardMatches[];
		static const char kValueDashboardCreateMatch[];
//		static const char kDashboardFriends[];
//		static const char kDashboardPlaying[];
//		static const char kDashboardHighscore[];

		static const char kValueCreateMatch[];
		static const char kValueQuitMatch[];
		static const char kValueRemoveMatch[];
		static const char kValueEndMatch[];
		static const char kValueCurrentPlayer[];
		static const char kValueResetAchievements[];
		static const char kValueLoadAchievements[];
		static const char kValueUnlockAchievement[];
		static const char kValuePlayerTurn[];
		static const char kValueEndTurn[];
		static const char kValueInvitationReceived[];
		static const char kValueSetEventHandler[];
		static const char kValueLoadMatchData[];
		static const char kValueMatchEnded[];
        static const char kValueMaxPlayersAllowedForTurnBased[];

		static const char kValueLoadScores[];
		static const char kValueSetHighScore[];

		static const char kValueLoadPlayerPhoto[];
		static const char kValueLoadAchievementImage[];
		static const char kValueLoadMatches[];
		static const char kValueLoadPlaceholderCompletedAchievementImage[];
		static const char kValueLoadIncompleteAchievementImage[];
		
		static const char kValueInit[];
		static const char kValueSignIn[];

		static const char kValueTimeScopeAllTime[];
		static const char kValueTimeScopeWeek[];
		static const char kValueTimeScopeToday[];

		static const char kValuePlayerScopeGlobal[];
		static const char kValuePlayerScopeFriendsOnly[];
		
		static const char kValuePhotoSizeNormal[];
		static const char kValuePhotoSizeSmall[];

		
		static const char kValueFetchLeaderboardCategories[];
		static const char kValueFetchAchievementDescriptions[];
		static const char kValueFetchFriends[];
		static const char kValueFetchPlayers[];
		static const char kValueFetchLocalPlayer[];
		static const char kValueFetchFriendRequestMaxNumberOfRecipients[];

		static const char kValueVariablePlayerID[];
	public:
//		static void DownloadBlobCallback( LuaResource * resource, const char * blob, size_t blobLength );
		
	public:
		IPhoneGameCenter(id<CoronaRuntime> runtime);
		virtual ~IPhoneGameCenter();
		
	public:
		virtual bool Init( lua_State *L, int index );
		virtual bool Show( lua_State *L );
		virtual int Request( lua_State *L );
		
		static NSInteger outcomeFromNSString( NSString* outcomeInput );
		static NSString* nsstringFromOutcome( GKTurnBasedMatchOutcome outcome );
		static NSString* nsstringFromStatus( GKTurnBasedParticipantStatus status);
		
	private:
		void Authenticate( lua_State *L );
		bool fIsInitialized;
		GKTurnBasedParticipant* findParticipantInMatch( GKTurnBasedMatch* match, NSString* participantID );
		GameCenterDelegate* fGameCenterDelegate;
		TurnBasedMatchMakerDelegate* fTurnBasedMatchMakerDelegate;
		TurnBasedEventHandlerDelegate* fTurnBasedEventHandlerDelegate;
		__block NSMutableDictionary* fMatchesDictionary;
		CoronaLuaRef fAuthenticationCallback; // GameCenter holds onto the callback for the life of the app and calls it again on every resume (from background)
		id<CoronaRuntime> fRuntime;
};

// ----------------------------------------------------------------------------
	
} // namespace Rtt

// ----------------------------------------------------------------------------


@interface GameCenterDelegate :  NSObject <GKLeaderboardViewControllerDelegate, GKAchievementViewControllerDelegate, GKFriendRequestComposeViewControllerDelegate>

@property(nonatomic, assign) CoronaLuaRef luaResourceForLeaderboard;
@property(nonatomic, assign) CoronaLuaRef luaResourceForAchievement;
@property(nonatomic, assign) CoronaLuaRef luaResourceForFriendRequest;
@property(nonatomic, assign) id<CoronaRuntime> runtime;
@end

@interface TurnBasedMatchMakerDelegate :  NSObject <GKTurnBasedMatchmakerViewControllerDelegate>

@property(nonatomic, assign) CoronaLuaRef luaResourceForMatchMaker;
@property(nonatomic, assign) NSMutableDictionary* fMatchesDictionary;
@property(nonatomic, assign) id<CoronaRuntime> runtime;
@end

@interface TurnBasedEventHandlerDelegate :  NSObject <GKTurnBasedEventHandlerDelegate>

@property(nonatomic, assign) CoronaLuaRef luaResourceForEventHandler;
@property(nonatomic, assign) NSMutableDictionary* fMatchesDictionary;
@property(nonatomic, assign) id<CoronaRuntime> runtime;
@end

#endif // _Rtt_PlatformGameCenter_H__
