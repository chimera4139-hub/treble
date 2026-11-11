#import "Screens.h"
#import "TBStore.h"
#import "TBPlayer.h"
#import <QuartzCore/QuartzCore.h>

#define ST [TBStore shared]
#define PL [TBPlayer shared]

static NSArray *KINDS(void) { return @[@"all", @"music", @"podcast", @"book"]; }
static NSString *PlName(NSDictionary *p) { return [p[@"name"] length] ? p[@"name"] : @"Untitled Playlist"; }

#pragma mark helpers
void TBToast(NSString *m) {
    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(30, 70, 260, 30)];
    l.text = m; l.textAlignment = NSTextAlignmentCenter; l.textColor = [UIColor whiteColor];
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:.8]; l.font = [UIFont systemFontOfSize:13];
    l.layer.cornerRadius = 8; l.clipsToBounds = YES; [w addSubview:l];
    [UIView animateWithDuration:.4 delay:1.3 options:0 animations:^{ l.alpha = 0; } completion:^(BOOL f) { [l removeFromSuperview]; }];
}

@interface TBSheet : NSObject <UIActionSheetDelegate>
@property (copy) void (^h)(NSInteger);
@end
static NSMutableArray *sheets;
@implementation TBSheet
- (void)actionSheet:(UIActionSheet *)a clickedButtonAtIndex:(NSInteger)i {
    if (i != a.cancelButtonIndex && self.h) self.h(i);
    [sheets removeObject:self];
}
@end
static void Sheet(NSString *t, NSArray *b, void (^h)(NSInteger)) {
    if (!sheets) sheets = [NSMutableArray array];
    TBSheet *s = [TBSheet new]; s.h = h; [sheets addObject:s];
    UIActionSheet *a = [[UIActionSheet alloc] initWithTitle:t delegate:s cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSString *x in b) [a addButtonWithTitle:x];
    a.cancelButtonIndex = [a addButtonWithTitle:@"Cancel"];
    [a showInView:[UIApplication sharedApplication].keyWindow];
}

static void SongMenu(NSString *sid) {
    NSDictionary *s = [ST song:sid]; if (!s) return;
    Sheet(s[@"title"], @[@"Play Next", @"Add to Queue", @"Add to Playlist…",
        [NSString stringWithFormat:@"Type: %@ (tap to change)", s[@"kind"]], @"Delete Song File"], ^(NSInteger i) {
        NSMutableDictionary *m = ST.songs[sid];
        if (i == 0) { [PL enqueue:sid atFront:YES]; TBToast(@"Playing next"); }
        else if (i == 1) { [PL enqueue:sid atFront:NO]; TBToast(@"Added to queue"); }
        else if (i == 2) {
            NSMutableArray *names = [NSMutableArray arrayWithObject:@"＋ New Playlist"];
            for (NSDictionary *p in ST.pls) [names addObject:PlName(p)];
            Sheet(@"Add to Playlist", names, ^(NSInteger j) {
                NSMutableDictionary *p = j == 0 ? [ST newPlaylistNamed:@"" ids:nil kind:m[@"kind"]] : ST.pls[j - 1];
                [p[@"ids"] addObject:sid]; [ST save]; TBToast(@"Added to playlist");
                [[NSNotificationCenter defaultCenter] postNotificationName:TBChanged object:nil];
            });
        }
        else if (i == 3) {
            NSArray *k = @[@"music", @"podcast", @"book"];
            m[@"kind"] = k[([k indexOfObject:m[@"kind"]] + 1) % 3]; [ST save];
            [[NSNotificationCenter defaultCenter] postNotificationName:TBChanged object:nil];
        }
        else if (i == 4) { if ([PL.curId isEqual:sid] && PL.playing) [PL toggle]; [ST deleteSong:sid]; }
    });
}

static NSString *Mins(double s) { int t = (int)s; return [NSString stringWithFormat:@"%d:%02d", t / 60, t % 60]; }

#pragma mark base
@class NowPlayingVC, DetailsVC, SongsVC;
@interface TBBase : UITableViewController {
    UISegmentedControl *_seg;
}
@property BOOL wantsKind;
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip;
- (UITableViewCell *)songCell:(NSString *)sid;
- (UITableViewCell *)plCell:(NSDictionary *)p;
- (void)refresh;
@end

@interface NowPlayingVC : UIViewController {
    UIImageView *_art; UILabel *_t, *_a, *_el, *_rm, *_rv; UISlider *_seek, *_spd; UIButton *_pp, *_sh, *_rp, *_kp; NSTimer *_tm;
}
@end

