#import "BookmarkManager.h"

// ── Bookmark
// ──────────────────────────────────────────────────────────────────

@implementation Bookmark

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithTitle:(NSString *)title url:(NSString *)url {
  self = [super init];
  if (self) {
    _title = title;
    _url = url;
    _dateAdded = [NSDate date];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)c {
  self = [super init];
  if (self) {
    _title = [c decodeObjectOfClass:[NSString class] forKey:@"title"];
    _url = [c decodeObjectOfClass:[NSString class] forKey:@"url"];
    _dateAdded = [c decodeObjectOfClass:[NSDate class] forKey:@"dateAdded"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)c {
  [c encodeObject:_title forKey:@"title"];
  [c encodeObject:_url forKey:@"url"];
  [c encodeObject:_dateAdded forKey:@"dateAdded"];
}
@end

// ── BookmarkManager
// ───────────────────────────────────────────────────────────

@interface BookmarkManager ()
@property(strong) NSMutableArray<Bookmark *> *mutableBookmarks;
@end

@implementation BookmarkManager

+ (instancetype)shared {
  static BookmarkManager *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [BookmarkManager new];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _mutableBookmarks = [NSMutableArray new];
    [self load];
  }
  return self;
}

- (NSArray<Bookmark *> *)bookmarks {
  return _mutableBookmarks;
}

- (void)addBookmarkWithTitle:(NSString *)title url:(NSString *)url {
  if ([self isBookmarked:url])
    return;
  [_mutableBookmarks addObject:[[Bookmark alloc] initWithTitle:title url:url]];
  [self save];
}

- (void)removeBookmarkAtIndex:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)_mutableBookmarks.count)
    return;
  [_mutableBookmarks removeObjectAtIndex:index];
  [self save];
}

- (BOOL)isBookmarked:(NSString *)url {
  for (Bookmark *b in _mutableBookmarks)
    if ([b.url isEqualToString:url])
      return YES;
  return NO;
}

- (void)save {
  NSError *err;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_mutableBookmarks
                                       requiringSecureCoding:YES
                                                       error:&err];
  if (data)
    [data writeToFile:[self filePath] atomically:YES];
}

- (void)load {
  NSData *data = [NSData dataWithContentsOfFile:[self filePath]];
  if (!data)
    return;
  NSError *err;
  NSArray *arr =
      [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:[Bookmark class]
                                                fromData:data
                                                   error:&err];
  if (arr)
    [_mutableBookmarks addObjectsFromArray:arr];
}

- (NSString *)filePath {
  NSString *support = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  NSString *dir = [support stringByAppendingPathComponent:@"BuildBrowser"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return [dir stringByAppendingPathComponent:@"bookmarks.plist"];
}
@end
