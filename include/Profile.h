#pragma once
#import <AppKit/AppKit.h>

@interface Profile : NSObject <NSSecureCoding>

@property (copy) NSString* name;
@property (copy) NSString* uuid;
@property (strong) NSColor* color;

- (instancetype)initWithName:(NSString*)name;
- (NSString*)dataDirectory;

@end