@implementation TBBase
- (id)init { return [super initWithStyle:UITableViewStylePlain]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 60;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:TBChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:TBPlayerChanged object:nil];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Playing" style:UIBarButtonItemStyleBordered target:self action:@selector(openNP)];
    UISwipeGestureRecognizer *g = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipe:)];
    g.direction = UISwipeGestureRecognizerDirectionRight; [self.tableView addGestureRecognizer:g];
    if (self.wantsKind) {
        _seg = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Music", @"Podcasts", @"Audiobooks"]];
        _seg.segmentedControlStyle = UISegmentedControlStyleBar;
        _seg.frame = CGRectMake(8, 7, 304, 30);
        [_seg addTarget:self action:@selector(kindChanged:) forControlEvents:UIControlEventValueChanged];
        UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)]; [h addSubview:_seg];
        self.tableView.tableHeaderView = h;
    }
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; _seg.selectedSegmentIndex = [KINDS() indexOfObject:ST.kind]; [self refresh]; }
- (void)kindChanged:(UISegmentedControl *)s { ST.kind = KINDS()[s.selectedSegmentIndex]; [self refresh]; }
- (void)refresh { [self.tableView reloadData]; }
- (void)openNP {
    if (!PL.curId) { TBToast(@"Nothing playing"); return; }
    [self presentViewController:[NowPlayingVC new] animated:YES completion:nil];
}
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip { return nil; }
- (void)swipe:(UISwipeGestureRecognizer *)g {
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:[g locationInView:self.tableView]];
    NSString *sid = ip ? [self songIdAtIndexPath:ip] : nil;
    if (sid) { [PL enqueue:sid atFront:NO]; TBToast([NSString stringWithFormat:@"Queued: %@", [ST song:sid][@"title"]]); }
}
- (UITableViewCell *)songCell:(NSString *)sid {
    UITableViewCell *c = [self.tableView dequeueReusableCellWithIdentifier:@"s"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"s"];
        c.textLabel.font = [UIFont boldSystemFontOfSize:17]; c.detailTextLabel.font = [UIFont systemFontOfSize:14];
    }
    NSDictionary *s = [ST song:sid];
    c.imageView.image = [ST thumbForSong:s];
    c.textLabel.text = s[@"title"];
    c.detailTextLabel.text = s ? [NSString stringWithFormat:@"%@ — %@", s[@"artist"], s[@"album"]] : @"";
    c.textLabel.textColor = [sid isEqual:PL.curId] ? [UIColor colorWithRed:.15 green:.4 blue:.8 alpha:1] : [UIColor darkGrayColor];
    c.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    return c;
}
- (UITableViewCell *)plCell:(NSDictionary *)p {
    UITableViewCell *c = [self.tableView dequeueReusableCellWithIdentifier:@"p"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"p"];
        c.textLabel.font = [UIFont boldSystemFontOfSize:17]; c.detailTextLabel.font = [UIFont systemFontOfSize:14];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    c.imageView.image = [ST thumbForPlaylist:p];
    c.textLabel.text = PlName(p);
    c.textLabel.textColor = [p[@"name"] length] ? [UIColor darkGrayColor] : [UIColor colorWithRed:.75 green:.2 blue:.2 alpha:1];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%d songs · %@", (int)[p[@"ids"] count], p[@"kind"]];
    return c;
}
- (void)tableView:(UITableView *)tv accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)ip {
    NSString *sid = [self songIdAtIndexPath:ip]; if (sid) SongMenu(sid);
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

#pragma mark songs list (songs / album / artist / playlist / queue)
@interface DetailsVC : UITableViewController <UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    NSMutableDictionary *_p; UITextField *_n, *_d;
}
- (id)initWithPlaylist:(NSMutableDictionary *)p;
@end

@interface SongsVC : TBBase {
    NSArray *(^_src)(void); NSMutableDictionary *_pl; BOOL _letters, _isQueue;
    NSArray *_ids, *_secs, *_lets; NSString *_sort; UIBarButtonItem *_edit;
}
- (id)initTitle:(NSString *)t src:(NSArray *(^)(void))s pl:(NSMutableDictionary *)p letters:(BOOL)l;
@end

