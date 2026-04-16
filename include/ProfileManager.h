#pragma once
#import <Foundation/Foundation.h>
#import "Profile.h"

@interface ProfileManager : NSObject

+ (instancetype)shared;

@property (readonly) NSArray<Profile*>* profiles;
@property (strong) Profile* activeProfile;

- (Profile*)createProfileWithName:(NSString*)name;
- (void)deleteProfile:(Profile*)profile;
- (void)loadProfiles;
- (void)saveProfiles;

@end
