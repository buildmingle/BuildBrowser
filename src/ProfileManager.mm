#import "ProfileManager.h"

@interface ProfileManager ()
@property (strong) NSMutableArray<Profile*>* mutableProfiles;
@end

@implementation ProfileManager

+ (instancetype)shared {
    static ProfileManager* inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [ProfileManager new]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableProfiles = [NSMutableArray new];
        [self loadProfiles];
        
        if (_mutableProfiles.count == 0) {
            [self createDefaultProfile];
        }
        
        // Default to first profile if active not set
        if (!_activeProfile && _mutableProfiles.count > 0) {
            _activeProfile = _mutableProfiles[0];
        }
    }
    return self;
}

- (NSArray<Profile*>*)profiles {
    return _mutableProfiles;
}

- (Profile*)createProfileWithName:(NSString*)name {
    Profile* p = [[Profile alloc] initWithName:name];
    [_mutableProfiles addObject:p];
    [self saveProfiles];
    return p;
}

- (void)createDefaultProfile {
    Profile* p = [[Profile alloc] initWithName:@"Default"];
    // For the default profile, we might want to use a fixed UUID or migrate old data
    [_mutableProfiles addObject:p];
    [self saveProfiles];
    [self migrateLegacyDataToProfile:p];
}

- (void)deleteProfile:(Profile*)profile {
    if (profile == _activeProfile) return; // Cannot delete active profile
    [_mutableProfiles removeObject:profile];
    [[NSFileManager defaultManager] removeItemAtPath:[profile dataDirectory] error:nil];
    [self saveProfiles];
}

- (void)saveProfiles {
    NSError* err;
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:_mutableProfiles requiringSecureCoding:YES error:&err];
    if (data) {
        NSString* path = [self profileListPath];
        [data writeToFile:path atomically:YES];
    }
    // Save active profile ID to defaults
    if (_activeProfile) {
        [[NSUserDefaults standardUserDefaults] setObject:_activeProfile.uuid forKey:@"LastActiveProfile"];
    }
}

- (void)loadProfiles {
    NSString* path = [self profileListPath];
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (data) {
        NSError* err;
        NSArray* arr = [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:[Profile class] fromData:data error:&err];
        if (arr) {
            [_mutableProfiles addObjectsFromArray:arr];
        }
    }
    
    NSString* lastUUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"LastActiveProfile"];
    if (lastUUID) {
        for (Profile* p in _mutableProfiles) {
            if ([p.uuid isEqualToString:lastUUID]) {
                _activeProfile = p;
                break;
            }
        }
    }
}

- (NSString*)profileListPath {
    NSString* support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString* base = [support stringByAppendingPathComponent:@"BuildBrowser"];
    [[NSFileManager defaultManager] createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
    return [base stringByAppendingPathComponent:@"profiles.plist"];
}

- (void)migrateLegacyDataToProfile:(Profile*)profile {
    NSString* support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString* base = [support stringByAppendingPathComponent:@"BuildBrowser"];
    NSString* target = [profile dataDirectory];
    
    NSArray* files = @[@"bookmarks.plist", @"history.plist"];
    NSFileManager* fm = [NSFileManager defaultManager];
    
    for (NSString* file in files) {
        NSString* oldPath = [base stringByAppendingPathComponent:file];
        NSString* newPath = [target stringByAppendingPathComponent:file];
        if ([fm fileExistsAtPath:oldPath] && ![fm fileExistsAtPath:newPath]) {
            [fm moveItemAtPath:oldPath toPath:newPath error:nil];
        }
    }
}

@end
