#pragma once
#import <Cocoa/Cocoa.h>
#import "TabManager.h"

@interface BrowserWindowController : NSWindowController <NSWindowDelegate>
- (instancetype)init;
@property (readonly) TabManager* tabManager;

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
