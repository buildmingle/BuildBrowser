#import "SettingsManager.h"

static NSString* const kHomepage        = @"KBrowser.homepage";
static NSString* const kSearchEngine    = @"KBrowser.searchEngineURL";
static NSString* const kJavascript      = @"KBrowser.javascriptEnabled";
static NSString* const kBlockPopups     = @"KBrowser.blockPopups";
static NSString* const kPrivateBrowsing = @"KBrowser.privateBrowsing";
static NSString* const kBookmarksBar    = @"KBrowser.showBookmarksBar";
static NSString* const kAdBlock         = @"KBrowser.adBlockEnabled";

#import "ProfileManager.h"

@interface SettingsManager ()
@property (strong) NSMutableDictionary* settings;
@property (copy) NSString* rootPath;
@end

@implementation SettingsManager

+ (instancetype)profileShared {
    static NSMutableDictionary* instances;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ instances = [NSMutableDictionary new]; });
    
    Profile* p = [ProfileManager shared].activeProfile;
    if (!p) return nil;
    
    if (!instances[p.uuid]) {
        instances[p.uuid] = [[SettingsManager alloc] initWithRootPath:[p dataDirectory]];
    }
    return instances[p.uuid];
}

- (instancetype)initWithRootPath:(NSString*)path {
    self = [super init];
    if (self) {
        _rootPath = path;
        [self load];
    }
    return self;
}

- (void)load {
    NSString* path = [self filePath];
    _settings = [[NSMutableDictionary alloc] initWithContentsOfFile:path] ?: [NSMutableDictionary new];
    
    // Default values if not present
    NSDictionary* defaults = @{
        kHomepage:        @"https://start.duckduckgo.com",
        kSearchEngine:    @"https://duckduckgo.com/?q=%@",
        kJavascript:      @YES,
        kBlockPopups:     @YES,
        kPrivateBrowsing: @NO,
        kBookmarksBar:    @YES,
        kAdBlock:         @YES,
    };
    
    for (NSString* key in defaults) {
        if (!_settings[key]) _settings[key] = defaults[key];
    }
}

- (void)save {
    [_settings writeToFile:[self filePath] atomically:YES];
}

- (NSString*)filePath {
    return [_rootPath stringByAppendingPathComponent:@"settings.plist"];
}

// ── Accessors backed by NSUserDefaults ────────────────────────────────────────

#define STR_PREF(getter, setter, key) \
- (NSString*)getter { return _settings[key]; } \
- (void)setter:(NSString*)v { _settings[key] = v; [self save]; }

#define BOOL_PREF(getter, setter, key) \
- (BOOL)getter { return [_settings[key] boolValue]; } \
- (void)setter:(BOOL)v { _settings[key] = @(v); [self save]; }

STR_PREF(homepage,        setHomepage,        kHomepage)
STR_PREF(searchEngineURL, setSearchEngineURL, kSearchEngine)
BOOL_PREF(javascriptEnabled, setJavascriptEnabled, kJavascript)
BOOL_PREF(blockPopups,       setBlockPopups,       kBlockPopups)
BOOL_PREF(privateBrowsing,   setPrivateBrowsing,   kPrivateBrowsing)
BOOL_PREF(showBookmarksBar,  setShowBookmarksBar,  kBookmarksBar)
BOOL_PREF(adBlockEnabled,    setAdBlockEnabled,    kAdBlock)

- (void)resetToDefaults {
    [_settings removeAllObjects];
    [self load];
    [self save];
}
@end
