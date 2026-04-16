#import <Cocoa/Cocoa.h>
#import "SettingsManager.h"
#import "HistoryManager.h"

// ── SettingsPanel ─────────────────────────────────────────────────────────────
// macOS-style settings: sidebar nav on the left, content pane on the right.
@interface SettingsPanel : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
+ (void)showAsSheetOnWindow:(NSWindow*)parent;
@end

// ── Row model for the sidebar ─────────────────────────────────────────────────
@interface SettingsSidebarItem : NSObject
@property (copy) NSString* label;
@property (copy) NSString* symbol;
+ (instancetype)item:(NSString*)label symbol:(NSString*)sym;
@end
@implementation SettingsSidebarItem
+ (instancetype)item:(NSString*)label symbol:(NSString*)sym {
    SettingsSidebarItem* i = [self new];
    i.label = label; i.symbol = sym; return i;
}
@end

// ── Helpers ───────────────────────────────────────────────────────────────────

// A rounded group box that looks like a macOS settings card
static NSView* makeGroupBox(CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    NSView* box = [[NSView alloc] initWithFrame:NSMakeRect(x, y, w, h)];
    box.wantsLayer = YES;
    box.layer.cornerRadius = 10;
    box.layer.backgroundColor = [NSColor colorWithWhite:0.5 alpha:0.08].CGColor;
    box.layer.borderColor     = [NSColor separatorColor].CGColor;
    box.layer.borderWidth     = 0.5;
    return box;
}

// A full-width separator line inside a group box
static NSView* makeSeparator(CGFloat y, CGFloat w) {
    NSView* sep = [[NSView alloc] initWithFrame:NSMakeRect(16, y, w - 32, 1)];
    sep.wantsLayer = YES;
    sep.layer.backgroundColor = [NSColor separatorColor].CGColor;
    return sep;
}

// Label on the left side of a row
static NSTextField* makeRowLabel(NSString* text) {
    NSTextField* f = [NSTextField labelWithString:text];
    f.font = [NSFont systemFontOfSize:13];
    return f;
}

// ── Main implementation ───────────────────────────────────────────────────────

@implementation SettingsPanel {
    // Sidebar
    NSTableView*  _sidebar;
    NSArray*      _sidebarItems;
    // Content stack (one NSView per section, swapped in/out)
    NSView*       _contentHost;
    NSArray*      _contentViews;
    // General
    NSTextField*  _homepageField;
    NSTextField*  _searchField;
    // Privacy
    NSButton*     _jsToggle;
    NSButton*     _popupToggle;
    NSButton*     _privateToggle;
    // Appearance
    NSButton*     _bookmarksBarToggle;
    // Data
    NSWindow*     _parentWindow;
}

+ (instancetype)shared {
    static SettingsPanel* inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [SettingsPanel new]; });
    return inst;
}

+ (void)showAsSheetOnWindow:(NSWindow*)parent {
    SettingsPanel* p = [SettingsPanel shared];
    [p reloadValues];
    p->_parentWindow = parent;
    [parent beginSheet:p.window completionHandler:nil];
}

- (instancetype)init {
    NSWindow* win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 620, 420)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered defer:NO];
    win.title = @"Settings";
    win.titlebarAppearsTransparent = YES;
    win.movableByWindowBackground  = YES;
    self = [super initWithWindow:win];
    if (!self) return nil;
    [self buildUI];
    return self;
}

// ── Build UI ──────────────────────────────────────────────────────────────────

