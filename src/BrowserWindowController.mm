#import "BrowserWindowController.h"
#import "BookmarkManager.h"
#import "HistoryManager.h"
#import "SettingsManager.h"
#import "DownloadManager.h"
#import <objc/runtime.h>

// Forward-declare panels (defined in their own .mm files, compiled together)
@interface SettingsPanel : NSWindowController
+ (void)showAsSheetOnWindow:(NSWindow*)parent;
@end

@interface SidePanel : NSWindowController
+ (instancetype)shared;
@property (copy) void (^openURLCallback)(NSString* url);
- (void)showBookmarks;
- (void)showHistory;
@end

@interface DownloadsPanel : NSWindowController
+ (instancetype)shared;
- (void)show;
@end

// ── Layout constants ──────────────────────────────────────────────────────────
static const CGFloat kToolbarH      = 44.0;
static const CGFloat kTabBarH       = 32.0;
static const CGFloat kBookmarksBarH = 28.0;
static const CGFloat kTabW          = 180.0;
static const CGFloat kTabMinW       = 80.0;
static const CGFloat kProgressH     = 3.0;
static const CGFloat kBtnSize       = 28.0;
static const CGFloat kFindBarH      = 36.0;

// ── Thin progress bar ─────────────────────────────────────────────────────────
@interface ProgressBarView : NSView
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) BOOL   visible;
@end
@implementation ProgressBarView
- (void)setProgress:(double)p { _progress = p; [self setNeedsDisplay:YES]; }
- (void)drawRect:(NSRect)_ {
    if (!_visible || _progress <= 0.0) return;
    // Subtle gradient fill
    NSGradient* grad = [[NSGradient alloc] initWithStartingColor:[NSColor controlAccentColor]
                                                     endingColor:[[NSColor controlAccentColor] colorWithAlphaComponent:0.7]];
    [grad drawInRect:NSMakeRect(0, 0, NSWidth(self.bounds) * _progress, NSHeight(self.bounds)) angle:0];
}
@end

// ── BrowserWindowController private interface ─────────────────────────────────
@interface BrowserWindowController () <NSWindowDelegate, NSTextFieldDelegate>
// Managers
@property (strong) TabManager*      tabManager;
// Chrome views
@property (strong) NSView*          toolbarView;
@property (strong) NSView*          tabBarView;
@property (strong) NSView*          bookmarksBarView;
@property (strong) NSView*          findBarView;
@property (strong) ProgressBarView* progressBar;
@property (strong) NSView*          contentArea;
// Toolbar widgets
@property (strong) NSButton*        backBtn;
@property (strong) NSButton*        fwdBtn;
@property (strong) NSButton*        reloadBtn;
@property (strong) NSButton*        homeBtn;      // New
@property (strong) NSTextField*     urlField;
@property (strong) NSButton*        readerModeBtn; // New
@property (strong) NSButton*        bookmarkStarBtn;
// Find bar widgets
@property (strong) NSTextField*     findField;
@property (strong) NSTextField*     findStatusLabel;
@property (assign) BOOL             findBarVisible;
@end

@implementation BrowserWindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 1280, 800);
    NSWindowStyleMask style = NSWindowStyleMaskTitled
                            | NSWindowStyleMaskClosable
                            | NSWindowStyleMaskMiniaturizable
                            | NSWindowStyleMaskResizable
                            | NSWindowStyleMaskFullSizeContentView;
    NSWindow* win = [[NSWindow alloc] initWithContentRect:frame
                                               styleMask:style
                                                 backing:NSBackingStoreBuffered defer:NO];
    win.title                      = @"KBrowser";
    win.titlebarAppearsTransparent = YES;
    win.movableByWindowBackground  = YES;
    win.minSize                    = NSMakeSize(640, 480);
    [win center];

    self = [super initWithWindow:win];
    if (!self) return nil;
    win.delegate = self;
    _tabManager  = [TabManager new];

    [self buildUI];
    [self wireTabManagerCallbacks];
    [self wireSidePanel];

    // Apply settings to first tab config
    [_tabManager newTabWithURL:[SettingsManager shared].homepage];
    return self;
}

// ── UI construction ───────────────────────────────────────────────────────────

