#import "TBStore.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

NSString *const TBChanged = @"TBChanged";
NSString *TBRoot(void) { return @"/var/mobile/Media/Treble"; }

NSArray *TBPresetNames(void) {
    return @[@"Flat",@"Bass Boost",@"Bass Reducer",@"Treble Boost",@"Treble Reducer",@"Rock",@"Pop",@"Jazz",
             @"Classical",@"Vocal Boost",@"Electronic",@"Hip-Hop",@"Acoustic",@"Loudness",@"Late Night"];
}
NSArray *TBPresetGains(NSString *n) {
    static NSDictionary *d;
    if (!d) d = @{
        @"Flat":@[@0,@0,@0,@0,@0,@0,@0,@0,@0,@0],
        @"Bass Boost":@[@7,@6,@5,@3,@1,@0,@0,@0,@0,@0],
        @"Bass Reducer":@[@-6,@-5,@-4,@-2,@0,@0,@0,@0,@0,@0],
        @"Treble Boost":@[@0,@0,@0,@0,@0,@1,@3,@5,@6,@7],
        @"Treble Reducer":@[@0,@0,@0,@0,@0,@-1,@-3,@-5,@-6,@-7],
        @"Rock":@[@5,@4,@2,@-1,@-2,@-1,@2,@4,@5,@5],
        @"Pop":@[@-1,@1,@3,@4,@3,@0,@-1,@-1,@1,@2],
        @"Jazz":@[@3,@2,@1,@2,@-2,@-2,@0,@1,@2,@3],
        @"Classical":@[@4,@3,@2,@2,@-1,@-1,@0,@2,@3,@4],
        @"Vocal Boost":@[@-3,@-2,@-1,@1,@4,@4,@3,@1,@0,@-1],
        @"Electronic":@[@5,@4,@1,@0,@-2,@2,@1,@2,@4,@5],
        @"Hip-Hop":@[@5,@5,@2,@3,@-1,@-1,@2,@0,@2,@3],
        @"Acoustic":@[@4,@3,@2,@1,@2,@2,@3,@3,@3,@2],
        @"Loudness":@[@6,@4,@0,@0,@-1,@0,@0,@-1,@4,@2],
        @"Late Night":@[@-4,@-2,@0,@2,@3,@3,@2,@0,@-2,@-4]};
    return d[n];
}

@implementation TBStore { NSCache *_cache; int _uid; }

+ (TBStore *)shared {
    static TBStore *s; static dispatch_once_t o;
    dispatch_once(&o, ^{ s = [TBStore new]; [s load]; });
    return s;
}
- (NSString *)dataDir { return [TBRoot() stringByAppendingPathComponent:@".data"]; }

- (void)load {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *d in @[@"Inbox", @".data/art", @".data/covers"])
        [fm createDirectoryAtPath:[TBRoot() stringByAppendingPathComponent:d] withIntermediateDirectories:YES attributes:nil error:nil];
    _cache = [NSCache new];
    NSData *dt = [NSData dataWithContentsOfFile:[[self dataDir] stringByAppendingPathComponent:@"state.plist"]];
    NSDictionary *d = dt ? [NSPropertyListSerialization propertyListWithData:dt options:NSPropertyListMutableContainersAndLeaves format:NULL error:nil] : nil;
    self.songs  = d[@"songs"]  ?: [NSMutableDictionary dictionary];
    self.pls    = d[@"pls"]    ?: [NSMutableArray array];
    self.queue  = [NSMutableDictionary dictionaryWithObject:(d[@"queue"] ?: [NSMutableArray array]) forKey:@"ids"];
    self.plays  = d[@"plays"]  ?: [NSMutableDictionary dictionary];
    self.recent = d[@"recent"] ?: [NSMutableArray array];
    self.secs = [d[@"secs"] doubleValue];
    _uid = [d[@"uid"] intValue];
    self.impMode = [d[@"impMode"] intValue];
    self.impKind = d[@"impKind"] ?: @"music";
    self.eqOn = d[@"eqOn"] ? [d[@"eqOn"] boolValue] : YES;
    self.keepPitch = d[@"keep"] ? [d[@"keep"] boolValue] : YES;
    self.eqPreset = d[@"eqPreset"] ?: @"Flat";
    self.eqGains = d[@"eqGains"] ?: [TBPresetGains(@"Flat") mutableCopy];
    self.kind = @"all";
}

