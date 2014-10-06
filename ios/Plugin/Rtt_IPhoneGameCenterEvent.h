// ----------------------------------------------------------------------------
// IPhoneGameCenterEvent.h
// Copyright (c) 2011 Ansca, Inc. All rights reserved.
// 
// Reviewers:
// 		Eric Wing
//
// ----------------------------------------------------------------------------
//

#ifndef Rtt_IPhoneGameCenterEvent_h
#define Rtt_IPhoneGameCenterEvent_h

@class UIImage;
@class NSString;
@class NSError;
@class NSDictionary;

// ----------------------------------------------------------------------------

// For gameNetwork request event callbacks
class IPhoneGameCenterEvent
{
	public:
		typedef IPhoneGameCenterEvent Self;

	public:
		static const char kTypeKey[];
		static const char kDataKey[];
		static const char kProviderKey[];
		static const char kProviderValue[];
		static const char kName[];

	public:
		// Type is expected to be a static const char because nothing is managing the memory.
		IPhoneGameCenterEvent( const char* type, NSError* error, id data );
		virtual ~IPhoneGameCenterEvent();
		virtual int Push( lua_State *L ) const;

	public:
		virtual const char* Type() const;
		virtual const char* Provider() const;
	
	protected:
		virtual void SetError( const char *errorMsg, int errorCode );

	// In the GameCenter implementation, we could skip the native Cocoa objects and refer directly to the objects in Lua,
	// but in a more complicated implementation where objects may be popped before this event can use them,
	// it is safer to keep a copy of the object.
	// Cocoa objects are convenient since there is a memory ownership convention already built-in.
	protected:
		NSString *fError;
		const char* fType; // should only be static const strings otherwise memory problems 
	// provider?
		id fData;
		const char *fErrorMsg;
		int fErrorCode;
};

// Special subclass for loadScores because it pushes back an additional field
class IPhoneGameCenterLoadScoresEvent : public IPhoneGameCenterEvent
{
	public:
		typedef IPhoneGameCenterEvent Super;
		typedef IPhoneGameCenterLoadScoresEvent Self;

	public:
		static const char kLocalPlayerScoreKey[];

	public:
		IPhoneGameCenterLoadScoresEvent( const char* type, NSError* error, id data, NSDictionary* localplayerscore );
		virtual ~IPhoneGameCenterLoadScoresEvent();

		virtual int Push( lua_State *L ) const;

	public:
	
	// In the GameCenter implementation, we could skip the native Cocoa objects and refer directly to the objects in Lua,
	// but in a more complicated implementation where objects may be popped before this event can use them,
	// it is safer to keep a copy of the object.
	// Cocoa objects are convenient since there is a memory ownership convention already built-in.
	protected:
		NSDictionary* fLocalPlayerScore;
		
};
	


// Special subclass for achievements with images. Will return a GKAchievementDescription table with the image property.
class IPhoneGameCenterLoadAchievementEvent : public IPhoneGameCenterEvent
{
	public:
		typedef IPhoneGameCenterEvent Super;
		typedef IPhoneGameCenterLoadAchievementEvent Self;


	public:
		IPhoneGameCenterLoadAchievementEvent( const char* type, NSError* error, id data, UIImage* image );
		virtual ~IPhoneGameCenterLoadAchievementEvent();

		virtual int Push( lua_State *L ) const;
	
	protected:
		UIImage* fImage;
	
};
	

// Special subclass for player avatar images. Will return a GKPlayer table with the photo property.
class IPhoneGameCenterLoadPlayerPhotoEvent : public IPhoneGameCenterEvent
{
	public:
		typedef IPhoneGameCenterEvent Super;
		typedef IPhoneGameCenterLoadPlayerPhotoEvent Self;


	public:
		IPhoneGameCenterLoadPlayerPhotoEvent( const char* type, NSError* error, id data, UIImage* image );
		virtual ~IPhoneGameCenterLoadPlayerPhotoEvent();

		virtual int Push( lua_State *L ) const;
	
	protected:
		UIImage* fImage;
	
};	


	

// Special subclass for pushing an image to data field. The intention is to use it with the class image methods of GKAchievementDescription
class IPhoneGameCenterLoadImageEvent : public IPhoneGameCenterEvent
{
	public:
		typedef IPhoneGameCenterEvent Super;
		typedef IPhoneGameCenterLoadImageEvent Self;


	public:
		IPhoneGameCenterLoadImageEvent( const char* type, NSError* error, UIImage* image );
		virtual ~IPhoneGameCenterLoadImageEvent();

		virtual int Push( lua_State *L ) const;
	
	protected:
		UIImage* fImage;
	
};	

#endif