- (void)buildUI {
    NSView* root = self.window.contentView;
    root.wantsLayer = YES;
    CGFloat W = 620, H = 420;

    // ── Sidebar (left 160px) ──────────────────────────────────────────────────
    NSVisualEffectView* sidebarBg = [[NSVisualEffectView alloc]
        initWithFrame:NSMakeRect(0, 0, 160, H)];
    sidebarBg.material     = NSVisualEffectMaterialSidebar;
    sidebarBg.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    sidebarBg.state        = NSVisualEffectStateActive;
    [root addSubview:sidebarBg];

    // Sidebar title
    NSTextField* sideTitle = [NSTextField labelWithString:@"Settings"];
    sideTitle.frame = NSMakeRect(16, H - 52, 128, 22);
    sideTitle.font  = [NSFont boldSystemFontOfSize:15];
    [sidebarBg addSubview:sideTitle];

    // Sidebar table
    NSScrollView* sideScroll = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, 0, 160, H - 60)];
    sideScroll.drawsBackground = NO;
    sideScroll.hasVerticalScroller = NO;

    _sidebar = [[NSTableView alloc] initWithFrame:sideScroll.bounds];
    _sidebar.backgroundColor = [NSColor clearColor];
    _sidebar.style = NSTableViewStyleSourceList;
    _sidebar.rowHeight  = 36;
    _sidebar.headerView = nil;
    _sidebar.dataSource = self;
    _sidebar.delegate   = self;
    NSTableColumn* sc = [[NSTableColumn alloc] initWithIdentifier:@"s"];
    sc.width = 160;
    [_sidebar addTableColumn:sc];
    sideScroll.documentView = _sidebar;
    [sidebarBg addSubview:sideScroll];

    _sidebarItems = @[
        [SettingsSidebarItem item:@"General"    symbol:@"house"],
        [SettingsSidebarItem item:@"Privacy"    symbol:@"lock.shield"],
        [SettingsSidebarItem item:@"Appearance" symbol:@"paintbrush"],
        [SettingsSidebarItem item:@"Data"       symbol:@"internaldrive"],
    ];
    [_sidebar reloadData];
    [_sidebar selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

    // Vertical divider
    NSView* divider = [[NSView alloc] initWithFrame:NSMakeRect(160, 0, 1, H)];
    divider.wantsLayer = YES;
    divider.layer.backgroundColor = [NSColor separatorColor].CGColor;
    [root addSubview:divider];

    // ── Content host (right side) ─────────────────────────────────────────────
    _contentHost = [[NSView alloc] initWithFrame:NSMakeRect(161, 0, W - 161, H)];
    [root addSubview:_contentHost];

    _contentViews = @[
        [self buildGeneralPane],
        [self buildPrivacyPane],
        [self buildAppearancePane],
        [self buildDataPane],
    ];
    for (NSView* v in _contentViews) {
        v.frame = _contentHost.bounds;
        v.hidden = YES;
        [_contentHost addSubview:v];
    }
    ((NSView*)_contentViews[0]).hidden = NO;

    // ── Done button (bottom right, always visible) ────────────────────────────
    NSButton* done = [NSButton buttonWithTitle:@"Done" target:self action:@selector(done:)];
    done.frame         = NSMakeRect(W - 100, 16, 84, 28);
    done.bezelStyle    = NSBezelStyleRounded;
    done.keyEquivalent = @"\r";
    [root addSubview:done];
}

// ── Content panes ─────────────────────────────────────────────────────────────

- (NSView*)buildGeneralPane {
    NSView* v = [NSView new];
    CGFloat W = 459, y = 340;

    NSTextField* title = [NSTextField labelWithString:@"General"];
    title.frame = NSMakeRect(24, y, 400, 24);
    title.font  = [NSFont boldSystemFontOfSize:17];
    [v addSubview:title]; y -= 36;

    // Homepage group
    NSView* box1 = makeGroupBox(16, y - 44, W - 32, 52);
    [v addSubview:box1];

    NSTextField* hpLabel = makeRowLabel(@"Homepage");
    hpLabel.frame = NSMakeRect(16, 16, 100, 20);
    [box1 addSubview:hpLabel];

    _homepageField = [[NSTextField alloc] initWithFrame:NSMakeRect(120, 14, W - 32 - 136, 22)];
    _homepageField.bezelStyle    = NSTextFieldRoundedBezel;
    _homepageField.focusRingType = NSFocusRingTypeNone;
    _homepageField.font          = [NSFont systemFontOfSize:13];
    [box1 addSubview:_homepageField];
    y -= 64;

    // Search engine group
    NSView* box2 = makeGroupBox(16, y - 64, W - 32, 72);
    [v addSubview:box2];

    NSTextField* seLabel = makeRowLabel(@"Search URL");
    seLabel.frame = NSMakeRect(16, 34, 100, 20);
    [box2 addSubview:seLabel];

    _searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(120, 32, W - 32 - 136, 22)];
    _searchField.bezelStyle    = NSTextFieldRoundedBezel;
    _searchField.focusRingType = NSFocusRingTypeNone;
    _searchField.font          = [NSFont systemFontOfSize:13];
    [box2 addSubview:_searchField];

    NSTextField* hint = [NSTextField labelWithString:@"Use %@ as the search query placeholder"];
    hint.frame     = NSMakeRect(120, 12, W - 32 - 136, 16);
    hint.font      = [NSFont systemFontOfSize:10];
    hint.textColor = [NSColor secondaryLabelColor];
    [box2 addSubview:hint];

    return v;
}