@implementation SongsVC
- (id)initTitle:(NSString *)t src:(NSArray *(^)(void))s pl:(NSMutableDictionary *)p letters:(BOOL)l {
    self = [super init]; self.title = t; _src = s; _pl = p; _letters = l; _isQueue = (p == ST.queue);
    _sort = @"title"; self.wantsKind = (!p && l);
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NSMutableArray *bs = [NSMutableArray array];
    if (_pl) { _edit = [[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStyleBordered target:self action:@selector(toggleEdit)]; [bs addObject:_edit]; }
    if (!_isQueue) [bs addObject:[[UIBarButtonItem alloc] initWithTitle:@"Sort" style:UIBarButtonItemStyleBordered target:self action:@selector(pickSort)]];
    if (_isQueue) [bs addObject:[[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStyleBordered target:self action:@selector(clearQ)]];
    self.navigationItem.rightBarButtonItems = bs;
}
- (void)clearQ { [ST.queue[@"ids"] removeAllObjects]; [ST save]; [self refresh]; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (_pl && !_isQueue) [self buildHeader]; }
- (void)rebuild {
    if (_pl) {
        NSString *k = _pl[@"sort"]; _sort = k;
        NSArray *base = _pl[@"ids"];
        _ids = (!k.length || [k isEqual:@"custom"] || self.tableView.editing) ? base : [ST sorted:base by:k];
    } else _ids = [ST sorted:_src() by:_sort];
    if (_letters && [@[@"title", @"artist", @"album"] containsObject:_sort]) {
        NSMutableArray *S = [NSMutableArray array], *L = [NSMutableArray array]; NSString *last = nil;
        for (NSString *i in _ids) {
            NSString *v = [ST song:i][_sort]; NSString *c = v.length ? [[v substringToIndex:1] uppercaseString] : @"#";
            unichar ch = [c characterAtIndex:0]; if (!(ch >= 'A' && ch <= 'Z')) c = @"#";
            if (![c isEqualToString:last]) { [L addObject:c]; [S addObject:[NSMutableArray array]]; last = c; }
            [[S lastObject] addObject:i];
        }
        _secs = S; _lets = L;
    } else { _secs = @[_ids]; _lets = nil; }
}
- (void)refresh { [self rebuild]; [self.tableView reloadData]; }
- (void)pickSort {
    NSArray *k = @[@"custom", @"title", @"artist", @"album", @"added", @"year"];
    NSArray *n = @[@"Custom Order", @"Title", @"Artist", @"Album", @"Recently Added", @"Date Released"];
    if (!_pl) { k = [k subarrayWithRange:NSMakeRange(1, 5)]; n = [n subarrayWithRange:NSMakeRange(1, 5)]; }
    Sheet(@"Sort by", n, ^(NSInteger i) { if (_pl) _pl[@"sort"] = k[i]; else _sort = k[i]; [ST save]; [self refresh]; });
}
- (void)toggleEdit {
    BOOL e = !self.tableView.editing;
    if (e && _pl && !_isQueue) _pl[@"sort"] = @"custom";
    [self.tableView setEditing:e animated:YES];
    _edit.title = e ? @"Done" : @"Edit"; _edit.style = e ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
    [self refresh];
}
- (void)buildHeader {
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 90, 90)]; iv.image = [ST thumbForPlaylist:_pl]; [h addSubview:iv];
    UILabel *n = [[UILabel alloc] initWithFrame:CGRectMake(110, 8, 200, 26)]; n.font = [UIFont boldSystemFontOfSize:19]; n.text = PlName(_pl); n.backgroundColor = [UIColor clearColor]; [h addSubview:n];
    UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(110, 36, 200, 44)]; d.numberOfLines = 3; d.font = [UIFont systemFontOfSize:13]; d.textColor = [UIColor grayColor];
    d.backgroundColor = [UIColor clearColor]; d.text = [_pl[@"desc"] length] ? _pl[@"desc"] : @"No description"; [h addSubview:d];
    UILabel *c = [[UILabel alloc] initWithFrame:CGRectMake(110, 82, 200, 18)]; c.font = [UIFont systemFontOfSize:12]; c.textColor = [UIColor grayColor]; c.backgroundColor = [UIColor clearColor];
    c.text = [NSString stringWithFormat:@"%d songs", (int)[_pl[@"ids"] count]]; [h addSubview:c];
    NSArray *t = @[@"Play", @"Shuffle", @"Add All to Queue"]; SEL s[] = {@selector(playAll), @selector(shufAll), @selector(queueAll)};
    for (int i = 0; i < 3; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeRoundedRect]; b.frame = CGRectMake(10 + i * 100, 108, i == 2 ? 110 : 92, 30);
        b.frame = CGRectMake(i == 0 ? 10 : (i == 1 ? 82 : 156), 108, i == 2 ? 154 : 66, 30);
        [b setTitle:t[i] forState:UIControlStateNormal]; b.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [b addTarget:self action:s[i] forControlEvents:UIControlEventTouchUpInside]; [h addSubview:b];
    }
    UIButton *e = [UIButton buttonWithType:UIButtonTypeRoundedRect]; e.frame = CGRectMake(10, 142, 300, 30);
    [e setTitle:@"Edit Details (name, description, cover art)" forState:UIControlStateNormal]; e.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [e addTarget:self action:@selector(details) forControlEvents:UIControlEventTouchUpInside]; [h addSubview:e];
    self.tableView.tableHeaderView = h;
}
- (void)playAll { if (_ids.count) [PL play:_ids[0] inList:_ids]; }
- (void)shufAll { if (_ids.count) { PL.shuffle = YES; [PL play:_ids[arc4random() % _ids.count] inList:_ids]; } }
- (void)queueAll { for (NSString *i in _ids) [PL enqueue:i atFront:NO]; TBToast([NSString stringWithFormat:@"Added %d songs to queue", (int)_ids.count]); }
- (void)details { [self.navigationController pushViewController:[[DetailsVC alloc] initWithPlaylist:_pl] animated:YES]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _secs.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [_secs[s] count]; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return _lets ? _lets[s] : nil; }
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tv { return _lets; }
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip { return _secs[ip.section][ip.row]; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip { return [self songCell:[self songIdAtIndexPath:ip]]; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSString *sid = [self songIdAtIndexPath:ip];
    if (_isQueue) { [ST.queue[@"ids"] removeObject:sid]; [ST save]; }
    [PL play:sid inList:_isQueue ? @[sid] : _ids];
}
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return _pl != nil; }
- (BOOL)tableView:(UITableView *)tv canMoveRowAtIndexPath:(NSIndexPath *)ip { return _pl && tv.editing; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)es forRowAtIndexPath:(NSIndexPath *)ip {
    [_pl[@"ids"] removeObject:[self songIdAtIndexPath:ip]]; [ST save]; [self refresh];
}
- (void)tableView:(UITableView *)tv moveRowAtIndexPath:(NSIndexPath *)f toIndexPath:(NSIndexPath *)t {
    NSMutableArray *a = _pl[@"ids"]; id o = a[f.row]; [a removeObjectAtIndex:f.row]; [a insertObject:o atIndex:t.row]; [ST save];
}
@end

