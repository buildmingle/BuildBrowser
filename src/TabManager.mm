#import "TabManager.h"
#import "ContentBlocker.h"

// ── BrowserTab ───────────────────────────────────────────────────────────────

@implementation BrowserTab
@end

// ── TabManager ───────────────────────────────────────────────────────────────

@interface TabManager () <WKNavigationDelegate, WKUIDelegate>
@property (strong) NSMutableArray<BrowserTab*>* mutableTabs;
@property (assign) NSInteger currentIndex;
@end

@implementation TabManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableTabs  = [NSMutableArray new];
        _currentIndex = -1;
    }
    return self;
}

- (NSArray<BrowserTab*>*)tabs { return _mutableTabs; }
- (BrowserTab*)activeTab      { return _currentIndex >= 0 ? _mutableTabs[_currentIndex] : nil; }
- (NSInteger)activeIndex      { return _currentIndex; }

// ── Tab creation ─────────────────────────────────────────────────────────────

- (BrowserTab*)newTabWithURL:(NSString*)url {
    WKWebViewConfiguration* config = [WKWebViewConfiguration new];
    config.preferences.javaScriptCanOpenWindowsAutomatically = NO;
    [[ContentBlocker shared] applyToConfiguration:config completion:nil];

    BrowserTab* tab   = [BrowserTab new];
    tab.webView       = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:config];
    tab.webView.navigationDelegate = self;
    tab.webView.UIDelegate         = self;
    tab.title = @"New Tab";
    tab.url   = url ?: @"";

    // Tab strip button
    tab.tabButton = [NSButton buttonWithTitle:@"New Tab" target:nil action:nil];
    tab.tabButton.bezelStyle    = NSBezelStyleRecessed;
    tab.tabButton.buttonType    = NSButtonTypePushOnPushOff;
    tab.tabButton.font          = [NSFont systemFontOfSize:12];
    tab.tabButton.imagePosition = NSNoImage;
    [tab.tabButton.cell setLineBreakMode:NSLineBreakByTruncatingTail];

    // KVO for live progress / title / URL updates
    [tab.webView addObserver:self forKeyPath:@"estimatedProgress"
                    options:NSKeyValueObservingOptionNew context:nil];
    [tab.webView addObserver:self forKeyPath:@"title"
                    options:NSKeyValueObservingOptionNew context:nil];
    [tab.webView addObserver:self forKeyPath:@"URL"
                    options:NSKeyValueObservingOptionNew context:nil];

    // Set default icon
    tab.favicon = [NSImage imageWithSystemSymbolName:@"globe" accessibilityDescription:nil];

    NSInteger index = (NSInteger)_mutableTabs.count;
    [_mutableTabs addObject:tab];

    if (self.onTabAdded) self.onTabAdded(tab, index);

    [self switchToIndex:index];
    [self loadURL:url inTab:tab];

    return tab;
}

// ── Tab switching / closing ───────────────────────────────────────────────────

- (void)switchToIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_mutableTabs.count) return;
    _currentIndex = index;
    if (self.onTabSwitched) self.onTabSwitched(_mutableTabs[index], index);
}

- (void)closeTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_mutableTabs.count) return;

    // Never close the last tab — navigate home instead
    if (_mutableTabs.count == 1) {
        [self loadURL:@"https://start.duckduckgo.com" inTab:_mutableTabs[0]];
        return;
    }

    // Remove KVO before releasing the web view
    BrowserTab* dying = _mutableTabs[index];
    [dying.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [dying.webView removeObserver:self forKeyPath:@"title"];
    [dying.webView removeObserver:self forKeyPath:@"URL"];

    [_mutableTabs removeObjectAtIndex:index];
    if (self.onTabClosed) self.onTabClosed(index);

    NSInteger next = (index > 0) ? index - 1 : 0;
    _currentIndex  = -1;
    [self switchToIndex:next];
}

// ── URL loading ───────────────────────────────────────────────────────────────

- (void)loadURL:(NSString*)raw inTab:(BrowserTab*)tab {
    NSString* url = [TabManager sanitizeURL:raw];
    tab.url = url;
    NSURL* nsurl = [NSURL URLWithString:url];
    if (nsurl) [tab.webView loadRequest:[NSURLRequest requestWithURL:nsurl]];
}

+ (NSString*)sanitizeURL:(NSString*)input {
    if (!input || input.length == 0) return @"https://start.duckduckgo.com";
    if ([input hasPrefix:@"http://"] || [input hasPrefix:@"https://"]) return input;
    if ([input containsString:@"."] && ![input containsString:@" "])
        return [@"https://" stringByAppendingString:input];
    NSString* enc = [input stringByAddingPercentEncodingWithAllowedCharacters:
                     NSCharacterSet.URLQueryAllowedCharacterSet];
    return [@"https://duckduckgo.com/?q=" stringByAppendingString:enc];
}