- (void)save {
    NSDictionary *d = @{@"songs":self.songs, @"pls":self.pls, @"queue":self.queue[@"ids"], @"plays":self.plays,
        @"recent":self.recent, @"secs":@(self.secs), @"uid":@(_uid), @"impMode":@(self.impMode), @"impKind":self.impKind,
        @"eqOn":@(self.eqOn), @"keep":@(self.keepPitch), @"eqPreset":self.eqPreset, @"eqGains":self.eqGains};
    [d writeToFile:[[self dataDir] stringByAppendingPathComponent:@"state.plist"] atomically:YES];
}

- (NSDictionary *)song:(NSString *)sid { return sid ? self.songs[sid] : nil; }
- (NSString *)path:(NSDictionary *)s { return [[TBRoot() stringByAppendingPathComponent:@"Inbox"] stringByAppendingPathComponent:s[@"path"]]; }

- (NSArray *)allIds {
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *k in self.songs)
        if ([self.kind isEqualToString:@"all"] || [self.songs[k][@"kind"] isEqualToString:self.kind]) [a addObject:k];
    return a;
}

- (NSArray *)sorted:(NSArray *)ids by:(NSString *)k {
    if (!k.length || [k isEqualToString:@"custom"]) return ids;
    return [ids sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSDictionary *x = self.songs[a], *y = self.songs[b];
        if ([k isEqualToString:@"added"]) return [y[@"added"] compare:x[@"added"]];
        if ([k isEqualToString:@"year"])  return [y[@"year"] compare:x[@"year"]];
        return [x[k] localizedCaseInsensitiveCompare:y[k]];
    }];
}

- (NSMutableDictionary *)newPlaylistNamed:(NSString *)n ids:(NSArray *)ids kind:(NSString *)k {
    NSMutableDictionary *p = [@{@"id":[NSString stringWithFormat:@"p%d", __sync_add_and_fetch(&_uid, 1)],
        @"name":n ?: @"", @"desc":@"", @"cover":@"", @"kind":k ?: @"music",
        @"added":@([[NSDate date] timeIntervalSince1970]), @"sort":@"custom",
        @"ids":(ids ? [ids mutableCopy] : [NSMutableArray array])} mutableCopy];
    [self.pls addObject:p]; [self save];
    return p;
}

- (void)deleteSong:(NSString *)sid {
    NSDictionary *s = self.songs[sid]; if (!s) return;
    [[NSFileManager defaultManager] removeItemAtPath:[self path:s] error:nil];
    [self.songs removeObjectForKey:sid];
    [self.queue[@"ids"] removeObject:sid];
    for (NSMutableDictionary *p in self.pls) [p[@"ids"] removeObject:sid];
    [self.recent removeObject:sid]; [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBChanged object:nil];
}

#pragma mark images
- (UIImage *)placeholder {
    static UIImage *p;
    if (!p) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(60,60), YES, 2);
        [[UIColor colorWithRed:.72 green:.76 blue:.82 alpha:1] setFill]; UIRectFill(CGRectMake(0,0,60,60));
        [[UIColor whiteColor] set];
        [@"♪" drawInRect:CGRectMake(0,8,60,50) withFont:[UIFont boldSystemFontOfSize:34] lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        p = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    }
    return p;
}
- (UIImage *)thumbForSong:(NSDictionary *)s {
    if (!s) return [self placeholder];
    NSString *k = s[@"id"]; UIImage *i = [_cache objectForKey:k]; if (i) return i;
    NSData *d = [NSData dataWithContentsOfFile:[[[self dataDir] stringByAppendingPathComponent:@"art"] stringByAppendingPathComponent:[k stringByAppendingString:@".jpg"]]];
    i = d ? [UIImage imageWithData:d scale:2] : nil;
    if (!i) i = [self placeholder];
    [_cache setObject:i forKey:k]; return i;
}
- (UIImage *)thumbForPlaylist:(NSDictionary *)p {
    if ([p[@"cover"] length]) {
        NSData *d = [NSData dataWithContentsOfFile:[[[self dataDir] stringByAppendingPathComponent:@"covers"] stringByAppendingPathComponent:[p[@"id"] stringByAppendingString:@".jpg"]]];
        UIImage *i = d ? [UIImage imageWithData:d scale:2] : nil; if (i) return i;
    }
    NSArray *ids = p[@"ids"];
    return [self thumbForSong:ids.count ? self.songs[ids[0]] : nil];
}
- (void)saveCover:(UIImage *)im forPlaylist:(NSMutableDictionary *)p {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(120,120), YES, 2);
    CGFloat sc = MAX(120/im.size.width, 120/im.size.height), w = im.size.width*sc, h = im.size.height*sc;
    [im drawInRect:CGRectMake((120-w)/2,(120-h)/2,w,h)];
    UIImage *sm = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    [UIImageJPEGRepresentation(sm, .85) writeToFile:[[[self dataDir] stringByAppendingPathComponent:@"covers"] stringByAppendingPathComponent:[p[@"id"] stringByAppendingString:@".jpg"]] atomically:YES];
    p[@"cover"] = @"1"; [self save];
}