- (void)buildUI {
    NSView* root = self.window.contentView;
    root.wantsLayer = YES;
    CGFloat W = root.bounds.size.width;
    CGFloat H = root.bounds.size.height;

    // ── Toolbar (frosted glass, full-width) ───────────────────────────────────
    _toolbarView = [[NSView alloc] initWithFrame:NSMakeRect(0, H - kToolbarH, W, kToolbarH)];
    _toolbarView.wantsLayer = YES;
    _toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [root addSubview:_toolbarView];

    NSVisualEffectView* bg = [[NSVisualEffectView alloc] initWithFrame:_toolbarView.bounds];
    bg.material = NSVisualEffectMaterialTitlebar;
    bg.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    bg.state = NSVisualEffectStateActive;
    bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_toolbarView addSubview:bg];

    // Nav cluster — back / forward / reload grouped tightly
    CGFloat cx = 76;  // leave room for traffic lights
    _backBtn   = [self makeSymbolButton:@"chevron.left"    size:16 tooltip:@"Back (⌘[)"];
    _fwdBtn    = [self makeSymbolButton:@"chevron.right"   size:16 tooltip:@"Forward (⌘])"];
    _reloadBtn = [self makeSymbolButton:@"arrow.clockwise" size:15 tooltip:@"Reload (⌘R)"];
    _backBtn.frame   = NSMakeRect(cx,      (kToolbarH-kBtnSize)/2, kBtnSize, kBtnSize);
    _fwdBtn.frame    = NSMakeRect(cx+30,   (kToolbarH-kBtnSize)/2, kBtnSize, kBtnSize);
    _reloadBtn.frame = NSMakeRect(cx+62,   (kToolbarH-kBtnSize)/2, kBtnSize, kBtnSize);
    _homeBtn   = [self makeSymbolButton:@"house" size:15 tooltip:@"Home"];
    _homeBtn.frame   = NSMakeRect(cx+94,   (kToolbarH-kBtnSize)/2, kBtnSize, kBtnSize);
    _backBtn.target   = self; _backBtn.action   = @selector(goBack:);
    _fwdBtn.target    = self; _fwdBtn.action    = @selector(goForward:);
    _reloadBtn.target = self; _reloadBtn.action = @selector(reloadOrStop:);
    _homeBtn.target   = self; _homeBtn.action   = @selector(goHome:);
    [_toolbarView addSubview:_backBtn];
    [_toolbarView addSubview:_fwdBtn];
    [_toolbarView addSubview:_reloadBtn];
    [_toolbarView addSubview:_homeBtn];

    // Right-side icon buttons: bookmark | bookmarks | history | downloads | settings | new-tab
    NSArray* syms  = @[@"bookmark",       @"books.vertical", @"clock",   @"arrow.down.circle", @"gearshape", @"plus"];
    NSArray* tips  = @[@"Bookmark (⌘D)",  @"Bookmarks (⌘B)", @"History (⌘Y)", @"Downloads (⌘J)", @"Settings (⌘,)", @"New Tab (⌘T)"];
    SEL acts[] = { @selector(toggleBookmark:), @selector(showBookmarks:), @selector(showHistory:),
                   @selector(showDownloads:),  @selector(showSettings:),  @selector(newTab:) };
    CGFloat rBase = W - 6 * 32 - 8;
    for (NSInteger i = 0; i < 6; i++) {
        NSButton* btn = [self makeSymbolButton:syms[i] size:15 tooltip:tips[i]];
        btn.frame = NSMakeRect(rBase + i * 32, (kToolbarH-kBtnSize)/2, kBtnSize, kBtnSize);
        btn.autoresizingMask = NSViewMinXMargin;
        btn.target = self; btn.action = acts[i];
        [_toolbarView addSubview:btn];
        if (i == 0) _bookmarkStarBtn = btn;
    }

    // URL field — fills the gap between nav cluster and right buttons
    CGFloat urlX = cx + 128; // adjusted for Home button
    CGFloat urlW = rBase - urlX - 8;
    _urlField = [[NSTextField alloc] initWithFrame:NSMakeRect(urlX, (kToolbarH-26)/2, urlW, 26)];
    _urlField.placeholderString = @"Search or enter address…";
    _urlField.bezelStyle        = NSTextFieldRoundedBezel;
    _urlField.focusRingType     = NSFocusRingTypeNone;
    _urlField.font              = [NSFont systemFontOfSize:13];
    _urlField.autoresizingMask  = NSViewWidthSizable;
    _urlField.delegate = self;
    _urlField.target = self; _urlField.action = @selector(urlFieldActivated:);
    [_toolbarView addSubview:_urlField];

    // Reader Mode button inside URL field (overlapping right edge)
    _readerModeBtn = [self makeSymbolButton:@"doc.plaintext" size:13 tooltip:@"Reader Mode"];
    _readerModeBtn.frame = NSMakeRect(urlX + urlW - 28, (kToolbarH-24)/2, 24, 24);
    _readerModeBtn.autoresizingMask = NSViewMinXMargin;
    _readerModeBtn.target = self; _readerModeBtn.action = @selector(toggleReaderMode:);
    _readerModeBtn.hidden = YES;
    [_toolbarView addSubview:_readerModeBtn];

    // Bottom edge of toolbar — 1px separator
    NSView* toolSep = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, W, 1)];
    toolSep.wantsLayer = YES;
    toolSep.layer.backgroundColor = [NSColor separatorColor].CGColor;
    toolSep.autoresizingMask = NSViewWidthSizable;
    [_toolbarView addSubview:toolSep];

    // ── Progress bar (2px, accent color) ─────────────────────────────────────
    _progressBar = [[ProgressBarView alloc] initWithFrame:
                    NSMakeRect(0, H-kToolbarH-kProgressH, W, kProgressH)];
    _progressBar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    _progressBar.visible = NO;
    [root addSubview:_progressBar];

    // ── Tab bar ───────────────────────────────────────────────────────────────
    CGFloat tabBarY = H - kToolbarH - kProgressH - kTabBarH;
    _tabBarView = [[NSView alloc] initWithFrame:NSMakeRect(0, tabBarY, W, kTabBarH)];
    _tabBarView.wantsLayer = YES;
    _tabBarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

    NSVisualEffectView* tabBg = [[NSVisualEffectView alloc] initWithFrame:_tabBarView.bounds];
    tabBg.material      = NSVisualEffectMaterialTitlebar;
    tabBg.blendingMode  = NSVisualEffectBlendingModeBehindWindow;
    tabBg.state         = NSVisualEffectStateActive;
    tabBg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_tabBarView addSubview:tabBg];

    NSView* tabSep = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, W, 1)];
    tabSep.wantsLayer = YES;
    tabSep.layer.backgroundColor = [NSColor separatorColor].CGColor;
    tabSep.autoresizingMask = NSViewWidthSizable;
    [_tabBarView addSubview:tabSep];
    [root addSubview:_tabBarView];

    // ── Bookmarks bar ─────────────────────────────────────────────────────────
    CGFloat bmBarY = tabBarY - kBookmarksBarH;
    _bookmarksBarView = [[NSView alloc] initWithFrame:NSMakeRect(0, bmBarY, W, kBookmarksBarH)];
    _bookmarksBarView.wantsLayer = YES;
    _bookmarksBarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

    NSVisualEffectView* bmBg = [[NSVisualEffectView alloc] initWithFrame:_bookmarksBarView.bounds];
    bmBg.material     = NSVisualEffectMaterialTitlebar;
    bmBg.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    bmBg.state        = NSVisualEffectStateActive;
    bmBg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_bookmarksBarView addSubview:bmBg];

    NSView* bmSep = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, W, 1)];
    bmSep.wantsLayer = YES;
    bmSep.layer.backgroundColor = [NSColor separatorColor].CGColor;
    bmSep.autoresizingMask = NSViewWidthSizable;
    [_bookmarksBarView addSubview:bmSep];
    [root addSubview:_bookmarksBarView];
    _bookmarksBarView.hidden = ![SettingsManager shared].showBookmarksBar;
    [self rebuildBookmarksBar];

    // ── Find bar (frosted, slides up from bottom) ─────────────────────────────
    _findBarView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, W, kFindBarH)];
    _findBarView.wantsLayer = YES;
    _findBarView.autoresizingMask = NSViewWidthSizable;
    _findBarView.hidden = YES;

    NSVisualEffectView* findBg = [[NSVisualEffectView alloc] initWithFrame:_findBarView.bounds];
    findBg.material     = NSVisualEffectMaterialHUDWindow;
    findBg.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    findBg.state        = NSVisualEffectStateActive;
    findBg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_findBarView addSubview:findBg];

    NSView* findTopSep = [[NSView alloc] initWithFrame:NSMakeRect(0, kFindBarH-1, W, 1)];
    findTopSep.wantsLayer = YES;
    findTopSep.layer.backgroundColor = [NSColor separatorColor].CGColor;
    findTopSep.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [_findBarView addSubview:findTopSep];

    _findField = [[NSTextField alloc] initWithFrame:NSMakeRect(12, (kFindBarH-24)/2, 200, 24)];
    _findField.placeholderString = @"Find in page…";
    _findField.bezelStyle = NSTextFieldRoundedBezel;
    _findField.focusRingType = NSFocusRingTypeNone;
    _findField.font = [NSFont systemFontOfSize:13];
    _findField.target = self; _findField.action = @selector(findNext:);
    [_findBarView addSubview:_findField];

    NSButton* prevBtn = [self makeSymbolButton:@"chevron.up"   size:12 tooltip:@"Previous"];
    NSButton* nextBtn = [self makeSymbolButton:@"chevron.down" size:12 tooltip:@"Next"];
    prevBtn.frame = NSMakeRect(218, (kFindBarH-24)/2, 28, 24);
    nextBtn.frame = NSMakeRect(250, (kFindBarH-24)/2, 28, 24);
    prevBtn.target = self; prevBtn.action = @selector(findPrev:);
    nextBtn.target = self; nextBtn.action = @selector(findNext:);
    [_findBarView addSubview:prevBtn];
    [_findBarView addSubview:nextBtn];

    _findStatusLabel = [NSTextField labelWithString:@""];
    _findStatusLabel.frame = NSMakeRect(284, (kFindBarH-16)/2, 140, 16);
    _findStatusLabel.font = [NSFont systemFontOfSize:11];
    _findStatusLabel.textColor = [NSColor secondaryLabelColor];
    [_findBarView addSubview:_findStatusLabel];

    NSButton* closeFind = [self makeSymbolButton:@"xmark" size:11 tooltip:@"Close (Esc)"];
    closeFind.frame = NSMakeRect(W - 32, (kFindBarH-kBtnSize)/2, kBtnSize, kBtnSize);
    closeFind.autoresizingMask = NSViewMinXMargin;
    closeFind.target = self; closeFind.action = @selector(closeFindBar:);
    [_findBarView addSubview:closeFind];
    [root addSubview:_findBarView];

    // ── Content area ──────────────────────────────────────────────────────────
    [self recalcContentArea];
}