#pragma mark groups (artists / albums)
@interface GroupsVC : TBBase { NSString *_f; NSArray *_names, *_lets, *_secs; NSDictionary *_info; }
- (id)initField:(NSString *)f;
@end
@implementation GroupsVC
- (id)initField:(NSString *)f { self = [super init]; _f = f; self.title = [f isEqual:@"artist"] ? @"Artists" : @"Albums"; self.wantsKind = YES; return self; }
- (void)refresh {
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    for (NSString *i in [ST allIds]) {
        NSDictionary *s = ST.songs[i]; NSString *n = s[_f]; NSMutableDictionary *g = m[n];
        if (!g) { g = [@{@"n":@0, @"s":s} mutableCopy]; m[n] = g; }
        g[@"n"] = @([g[@"n"] intValue] + 1);
    }
    _info = m;
    NSArray *names = [[m allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableArray *S = [NSMutableArray array], *L = [NSMutableArray array]; NSString *last = nil;
    for (NSString *n in names) {
        NSString *c = n.length ? [[n substringToIndex:1] uppercaseString] : @"#"; unichar ch = [c characterAtIndex:0]; if (!(ch >= 'A' && ch <= 'Z')) c = @"#";
        if (![c isEqualToString:last]) { [L addObject:c]; [S addObject:[NSMutableArray array]]; last = c; }
        [[S lastObject] addObject:n];
    }
    _secs = S; _lets = L; [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _secs.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [_secs[s] count]; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return _lets[s]; }
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tv { return _lets; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"g"];
    if (!c) { c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"g"]; c.textLabel.font = [UIFont boldSystemFontOfSize:17]; c.detailTextLabel.font = [UIFont systemFontOfSize:14]; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    NSString *n = _secs[ip.section][ip.row]; NSDictionary *g = _info[n];
    c.imageView.image = [ST thumbForSong:g[@"s"]]; c.textLabel.text = n; c.textLabel.textColor = [UIColor darkGrayColor];
    c.detailTextLabel.text = [_f isEqual:@"album"] ? g[@"s"][@"artist"] : [NSString stringWithFormat:@"%@ songs", g[@"n"]];
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSString *n = _secs[ip.section][ip.row], *f = _f;
    SongsVC *v = [[SongsVC alloc] initTitle:n src:^NSArray *{
        NSMutableArray *a = [NSMutableArray array];
        for (NSString *i in [ST allIds]) if ([ST.songs[i][f] isEqual:n]) [a addObject:i];
        return a; } pl:nil letters:NO];
    [self.navigationController pushViewController:v animated:YES];
}
@end

#pragma mark home / search / library / playlists / create / more
@interface HomeVC : TBBase { NSArray *_rec, *_add; } @end
@implementation HomeVC
- (id)init { self = [super init]; self.title = @"Home"; self.wantsKind = YES; return self; }
- (void)refresh {
    NSMutableArray *r = [NSMutableArray array];
    for (NSString *i in ST.recent) { NSDictionary *s = ST.songs[i]; if (s && ([ST.kind isEqual:@"all"] || [s[@"kind"] isEqual:ST.kind]) && r.count < 5) [r addObject:i]; }
    _rec = r; _add = [[ST sorted:[ST allIds] by:@"added"] subarrayWithRange:NSMakeRange(0, MIN(5, [ST allIds].count))];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @[@"Listening Stats", @"Recently Listened To", @"Recently Added", @"Playlists"][s]; }
- (NSArray *)plsFiltered { NSMutableArray *a = [NSMutableArray array]; for (NSDictionary *p in ST.pls) if ([ST.kind isEqual:@"all"] || [p[@"kind"] isEqual:ST.kind]) [a addObject:p]; return a; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 1 : s == 1 ? _rec.count : s == 2 ? _add.count : [self plsFiltered].count; }
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip { return ip.section == 1 ? _rec[ip.row] : ip.section == 2 ? _add[ip.row] : nil; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 0 ? 56 : 60; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        int pc = 0; NSMutableDictionary *ar = [NSMutableDictionary dictionary]; NSString *best = nil;
        for (NSString *k in ST.plays) { int n = [ST.plays[k] intValue]; pc += n; NSString *a = ST.songs[k][@"artist"]; if (a) { ar[a] = @([ar[a] intValue] + n); if (!best || [ar[a] intValue] > [ar[best] intValue]) best = a; } }
        c.textLabel.text = [NSString stringWithFormat:@"%d plays · %d min · %d songs", pc, (int)(ST.secs / 60), (int)ST.songs.count];
        c.textLabel.font = [UIFont boldSystemFontOfSize:15]; c.detailTextLabel.text = [NSString stringWithFormat:@"Top artist: %@", best ?: @"—"];
        c.selectionStyle = UITableViewCellSelectionStyleNone; return c;
    }
    if (ip.section == 3) return [self plCell:[self plsFiltered][ip.row]];
    return [self songCell:[self songIdAtIndexPath:ip]];
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 3) { NSMutableDictionary *p = [self plsFiltered][ip.row]; [self.navigationController pushViewController:[[SongsVC alloc] initTitle:PlName(p) src:nil pl:p letters:NO] animated:YES]; }
    else if (ip.section > 0) [PL play:[self songIdAtIndexPath:ip] inList:ip.section == 1 ? _rec : _add];
}
@end

