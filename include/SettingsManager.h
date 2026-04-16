#pragma once
#import <Foundation/Foundation.h>

// All settings stored in NSUserDefaults under "KBrowser.*"
@interface SettingsManager : NSObject
+ (instancetype)profileShared;
- (instancetype)initWithRootPath:(NSString*)path;

// General
@property (copy) NSString* homepage;        // default: https://start.duckduckgo.com
@property (copy) NSString* searchEngineURL; // default: https://duckduckgo.com/?q=%@

// Privacy
@property (assign) BOOL javascriptEnabled;
@property (assign) BOOL blockPopups;
@property (assign) BOOL privateBrowsing;
@property (assign) BOOL adBlockEnabled;

// Appearance
@property (assign) BOOL showBookmarksBar;

- (void)resetToDefaults;
@end