// Recalculate and resize the content area based on which bars are visible
- (void)recalcContentArea {
    NSView* root = self.window.contentView;
    CGFloat W = root.bounds.size.width;
    CGFloat H = root.bounds.size.height;

    CGFloat top = H - kToolbarH - kProgressH - kTabBarH;
    if (![SettingsManager shared].showBookmarksBar || _bookmarksBarView.hidden == NO)
        top -= kBookmarksBarH;
    CGFloat bottom = _findBarVisible ? kFindBarH : 0;
    CGFloat contentH = top - bottom;

    if (!_contentArea) {
        _contentArea = [[NSView alloc] initWithFrame:NSMakeRect(0, bottom, W, contentH)];
        _contentArea.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [root addSubview:_contentArea];
    } else {
        _contentArea.frame = NSMakeRect(0, bottom, W, contentH);
    }

    // Reposition find bar
    _findBarView.frame = NSMakeRect(0, 0, W, kFindBarH);

    // Resize all web views
    for (BrowserTab* t in _tabManager.tabs) {
        t.webView.frame = _contentArea.bounds;
    }
}

// ── Tab manager callbacks ─────────────────────────────────────────────────────

- (void)wireTabManagerCallbacks {
    __unsafe_unretained typeof(self) ws = self;
    _tabManager.onTabAdded        = ^(BrowserTab* t, NSInteger i) { [ws onTabAdded:t atIndex:i]; };
    _tabManager.onTabClosed       = ^(NSInteger i)                 { [ws onTabClosedAtIndex:i]; };
    _tabManager.onTabSwitched     = ^(BrowserTab* t, NSInteger i)  { [ws onTabSwitched:t atIndex:i]; };
    _tabManager.onTitleChanged    = ^(BrowserTab* t, NSString* s)  { [ws onTitleChanged:s forTab:t]; };
    _tabManager.onURLChanged      = ^(BrowserTab* t, NSString* s)  { [ws onURLChanged:s forTab:t]; };
    _tabManager.onLoadProgress    = ^(BrowserTab* t, double p)     { [ws onLoadProgress:p forTab:t]; };
    _tabManager.onLoadStateChanged= ^(BrowserTab* t, BOOL l)       { [ws onLoadStateChanged:l forTab:t]; };
    _tabManager.onFaviconChanged  = ^(BrowserTab* t, NSImage* i)   { [ws onFaviconChanged:i forTab:t]; };
}