- (NSView*)buildPrivacyPane {
    NSView* v = [NSView new];
    CGFloat W = 459, y = 340;

    NSTextField* title = [NSTextField labelWithString:@"Privacy"];
    title.frame = NSMakeRect(24, y, 400, 24);
    title.font  = [NSFont boldSystemFontOfSize:17];
    [v addSubview:title]; y -= 36;

    // Three toggles in one group box
    NSView* box = makeGroupBox(16, y - 3*44 - 2, W - 32, 3*44 + 2);
    [v addSubview:box];

    // Build toggles individually to avoid ARC pointer-to-ivar issues
    NSString* labels[] = { @"Enable JavaScript", @"Block pop-up windows", @"Private browsing (no history)" };
    NSString* subtitles[] = {
        @"Required by most modern websites",
        @"Prevent sites from opening new windows",
        @"History and cookies won't be saved"
    };

    for (NSInteger i = 0; i < 3; i++) {
        CGFloat rowY = (2 - i) * 44 + 2;
        if (i > 0) [box addSubview:makeSeparator(rowY + 44, W - 32)];

        NSTextField* lbl = makeRowLabel(labels[i]);
        lbl.frame = NSMakeRect(16, rowY + 22, W - 32 - 60, 18);
        [box addSubview:lbl];

        NSTextField* sub = [NSTextField labelWithString:subtitles[i]];
        sub.frame     = NSMakeRect(16, rowY + 6, W - 32 - 60, 14);
        sub.font      = [NSFont systemFontOfSize:11];
        sub.textColor = [NSColor secondaryLabelColor];
        [box addSubview:sub];

        NSButton* toggle = [NSButton buttonWithTitle:@"" target:nil action:nil];
        toggle.buttonType = NSButtonTypeSwitch;
        toggle.frame      = NSMakeRect(W - 32 - 52, rowY + 14, 44, 22);
        toggle.tag        = i;
        [box addSubview:toggle];

        if (i == 0) _jsToggle      = toggle;
        else if (i == 1) _popupToggle   = toggle;
        else             _privateToggle = toggle;
    }

    return v;
}

- (NSView*)buildAppearancePane {
    NSView* v = [NSView new];
    CGFloat W = 459, y = 340;

    NSTextField* title = [NSTextField labelWithString:@"Appearance"];
    title.frame = NSMakeRect(24, y, 400, 24);
    title.font  = [NSFont boldSystemFontOfSize:17];
    [v addSubview:title]; y -= 36;

    NSView* box = makeGroupBox(16, y - 46, W - 32, 46);
    [v addSubview:box];

    NSTextField* lbl = makeRowLabel(@"Show bookmarks bar");
    lbl.frame = NSMakeRect(16, 14, W - 32 - 60, 18);
    [box addSubview:lbl];

    _bookmarksBarToggle = [NSButton buttonWithTitle:@"" target:nil action:nil];
    _bookmarksBarToggle.buttonType = NSButtonTypeSwitch;
    _bookmarksBarToggle.frame      = NSMakeRect(W - 32 - 52, 12, 44, 22);
    [box addSubview:_bookmarksBarToggle];

    return v;
}

- (NSView*)buildDataPane {
    NSView* v = [NSView new];
    CGFloat W = 459, y = 340;

    NSTextField* title = [NSTextField labelWithString:@"Data"];
    title.frame = NSMakeRect(24, y, 400, 24);
    title.font  = [NSFont boldSystemFontOfSize:17];
    [v addSubview:title]; y -= 36;

    NSView* box = makeGroupBox(16, y - 96, W - 32, 96);
    [v addSubview:box];

    // Clear history row
    NSTextField* histLabel = makeRowLabel(@"Browsing History");
    histLabel.frame = NSMakeRect(16, 56, 200, 18);
    [box addSubview:histLabel];
    NSTextField* histSub = [NSTextField labelWithString:@"Visited pages and search queries"];
    histSub.frame = NSMakeRect(16, 40, 240, 14);
    histSub.font  = [NSFont systemFontOfSize:11];
    histSub.textColor = [NSColor secondaryLabelColor];
    [box addSubview:histSub];
    NSButton* clearHist = [NSButton buttonWithTitle:@"Clear…" target:self action:@selector(clearHistory:)];
    clearHist.frame = NSMakeRect(W - 32 - 90, 50, 84, 24);
    clearHist.bezelStyle = NSBezelStyleRounded;
    [box addSubview:clearHist];

    [box addSubview:makeSeparator(44, W - 32)];

    // Reset defaults row
    NSTextField* resetLabel = makeRowLabel(@"Reset All Settings");
    resetLabel.frame = NSMakeRect(16, 12, 200, 18);
    [box addSubview:resetLabel];
    NSButton* resetBtn = [NSButton buttonWithTitle:@"Reset…" target:self action:@selector(resetDefaults:)];
    resetBtn.frame = NSMakeRect(W - 32 - 90, 6, 84, 24);
    resetBtn.bezelStyle = NSBezelStyleRounded;
    [box addSubview:resetBtn];

    return v;
}