#pragma mark scanning
- (NSMutableDictionary *)readSong:(NSString *)rel inbox:(NSString *)inbox {
    NSString *sid = [NSString stringWithFormat:@"s%d", __sync_add_and_fetch(&_uid, 1)];
    AVURLAsset *a = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:[inbox stringByAppendingPathComponent:rel]] options:nil];
    NSString *t = nil, *ar = nil, *al = nil; int yr = 0; NSData *art = nil;
    for (AVMetadataItem *i in a.commonMetadata) {
        NSString *k = i.commonKey;
        if ([k isEqualToString:AVMetadataCommonKeyTitle]) t = i.stringValue;
        else if ([k isEqualToString:AVMetadataCommonKeyArtist]) ar = i.stringValue;
        else if ([k isEqualToString:AVMetadataCommonKeyAlbumName]) al = i.stringValue;
        else if ([k isEqualToString:AVMetadataCommonKeyCreationDate]) { NSString *v = i.stringValue; if (v.length >= 4) yr = [[v substringToIndex:4] intValue]; }
        else if ([k isEqualToString:AVMetadataCommonKeyArtwork]) {
            id v = i.value;
            art = [v isKindOfClass:[NSData class]] ? v : ([v isKindOfClass:[NSDictionary class]] ? v[@"data"] : nil);
        }
    }
    double dur = CMTimeGetSeconds(a.duration); if (isnan(dur) || dur < 0) dur = 0;
    UIImage *im = art ? [UIImage imageWithData:art] : nil;
    if (im) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(60,60), YES, 2);
        [im drawInRect:CGRectMake(0,0,60,60)];
        UIImage *sm = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
        [UIImageJPEGRepresentation(sm, .8) writeToFile:[[[self dataDir] stringByAppendingPathComponent:@"art"] stringByAppendingPathComponent:[sid stringByAppendingString:@".jpg"]] atomically:NO];
    }
    NSString *fn = [[rel lastPathComponent] stringByDeletingPathExtension];
    NSString *kind = ([[rel pathExtension] caseInsensitiveCompare:@"m4b"] == NSOrderedSame) ? @"book" : self.impKind;
    return [@{@"id":sid, @"path":rel, @"title":t.length ? t : fn, @"artist":ar.length ? ar : @"Unknown Artist",
        @"album":al.length ? al : @"Unknown Album", @"year":@(yr), @"dur":@(dur),
        @"added":@([[NSDate date] timeIntervalSince1970]), @"kind":kind, @"rate":@1.0} mutableCopy];
}

- (void)scan {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *inbox = [TBRoot() stringByAppendingPathComponent:@"Inbox"];
        NSMutableSet *known = [NSMutableSet set];
        for (NSDictionary *s in [self.songs allValues]) [known addObject:s[@"path"]];
        NSSet *ext = [NSSet setWithObjects:@"mp3",@"m4a",@"m4b",@"aac",@"wav",@"aif",@"aiff",@"caf",@"mp4",nil];
        NSMutableArray *files = [NSMutableArray array];
        for (NSString *rel in [fm enumeratorAtPath:inbox])
            if ([ext containsObject:[[rel pathExtension] lowercaseString]] && ![known containsObject:rel]) [files addObject:rel];
        [files sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            return [a compare:b options:NSNumericSearch | NSCaseInsensitiveSearch]; }];
        NSMutableArray *fresh = [NSMutableArray array];
        for (NSString *rel in files) [fresh addObject:[self readSong:rel inbox:inbox]];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary *groups = [NSMutableDictionary dictionary]; NSMutableArray *order = [NSMutableArray array];
            for (NSMutableDictionary *s in fresh) {
                self.songs[s[@"id"]] = s;
                NSArray *c = [s[@"path"] pathComponents];
                if (c.count > 1 && self.impMode == 0) {
                    NSString *f = c[0];
                    if (!groups[f]) { groups[f] = [NSMutableArray array]; [order addObject:f]; }
                    [groups[f] addObject:s[@"id"]];
                }
            }
            for (NSString *f in order) [self newPlaylistNamed:@"" ids:groups[f] kind:self.impKind];
            [self save];
            [[NSNotificationCenter defaultCenter] postNotificationName:TBChanged object:nil];
        });
    });
}
@end