- (void)wireSidePanel {
    __unsafe_unretained typeof(self) ws = self;
    [SidePanel shared].openURLCallback = ^(NSString* url) {
        [ws.tabManager newTabWithURL:url];
        [ws rebuildTabStrip];
    };
}

// ── Tab event handlers ────────────────────────────────────────────────────────

- (void)onTabAdded:(BrowserTab*)tab atIndex:(NSInteger)index {
    tab.tabButton.frame = NSMakeRect(0, 2, kTabW, kTabBarH-4);
    tab.tabButton.tag    = index;
    tab.tabButton.target = self;
    tab.tabButton.action = @selector(tabButtonClicked:);
    [_tabBarView addSubview:tab.tabButton];

    tab.webView.frame            = _contentArea.bounds;
    tab.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    tab.webView.hidden           = YES;
    [_contentArea addSubview:tab.webView];
    [self rebuildTabStrip];
}

- (void)onTabClosedAtIndex:(NSInteger)_ { [self rebuildTabStrip]; }

- (void)onTabSwitched:(BrowserTab*)tab atIndex:(NSInteger)_ {
    for (BrowserTab* t in _tabManager.tabs) t.webView.hidden = YES;
    tab.webView.hidden = NO;
    [_urlField setStringValue:tab.url ?: @""];
    [self updateNavButtons];
    [self updateBookmarkStar];
    for (BrowserTab* t in _tabManager.tabs)
        t.tabButton.state = (t == tab) ? NSControlStateValueOn : NSControlStateValueOff;
    [self.window setTitle:tab.title.length ? tab.title : @"KBrowser"];
}

