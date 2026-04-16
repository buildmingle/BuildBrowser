#import "ContentBlocker.h"
#import "SettingsManager.h"
#import "ProfileManager.h"

@implementation ContentBlocker {
    WKContentRuleList* _ruleList;
}

+ (instancetype)shared {
    static ContentBlocker* inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [ContentBlocker new]; });
    return inst;
}

- (void)applyToConfiguration:(WKWebViewConfiguration*)config completion:(void(^)(void))completion {
    if (![SettingsManager profileShared].adBlockEnabled) {
        if (completion) completion();
        return;
    }

    if (_ruleList) {
        [config.userContentController addContentRuleList:_ruleList];
        if (completion) completion();
        return;
    }

    // Basic common tracker/ad domains blocking rules in WKContentRuleList JSON format
    NSString* json = @"["
    "  { \"trigger\": { \"url-filter\": \".*google-analytics\\\\.com.*\" }, \"action\": { \"type\": \"block\" } },"
    "  { \"trigger\": { \"url-filter\": \".*doubleclick\\\\.net.*\" }, \"action\": { \"type\": \"block\" } },"
    "  { \"trigger\": { \"url-filter\": \".*scorecardresearch\\\\.com.*\" }, \"action\": { \"type\": \"block\" } },"
    "  { \"trigger\": { \"url-filter\": \".*ads\\\\..*\" }, \"action\": { \"type\": \"block\" } },"
    "  { \"trigger\": { \"url-filter\": \".*tracker.*\" }, \"action\": { \"type\": \"block\" } }"
    "]";

    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"KBrowserBlocker"
                                                       encodedContentRuleList:json
                                                            completionHandler:^(WKContentRuleList* list, NSError* error) {
        if (list) {
            self->_ruleList = list;
            [config.userContentController addContentRuleList:list];
        } else {
            NSLog(@"ContentBlocker: Compilation failed: %@", error);
        }
        if (completion) completion();
    }];
}

@end
