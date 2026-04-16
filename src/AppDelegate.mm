#import "BrowserWindowController.h"
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(strong) BrowserWindowController *mainWindow;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)_ {
  [self buildMenu];
  _mainWindow = [BrowserWindowController new];
  [_mainWindow showWindow:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)_ {
  return YES;
}

// ── Menu bar
// ──────────────────────────────────────────────────────────────────
- (void)buildMenu {
  NSMenu *bar = [NSMenu new];

  // ── BuildBrowser
  // ──────────────────────────────────────────────────────────────
  NSMenu *appMenu = [NSMenu new];
  [appMenu addItemWithTitle:@"Settings…"
                     action:@selector(showSettings:)
              keyEquivalent:@","];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [appMenu addItemWithTitle:@"Quit BuildBrowser"
                     action:@selector(terminate:)
              keyEquivalent:@"q"];
  NSMenuItem *appItem = [NSMenuItem new];
  appItem.submenu = appMenu;
  [bar addItem:appItem];

  // ── File ──────────────────────────────────────────────────────────────────
  NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
  [fileMenu addItemWithTitle:@"New Tab"
                      action:@selector(newTab:)
               keyEquivalent:@"t"];
  [fileMenu addItemWithTitle:@"Close Tab"
                      action:@selector(closeCurrentTab:)
               keyEquivalent:@"w"];
  NSMenuItem *fileItem = [NSMenuItem new];
  fileItem.submenu = fileMenu;
  [bar addItem:fileItem];

  // ── Edit ──────────────────────────────────────────────────────────────────
  NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
  [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [editMenu addItemWithTitle:@"Copy"
                      action:@selector(copy:)
               keyEquivalent:@"c"];
  [editMenu addItemWithTitle:@"Paste"
                      action:@selector(paste:)
               keyEquivalent:@"v"];
  [editMenu addItemWithTitle:@"Select All"
                      action:@selector(selectAll:)
               keyEquivalent:@"a"];
  [editMenu addItem:[NSMenuItem separatorItem]];
  [editMenu addItemWithTitle:@"Find…"
                      action:@selector(openFindBar:)
               keyEquivalent:@"f"];
  [editMenu addItemWithTitle:@"Find Next"
                      action:@selector(findNext:)
               keyEquivalent:@"g"];
  NSMenuItem *editItem = [NSMenuItem new];
  editItem.submenu = editMenu;
  [bar addItem:editItem];

  // ── View ──────────────────────────────────────────────────────────────────
  NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
  [viewMenu addItemWithTitle:@"Reload"
                      action:@selector(reloadOrStop:)
               keyEquivalent:@"r"];
  [viewMenu addItemWithTitle:@"Back"
                      action:@selector(goBack:)
               keyEquivalent:@"["];
  [viewMenu addItemWithTitle:@"Forward"
                      action:@selector(goForward:)
               keyEquivalent:@"]"];
  [viewMenu addItem:[NSMenuItem separatorItem]];
  [viewMenu addItemWithTitle:@"Bookmarks"
                      action:@selector(showBookmarks:)
               keyEquivalent:@"b"];
  [viewMenu addItemWithTitle:@"History"
                      action:@selector(showHistory:)
               keyEquivalent:@"y"];
  [viewMenu addItemWithTitle:@"Downloads"
                      action:@selector(showDownloads:)
               keyEquivalent:@"j"];
  [viewMenu addItem:[NSMenuItem separatorItem]];
  [viewMenu addItemWithTitle:@"Bookmark This Page"
                      action:@selector(toggleBookmark:)
               keyEquivalent:@"d"];
  NSMenuItem *viewItem = [NSMenuItem new];
  viewItem.submenu = viewMenu;
  [bar addItem:viewItem];

  NSApp.mainMenu = bar;
}

// Close-tab forwarded to window controller
- (void)closeCurrentTab:(id)_ {
  [_mainWindow.tabManager closeTabAtIndex:_mainWindow.tabManager.activeIndex];
}

@end