- (void)onTitleChanged:(NSString*)title forTab:(BrowserTab*)tab {
    if (tab == _tabManager.activeTab)
        [self.window setTitle:title.length ? title : @"KBrowser"];
    [self rebuildTabStrip];  // refresh label + weight
    // Record in history (skip private mode)
    if (![SettingsManager shared].privateBrowsing && tab.url.length)
        [[HistoryManager shared] recordVisitWithTitle:title url:tab.url];
}

- (void)onURLChanged:(NSString*)url forTab:(BrowserTab*)tab {
    if (tab == _tabManager.activeTab) {
        [_urlField setStringValue:url ?: @""];
        [self updateBookmarkStar];
    }
}

- (void)onLoadProgress:(double)p forTab:(BrowserTab*)tab {
    if (tab == _tabManager.activeTab) _progressBar.progress = p;
}

- (void)onLoadStateChanged:(BOOL)loading forTab:(BrowserTab*)tab {
    if (tab != _tabManager.activeTab) return;
    _progressBar.visible  = loading;
    _progressBar.progress = loading ? _progressBar.progress : 0.0;
    [_progressBar setNeedsDisplay:YES];
    NSString* sym = loading ? @"xmark" : @"arrow.clockwise";
    [_reloadBtn setImage:[NSImage imageWithSystemSymbolName:sym accessibilityDescription:nil]];
    [self updateNavButtons];
    if (!loading) [self injectContextMenuScript:tab.webView];
    if (!loading) [self updateReaderModeAvailability:tab];
}

- (void)onFaviconChanged:(NSImage*)icon forTab:(BrowserTab*)tab {
    [self rebuildTabStrip];
}

// ── Navigation actions ────────────────────────────────────────────────────────

- (void)newTab:(id)_ {
    [_tabManager newTabWithURL:[SettingsManager shared].homepage];
    [self rebuildTabStrip];
}

- (void)goBack:(id)_    { [_tabManager.activeTab.webView goBack]; }
- (void)goForward:(id)_ { [_tabManager.activeTab.webView goForward]; }
- (void)goHome:(id)_    { [_tabManager.activeTab.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[SettingsManager shared].homepage]]]; }

- (void)reloadOrStop:(id)_ {
    WKWebView* wv = _tabManager.activeTab.webView;
    if (wv.isLoading) [wv stopLoading]; else [wv reload];
}

