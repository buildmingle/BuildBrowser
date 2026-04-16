#pragma once
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface ContentBlocker : NSObject

+ (instancetype)shared;

// Compiles a basic set of blocking rules and applies them to the given configuration
- (void)applyToConfiguration:(WKWebViewConfiguration*)config completion:(void(^)(void))completion;

@end