// ── Reload values ─────────────────────────────────────────────────────────────

- (void)reloadValues {
    SettingsManager* s = [SettingsManager shared];
    _homepageField.stringValue     = s.homepage ?: @"";
    _searchField.stringValue       = s.searchEngineURL ?: @"";
    _jsToggle.state                = s.javascriptEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _popupToggle.state             = s.blockPopups       ? NSControlStateValueOn : NSControlStateValueOff;
    _privateToggle.state           = s.privateBrowsing   ? NSControlStateValueOn : NSControlStateValueOff;
    _bookmarksBarToggle.state      = s.showBookmarksBar  ? NSControlStateValueOn : NSControlStateValueOff;
}

// ── Actions ───────────────────────────────────────────────────────────────────

- (void)done:(id)_ {
    SettingsManager* s  = [SettingsManager shared];
    s.homepage          = _homepageField.stringValue;
    s.searchEngineURL   = _searchField.stringValue;
    s.javascriptEnabled = (_jsToggle.state             == NSControlStateValueOn);
    s.blockPopups       = (_popupToggle.state           == NSControlStateValueOn);
    s.privateBrowsing   = (_privateToggle.state         == NSControlStateValueOn);
    s.showBookmarksBar  = (_bookmarksBarToggle.state    == NSControlStateValueOn);
    [_parentWindow endSheet:self.window];
    [self.window orderOut:nil];
    _parentWindow = nil;
}

- (void)clearHistory:(id)_ {
    NSAlert* a        = [NSAlert new];
    a.messageText     = @"Clear all browsing history?";
    a.informativeText = @"This cannot be undone.";
    [a addButtonWithTitle:@"Clear"];
    [a addButtonWithTitle:@"Cancel"];
    [a beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse r) {
        if (r == NSAlertFirstButtonReturn) [[HistoryManager shared] clearAll];
    }];
}

- (void)resetDefaults:(id)_ {
    NSAlert* a        = [NSAlert new];
    a.messageText     = @"Reset all settings to defaults?";
    a.informativeText = @"This cannot be undone.";
    [a addButtonWithTitle:@"Reset"];
    [a addButtonWithTitle:@"Cancel"];
    [a beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse r) {
        if (r == NSAlertFirstButtonReturn) {
            [[SettingsManager shared] resetToDefaults];
            [self reloadValues];
        }
    }];
}

// ── NSTableViewDataSource / Delegate (sidebar) ────────────────────────────────

- (NSInteger)numberOfRowsInTableView:(NSTableView*)_ { return (NSInteger)_sidebarItems.count; }

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)_ row:(NSInteger)row {
    NSTableCellView* cell = [tv makeViewWithIdentifier:@"si" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 160, 36)];
        cell.identifier = @"si";

        NSImageView* iv = [[NSImageView alloc] initWithFrame:NSMakeRect(12, 8, 20, 20)];
        iv.identifier = @"icon";
        [cell addSubview:iv];

        NSTextField* lbl = [NSTextField labelWithString:@""];
        lbl.frame      = NSMakeRect(40, 9, 110, 18);
        lbl.font       = [NSFont systemFontOfSize:13];
        lbl.identifier = @"lbl";
        [cell addSubview:lbl];
    }
    SettingsSidebarItem* item = _sidebarItems[row];
    for (NSView* sub in cell.subviews) {
        if ([sub.identifier isEqualToString:@"icon"])
            ((NSImageView*)sub).image = [NSImage imageWithSystemSymbolName:item.symbol
                                                   accessibilityDescription:nil];
        else if ([sub.identifier isEqualToString:@"lbl"])
            ((NSTextField*)sub).stringValue = item.label;
    }
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification*)_ {
    NSInteger sel = _sidebar.selectedRow;
    for (NSInteger i = 0; i < (NSInteger)_contentViews.count; i++)
        ((NSView*)_contentViews[i]).hidden = (i != sel);
}

- (CGFloat)tableView:(NSTableView*)_ heightOfRow:(NSInteger)__ { return 36; }

@end
