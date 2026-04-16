#import "Profile.h"
#import <AppKit/AppKit.h>

@implementation Profile

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithName:(NSString*)name {
    self = [super init];
    if (self) {
        _name = name;
        _uuid = [[NSUUID UUID] UUIDString];
        _color = [NSColor controlAccentColor];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)c {
    self = [super init];
    if (self) {
        _name = [c decodeObjectOfClass:[NSString class] forKey:@"name"];
        _uuid = [c decodeObjectOfClass:[NSString class] forKey:@"uuid"];
        _color = [c decodeObjectOfClass:[NSColor class] forKey:@"color"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)c {
    [c encodeObject:_name forKey:@"name"];
    [c encodeObject:_uuid forKey:@"uuid"];
    [c encodeObject:_color forKey:@"color"];
}

- (NSString*)dataDirectory {
    NSString* support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString* base = [support stringByAppendingPathComponent:@"BuildBrowser"];
    NSString* profiles = [base stringByAppendingPathComponent:@"Profiles"];
    NSString* path = [profiles stringByAppendingPathComponent:self.uuid];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

@end
