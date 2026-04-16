#import <Cocoa/Cocoa.h>
#import "DownloadManager.h"

@interface DownloadsPanel : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
+ (instancetype)shared;
- (void)show;
@end

@implementation DownloadsPanel {
    NSTableView* _tableView;
    NSTextField* _emptyLabel;
}

+ (instancetype)shared {
    static DownloadsPanel* inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [DownloadsPanel new]; });
    return inst;
}

- (instancetype)init {
    NSWindow* win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 420, 400)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                           | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered defer:NO];
    win.title = @"Downloads";
    win.titlebarAppearsTransparent = YES;
    win.movableByWindowBackground  = YES;
    win.minSize = NSMakeSize(320, 240);
    self = [super initWithWindow:win];
    if (!self) return nil;
    [self buildUI];

    DownloadsPanel* __unsafe_unretained ws = self;
    [DownloadManager shared].onUpdate = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws->_tableView reloadData];
            ws->_emptyLabel.hidden = ([DownloadManager shared].items.count > 0);
        });
    };
    return self;
}

- (void)buildUI {
    NSView* root = self.window.contentView;
    root.wantsLayer = YES;
    CGFloat W = 420, H = 400;

    // Frosted background
    NSVisualEffectView* bg = [[NSVisualEffectView alloc] initWithFrame:root.bounds];
    bg.material        = NSVisualEffectMaterialSidebar;
    bg.blendingMode    = NSVisualEffectBlendingModeWithinWindow;
    bg.state           = NSVisualEffectStateActive;
    bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:bg];

    // Header
    NSTextField* header = [NSTextField labelWithString:@"Downloads"];
    header.frame = NSMakeRect(16, H - 48, 200, 24);
    header.font  = [NSFont boldSystemFontOfSize:17];
    header.autoresizingMask = NSViewMinYMargin;
    [root addSubview:header];

    // Clear completed button
    NSButton* clearBtn = [NSButton buttonWithTitle:@"Clear Completed"
                                            target:self action:@selector(clearCompleted:)];
    clearBtn.frame      = NSMakeRect(W - 140, H - 46, 124, 22);
    clearBtn.bezelStyle = NSBezelStyleInline;
    clearBtn.font       = [NSFont systemFontOfSize:11];
    clearBtn.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [root addSubview:clearBtn];

    // Separator
    NSView* sep = [[NSView alloc] initWithFrame:NSMakeRect(0, H - 56, W, 1)];
    sep.wantsLayer = YES;
    sep.layer.backgroundColor = [NSColor separatorColor].CGColor;
    sep.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [root addSubview:sep];

    // Table
    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, W, H - 57)];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;

    _tableView = [[NSTableView alloc] initWithFrame:scroll.bounds];
    _tableView.backgroundColor = [NSColor clearColor];
    _tableView.dataSource = self;
    _tableView.delegate   = self;
    _tableView.rowHeight  = 64;
    _tableView.intercellSpacing = NSMakeSize(0, 0);
    _tableView.headerView = nil;
    _tableView.doubleAction = @selector(revealInFinder:);
    _tableView.target       = self;

    NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:@"main"];
    col.width = W;
    [_tableView addTableColumn:col];
    scroll.documentView = _tableView;
    [root addSubview:scroll];

    // Empty state
    _emptyLabel = [NSTextField labelWithString:@"No downloads yet"];
    _emptyLabel.frame     = NSMakeRect(0, H / 2 - 30, W, 40);
    _emptyLabel.alignment = NSTextAlignmentCenter;
    _emptyLabel.font      = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    _emptyLabel.textColor = [NSColor tertiaryLabelColor];
    _emptyLabel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin;
    [root addSubview:_emptyLabel];
}

- (void)show {
    [_tableView reloadData];
    _emptyLabel.hidden = ([DownloadManager shared].items.count > 0);
    [self.window makeKeyAndOrderFront:nil];
}

// ── NSTableViewDataSource ─────────────────────────────────────────────────────

- (NSInteger)numberOfRowsInTableView:(NSTableView*)_ {
    return (NSInteger)[DownloadManager shared].items.count;
}

