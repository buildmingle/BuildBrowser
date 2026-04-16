#import "SettingsManager.h"

static NSString* const kHomepage        = @"KBrowser.homepage";
static NSString* const kSearchEngine    = @"KBrowser.searchEngineURL";
static NSString* const kJavascript      = @"KBrowser.javascriptEnabled";
static NSString* const kBlockPopups     = @"KBrowser.blockPopups";
static NSString* const kPrivateBrowsing = @"KBrowser.privateBrowsing";
static NSString* const kBookmarksBar    = @"KBrowser.showBookmarksBar";
static NSString* const kAdBlock         = @"KBrowser.adBlockEnabled";

@implementation SettingsManager

+ (instancetype)shared {
    static SettingsManager* inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [SettingsManager new]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Register defaults — only applied if key has never been set
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            kHomepage:        @"https://start.duckduckgo.com",
            kSearchEngine:    @"https://duckduckgo.com/?q=%@",
            kJavascript:      @YES,
            kBlockPopups:     @YES,
            kPrivateBrowsing: @NO,
            kBookmarksBar:    @YES,
            kAdBlock:         @YES,
        }];
    }
    return self;
}

// ── Accessors backed by NSUserDefaults ────────────────────────────────────────

#define STR_PREF(getter, setter, key) \
- (NSString*)getter { return [[NSUserDefaults standardUserDefaults] stringForKey:key]; } \
- (void)setter:(NSString*)v { [[NSUserDefaults standardUserDefaults] setObject:v forKey:key]; }

#define BOOL_PREF(getter, setter, key) \
- (BOOL)getter { return [[NSUserDefaults standardUserDefaults] boolForKey:key]; } \
- (void)setter:(BOOL)v { [[NSUserDefaults standardUserDefaults] setBool:v forKey:key]; }

STR_PREF(homepage,        setHomepage,        kHomepage)
STR_PREF(searchEngineURL, setSearchEngineURL, kSearchEngine)
BOOL_PREF(javascriptEnabled, setJavascriptEnabled, kJavascript)
BOOL_PREF(blockPopups,       setBlockPopups,       kBlockPopups)
BOOL_PREF(privateBrowsing,   setPrivateBrowsing,   kPrivateBrowsing)
BOOL_PREF(showBookmarksBar,  setShowBookmarksBar,  kBookmarksBar)
BOOL_PREF(adBlockEnabled,    setAdBlockEnabled,    kAdBlock)

- (void)resetToDefaults {
    for (NSString* key in @[kHomepage, kSearchEngine, kJavascript,
                            kBlockPopups, kPrivateBrowsing, kBookmarksBar, kAdBlock])
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}
@end
