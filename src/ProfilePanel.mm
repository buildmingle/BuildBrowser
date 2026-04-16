#import <Cocoa/Cocoa.h>
#import "ProfileManager.h"

@interface ProfilePanel : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
+ (void)showAsSheetOnWindow:(NSWindow*)parent;
@end

@implementation ProfilePanel {
    NSTableView* _tableView;
    NSWindow*    _parentWindow;
}

+ (instancetype)shared {
    static ProfilePanel* inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [ProfilePanel new]; });
    return inst;
}

+ (void)showAsSheetOnWindow:(NSWindow*)parent {
    ProfilePanel* p = [ProfilePanel shared];
    p->_parentWindow = parent;
    [parent beginSheet:p.window completionHandler:nil];
}

- (instancetype)init {
    NSWindow* win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 400, 300)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered defer:NO];
    win.title = @"Manage Profiles";
    self = [super initWithWindow:win];
    if (self) [self buildUI];
    return self;
}

- (void)buildUI {
    NSView* root = self.window.contentView;
    root.wantsLayer = YES;
    
    NSVisualEffectView* bg = [[NSVisualEffectView alloc] initWithFrame:root.bounds];
    bg.material = NSVisualEffectMaterialHeaderView;
    bg.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:bg];

    NSTextField* header = [NSTextField labelWithString:@"Profiles"];
    header.frame = NSMakeRect(20, 260, 200, 24);
    header.font = [NSFont boldSystemFontOfSize:17];
    [root addSubview:header];

    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 60, 360, 190)];
    scroll.hasVerticalScroller = YES;
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    _tableView = [[NSTableView alloc] initWithFrame:scroll.bounds];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.headerView = nil;
    NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    col.title = @"Name";
    [_tableView addTableColumn:col];
    scroll.documentView = _tableView;
    [root addSubview:scroll];

    NSButton* addBtn = [NSButton buttonWithTitle:@"+" target:self action:@selector(addProfile:)];
    addBtn.frame = NSMakeRect(20, 20, 32, 32);
    addBtn.bezelStyle = NSBezelStyleSmallSquare;
    [root addSubview:addBtn];

    NSButton* delBtn = [NSButton buttonWithTitle:@"-" target:self action:@selector(deleteProfile:)];
    delBtn.frame = NSMakeRect(52, 20, 32, 32);
    delBtn.bezelStyle = NSBezelStyleSmallSquare;
    [root addSubview:delBtn];

    NSButton* done = [NSButton buttonWithTitle:@"Done" target:self action:@selector(done:)];
    done.frame = NSMakeRect(300, 20, 80, 32);
    done.bezelStyle = NSBezelStyleRounded;
    [root addSubview:done];
}

- (void)addProfile:(id)_ {
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"New Profile";
    alert.informativeText = @"Enter a name for the new profile:";
    NSTextField* input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"e.g. Work, School";
    alert.accessoryView = input;
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSString* name = input.stringValue;
            if (name.length > 0) {
                [[ProfileManager shared] createProfileWithName:name];
                [self->_tableView reloadData];
            }
        }
    }];
}

- (void)deleteProfile:(id)_ {
    NSInteger row = _tableView.selectedRow;
    if (row < 0) return;
    Profile* p = [ProfileManager shared].profiles[row];
    if (p == [ProfileManager shared].activeProfile) {
        NSAlert* a = [NSAlert new];
        a.messageText = @"Cannot Delete Active Profile";
        [a runModal];
        return;
    }
    [[ProfileManager shared] deleteProfile:p];
    [_tableView reloadData];
}

- (void)done:(id)_ {
    [_parentWindow endSheet:self.window];
    _parentWindow = nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)_ { return [ProfileManager shared].profiles.count; }
- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)_ row:(NSInteger)row {
    NSTableCellView* v = [tv makeViewWithIdentifier:@"cell" owner:self];
    if (!v) {
        v = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 360, 24)];
        v.identifier = @"cell";
        NSTextField* t = [NSTextField labelWithString:@""];
        t.frame = NSMakeRect(0, 0, 360, 24);
        t.identifier = @"name";
        [v addSubview:t];
    }
    Profile* p = [ProfileManager shared].profiles[row];
    for (NSView* sub in v.subviews) {
        if ([sub.identifier isEqualToString:@"name"]) ((NSTextField*)sub).stringValue = p.name;
    }
    return v;
}

@end