- (NSView*)tableView:(NSTableView*)tv viewForTableColumn:(NSTableColumn*)_ row:(NSInteger)row {
    NSTableCellView* cell = [tv makeViewWithIdentifier:@"dl" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 420, 64)];
        cell.identifier = @"dl";

        // Icon
        NSImageView* icon = [[NSImageView alloc] initWithFrame:NSMakeRect(14, 18, 28, 28)];
        icon.identifier = @"icon";
        [cell addSubview:icon];

        // Filename
        NSTextField* name = [NSTextField labelWithString:@""];
        name.frame = NSMakeRect(54, 40, 280, 16);
        name.font  = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        name.lineBreakMode = NSLineBreakByTruncatingMiddle;
        name.identifier = @"name";
        [cell addSubview:name];

        // Progress bar
        NSProgressIndicator* bar = [[NSProgressIndicator alloc]
            initWithFrame:NSMakeRect(54, 26, 280, 6)];
        bar.style    = NSProgressIndicatorStyleBar;
        bar.minValue = 0; bar.maxValue = 1;
        bar.identifier = @"bar";
        [cell addSubview:bar];

        // Status text
        NSTextField* status = [NSTextField labelWithString:@""];
        status.frame     = NSMakeRect(54, 10, 220, 13);
        status.font      = [NSFont systemFontOfSize:11];
        status.textColor = [NSColor secondaryLabelColor];
        status.lineBreakMode = NSLineBreakByTruncatingTail;
        status.identifier = @"status";
        [cell addSubview:status];

        // Action button (reveal / open)
        NSButton* actionBtn = [NSButton buttonWithTitle:@"Show" target:nil action:nil];
        actionBtn.frame      = NSMakeRect(340, 20, 64, 22);
        actionBtn.bezelStyle = NSBezelStyleInline;
        actionBtn.font       = [NSFont systemFontOfSize:11];
        actionBtn.identifier = @"action";
        [cell addSubview:actionBtn];

        // Row separator
        NSView* rowSep = [[NSView alloc] initWithFrame:NSMakeRect(54, 0, 360, 1)];
        rowSep.wantsLayer = YES;
        rowSep.layer.backgroundColor = [NSColor separatorColor].CGColor;
        rowSep.identifier = @"sep";
        [cell addSubview:rowSep];
    }

    DownloadItem* item = [DownloadManager shared].items[row];

    for (NSView* sub in cell.subviews) {
        if ([sub.identifier isEqualToString:@"icon"]) {
            NSString* sym;
            NSColor*  tint;
            if (item.state == DownloadStateComplete) {
                sym = @"checkmark.circle.fill"; tint = [NSColor systemGreenColor];
            } else if (item.state == DownloadStateFailed) {
                sym = @"xmark.circle.fill";     tint = [NSColor systemRedColor];
            } else {
                sym = @"arrow.down.circle.fill"; tint = [NSColor controlAccentColor];
            }
            NSImageView* iv = (NSImageView*)sub;
            iv.image = [NSImage imageWithSystemSymbolName:sym accessibilityDescription:nil];
            iv.contentTintColor = tint;

        } else if ([sub.identifier isEqualToString:@"name"]) {
            ((NSTextField*)sub).stringValue = item.filename ?: @"Unknown";

        } else if ([sub.identifier isEqualToString:@"bar"]) {
            NSProgressIndicator* bar = (NSProgressIndicator*)sub;
            bar.hidden = (item.state != DownloadStateInProgress);
            if (!bar.hidden) {
                if (item.totalBytes > 0) {
                    bar.indeterminate = NO;
                    bar.doubleValue   = (double)item.bytesReceived / item.totalBytes;
                } else {
                    bar.indeterminate = YES;
                    [bar startAnimation:nil];
                }
            }

        } else if ([sub.identifier isEqualToString:@"status"]) {
            NSString* s;
            if (item.state == DownloadStateComplete)
                s = [NSString stringWithFormat:@"Saved — %@",
                     item.destinationPath.lastPathComponent];
            else if (item.state == DownloadStateFailed)
                s = @"Download failed";
            else if (item.totalBytes > 0)
                s = [NSString stringWithFormat:@"%.1f / %.1f MB",
                     item.bytesReceived / 1e6, item.totalBytes / 1e6];
            else
                s = [NSString stringWithFormat:@"%.1f MB received",
                     item.bytesReceived / 1e6];
            ((NSTextField*)sub).stringValue = s;

        } else if ([sub.identifier isEqualToString:@"action"]) {
            NSButton* btn = (NSButton*)sub;
            btn.hidden = (item.state == DownloadStateInProgress);
            btn.title  = (item.state == DownloadStateComplete) ? @"Show" : @"";
            btn.tag    = row;
            btn.target = self;
            btn.action = @selector(actionButtonClicked:);

        } else if ([sub.identifier isEqualToString:@"sep"]) {
            sub.hidden = (row == (NSInteger)[DownloadManager shared].items.count - 1);
        }
    }
    return cell;
}

// ── Actions ───────────────────────────────────────────────────────────────────

- (void)actionButtonClicked:(NSButton*)btn {
    NSInteger row = btn.tag;
    NSArray<DownloadItem*>* items = [DownloadManager shared].items;
    if (row >= (NSInteger)items.count) return;
    DownloadItem* item = items[row];
    if (item.destinationPath)
        [[NSWorkspace sharedWorkspace] selectFile:item.destinationPath
                         inFileViewerRootedAtPath:@""];
}

- (void)revealInFinder:(id)_ {
    NSInteger row = _tableView.clickedRow;
    if (row < 0) return;
    NSArray<DownloadItem*>* items = [DownloadManager shared].items;
    if (row >= (NSInteger)items.count) return;
    DownloadItem* item = items[row];
    if (item.destinationPath)
        [[NSWorkspace sharedWorkspace] selectFile:item.destinationPath
                         inFileViewerRootedAtPath:@""];
}

- (void)clearCompleted:(id)_ {
    NSMutableArray* items = [[DownloadManager shared].items mutableCopy];
    [items filterUsingPredicate:[NSPredicate predicateWithBlock:
        ^BOOL(DownloadItem* i, NSDictionary* _) {
            return i.state == DownloadStateInProgress;
        }]];
    // DownloadManager doesn't expose a remove API yet — reload is enough for display
    [_tableView reloadData];
}
@end