@interface SearchVC : TBBase <UISearchBarDelegate> { NSArray *_s, *_p; } @end
@implementation SearchVC
- (id)init { self = [super init]; self.title = @"Search"; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    UISearchBar *b = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)]; b.delegate = self; b.placeholder = @"Songs, artists, albums, playlists";
    b.tintColor = [UIColor colorWithWhite:.7 alpha:1]; self.tableView.tableHeaderView = b;
}
- (void)searchBar:(UISearchBar *)b textDidChange:(NSString *)q {
    q = [q lowercaseString]; NSMutableArray *s = [NSMutableArray array], *p = [NSMutableArray array];
    if (q.length) {
        for (NSString *i in [ST allIds]) { NSDictionary *x = ST.songs[i]; NSString *h = [[NSString stringWithFormat:@"%@ %@ %@", x[@"title"], x[@"artist"], x[@"album"]] lowercaseString]; if ([h rangeOfString:q].location != NSNotFound) [s addObject:i]; }
        for (NSMutableDictionary *x in ST.pls) if ([[PlName(x) lowercaseString] rangeOfString:q].location != NSNotFound) [p addObject:x];
    }
    _s = s; _p = p; [self.tableView reloadData];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)b { [b resignFirstResponder]; }
- (void)refresh { [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return (s == 0 ? _p.count : _s.count) ? (s == 0 ? @"Playlists" : @"Songs") : nil; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? _p.count : _s.count; }
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip { return ip.section == 1 ? _s[ip.row] : nil; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 0 ? [self plCell:_p[ip.row]] : [self songCell:_s[ip.row]]; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) { NSMutableDictionary *p = _p[ip.row]; [self.navigationController pushViewController:[[SongsVC alloc] initTitle:PlName(p) src:nil pl:p letters:NO] animated:YES]; }
    else [PL play:_s[ip.row] inList:_s];
}
@end

@interface PlaylistsVC : TBBase @end
@implementation PlaylistsVC
- (id)init { self = [super init]; self.title = @"Playlists"; self.wantsKind = YES; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItems = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add)]];
}
- (void)add { [ST newPlaylistNamed:@"" ids:nil kind:[ST.kind isEqual:@"all"] ? @"music" : ST.kind]; [self refresh]; }
- (NSArray *)list { NSMutableArray *a = [NSMutableArray array]; for (NSMutableDictionary *p in ST.pls) if ([ST.kind isEqual:@"all"] || [p[@"kind"] isEqual:ST.kind]) [a addObject:p]; return a; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [self list].count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip { return [self plCell:[self list][ip.row]]; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSMutableDictionary *p = [self list][ip.row];
    [self.navigationController pushViewController:[[SongsVC alloc] initTitle:PlName(p) src:nil pl:p letters:NO] animated:YES];
}
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)es forRowAtIndexPath:(NSIndexPath *)ip {
    [ST.pls removeObject:[self list][ip.row]]; [ST save]; [self refresh];
}
@end

@interface MenuVC : TBBase { NSArray *_rows; } @end
@implementation MenuVC
- (id)initTitle:(NSString *)t rows:(NSArray *)r { self = [super init]; self.title = t; _rows = r; self.wantsKind = [t isEqual:@"Library"]; return self; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _rows.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"m"];
    if (!c) { c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"m"]; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; c.textLabel.font = [UIFont boldSystemFontOfSize:19]; }
    c.textLabel.text = _rows[ip.row]; NSString *r = _rows[ip.row];
    c.detailTextLabel.text = [r isEqual:@"Playlists"] ? [NSString stringWithFormat:@"%d", (int)ST.pls.count] : [r isEqual:@"Songs"] ? [NSString stringWithFormat:@"%d", (int)[ST allIds].count]
        : [r isEqual:@"Queue"] ? [NSString stringWithFormat:@"%d", (int)[ST.queue[@"ids"] count]] : [r isEqual:@"Equalizer"] ? (ST.eqOn ? ST.eqPreset : @"Off") : @"";
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES]; NSString *r = _rows[ip.row]; UIViewController *v = nil;
    if ([r isEqual:@"Playlists"]) v = [PlaylistsVC new];
    else if ([r isEqual:@"Songs"]) v = [[SongsVC alloc] initTitle:@"Songs" src:^NSArray *{ return [ST allIds]; } pl:nil letters:YES];
    else if ([r isEqual:@"Artists"]) v = [[GroupsVC alloc] initField:@"artist"];
    else if ([r isEqual:@"Albums"]) v = [[GroupsVC alloc] initField:@"album"];
    else if ([r isEqual:@"Queue"]) v = [[SongsVC alloc] initTitle:@"Queue" src:nil pl:ST.queue letters:NO];
    else if ([r isEqual:@"Equalizer"]) v = [NSClassFromString(@"EQVC") new];
    if (v) [self.navigationController pushViewController:v animated:YES];
}
@end

