#pragma once
#import <Cocoa/Cocoa.h>
#import "TabManager.h"
#import "Profile.h"

@interface BrowserWindowController : NSWindowController <NSWindowDelegate>
- (instancetype)initWithProfile:(Profile*)profile;
@property (readonly) TabManager* tabManager;
@property (readonly) Profile* profile;

// Actions reachable from menu / keyboard
- (void)newTab:(id)sender;
- (void)goBack:(id)sender;
- (void)goForward:(id)sender;
- (void)reloadOrStop:(id)sender;
- (void)toggleBookmark:(id)sender;
- (void)showBookmarks:(id)sender;
- (void)showHistory:(id)sender;
- (void)showDownloads:(id)sender;
- (void)showSettings:(id)sender;
- (void)openFindBar:(id)sender;
- (void)findNext:(id)sender;
@end