// ── WKNavigationDelegate ──────────────────────────────────────────────────────

- (void)webView:(WKWebView*)wv didStartProvisionalNavigation:(WKNavigation*)_ {
    BrowserTab* tab = [self tabForWebView:wv];
    if (tab && self.onLoadStateChanged) self.onLoadStateChanged(tab, YES);
}

- (void)webView:(WKWebView*)wv didFinishNavigation:(WKNavigation*)_ {
    BrowserTab* tab = [self tabForWebView:wv];
    if (!tab) return;
    if (self.onLoadStateChanged) self.onLoadStateChanged(tab, NO);
    NSString* title = wv.title.length ? wv.title : @"New Tab";
    NSString* url   = wv.URL.absoluteString ?: @"";
    tab.title = title;  tab.url = url;
    if (self.onTitleChanged) self.onTitleChanged(tab, title);
    if (self.onURLChanged)   self.onURLChanged(tab, url);
    [self updateFaviconForTab:tab];
}

- (void)webView:(WKWebView*)wv didFailNavigation:(WKNavigation*)_ withError:(NSError*)__ {
    BrowserTab* tab = [self tabForWebView:wv];
    if (tab && self.onLoadStateChanged) self.onLoadStateChanged(tab, NO);
}

- (void)webView:(WKWebView*)wv didFailProvisionalNavigation:(WKNavigation*)_ withError:(NSError*)__ {
    BrowserTab* tab = [self tabForWebView:wv];
    if (tab && self.onLoadStateChanged) self.onLoadStateChanged(tab, NO);
}

// ── KVO ───────────────────────────────────────────────────────────────────────

- (void)observeValueForKeyPath:(NSString*)kp ofObject:(id)obj
                        change:(NSDictionary*)_ context:(void*)__ {
    WKWebView*  wv  = (WKWebView*)obj;
    BrowserTab* tab = [self tabForWebView:wv];
    if (!tab) return;

    if ([kp isEqualToString:@"estimatedProgress"]) {
        if (self.onLoadProgress) self.onLoadProgress(tab, wv.estimatedProgress);
    } else if ([kp isEqualToString:@"title"]) {
        NSString* t = wv.title.length ? wv.title : @"New Tab";
        tab.title = t;
        if (self.onTitleChanged) self.onTitleChanged(tab, t);
    } else if ([kp isEqualToString:@"URL"]) {
        NSString* u = wv.URL.absoluteString ?: @"";
        tab.url = u;
        if (self.onURLChanged) self.onURLChanged(tab, u);
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

- (void)updateFaviconForTab:(BrowserTab*)tab {
    // 1. Try to extract from page via JS
    NSString* js = @"(function() {"
    "  var rels = ['icon', 'shortcut icon', 'apple-touch-icon'];"
    "  for (var i = 0; i < rels.length; i++) {"
    "    var el = document.querySelector('link[rel=\"' + rels[i] + '\"]');"
    "    if (el && el.href) return el.href;"
    "  }"
    "  return null;"
    "})();";

    __weak typeof(self) weakSelf = self;
    [tab.webView evaluateJavaScript:js completionHandler:^(id result, NSError* error) {
        NSString* iconURLString = (NSString*)result;
        if (![iconURLString isKindOfClass:[NSString class]] || iconURLString.length == 0) {
            // 2. Fallback to Google Favicon API
            NSURL* url = [NSURL URLWithString:tab.url];
            if (url.host) {
                iconURLString = [NSString stringWithFormat:@"https://www.google.com/s2/favicons?domain=%@&sz=32", url.host];
            }
        }

        if (iconURLString) {
            [weakSelf downloadFavicon:iconURLString forTab:tab];
        }
    }];
}

- (void)downloadFavicon:(NSString*)urlString forTab:(BrowserTab*)tab {
    NSURL* url = [NSURL URLWithString:urlString];
    if (!url) return;

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (data && !error) {
            NSImage* image = [[NSImage alloc] initWithData:data];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    tab.favicon = image;
                    if (weakSelf.onFaviconChanged) weakSelf.onFaviconChanged(tab, image);
                });
            }
        }
    }] resume];
}

- (BrowserTab*)tabForWebView:(WKWebView*)wv {
    for (BrowserTab* t in _mutableTabs)
        if (t.webView == wv) return t;
    return nil;
}

@end