- (void)urlFieldActivated:(id)_ {
    BrowserTab* tab = _tabManager.activeTab;
    if (!tab) return;
    NSString* url = [TabManager sanitizeURL:_urlField.stringValue];
    [tab.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    [self.window makeFirstResponder:tab.webView];
}

- (void)toggleReaderMode:(id)_ {
    // Basic toggle: we'll use a script to find content and display it cleanly
    // For a real generic 'Reader Mode', WebKit provides _WKWebViewPrintFormatter or just CSS overrides
    // Here we'll just toggle a simplistic fullscreen overlay for now.
    WKWebView* wv = _tabManager.activeTab.webView;
    [wv evaluateJavaScript:@"(function(){ if(window._readerOn){ location.reload(); } else { document.body.innerHTML = '<div style=\"max-width:800px;margin:50px auto;font-family:serif;font-size:20px;line-height:1.6;color:#333;background:#fff;padding:40px;\">' + (document.querySelector('article') || document.body).innerHTML + '</div>'; window._readerOn=true; document.body.style.background='#fff'; } })()" completionHandler:nil];
}

- (void)updateReaderModeAvailability:(BrowserTab*)tab {
    // Show reader button if we find an <article> tag or enough text
    [tab.webView evaluateJavaScript:@"(!!document.querySelector('article') || document.body.innerText.length > 2000)" completionHandler:^(id res, NSError* _) {
        if (tab == self.tabManager.activeTab) {
            self.readerModeBtn.hidden = ![res boolValue];
        }
    }];
}

- (void)tabButtonClicked:(NSButton*)btn {
    NSEvent* ev = NSApp.currentEvent;
    if (ev.modifierFlags & NSEventModifierFlagOption)
        [_tabManager closeTabAtIndex:btn.tag];
    else
        [_tabManager switchToIndex:btn.tag];
}

- (void)closeTabButtonClicked:(NSButton*)btn {
    [_tabManager closeTabAtIndex:btn.tag];
}

// ── Bookmark actions ──────────────────────────────────────────────────────────

- (void)toggleBookmark:(id)_ {
    BrowserTab* tab = _tabManager.activeTab;
    if (!tab || !tab.url.length) return;
    BookmarkManager* bm = [BookmarkManager shared];
    if ([bm isBookmarked:tab.url]) {
        NSArray<Bookmark*>* list = bm.bookmarks;
        for (NSInteger i = 0; i < (NSInteger)list.count; i++)
            if ([list[i].url isEqualToString:tab.url]) { [bm removeBookmarkAtIndex:i]; break; }
    } else {
        [bm addBookmarkWithTitle:tab.title url:tab.url];
    }
    [self updateBookmarkStar];
    [self rebuildBookmarksBar];
}

- (void)updateBookmarkStar {
    BrowserTab* tab = _tabManager.activeTab;
    BOOL starred = tab && [[BookmarkManager shared] isBookmarked:tab.url];
    NSString* sym = starred ? @"bookmark.fill" : @"bookmark";
    [_bookmarkStarBtn setImage:[NSImage imageWithSystemSymbolName:sym accessibilityDescription:nil]];
}

// ── Bookmarks bar ─────────────────────────────────────────────────────────────

- (void)rebuildBookmarksBar {
    // Remove old bookmark buttons (keep the separator box)
    for (NSView* v in _bookmarksBarView.subviews.copy)
        if ([v isKindOfClass:[NSButton class]]) [v removeFromSuperview];

    CGFloat x = 8;
    for (Bookmark* bm in [BookmarkManager shared].bookmarks) {
        NSButton* btn = [NSButton buttonWithTitle:bm.title target:self
                                           action:@selector(bookmarkBarItemClicked:)];
        btn.bezelStyle = NSBezelStyleInline;
        btn.font       = [NSFont systemFontOfSize:11];
        [btn sizeToFit];
        CGFloat w = MAX(btn.frame.size.width + 12, 60);
        btn.frame = NSMakeRect(x, 4, w, kBookmarksBarH - 8);
        [btn.cell setLineBreakMode:NSLineBreakByTruncatingTail];
        // Store URL in representedObject via associated object trick using tag + lookup
        objc_setAssociatedObject(btn, "bmurl", bm.url, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [_bookmarksBarView addSubview:btn];
        x += w + 4;
        if (x > _bookmarksBarView.bounds.size.width - 20) break; // don't overflow
    }
}

- (void)bookmarkBarItemClicked:(NSButton*)btn {
    NSString* url = objc_getAssociatedObject(btn, "bmurl");
    if (url) [_tabManager newTabWithURL:url];
    [self rebuildTabStrip];
}

// ── Panel actions ─────────────────────────────────────────────────────────────

- (void)showBookmarks:(id)_  { [[SidePanel shared] showBookmarks]; }
- (void)showHistory:(id)_    { [[SidePanel shared] showHistory]; }
- (void)showDownloads:(id)_  { [[DownloadsPanel shared] show]; }
- (void)showSettings:(id)_   { [SettingsPanel showAsSheetOnWindow:self.window]; }

// ── Find in page ──────────────────────────────────────────────────────────────

- (void)openFindBar:(id)_ {
    _findBarVisible = YES;
    _findBarView.hidden = NO;
    [self recalcContentArea];
    [self.window makeFirstResponder:_findField];
}

- (void)closeFindBar:(id)_ {
    _findBarVisible = NO;
    _findBarView.hidden = YES;
    [self recalcContentArea];
    // Clear highlights
    [_tabManager.activeTab.webView evaluateJavaScript:
        @"window.getSelection().removeAllRanges();" completionHandler:nil];
    _findStatusLabel.stringValue = @"";
}

- (void)findNext:(id)_ { [self findInPage:YES]; }
- (void)findPrev:(id)_ { [self findInPage:NO]; }

- (void)findInPage:(BOOL)forward {
    NSString* query = _findField.stringValue;
    if (!query.length) { _findStatusLabel.stringValue = @""; return; }

    // Use window.find() — simple, no extra JS libraries needed
    NSString* js = [NSString stringWithFormat:
        @"window.find(%@, false, %@, true, false, false, false)",
        [self jsString:query], forward ? @"false" : @"true"];

    __unsafe_unretained typeof(self) ws = self;
    [_tabManager.activeTab.webView evaluateJavaScript:js completionHandler:^(id res, NSError* _) {
        BOOL found = [res boolValue];
        ws.findStatusLabel.stringValue = found ? @"" : @"Not found";
        ws.findStatusLabel.textColor   = found
            ? [NSColor secondaryLabelColor] : [NSColor systemRedColor];
    }];
}

- (NSString*)jsString:(NSString*)s {
    NSString* escaped = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return [NSString stringWithFormat:@"\"%@\"", escaped];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

- (void)updateNavButtons {
    WKWebView* wv = _tabManager.activeTab.webView;
    _backBtn.enabled = wv.canGoBack;
    _fwdBtn.enabled  = wv.canGoForward;
}

- (void)rebuildTabStrip {
    // Remove all tab buttons (leave the separator and visual effect bg)
    for (NSView* v in _tabBarView.subviews.copy)
        if ([v isKindOfClass:[NSButton class]] || [v.identifier isEqualToString:@"tabItem"])
            [v removeFromSuperview];

    NSArray<BrowserTab*>* tabs = _tabManager.tabs;
    CGFloat totalW = _tabBarView.bounds.size.width - 4;
    CGFloat tabW   = MIN(kTabW, MAX(kTabMinW, (totalW / MAX(1, tabs.count)) - 2));
    BOOL showClose = (tabW > 100);  // only show × when tabs are wide enough

    for (NSInteger i = 0; i < (NSInteger)tabs.count; i++) {
        BrowserTab* tab = tabs[i];
        BOOL active = (i == _tabManager.activeIndex);

        // Container view for the tab
        NSView* item = [[NSView alloc] initWithFrame:
                        NSMakeRect(2 + i*(tabW+2), 2, tabW, kTabBarH-4)];
        item.wantsLayer = YES;
        item.layer.cornerRadius = 6;
        item.identifier = @"tabItem";

        if (active) {
            item.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.15].CGColor;
            item.layer.borderColor     = [NSColor colorWithWhite:1.0 alpha:0.12].CGColor;
            item.layer.borderWidth     = 0.5;
        }
        
        // Favicon
        NSImageView* iv = [[NSImageView alloc] initWithFrame:NSMakeRect(8, (kTabBarH-4-16)/2, 16, 16)];
        iv.image = tab.favicon;
        iv.imageScaling = NSImageScaleProportionallyUpOrDown;
        [item addSubview:iv];

        // Title label
        NSTextField* lbl = [NSTextField labelWithString:tab.title.length ? tab.title : @"New Tab"];
        CGFloat lblX = 28;
        CGFloat lblW = showClose ? tabW - 54 : tabW - 36;
        lbl.frame = NSMakeRect(lblX, (kTabBarH-4-16)/2, lblW, 16);
        lbl.font  = active
            ? [NSFont systemFontOfSize:12 weight:NSFontWeightMedium]
            : [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        lbl.textColor    = active ? [NSColor labelColor] : [NSColor secondaryLabelColor];
        lbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [item addSubview:lbl];

        // Close button (×)
        if (showClose) {
            NSButton* closeBtn = [self makeSymbolButton:@"xmark" size:9 tooltip:@"Close Tab"];
            closeBtn.frame  = NSMakeRect(tabW - 26, (kTabBarH-4-18)/2, 18, 18);
            closeBtn.tag    = i;
            closeBtn.target = self;
            closeBtn.action = @selector(closeTabButtonClicked:);
            closeBtn.alphaValue = active ? 0.7 : 0.0;  // only show on active; hover handled below
            [item addSubview:closeBtn];
        }

        // Invisible click target over the whole tab
        NSButton* hitArea = [[NSButton alloc] initWithFrame:
                             NSMakeRect(0, 0, showClose ? tabW - 24 : tabW, kTabBarH-4)];
        hitArea.bordered    = NO;
        hitArea.transparent = YES;
        hitArea.tag         = i;
        hitArea.target      = self;
        hitArea.action      = @selector(tabButtonClicked:);
        [item addSubview:hitArea];

        // Keep a ref on the tab for title updates
        tab.tabButton = hitArea;

        [_tabBarView addSubview:item];
    }

    // Add "+" button after the last tab
    NSButton* addBtn = [self makeSymbolButton:@"plus" size:12 tooltip:@"New Tab (⌘T)"];
    CGFloat addX = 2 + tabs.count * (tabW + 2) + 4;
    addBtn.frame = NSMakeRect(addX, (kTabBarH - 24) / 2, 24, 24);
    addBtn.target = self;
    addBtn.action = @selector(newTab:);
    [_tabBarView addSubview:addBtn];
}

- (NSButton*)makeSymbolButton:(NSString*)sym size:(CGFloat)ptSize tooltip:(NSString*)tip {
    NSImageSymbolConfiguration* cfg = [NSImageSymbolConfiguration
        configurationWithPointSize:ptSize weight:NSFontWeightRegular];
    NSImage* img = [[NSImage imageWithSystemSymbolName:sym accessibilityDescription:tip]
                    imageWithSymbolConfiguration:cfg];
    NSButton* btn = [NSButton buttonWithImage:img target:nil action:nil];
    btn.bezelStyle   = NSBezelStyleCircular;
    btn.bordered     = NO;
    btn.toolTip      = tip;
    btn.imageScaling = NSImageScaleProportionallyDown;
    return btn;
}

// Legacy overload used by older call sites
- (NSButton*)makeSymbolButton:(NSString*)sym tooltip:(NSString*)tip {
    return [self makeSymbolButton:sym size:15 tooltip:tip];
}

// ── Context menu (right-click on web view) ────────────────────────────────────
// We inject a JS listener instead of using the WKUIDelegate context menu API
// (which requires macOS 13+ for full link info). This works on all targets.
- (void)injectContextMenuScript:(WKWebView*)wv {
    NSString* js = @""
    "document.addEventListener('contextmenu', function(e) {"
    "  var el = e.target;"
    "  var link = el.closest('a');"
    "  if (link) {"
    "    window._kbContextURL = link.href;"
    "  } else {"
    "    window._kbContextURL = null;"
    "  }"
    "}, true);";
    [wv evaluateJavaScript:js completionHandler:nil];
}

// ── NSTextFieldDelegate ───────────────────────────────────────────────────────

- (NSArray<NSString*>*)control:(NSControl*)control textView:(NSTextView*)textView completions:(NSArray<NSString*>*)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger*)index {
    if (control != _urlField) return words;
    
    NSString* partial = [control.stringValue substringWithRange:charRange];
    if (partial.length < 2) return words;

    NSMutableArray* results = [NSMutableArray new];
    // 1. Check open tabs
    for (BrowserTab* t in _tabManager.tabs) {
        if ([t.url containsString:partial]) [results addObject:t.url];
    }
    // 2. Check history
    for (HistoryEntry* e in [HistoryManager shared].entries) {
        if ([e.url containsString:partial]) [results addObject:e.url];
        if (results.count > 10) break;
    }
    // 3. Check bookmarks
    for (Bookmark* b in [BookmarkManager shared].bookmarks) {
        if ([b.url containsString:partial]) [results addObject:b.url];
        if (results.count > 20) break;
    }

    // Deduplicate
    return [[NSSet setWithArray:results] allObjects];
}

// ── Window delegate ───────────────────────────────────────────────────────────

- (void)windowWillClose:(NSNotification*)_ { [NSApp terminate:nil]; }

@end