@interface CreateVC : TBBase @end
@implementation CreateVC
- (id)init { self = [super init]; self.title = @"Create"; return self; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Add to Library" : @"Import Settings"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return s == 0 ? @"Copy songs or folders to /var/mobile/Media/Treble/Inbox (SFTP, iFile, 3uTools, iFunBox), then tap Scan. A folder becomes one playlist (unnamed until you name it) when 'Folder = Playlist' is on." : nil;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 2 : 2; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (ip.section == 0) { c.textLabel.text = ip.row == 0 ? @"Scan Inbox for New Files" : @"New Playlist"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return c; }
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    UISegmentedControl *s = [[UISegmentedControl alloc] initWithItems:ip.row == 0 ? @[@"Folder = Playlist", @"Songs Only"] : @[@"Music", @"Podcast", @"Audiobook"]];
    s.frame = CGRectMake(8, 7, 284, 30); s.tag = ip.row;
    s.selectedSegmentIndex = ip.row == 0 ? ST.impMode : [@[@"music", @"podcast", @"book"] indexOfObject:ST.impKind];
    [s addTarget:self action:@selector(seg:) forControlEvents:UIControlEventValueChanged]; [c.contentView addSubview:s];
    return c;
}
- (void)seg:(UISegmentedControl *)s {
    if (s.tag == 0) ST.impMode = (int)s.selectedSegmentIndex; else ST.impKind = @[@"music", @"podcast", @"book"][s.selectedSegmentIndex];
    [ST save];
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 0) return;
    if (ip.row == 0) { [ST scan]; TBToast(@"Scanning…"); }
    else { NSMutableDictionary *p = [ST newPlaylistNamed:@"" ids:nil kind:ST.impKind]; [self.navigationController pushViewController:[[SongsVC alloc] initTitle:PlName(p) src:nil pl:p letters:NO] animated:YES]; }
}
@end

#pragma mark equalizer
@interface EQVC : UIViewController { UISlider *_sl[10]; UILabel *_gl[10]; UIButton *_pb; UISwitch *_sw; } @end
@implementation EQVC
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Equalizer"; self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(15, 14, 150, 27)]; l.text = @"Equalizer"; l.font = [UIFont boldSystemFontOfSize:17]; l.backgroundColor = [UIColor clearColor]; [self.view addSubview:l];
    _sw = [[UISwitch alloc] initWithFrame:CGRectMake(225, 14, 80, 27)]; _sw.on = ST.eqOn; [_sw addTarget:self action:@selector(sw) forControlEvents:UIControlEventValueChanged]; [self.view addSubview:_sw];
    _pb = [UIButton buttonWithType:UIButtonTypeRoundedRect]; _pb.frame = CGRectMake(15, 54, 290, 36); [_pb addTarget:self action:@selector(presets) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:_pb];
    NSArray *fq = @[@"32", @"64", @"125", @"250", @"500", @"1k", @"2k", @"4k", @"8k", @"16k"];
    for (int i = 0; i < 10; i++) {
        float x = 10 + i * 30.5;
        _gl[i] = [[UILabel alloc] initWithFrame:CGRectMake(x, 98, 30, 16)]; _gl[i].font = [UIFont systemFontOfSize:10]; _gl[i].textAlignment = NSTextAlignmentCenter; _gl[i].backgroundColor = [UIColor clearColor]; [self.view addSubview:_gl[i]];
        UISlider *s = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 190, 30)]; s.minimumValue = -12; s.maximumValue = 12; s.tag = i;
        s.transform = CGAffineTransformMakeRotation(-M_PI_2); s.center = CGPointMake(x + 15, 214);
        [s addTarget:self action:@selector(moved:) forControlEvents:UIControlEventValueChanged];
        [s addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.view addSubview:s]; _sl[i] = s;
        UILabel *f = [[UILabel alloc] initWithFrame:CGRectMake(x, 316, 30, 14)]; f.text = fq[i]; f.font = [UIFont systemFontOfSize:10]; f.textAlignment = NSTextAlignmentCenter; f.backgroundColor = [UIColor clearColor]; [self.view addSubview:f];
    }
    [self sync];
}
- (void)sync { for (int i = 0; i < 10; i++) { float g = [ST.eqGains[i] floatValue]; _sl[i].value = g; _gl[i].text = [NSString stringWithFormat:@"%+d", (int)g]; }
    [_pb setTitle:[NSString stringWithFormat:@"Preset: %@", ST.eqPreset] forState:UIControlStateNormal]; }
- (void)sw { ST.eqOn = _sw.on; [PL applyEQ]; [ST save]; }
- (void)moved:(UISlider *)s { int g = (int)roundf(s.value); ST.eqGains[s.tag] = @(g); ST.eqPreset = @"Custom"; _gl[s.tag].text = [NSString stringWithFormat:@"%+d", g]; [PL applyEQ];
    [_pb setTitle:@"Preset: Custom" forState:UIControlStateNormal]; }
- (void)done { [ST save]; }
- (void)presets {
    NSArray *n = TBPresetNames();
    Sheet(@"EQ Preset", n, ^(NSInteger i) { ST.eqPreset = n[i]; ST.eqGains = [TBPresetGains(n[i]) mutableCopy]; [PL applyEQ]; [ST save]; [self sync]; });
}
@end

#pragma mark details editor
@implementation DetailsVC
- (id)initWithPlaylist:(NSMutableDictionary *)p { self = [super initWithStyle:UITableViewStyleGrouped]; _p = p; self.title = @"Edit Details"; return self; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 3; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (ip.row == 2) { c.textLabel.text = @"Choose Cover Art from Photos…"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return c; }
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(12, 12, 280, 24)]; f.delegate = self; f.clearButtonMode = UITextFieldViewModeWhileEditing; f.returnKeyType = UIReturnKeyDone;
    f.placeholder = ip.row == 0 ? @"Playlist name" : @"Description"; f.text = _p[ip.row == 0 ? @"name" : @"desc"];
    if (ip.row == 0) _n = f; else _d = f; c.selectionStyle = UITableViewCellSelectionStyleNone; [c.contentView addSubview:f];
    return c;
}
- (BOOL)textFieldShouldReturn:(UITextField *)f { [f resignFirstResponder]; return YES; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.row != 2) return;
    UIImagePickerController *pk = [UIImagePickerController new]; pk.sourceType = UIImagePickerControllerSourceTypePhotoLibrary; pk.delegate = self;
    [self presentViewController:pk animated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)pk didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *im = info[UIImagePickerControllerOriginalImage]; if (im) [ST saveCover:im forPlaylist:_p];
    [self dismissViewControllerAnimated:YES completion:nil]; TBToast(@"Cover saved");
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)pk { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewWillDisappear:(BOOL)a {
    [super viewWillDisappear:a];
    if (_n) _p[@"name"] = _n.text ?: @""; if (_d) _p[@"desc"] = _d.text ?: @"";
    [ST save]; [[NSNotificationCenter defaultCenter] postNotificationName:TBChanged object:nil];
}
@end

#pragma mark now playing
@implementation NowPlayingVC
- (UIButton *)btn:(NSString *)t frame:(CGRect)f sel:(SEL)s size:(CGFloat)sz {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.frame = f; [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:sz]; [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; [b setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:b]; return b;
}
- (UILabel *)lab:(CGRect)f size:(CGFloat)sz bold:(BOOL)b align:(NSTextAlignment)a {
    UILabel *l = [[UILabel alloc] initWithFrame:f]; l.font = b ? [UIFont boldSystemFontOfSize:sz] : [UIFont systemFontOfSize:sz]; l.textColor = b ? [UIColor whiteColor] : [UIColor lightGrayColor];
    l.textAlignment = a; l.backgroundColor = [UIColor clearColor]; [self.view addSubview:l]; return l;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = [UIColor colorWithWhite:.1 alpha:1];
    [self btn:@"Done" frame:CGRectMake(10, 26, 70, 30) sel:@selector(close) size:16];
    [self btn:@"Queue" frame:CGRectMake(240, 26, 70, 30) sel:@selector(showQueue) size:16];
    _art = [[UIImageView alloc] initWithFrame:CGRectMake(70, 62, 180, 180)]; [self.view addSubview:_art];
    _t = [self lab:CGRectMake(20, 250, 280, 24) size:18 bold:YES align:NSTextAlignmentCenter];
    _a = [self lab:CGRectMake(20, 274, 280, 20) size:14 bold:NO align:NSTextAlignmentCenter];
    _seek = [[UISlider alloc] initWithFrame:CGRectMake(20, 302, 280, 20)]; [_seek addTarget:self action:@selector(seeked) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside]; [self.view addSubview:_seek];
    _el = [self lab:CGRectMake(20, 324, 60, 16) size:11 bold:NO align:NSTextAlignmentLeft];
    _rm = [self lab:CGRectMake(240, 324, 60, 16) size:11 bold:NO align:NSTextAlignmentRight];
    [self btn:@"◀◀" frame:CGRectMake(40, 346, 70, 44) sel:@selector(prev) size:24];
    _pp = [self btn:@"❚❚" frame:CGRectMake(125, 346, 70, 44) sel:@selector(pp) size:28];
    [self btn:@"▶▶" frame:CGRectMake(210, 346, 70, 44) sel:@selector(next) size:24];
    [self lab:CGRectMake(20, 402, 50, 20) size:12 bold:NO align:NSTextAlignmentLeft].text = @"Speed";
    _spd = [[UISlider alloc] initWithFrame:CGRectMake(68, 400, 160, 24)]; _spd.minimumValue = .5; _spd.maximumValue = 2; [_spd addTarget:self action:@selector(speed) forControlEvents:UIControlEventValueChanged]; [self.view addSubview:_spd];
    _rv = [self lab:CGRectMake(230, 402, 44, 20) size:12 bold:NO align:NSTextAlignmentCenter];
    [self btn:@"1×" frame:CGRectMake(276, 398, 34, 28) sel:@selector(speed1) size:14];
    _sh = [self btn:@"Shuffle" frame:CGRectMake(10, 436, 90, 30) sel:@selector(shuf) size:13];
    _rp = [self btn:@"Repeat" frame:CGRectMake(115, 436, 90, 30) sel:@selector(rep) size:13];
    _kp = [self btn:@"Keep Pitch" frame:CGRectMake(220, 436, 95, 30) sel:@selector(pitch) size:13];
    [self sync]; _tm = [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sync) name:TBPlayerChanged object:nil];
}
- (void)sync {
    NSDictionary *s = [ST song:PL.curId]; if (!s) return;
    _art.image = [ST thumbForSong:s]; _t.text = s[@"title"]; _a.text = [NSString stringWithFormat:@"%@ — %@", s[@"artist"], s[@"album"]];
    float r = [s[@"rate"] floatValue]; if (r < .5) r = 1; _spd.value = r; _rv.text = [NSString stringWithFormat:@"%.2f×", r];
    [_pp setTitle:PL.playing ? @"❚❚" : @"▶" forState:UIControlStateNormal];
    [_sh setTitleColor:PL.shuffle ? [UIColor colorWithRed:.3 green:.65 blue:1 alpha:1] : [UIColor grayColor] forState:UIControlStateNormal];
    [_rp setTitle:PL.repeat == 2 ? @"Repeat 1" : @"Repeat" forState:UIControlStateNormal];
    [_rp setTitleColor:PL.repeat ? [UIColor colorWithRed:.3 green:.65 blue:1 alpha:1] : [UIColor grayColor] forState:UIControlStateNormal];
    [_kp setTitleColor:ST.keepPitch ? [UIColor colorWithRed:.3 green:.65 blue:1 alpha:1] : [UIColor grayColor] forState:UIControlStateNormal];
}
- (void)tick { double d = PL.duration, p = PL.position; if (!_seek.tracking && d > 0) _seek.value = p / d; _el.text = Mins(p); _rm.text = [@"-" stringByAppendingString:Mins(MAX(0, d - p))]; }
- (void)seeked { [PL seek:_seek.value * PL.duration]; }
- (void)speed { float r = roundf(_spd.value * 20) / 20; _rv.text = [NSString stringWithFormat:@"%.2f×", r]; [PL setSpeed:r]; }
- (void)speed1 { _spd.value = 1; [self speed]; }
- (void)pp { [PL toggle]; } - (void)next { [PL next]; } - (void)prev { [PL prev]; }
- (void)shuf { PL.shuffle = !PL.shuffle; [self sync]; }
- (void)rep { PL.repeat = (PL.repeat + 1) % 3; [self sync]; }
- (void)pitch { ST.keepPitch = !ST.keepPitch; [ST save]; [PL applyRate]; [self sync]; }
- (void)close { [_tm invalidate]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)showQueue { [self close]; [[NSNotificationCenter defaultCenter] postNotificationName:@"TBShowQueue" object:nil]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

#pragma mark app shell
static UIImage *Icon(int k) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 2); CGContextRef c = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setStroke]; [[UIColor blackColor] setFill]; CGContextSetLineWidth(c, 2.5);
    if (k == 0) { CGContextMoveToPoint(c, 15, 4); CGContextAddLineToPoint(c, 27, 15); CGContextAddLineToPoint(c, 23, 15); CGContextAddLineToPoint(c, 23, 26); CGContextAddLineToPoint(c, 7, 26); CGContextAddLineToPoint(c, 7, 15); CGContextAddLineToPoint(c, 3, 15); CGContextClosePath(c); CGContextFillPath(c); }
    else if (k == 1) { CGContextStrokeEllipseInRect(c, CGRectMake(4, 4, 16, 16)); CGContextMoveToPoint(c, 18, 18); CGContextAddLineToPoint(c, 27, 27); CGContextStrokePath(c); }
    else if (k == 2) { [@"♫" drawInRect:CGRectMake(0, 0, 30, 30) withFont:[UIFont boldSystemFontOfSize:28] lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter]; }
    else if (k == 3) { CGContextMoveToPoint(c, 15, 5); CGContextAddLineToPoint(c, 15, 25); CGContextMoveToPoint(c, 5, 15); CGContextAddLineToPoint(c, 25, 15); CGContextStrokePath(c); }
    else { for (int i = 0; i < 3; i++) CGContextFillEllipseInRect(c, CGRectMake(3 + i * 9, 12, 6, 6)); }
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return im;
}

@interface TBTabs : UITabBarController @end
@implementation TBTabs
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents]; [self becomeFirstResponder];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showQueue) name:@"TBShowQueue" object:nil];
}
- (void)showQueue {
    self.selectedIndex = 4; UINavigationController *n = (UINavigationController *)self.selectedViewController; [n popToRootViewControllerAnimated:NO];
    [n pushViewController:[[SongsVC alloc] initTitle:@"Queue" src:nil pl:ST.queue letters:NO] animated:NO];
}
- (void)remoteControlReceivedWithEvent:(UIEvent *)e {
    if (e.type != UIEventTypeRemoteControl) return;
    switch (e.subtype) {
        case UIEventSubtypeRemoteControlTogglePlayPause: case UIEventSubtypeRemoteControlPlay: case UIEventSubtypeRemoteControlPause: [PL toggle]; break;
        case UIEventSubtypeRemoteControlNextTrack: [PL next]; break;
        case UIEventSubtypeRemoteControlPreviousTrack: [PL prev]; break;
        default: break;
    }
}
@end

void TBStyleAppearance(void) {
    UIColor *g = [UIColor colorWithWhite:.78 alpha:1];
    [[UINavigationBar appearance] setTintColor:g];
    [[UINavigationBar appearance] setTitleTextAttributes:@{UITextAttributeTextColor:[UIColor colorWithWhite:.3 alpha:1], UITextAttributeTextShadowColor:[UIColor whiteColor], UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0, 1)]}];
    [[UIBarButtonItem appearance] setTintColor:[UIColor colorWithWhite:.6 alpha:1]];
    [[UISegmentedControl appearance] setTintColor:[UIColor colorWithWhite:.6 alpha:1]];
}

UITabBarController *TBMakeTabs(void) {
    NSArray *roots = @[[HomeVC new], [SearchVC new],
        [[MenuVC alloc] initTitle:@"Library" rows:@[@"Playlists", @"Songs", @"Artists", @"Albums"]],
        [CreateVC new], [[MenuVC alloc] initTitle:@"More" rows:@[@"Equalizer", @"Queue"]]];
    NSArray *names = @[@"Home", @"Search", @"Library", @"Create", @"More"]; NSMutableArray *vcs = [NSMutableArray array];
    for (int i = 0; i < 5; i++) {
        UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:roots[i]];
        n.tabBarItem = [[UITabBarItem alloc] initWithTitle:names[i] image:Icon(i) tag:i]; [vcs addObject:n];
    }
    TBTabs *t = [TBTabs new]; t.viewControllers = vcs; return t;
}
