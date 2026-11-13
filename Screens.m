#import "Screens.h"
#import "TBStore.h"
#import "TBPlayer.h"
#import "TBTheme.h"
#import <QuartzCore/QuartzCore.h>

#define ST [TBStore shared]
#define PL [TBPlayer shared]
#define TH [TBTheme cur]
#define RGB(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define RGBA(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]

static NSArray *KINDS(void) { return @[@"all", @"music", @"podcast", @"book"]; }
static NSString *PlName(NSDictionary *p) { return [p[@"name"] length] ? p[@"name"] : @"Untitled Playlist"; }
static NSString *Mins(double s) { int t = (int)s; return [NSString stringWithFormat:@"%d:%02d", t / 60, t % 60]; }
static UIFont *F(NSString *n, CGFloat s, BOOL bold) {
    UIFont *f = n ? [UIFont fontWithName:n size:s] : nil;
    return f ?: (bold ? [UIFont boldSystemFontOfSize:s] : [UIFont systemFontOfSize:s]);
}

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

// ---- drawn glyphs (no text / emoji) ----
static void Tri(CGContextRef c, float a, float b, float d, float e, float f, float g) {
    CGContextMoveToPoint(c, a, b); CGContextAddLineToPoint(c, d, e); CGContextAddLineToPoint(c, f, g); CGContextClosePath(c); CGContextFillPath(c);
}
// 0 prev 1 next 2 play 3 pause 4 shuffle 5 repeat 6 repeat-one 7 queue 8 chevron-down 9 X 10 dots 11 chevron-right
static UIImage *Glyph(int k, CGFloat s, UIColor *col) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(c, s / 28.0, s / 28.0);
    [col setFill]; [col setStroke];
    CGContextSetLineWidth(c, 2.6); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
    switch (k) {
        case 0: CGContextFillRect(c, CGRectMake(3, 5, 4, 18)); Tri(c, 25, 5, 25, 23, 9, 14); break;
        case 1: Tri(c, 3, 5, 3, 23, 19, 14); CGContextFillRect(c, CGRectMake(21, 5, 4, 18)); break;
        case 2: Tri(c, 7, 3, 7, 25, 25, 14); break;
        case 3: CGContextFillRect(c, CGRectMake(6, 4, 6, 20)); CGContextFillRect(c, CGRectMake(16, 4, 6, 20)); break;
        case 4:
            CGContextMoveToPoint(c, 3, 8); CGContextAddLineToPoint(c, 10, 8); CGContextAddLineToPoint(c, 18, 20); CGContextAddLineToPoint(c, 21, 20); CGContextStrokePath(c); Tri(c, 21, 16, 21, 24, 26, 20);
            CGContextMoveToPoint(c, 3, 20); CGContextAddLineToPoint(c, 10, 20); CGContextAddLineToPoint(c, 18, 8); CGContextAddLineToPoint(c, 21, 8); CGContextStrokePath(c); Tri(c, 21, 4, 21, 12, 26, 8);
            break;
        case 5: case 6:
            CGContextMoveToPoint(c, 4, 13); CGContextAddLineToPoint(c, 4, 8); CGContextAddLineToPoint(c, 19, 8); CGContextStrokePath(c); Tri(c, 19, 4, 19, 12, 25, 8);
            CGContextMoveToPoint(c, 24, 15); CGContextAddLineToPoint(c, 24, 20); CGContextAddLineToPoint(c, 9, 20); CGContextStrokePath(c); Tri(c, 9, 16, 9, 24, 3, 20);
            if (k == 6) [@"1" drawInRect:CGRectMake(10, 8.5, 8, 11) withFont:[UIFont boldSystemFontOfSize:10] lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
            break;
        case 7:
            CGContextMoveToPoint(c, 3, 6); CGContextAddLineToPoint(c, 25, 6); CGContextMoveToPoint(c, 3, 13); CGContextAddLineToPoint(c, 25, 13);
            CGContextMoveToPoint(c, 3, 20); CGContextAddLineToPoint(c, 13, 20); CGContextStrokePath(c); Tri(c, 16, 16, 16, 25, 25, 20.5); break;
        case 8: CGContextMoveToPoint(c, 5, 10); CGContextAddLineToPoint(c, 14, 19); CGContextAddLineToPoint(c, 23, 10); CGContextStrokePath(c); break;
        case 10: for (int i = 0; i < 3; i++) CGContextFillEllipseInRect(c, CGRectMake(2.4 + i * 9, 11.4, 5.2, 5.2)); break;
        case 11: CGContextMoveToPoint(c, 10, 5); CGContextAddLineToPoint(c, 19, 14); CGContextAddLineToPoint(c, 10, 23); CGContextStrokePath(c); break;
        default: CGContextMoveToPoint(c, 7, 7); CGContextAddLineToPoint(c, 21, 21); CGContextMoveToPoint(c, 21, 7); CGContextAddLineToPoint(c, 7, 21); CGContextStrokePath(c); break;
    }
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return im;
}
static UIImage *PlayImg(BOOL playing, CGFloat s) {
    TBTheme *T = TH; int k = T.kind; UIColor *gc;
    switch (k) { case 1: gc = T.npText; break; case 2: gc = T.dark ? RGB(18, 18, 18) : [UIColor whiteColor]; break; case 3: gc = RGB(58, 36, 18); break; case 4: gc = RGB(10, 10, 10); break; default: gc = [UIColor whiteColor]; }
    UIImage *g = Glyph(playing ? 3 : 2, k == 1 ? s * .7 : s * .46, gc);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0); CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(2, 2, s - 4, s - 4);
    if (k == 0) { [[UIColor whiteColor] setStroke]; CGContextSetLineWidth(c, 2.5); CGContextStrokeEllipseInRect(c, r); }
    else if (k == 2) { [T.npText setFill]; CGContextFillEllipseInRect(c, r); }
    else if (k == 3) { [RGB(201, 162, 75) setFill]; CGContextFillEllipseInRect(c, r); [RGB(110, 80, 24) setStroke]; CGContextSetLineWidth(c, 3); CGContextStrokeEllipseInRect(c, CGRectInset(r, 1.5, 1.5)); }
    else if (k == 4) { [T.accent setFill]; CGContextFillRect(c, r); [RGB(10, 10, 10) setStroke]; CGContextSetLineWidth(c, 3); CGContextStrokeRect(c, CGRectInset(r, 1.5, 1.5)); }
    CGFloat gs = g.size.width; [g drawInRect:CGRectMake((s - gs) / 2 + (playing ? 0 : gs * .07), (s - gs) / 2, gs, gs)];
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return im;
}

static void SpeedSheet(NSString *sid) {
    NSDictionary *s = [ST song:sid]; if (!s) return;
    float cur = [s[@"rate"] floatValue]; if (cur < .5) cur = 1;
    NSArray *v = @[@0.5, @0.75, @0.9, @1.0, @1.1, @1.25, @1.5, @1.75, @2.0]; NSMutableArray *t = [NSMutableArray array];
    for (NSNumber *n in v) [t addObject:[NSString stringWithFormat:@"%@%.2f×", fabsf([n floatValue] - cur) < .01 ? @"● " : @"", [n floatValue]]];
    [t addObject:ST.keepPitch ? @"Keep Pitch: ON (tap to turn off)" : @"Keep Pitch: OFF (tap to turn on)"];
    Sheet([NSString stringWithFormat:@"Speed for this song: %@", s[@"title"]], t, ^(NSInteger i) {
        if (i < (NSInteger)v.count) [PL setSpeed:[v[i] floatValue] forSong:sid];
        else { ST.keepPitch = !ST.keepPitch; [ST save]; [PL applyRate]; }
    });
}
static void SleepSheet(void) {
    Sheet(@"Sleep Timer", @[@"Off", @"15 minutes", @"30 minutes", @"45 minutes", @"60 minutes", @"90 minutes"], ^(NSInteger i) {
        int m[] = {0, 15, 30, 45, 60, 90}; [PL setSleepMinutes:m[i]]; TBToast(i ? @"Sleep timer set" : @"Sleep timer off");
        [[NSNotificationCenter defaultCenter] postNotificationName:TBChanged object:nil];
    });
}
static void ThemeSheet(void) {
    NSMutableArray *n = [NSMutableArray array]; for (NSString *x in [TBTheme names]) [n addObject:x];
    Sheet(@"Theme", n, ^(NSInteger i) { ST.theme = (int)i; [ST save]; TBApplyTheme(YES); });
}
static void ModeSheet(void) {
    Sheet(@"Light / Dark", @[@"Light", @"Dark", @"Auto (dark 7pm–7am)"], ^(NSInteger i) { ST.mode = (int)i; [ST save]; TBApplyTheme(YES); });
}

static void SongMenu(NSString *sid) {
    NSDictionary *s = [ST song:sid]; if (!s) return;
    float r = [s[@"rate"] floatValue]; if (r < .5) r = 1;
    Sheet(s[@"title"], @[@"Play Next", @"Add to Queue", @"Add to Playlist…",
        [NSString stringWithFormat:@"Playback Speed: %.2f×…", r],
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
        else if (i == 3) SpeedSheet(sid);
        else if (i == 4) {
            NSArray *k = @[@"music", @"podcast", @"book"];
            m[@"kind"] = k[([k indexOfObject:m[@"kind"]] + 1) % 3]; [ST save];
            [[NSNotificationCenter defaultCenter] postNotificationName:TBChanged object:nil];
        }
        else if (i == 5) { if ([PL.curId isEqual:sid] && PL.playing) [PL toggle]; [ST deleteSong:sid]; }
    });
}

#pragma mark base
@class NowPlayingVC, DetailsVC, SongsVC, SettingsVC;
@interface TBBase : UITableViewController <UIGestureRecognizerDelegate> {
    UISegmentedControl *_seg; UIView *_chips; UIView *_swBg; UITableViewCell *_swCell; NSString *_swSid;
}
@property BOOL wantsKind;
@property (strong) UIView *extraHeader;
- (NSString *)bigTitle;
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip;
- (UITableViewCell *)songCell:(NSString *)sid;
- (UITableViewCell *)plCell:(NSDictionary *)p;
- (void)setAccessory:(UITableViewCell *)c glyph:(int)g action:(SEL)act;
- (void)refresh;
- (void)fixInset;
@end

@interface NowPlayingVC : UIViewController {
    UIImageView *_art; UIView *_wrap, *_hard; UILabel *_t, *_a, *_al, *_el, *_rm; UISlider *_seek;
    UIButton *_pp, *_sh, *_rp, *_spd, *_cl, *_qb; NSTimer *_tm; CAGradientLayer *_bgl;
}
@end

@implementation TBBase
- (id)init { return [super initWithStyle:UITableViewStylePlain]; }
- (NSString *)bigTitle { return self.title; }
- (void)viewDidLoad {
    [super viewDidLoad];
    TBTheme *T = TH;
    self.tableView.rowHeight = T.rowH; self.tableView.backgroundColor = T.bg; self.tableView.backgroundView = nil;
    self.tableView.separatorStyle = T.showSep ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = T.sep; self.tableView.sectionIndexColor = T.accent;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:TBChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerChanged) name:TBPlayerChanged object:nil];
    UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    p.delegate = self; [self.tableView addGestureRecognizer:p];
    [self buildTop];
}
- (void)buildTop {
    TBTheme *T = TH; CGFloat y = 0; UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 0)]; h.backgroundColor = [UIColor clearColor];
    BOOL large = T.largeTitle && self.navigationController.viewControllers.count <= 1;
    if (large) { UILabel *l = [T bigLabel:[self bigTitle]]; l.frame = CGRectMake(16, 2, 288, T.bigH); [h addSubview:l]; y = T.bigH + 4; self.navigationItem.title = @""; }
    if (self.extraHeader) { CGRect f = self.extraHeader.frame; f.origin.y = y; self.extraHeader.frame = f; [h addSubview:self.extraHeader]; y += f.size.height; }
    if (self.wantsKind) {
        if (T.kind == 0) {
            _seg = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Music", @"Podcasts", @"Audiobooks"]];
            _seg.segmentedControlStyle = UISegmentedControlStyleBar; _seg.frame = CGRectMake(8, y + 7, 304, 30);
            [_seg addTarget:self action:@selector(kindChanged:) forControlEvents:UIControlEventValueChanged]; [h addSubview:_seg]; y += 44;
        } else {
            _chips = [T chipBar:self action:@selector(chipTap:) selected:(int)[KINDS() indexOfObject:ST.kind]];
            CGRect f = _chips.frame; f.origin.y = y; _chips.frame = f; [h addSubview:_chips]; y += f.size.height;
        }
    }
    h.frame = CGRectMake(0, 0, 320, y); self.tableView.tableHeaderView = y > 0 ? h : nil;
}
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    int i = (int)[KINDS() indexOfObject:ST.kind]; _seg.selectedSegmentIndex = i; if (_chips) [TH selectChips:_chips index:i];
    if (TH.upper && self.title && self.navigationController.viewControllers.count > 1) self.navigationItem.title = [self.title uppercaseString];
    [self fixInset]; [self refresh];
}
- (void)fixInset { UIEdgeInsets e = UIEdgeInsetsMake(0, 0, PL.curId ? TH.miniInset : 0, 0); self.tableView.contentInset = e; self.tableView.scrollIndicatorInsets = e; }
- (void)playerChanged { [self fixInset]; if (self.tableView.editing) return; [self refresh]; }
- (void)kindChanged:(UISegmentedControl *)s { ST.kind = KINDS()[s.selectedSegmentIndex]; [self refresh]; }
- (void)chipTap:(UIButton *)b { ST.kind = KINDS()[b.tag]; [TH selectChips:_chips index:(int)b.tag]; [self refresh]; }
- (void)refresh { [self.tableView reloadData]; }
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip { return nil; }

// themed section headers / footers
- (NSString *)hdrTitle:(UITableView *)tv section:(NSInteger)s { return [self respondsToSelector:@selector(tableView:titleForHeaderInSection:)] ? [self tableView:tv titleForHeaderInSection:s] : nil; }
- (NSString *)ftrTitle:(UITableView *)tv section:(NSInteger)s { return [self respondsToSelector:@selector(tableView:titleForFooterInSection:)] ? [self tableView:tv titleForFooterInSection:s] : nil; }
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    if (!TH.customHeaders) return nil; NSString *t = [self hdrTitle:tv section:s]; return t.length ? [TH headerView:t] : nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
    NSString *t = [self hdrTitle:tv section:s];
    if (!t.length) return tv.style == UITableViewStyleGrouped ? 10 : 0.01;
    return TH.customHeaders ? TH.hdrH : (tv.style == UITableViewStyleGrouped ? 36 : 22);
}
- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)s {
    if (!TH.customHeaders) return nil; NSString *t = [self ftrTitle:tv section:s]; return t.length ? [TH footerView:t] : nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s {
    NSString *t = [self ftrTitle:tv section:s];
    if (t.length) return 44; return tv.style == UITableViewStyleGrouped ? 10 : 0.01;
}
- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip { [TH styleCell:c]; }

// swipe right = add to queue, with the row following your finger
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    if (![g isKindOfClass:[UIPanGestureRecognizer class]] || self.tableView.editing) return NO;
    UIPanGestureRecognizer *p = (UIPanGestureRecognizer *)g; CGPoint v = [p velocityInView:self.tableView];
    if (v.x <= 0 || fabs(v.x) < fabs(v.y) * 1.5) return NO;
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:[p locationInView:self.tableView]];
    return ip && [self songIdAtIndexPath:ip] != nil;
}
- (void)pan:(UIPanGestureRecognizer *)p {
    UITableView *tv = self.tableView; CGFloat dx = [p translationInView:tv].x;
    if (p.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *ip = [tv indexPathForRowAtPoint:[p locationInView:tv]];
        _swCell = ip ? [tv cellForRowAtIndexPath:ip] : nil; _swSid = ip ? [self songIdAtIndexPath:ip] : nil;
        if (!_swCell) return;
        _swBg = [[UIView alloc] initWithFrame:_swCell.frame]; _swBg.backgroundColor = TH.kind == 4 ? TH.accent : [UIColor colorWithRed:.2 green:.62 blue:.3 alpha:1];
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 200, _swCell.frame.size.height)]; l.text = @"＋  Add to Queue"; l.textColor = [UIColor whiteColor];
        l.font = [UIFont boldSystemFontOfSize:16]; l.backgroundColor = [UIColor clearColor]; l.tag = 77; [_swBg addSubview:l];
        [tv insertSubview:_swBg atIndex:0];
    } else if (p.state == UIGestureRecognizerStateChanged && _swCell) {
        _swCell.transform = CGAffineTransformMakeTranslation(MAX(0, MIN(dx, 150)), 0);
    } else if (_swCell && (p.state == UIGestureRecognizerStateEnded || p.state == UIGestureRecognizerStateCancelled)) {
        UITableViewCell *c = _swCell; UIView *bg = _swBg; NSString *sid = _swSid; _swCell = nil; _swBg = nil;
        BOOL ok = (p.state == UIGestureRecognizerStateEnded && dx > 70 && sid);
        if (ok) {
            [PL enqueue:sid atFront:NO]; [(UILabel *)[bg viewWithTag:77] setText:@"✓  Queued"];
            [UIView animateWithDuration:.15 animations:^{ c.transform = CGAffineTransformMakeTranslation(190, 0); } completion:^(BOOL f) {
                [UIView animateWithDuration:.35 delay:.1 options:UIViewAnimationOptionCurveEaseInOut animations:^{ c.transform = CGAffineTransformIdentity; } completion:^(BOOL f2) { [bg removeFromSuperview]; }];
            }];
        } else {
            [UIView animateWithDuration:.2 animations:^{ c.transform = CGAffineTransformIdentity; } completion:^(BOOL f) { [bg removeFromSuperview]; }];
        }
    }
}
- (void)moreTapped:(UIButton *)b {
    UIView *v = b; while (v && ![v isKindOfClass:[UITableViewCell class]]) v = v.superview;
    NSIndexPath *ip = v ? [self.tableView indexPathForCell:(UITableViewCell *)v] : nil;
    NSString *sid = ip ? [self songIdAtIndexPath:ip] : nil; if (sid) SongMenu(sid);
}
- (void)setAccessory:(UITableViewCell *)c glyph:(int)g action:(SEL)act {
    TBTheme *T = TH;
    if (T.kind == 0) { c.accessoryView = nil; c.accessoryType = act ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryDisclosureIndicator; return; }
    c.accessoryType = UITableViewCellAccessoryNone;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.frame = CGRectMake(0, 0, 40, 40);
    [b setImage:Glyph(g, 20, T.sub) forState:UIControlStateNormal];
    if (act) [b addTarget:self action:act forControlEvents:UIControlEventTouchUpInside]; else b.userInteractionEnabled = NO;
    c.accessoryView = b;
}
- (UITableViewCell *)songCell:(NSString *)sid {
    UITableViewCell *c = [self.tableView dequeueReusableCellWithIdentifier:@"s"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"s"];
    c.transform = CGAffineTransformIdentity;
    NSDictionary *s = [ST song:sid];
    c.imageView.image = [TH art:[ST thumbForSong:s]];
    c.textLabel.text = s[@"title"];
    c.detailTextLabel.text = s ? [NSString stringWithFormat:@"%@ — %@", s[@"artist"], s[@"album"]] : @"";
    c.tag = [sid isEqual:PL.curId] ? 2 : 0;
    [self setAccessory:c glyph:10 action:@selector(moreTapped:)];
    return c;
}
- (UITableViewCell *)plCell:(NSDictionary *)p {
    UITableViewCell *c = [self.tableView dequeueReusableCellWithIdentifier:@"p"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"p"];
    c.imageView.image = [TH art:[ST thumbForPlaylist:p]];
    c.textLabel.text = PlName(p); c.tag = [p[@"name"] length] ? 0 : 1;
    c.detailTextLabel.text = [NSString stringWithFormat:@"%d songs · %@", (int)[p[@"ids"] count], p[@"kind"]];
    [self setAccessory:c glyph:11 action:nil];
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
    TBTheme *T = TH;
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)]; h.backgroundColor = [UIColor clearColor];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 90, 90)]; iv.image = [ST thumbForPlaylist:_pl];
    if (T.kind == 3) { iv.layer.cornerRadius = 45; iv.clipsToBounds = YES; } else if (T.kind == 1 || T.kind == 2) { iv.layer.cornerRadius = T.kind == 1 ? 8 : 3; iv.clipsToBounds = YES; }
    if (T.kind == 4) { iv.layer.borderWidth = 3; iv.layer.borderColor = T.text.CGColor; }
    [h addSubview:iv];
    UILabel *n = [[UILabel alloc] initWithFrame:CGRectMake(110, 8, 200, 28)]; n.font = F(T.fHead, T.kind == 4 ? 24 : 19, YES); n.text = T.upper ? [PlName(_pl) uppercaseString] : PlName(_pl);
    n.textColor = T.kind == 3 ? T.hdrText : T.text; n.backgroundColor = [UIColor clearColor]; n.adjustsFontSizeToFitWidth = YES; n.minimumScaleFactor = .7; [h addSubview:n];
    UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(110, 38, 200, 44)]; d.numberOfLines = 3; d.font = T.subFont; d.textColor = T.kind == 3 ? RGB(214, 184, 130) : T.sub;
    d.backgroundColor = [UIColor clearColor]; d.text = [_pl[@"desc"] length] ? _pl[@"desc"] : @"No description"; [h addSubview:d];
    UILabel *c = [[UILabel alloc] initWithFrame:CGRectMake(110, 84, 200, 18)]; c.font = T.subFont; c.textColor = d.textColor; c.backgroundColor = [UIColor clearColor];
    c.text = [NSString stringWithFormat:@"%d songs", (int)[_pl[@"ids"] count]]; [h addSubview:c];
    NSArray *t = @[@"Play", @"Shuffle", @"Add All to Queue"]; SEL sel[] = {@selector(playAll), @selector(shufAll), @selector(queueAll)};
    for (int i = 0; i < 3; i++) {
        UIButton *b = [T button:t[i] primary:i == 0];
        b.frame = CGRectMake(i == 0 ? 10 : (i == 1 ? 82 : 156), 108, i == 2 ? 154 : 66, 30);
        [b addTarget:self action:sel[i] forControlEvents:UIControlEventTouchUpInside]; [h addSubview:b];
    }
    UIButton *e = [T button:@"Edit Details (name, description, cover art)" primary:NO]; e.frame = CGRectMake(10, 142, 300, 30);
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
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip { return ip.section < (NSInteger)_secs.count && ip.row < (NSInteger)[_secs[ip.section] count] ? _secs[ip.section][ip.row] : nil; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip { return [self songCell:[self songIdAtIndexPath:ip]]; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSString *sid = [self songIdAtIndexPath:ip]; if (!sid) return;
    if (_isQueue) { [ST.queue[@"ids"] removeObject:sid]; [ST save]; }
    [PL play:sid inList:_isQueue ? @[sid] : _ids];
}
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return _pl != nil && tv.editing; }
- (BOOL)tableView:(UITableView *)tv canMoveRowAtIndexPath:(NSIndexPath *)ip { return _pl && tv.editing; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)es forRowAtIndexPath:(NSIndexPath *)ip {
    [_pl[@"ids"] removeObject:[self songIdAtIndexPath:ip]]; [ST save]; [self refresh];
}
- (void)tableView:(UITableView *)tv moveRowAtIndexPath:(NSIndexPath *)f toIndexPath:(NSIndexPath *)t {
    NSMutableArray *a = _pl[@"ids"]; id o = a[f.row]; [a removeObjectAtIndex:f.row]; [a insertObject:o atIndex:t.row]; [ST save];
}
@end

#pragma mark groups (artists / albums)
@interface GroupsVC : TBBase { NSString *_f; NSArray *_lets, *_secs; NSDictionary *_info; }
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
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"g"];
    NSString *n = _secs[ip.section][ip.row]; NSDictionary *g = _info[n];
    c.imageView.image = [TH art:[ST thumbForSong:g[@"s"]]]; c.textLabel.text = n; c.tag = 0;
    c.detailTextLabel.text = [_f isEqual:@"album"] ? g[@"s"][@"artist"] : [NSString stringWithFormat:@"%@ songs", g[@"n"]];
    [self setAccessory:c glyph:11 action:nil];
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

#pragma mark home / search
@interface HomeVC : TBBase { NSArray *_rec, *_add; } @end
@implementation HomeVC
- (id)init { self = [super init]; self.title = @"Home"; self.wantsKind = YES; return self; }
- (NSString *)bigTitle {
    if (TH.kind != 2) return @"Home";
    NSInteger h = [[NSCalendar currentCalendar] components:NSHourCalendarUnit fromDate:[NSDate date]].hour;
    return h < 12 ? @"Good morning" : (h < 18 ? @"Good afternoon" : @"Good evening");
}
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
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 0 ? 56 : TH.rowH; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == 0) {
        UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        int pc = 0; NSMutableDictionary *ar = [NSMutableDictionary dictionary]; NSString *best = nil;
        for (NSString *k in ST.plays) { int n = [ST.plays[k] intValue]; pc += n; NSString *a = ST.songs[k][@"artist"]; if (a) { ar[a] = @([ar[a] intValue] + n); if (!best || [ar[a] intValue] > [ar[best] intValue]) best = a; } }
        c.textLabel.text = [NSString stringWithFormat:@"%d plays · %d min · %d songs", pc, (int)(ST.secs / 60), (int)ST.songs.count];
        c.detailTextLabel.text = [NSString stringWithFormat:@"Top artist: %@", best ?: @"—"];
        c.selectionStyle = UITableViewCellSelectionStyleNone; c.tag = 0; return c;
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

@interface SearchVC : TBBase <UISearchBarDelegate> { NSArray *_s, *_p; NSString *_q; UISearchBar *_bar; } @end
@implementation SearchVC
- (id)init { self = [super init]; self.title = @"Search"; _q = @""; return self; }
- (void)viewDidLoad {
    _bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)]; _bar.delegate = self; _bar.placeholder = @"Songs, artists, albums, playlists";
    [TH styleSearchBar:_bar]; self.extraHeader = _bar;
    [super viewDidLoad];
    UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKb)]; t.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:t];
}
- (void)dismissKb { [_bar resignFirstResponder]; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)sv { [_bar resignFirstResponder]; }
- (void)searchBarTextDidBeginEditing:(UISearchBar *)b { [b setShowsCancelButton:YES animated:YES]; }
- (void)searchBarTextDidEndEditing:(UISearchBar *)b { [b setShowsCancelButton:NO animated:YES]; }
- (void)searchBarCancelButtonClicked:(UISearchBar *)b { b.text = @""; [self searchBar:b textDidChange:@""]; [b resignFirstResponder]; }
- (void)remember:(NSString *)q {
    q = [q stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; if (q.length < 2) return;
    for (NSString *x in [ST.searches copy]) if ([x caseInsensitiveCompare:q] == NSOrderedSame) [ST.searches removeObject:x];
    [ST.searches insertObject:q atIndex:0]; while (ST.searches.count > 10) [ST.searches removeLastObject]; [ST save];
}
- (void)searchBar:(UISearchBar *)b textDidChange:(NSString *)q {
    _q = q ?: @""; NSString *l = [_q lowercaseString]; NSMutableArray *s = [NSMutableArray array], *p = [NSMutableArray array];
    if (l.length) {
        for (NSString *i in [ST allIds]) { NSDictionary *x = ST.songs[i]; NSString *h = [[NSString stringWithFormat:@"%@ %@ %@", x[@"title"], x[@"artist"], x[@"album"]] lowercaseString]; if ([h rangeOfString:l].location != NSNotFound) [s addObject:i]; }
        for (NSMutableDictionary *x in ST.pls) if ([[PlName(x) lowercaseString] rangeOfString:l].location != NSNotFound) [p addObject:x];
    }
    _s = s; _p = p; [self.tableView reloadData];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)b { [self remember:_q]; [b resignFirstResponder]; [self.tableView reloadData]; }
- (void)refresh { [self.tableView reloadData]; }
- (void)delRecent:(UIButton *)b { if (b.tag < (NSInteger)ST.searches.count) { [ST.searches removeObjectAtIndex:b.tag]; [ST save]; [self.tableView reloadData]; } }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _q.length ? 2 : 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (!_q.length) return ST.searches.count ? @"Recent Searches" : nil;
    return (s == 0 ? _p.count : _s.count) ? (s == 0 ? @"Playlists" : @"Songs") : nil;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (!_q.length) return ST.searches.count ? ST.searches.count + 1 : 0;
    return s == 0 ? _p.count : _s.count;
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return _q.length ? TH.rowH : 46; }
- (NSString *)songIdAtIndexPath:(NSIndexPath *)ip { return (_q.length && ip.section == 1) ? _s[ip.row] : nil; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (!_q.length) {
        UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        if (ip.row < (NSInteger)ST.searches.count) {
            c.textLabel.text = ST.searches[ip.row]; c.tag = 0;
            UIButton *x = [UIButton buttonWithType:UIButtonTypeCustom]; x.frame = CGRectMake(0, 0, 44, 44); x.tag = ip.row;
            [x setImage:Glyph(9, 18, TH.sub) forState:UIControlStateNormal]; [x addTarget:self action:@selector(delRecent:) forControlEvents:UIControlEventTouchUpInside];
            c.accessoryView = x;
        } else { c.textLabel.text = @"Clear All Recent Searches"; c.tag = 1; c.textLabel.textAlignment = NSTextAlignmentCenter; }
        return c;
    }
    return ip.section == 0 ? [self plCell:_p[ip.row]] : [self songCell:_s[ip.row]];
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (!_q.length) {
        if (ip.row >= (NSInteger)ST.searches.count) { [ST.searches removeAllObjects]; [ST save]; [tv reloadData]; return; }
        NSString *t = ST.searches[ip.row]; _bar.text = t; [self searchBar:_bar textDidChange:t]; [self remember:t]; return;
    }
    [self remember:_q]; [_bar resignFirstResponder];
    if (ip.section == 0) { NSMutableDictionary *p = _p[ip.row]; [self.navigationController pushViewController:[[SongsVC alloc] initTitle:PlName(p) src:nil pl:p letters:NO] animated:YES]; }
    else [PL play:_s[ip.row] inList:_s];
}
@end

#pragma mark playlists / library / settings / more / create / premium
@interface PlaylistsVC : TBBase @end
@implementation PlaylistsVC
- (id)init { self = [super init]; self.title = @"Playlists"; self.wantsKind = YES; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItems = @[[[UIBarButtonItem alloc] initWithTitle:@"＋" style:UIBarButtonItemStyleBordered target:self action:@selector(add)]];
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

@interface SettingsVC : TBBase @end
@implementation SettingsVC
- (id)init { self = [super initWithStyle:UITableViewStyleGrouped]; self.title = @"Settings"; return self; }
- (NSArray *)rows { return @[@[@"Theme", @"Light / Dark Mode"], @[@"Keep Pitch With Speed", @"Sleep Timer"], @[@"Clear Search History", @"Clear Recently Played", @"Reset Listening Stats"],
                              @[@"Songs in Library", @"Delete Empty Playlists"], @[@"Treble 1.1 · iPod touch 4"]]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 5; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @[@"Appearance", @"Playback", @"History", @"Library", @"About"][s]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [[self rows][s] count]; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.textLabel.text = [self rows][ip.section][ip.row]; c.tag = 0;
    if (ip.section == 0) c.detailTextLabel.text = ip.row == 0 ? [TBTheme names][ST.theme] : [TBTheme modeNames][ST.mode];
    else if (ip.section == 1 && ip.row == 0) { UISwitch *w = [UISwitch new]; w.on = ST.keepPitch; [w addTarget:self action:@selector(pitchSw:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = w; c.selectionStyle = UITableViewCellSelectionStyleNone; }
    else if (ip.section == 1) c.detailTextLabel.text = PL.sleepAt > 0 ? [NSString stringWithFormat:@"%d min left", (int)ceil((PL.sleepAt - [[NSDate date] timeIntervalSince1970]) / 60)] : @"Off";
    else if (ip.section == 3 && ip.row == 0) { c.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)ST.songs.count]; c.selectionStyle = UITableViewCellSelectionStyleNone; }
    else if (ip.section == 4) c.selectionStyle = UITableViewCellSelectionStyleNone;
    return c;
}
- (void)pitchSw:(UISwitch *)w { ST.keepPitch = w.on; [ST save]; [PL applyRate]; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) { if (ip.row == 0) ThemeSheet(); else ModeSheet(); }
    else if (ip.section == 1 && ip.row == 1) SleepSheet();
    else if (ip.section == 2) {
        if (ip.row == 0) [ST.searches removeAllObjects]; else if (ip.row == 1) [ST.recent removeAllObjects]; else { [ST.plays removeAllObjects]; ST.secs = 0; }
        [ST save]; TBToast(@"Cleared");
    } else if (ip.section == 3 && ip.row == 1) {
        for (NSMutableDictionary *p in [ST.pls copy]) if (![p[@"ids"] count]) [ST.pls removeObject:p];
        [ST save]; TBToast(@"Empty playlists deleted");
    }
}
@end

@interface CreateVC : TBBase @end
@implementation CreateVC
- (id)init { self = [super initWithStyle:UITableViewStyleGrouped]; self.title = @"Create"; return self; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @[@"Add to Library", @"Smart Playlists", @"Import Settings"][s]; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return s == 0 ? @"Put music in Treble/Inbox on the iPod, then scan." : s == 2 ? @"Folder = Playlist makes one unnamed playlist per folder." : nil;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 1 ? 3 : 2; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; c.tag = 0;
    if (ip.section < 2) {
        c.textLabel.text = ip.section == 0 ? (ip.row == 0 ? @"Scan Inbox for New Files" : @"New Playlist") : @[@"Most Played", @"Recently Added", @"Never Played"][ip.row];
        [self setAccessory:c glyph:11 action:nil]; return c;
    }
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
- (void)open:(NSMutableDictionary *)p { [self.navigationController pushViewController:[[SongsVC alloc] initTitle:PlName(p) src:nil pl:p letters:NO] animated:YES]; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) {
        if (ip.row == 0) { [ST scan]; TBToast(@"Scanning…"); } else [self open:[ST newPlaylistNamed:@"" ids:nil kind:ST.impKind]];
    } else if (ip.section == 1) {
        NSMutableArray *ids; NSString *name = @[@"Most Played", @"Recently Added", @"Never Played"][ip.row];
        if (ip.row == 0) {
            NSMutableArray *a = [NSMutableArray array]; for (NSString *k in ST.plays) if (ST.songs[k] && [ST.plays[k] intValue] > 0) [a addObject:k];
            [a sortUsingComparator:^NSComparisonResult(id x, id y) { return [ST.plays[y] compare:ST.plays[x]]; }];
            ids = [[a subarrayWithRange:NSMakeRange(0, MIN(25, a.count))] mutableCopy];
        } else if (ip.row == 1) { NSArray *a = [ST sorted:[ST.songs allKeys] by:@"added"]; ids = [[a subarrayWithRange:NSMakeRange(0, MIN(25, a.count))] mutableCopy]; }
        else { ids = [NSMutableArray array]; for (NSString *k in [ST sorted:[ST.songs allKeys] by:@"title"]) if (![ST.plays[k] intValue] && ids.count < 100) [ids addObject:k]; }
        [self open:[ST newPlaylistNamed:name ids:ids kind:@"music"]];
    }
}
@end

@interface MenuVC : TBBase { NSArray *_rows; } @end
@implementation MenuVC
- (id)initTitle:(NSString *)t rows:(NSArray *)r { self = [super init]; self.title = t; _rows = r; self.wantsKind = [t isEqual:@"Library"]; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self.title isEqual:@"Library"] && TH.kind == 2)   // Spotify keeps "create" as a + button in Your Library
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"＋" style:UIBarButtonItemStyleBordered target:self action:@selector(plus)];
}
- (void)plus { [self.navigationController pushViewController:[CreateVC new] animated:YES]; }
- (NSString *)bigTitle { return (TH.kind == 2 && [self.title isEqual:@"Library"]) ? @"Your Library" : self.title; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _rows.count; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return TH.kind == 0 ? 46 : 54; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil]; c.tag = 0;
    NSString *r = _rows[ip.row]; c.textLabel.text = r;
    c.detailTextLabel.text = [r isEqual:@"Playlists"] ? [NSString stringWithFormat:@"%d", (int)ST.pls.count] : [r isEqual:@"Songs"] ? [NSString stringWithFormat:@"%d", (int)[ST allIds].count]
        : [r isEqual:@"Queue"] ? [NSString stringWithFormat:@"%d", (int)[ST.queue[@"ids"] count]] : [r isEqual:@"Equalizer"] ? (ST.eqOn ? ST.eqPreset : @"Off")
        : [r isEqual:@"Sleep Timer"] ? (PL.sleepAt > 0 ? @"On" : @"Off") : [r isEqual:@"Theme"] ? [TBTheme names][ST.theme] : [r isEqual:@"Light / Dark"] ? [TBTheme modeNames][ST.mode] : @"";
    [self setAccessory:c glyph:11 action:nil];
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
    else if ([r isEqual:@"Settings"]) v = [SettingsVC new];
    else if ([r isEqual:@"Sleep Timer"]) { SleepSheet(); return; }
    else if ([r isEqual:@"Theme"]) { ThemeSheet(); return; }
    else if ([r isEqual:@"Light / Dark"]) { ModeSheet(); return; }
    if (v) [self.navigationController pushViewController:v animated:YES];
}
@end

@interface PremiumVC : UIViewController @end
@implementation PremiumVC
- (id)init { self = [super init]; self.title = @"Premium"; return self; }
- (void)viewDidLoad {
    [super viewDidLoad]; TBTheme *T = TH; self.view.backgroundColor = T.bg; self.navigationItem.title = @"";
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, 304, 300)]; l.center = CGPointMake(160, 190);
    l.text = @"LMAO"; l.font = F(@"HelveticaNeue-Bold", 110, YES); l.textColor = T.accent; l.textAlignment = NSTextAlignmentCenter; l.backgroundColor = [UIColor clearColor];
    l.adjustsFontSizeToFitWidth = YES; l.minimumScaleFactor = .4; [self.view addSubview:l];
}
@end

#pragma mark equalizer
@interface EQVC : UIViewController { UISlider *_sl[10]; UILabel *_gl[10]; UIButton *_pb; UISwitch *_sw; } @end
@implementation EQVC
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Equalizer"; TBTheme *T = TH; self.view.backgroundColor = T.kind == 0 && !T.dark ? [UIColor groupTableViewBackgroundColor] : T.bg;
    UIColor *tc = T.kind == 3 ? T.hdrText : (T.kind == 0 && !T.dark ? [UIColor darkTextColor] : T.text);
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 150, 27)]; l.text = @"Equalizer"; l.font = T.titleFont; l.textColor = tc; l.backgroundColor = [UIColor clearColor]; [self.view addSubview:l];
    _sw = [[UISwitch alloc] initWithFrame:CGRectMake(225, 12, 80, 27)]; _sw.on = ST.eqOn; [_sw addTarget:self action:@selector(sw) forControlEvents:UIControlEventValueChanged]; [self.view addSubview:_sw];
    _pb = [T button:@"Preset" primary:NO]; _pb.frame = CGRectMake(15, 48, 290, 34); [_pb addTarget:self action:@selector(presets) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:_pb];
    NSArray *fq = @[@"32", @"64", @"125", @"250", @"500", @"1k", @"2k", @"4k", @"8k", @"16k"];
    for (int i = 0; i < 10; i++) {
        float x = 10 + i * 30.5;
        _gl[i] = [[UILabel alloc] initWithFrame:CGRectMake(x, 88, 30, 16)]; _gl[i].font = [UIFont systemFontOfSize:10]; _gl[i].textColor = tc; _gl[i].textAlignment = NSTextAlignmentCenter; _gl[i].backgroundColor = [UIColor clearColor]; [self.view addSubview:_gl[i]];
        UISlider *s = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 180, 30)]; s.minimumValue = -12; s.maximumValue = 12; s.tag = i;
        if (T.kind != 0) s.minimumTrackTintColor = T.accent;
        s.transform = CGAffineTransformMakeRotation(-M_PI_2); s.center = CGPointMake(x + 15, 197);
        [s addTarget:self action:@selector(moved:) forControlEvents:UIControlEventValueChanged];
        [s addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.view addSubview:s]; _sl[i] = s;
        UILabel *f = [[UILabel alloc] initWithFrame:CGRectMake(x, 292, 30, 14)]; f.text = fq[i]; f.font = [UIFont systemFontOfSize:10]; f.textColor = tc; f.textAlignment = NSTextAlignmentCenter; f.backgroundColor = [UIColor clearColor]; [self.view addSubview:f];
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
- (void)viewDidLoad { [super viewDidLoad]; TBTheme *T = TH; if (!(T.kind == 0 && !T.dark)) { self.tableView.backgroundView = nil; self.tableView.backgroundColor = T.bg; self.tableView.separatorColor = T.sep; } }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 3; }
- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip { if (!(TH.kind == 0 && !TH.dark)) [TH styleCell:c]; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (ip.row == 2) { c.textLabel.text = @"Choose Cover Art from Photos…"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; return c; }
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(12, 12, 280, 24)]; f.delegate = self; f.clearButtonMode = UITextFieldViewModeWhileEditing; f.returnKeyType = UIReturnKeyDone;
    f.placeholder = ip.row == 0 ? @"Playlist name" : @"Description"; f.text = _p[ip.row == 0 ? @"name" : @"desc"]; f.textColor = TH.kind == 0 && !TH.dark ? [UIColor blackColor] : TH.text;
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
- (UIButton *)ib:(UIImage *)im frame:(CGRect)f sel:(SEL)s {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.frame = f; [b setImage:im forState:UIControlStateNormal];
    [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:b]; return b;
}
- (UILabel *)lab:(CGRect)f font:(UIFont *)fo color:(UIColor *)col {
    UILabel *l = [[UILabel alloc] initWithFrame:f]; l.font = fo; l.textColor = col; l.textAlignment = NSTextAlignmentCenter; l.backgroundColor = [UIColor clearColor];
    l.adjustsFontSizeToFitWidth = YES; l.minimumScaleFactor = .6; [self.view addSubview:l]; return l;
}
- (void)viewDidLoad {
    [super viewDidLoad]; TBTheme *T = TH; int k = T.kind;
    if (k == 3) {
        self.view.backgroundColor = T.bg;
        _bgl = [CAGradientLayer layer]; _bgl.frame = CGRectMake(0, 0, 320, 480); _bgl.colors = @[(id)RGBA(0, 0, 0, .05).CGColor, (id)RGBA(0, 0, 0, .7).CGColor]; [self.view.layer addSublayer:_bgl];
    } else {
        self.view.backgroundColor = T.npB;
        _bgl = [CAGradientLayer layer]; _bgl.frame = CGRectMake(0, 0, 320, 480); _bgl.colors = @[(id)T.npA.CGColor, (id)T.npB.CGColor]; [self.view.layer addSublayer:_bgl];
    }
    _cl = [self ib:Glyph(8, 26, T.npText) frame:CGRectMake(8, 4, 50, 40) sel:@selector(close)];
    _qb = [self ib:Glyph(7, 24, T.npText) frame:CGRectMake(262, 4, 50, 40) sel:@selector(showQueue)];
    CGFloat as = 196; CGRect ar = CGRectMake(62, 44, as, as);
    if (k == 4) { _hard = [[UIView alloc] initWithFrame:CGRectOffset(ar, 7, 7)]; _hard.backgroundColor = T.accent; [self.view addSubview:_hard]; }
    _wrap = [[UIView alloc] initWithFrame:ar]; [self.view addSubview:_wrap];
    if (k == 3) {
        UIImageView *vin = [[UIImageView alloc] initWithImage:[TBTheme vinyl:as]]; vin.frame = _wrap.bounds; [_wrap addSubview:vin];
        _art = [[UIImageView alloc] initWithFrame:CGRectMake(38, 38, 120, 120)]; _art.layer.cornerRadius = 60; _art.clipsToBounds = YES; [_wrap addSubview:_art];
        UIView *hole = [[UIView alloc] initWithFrame:CGRectMake(as / 2 - 6, as / 2 - 6, 12, 12)]; hole.layer.cornerRadius = 6; hole.backgroundColor = RGB(30, 20, 10); hole.layer.borderWidth = 2; hole.layer.borderColor = RGB(244, 229, 196).CGColor; [_wrap addSubview:hole];
        _wrap.layer.shadowColor = [UIColor blackColor].CGColor; _wrap.layer.shadowOpacity = .7; _wrap.layer.shadowRadius = 10;
    } else {
        _art = [[UIImageView alloc] initWithFrame:_wrap.bounds]; [_wrap addSubview:_art];
        _art.layer.cornerRadius = k == 1 ? 14 : (k == 2 ? 4 : 0); _art.clipsToBounds = YES;
        if (k == 4) { _art.layer.borderWidth = 3; _art.layer.borderColor = T.text.CGColor; }
        else { _wrap.layer.shadowColor = [UIColor blackColor].CGColor; _wrap.layer.shadowOpacity = .6; _wrap.layer.shadowRadius = 9; _wrap.layer.shadowOffset = CGSizeMake(0, 4); }
    }
    UIColor *cc = k == 3 ? T.npText : T.npText;
    _t = [self lab:CGRectMake(20, 246, 280, k == 4 ? 30 : 22) font:F(T.fHead, k == 4 ? 28 : 18, YES) color:cc];
    _a = [self lab:CGRectMake(20, k == 4 ? 276 : 268, 280, 18) font:F(T.fSub, 14, NO) color:T.npSub];
    _al = [self lab:CGRectMake(20, k == 4 ? 294 : 286, 280, 14) font:F(T.fSub, 12, NO) color:T.npSub];
    _seek = [[UISlider alloc] initWithFrame:CGRectMake(20, 308, 280, 20)]; [_seek addTarget:self action:@selector(seeked) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    if (k != 0) { _seek.minimumTrackTintColor = (k == 2 || k == 1) ? T.npText : T.accent; _seek.maximumTrackTintColor = [T.npSub colorWithAlphaComponent:.35]; _seek.thumbTintColor = k == 3 ? RGB(255, 196, 64) : T.npText; }
    [self.view addSubview:_seek];
    _el = [self lab:CGRectMake(20, 330, 60, 14) font:[UIFont systemFontOfSize:11] color:T.npSub]; _el.textAlignment = NSTextAlignmentLeft;
    _rm = [self lab:CGRectMake(240, 330, 60, 14) font:[UIFont systemFontOfSize:11] color:T.npSub]; _rm.textAlignment = NSTextAlignmentRight;
    _sh = [self ib:Glyph(4, 26, T.npSub) frame:CGRectMake(12, 358, 48, 44) sel:@selector(shuf)];
    [self ib:Glyph(0, 30, T.npText) frame:CGRectMake(70, 358, 56, 44) sel:@selector(prev)];
    _pp = [self ib:PlayImg(NO, 64) frame:CGRectMake(128, 348, 64, 64) sel:@selector(pp)];
    [self ib:Glyph(1, 30, T.npText) frame:CGRectMake(194, 358, 56, 44) sel:@selector(next)];
    _rp = [self ib:Glyph(5, 26, T.npSub) frame:CGRectMake(260, 358, 48, 44) sel:@selector(rep)];
    _spd = [UIButton buttonWithType:UIButtonTypeCustom]; _spd.frame = CGRectMake(110, 420, 100, 28);
    _spd.layer.cornerRadius = k == 4 ? 0 : 14; _spd.layer.borderWidth = k == 4 ? 2 : 1; _spd.titleLabel.font = F(T.fHead, k == 4 ? 16 : 14, YES);
    [_spd addTarget:self action:@selector(speedMenu) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:_spd];
    [self sync]; _tm = [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sync) name:TBPlayerChanged object:nil];
}
- (void)spin:(BOOL)on {
    CALayer *l = _wrap.layer;
    if (!l.animationKeys.count) {
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"]; a.fromValue = @0; a.toValue = @(2 * M_PI); a.duration = 5; a.repeatCount = HUGE_VALF;
        [l addAnimation:a forKey:@"spin"]; l.speed = 0;
    }
    if (on && l.speed == 0) {
        CFTimeInterval p = l.timeOffset; l.speed = 1; l.timeOffset = 0; l.beginTime = 0;
        l.beginTime = [l convertTime:CACurrentMediaTime() fromLayer:nil] - p;
    } else if (!on && l.speed == 1) {
        CFTimeInterval t = [l convertTime:CACurrentMediaTime() fromLayer:nil]; l.speed = 0; l.timeOffset = t;
    }
}
- (void)sync {
    TBTheme *T = TH; NSDictionary *s = [ST song:PL.curId]; if (!s) return;
    _art.image = [ST thumbForSong:s]; _t.text = T.upper ? [s[@"title"] uppercaseString] : s[@"title"]; _a.text = s[@"artist"]; _al.text = s[@"album"];
    float r = [s[@"rate"] floatValue]; if (r < .5) r = 1;
    [_spd setTitle:[NSString stringWithFormat:@"%.2f×", r] forState:UIControlStateNormal];
    UIColor *c = fabsf(r - 1) > .001f ? T.accent : T.npSub;
    [_spd setTitleColor:c forState:UIControlStateNormal]; _spd.layer.borderColor = c.CGColor;
    [_pp setImage:PlayImg(PL.playing, 64) forState:UIControlStateNormal];
    [_sh setImage:Glyph(4, 26, PL.shuffle ? T.accent : T.npSub) forState:UIControlStateNormal];
    [_rp setImage:Glyph(PL.repeat == 2 ? 6 : 5, 26, PL.repeat ? T.accent : T.npSub) forState:UIControlStateNormal];
    if (T.kind == 3) [self spin:PL.playing];
}
- (void)tick { double d = PL.duration, p = PL.position; if (!_seek.tracking && d > 0) _seek.value = p / d; _el.text = Mins(p); _rm.text = [@"-" stringByAppendingString:Mins(MAX(0, d - p))]; }
- (void)seeked { [PL seek:_seek.value * PL.duration]; }
- (void)speedMenu { if (PL.curId) SpeedSheet(PL.curId); }
- (void)pp { [PL toggle]; } - (void)next { [PL next]; } - (void)prev { [PL prev]; }
- (void)shuf { PL.shuffle = !PL.shuffle; [self sync]; }
- (void)rep { PL.repeat = (PL.repeat + 1) % 3; [self sync]; }
- (void)close { [_tm invalidate]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)showQueue { [self close]; [[NSNotificationCenter defaultCenter] postNotificationName:@"TBShowQueue" object:nil]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

#pragma mark app shell
// 0 home 1 search 2 library 3 create 4 more 5 premium (diamond)
static UIImage *Icon(int k, UIColor *col) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 2); CGContextRef c = UIGraphicsGetCurrentContext();
    [col setStroke]; [col setFill]; CGContextSetLineWidth(c, 2.5); CGContextSetLineJoin(c, kCGLineJoinRound);
    if (k == 0) { CGContextMoveToPoint(c, 15, 4); CGContextAddLineToPoint(c, 27, 15); CGContextAddLineToPoint(c, 23, 15); CGContextAddLineToPoint(c, 23, 26); CGContextAddLineToPoint(c, 7, 26); CGContextAddLineToPoint(c, 7, 15); CGContextAddLineToPoint(c, 3, 15); CGContextClosePath(c); CGContextFillPath(c); }
    else if (k == 1) { CGContextStrokeEllipseInRect(c, CGRectMake(4, 4, 16, 16)); CGContextMoveToPoint(c, 18, 18); CGContextAddLineToPoint(c, 27, 27); CGContextStrokePath(c); }
    else if (k == 2) { [@"♫" drawInRect:CGRectMake(0, 0, 30, 30) withFont:[UIFont boldSystemFontOfSize:28] lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter]; }
    else if (k == 3) { CGContextMoveToPoint(c, 15, 5); CGContextAddLineToPoint(c, 15, 25); CGContextMoveToPoint(c, 5, 15); CGContextAddLineToPoint(c, 25, 15); CGContextStrokePath(c); }
    else if (k == 5) { CGContextMoveToPoint(c, 15, 3); CGContextAddLineToPoint(c, 26, 12); CGContextAddLineToPoint(c, 15, 27); CGContextAddLineToPoint(c, 4, 12); CGContextClosePath(c); CGContextStrokePath(c); CGContextMoveToPoint(c, 4, 12); CGContextAddLineToPoint(c, 26, 12); CGContextStrokePath(c); }
    else { for (int i = 0; i < 3; i++) CGContextFillEllipseInRect(c, CGRectMake(3 + i * 9, 12, 6, 6)); }
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return im;
}

@interface TBTabs : UITabBarController {
    UIView *_mini; UIImageView *_mArt; UILabel *_mT, *_mA; UIButton *_mPrev, *_mPlay, *_mNext; UIView *_mBar; CAGradientLayer *_gl; NSTimer *_mt;
}
@end
@implementation TBTabs
- (BOOL)canBecomeFirstResponder { return YES; }
- (UIButton *)mb:(SEL)s { UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside]; [_mini addSubview:b]; return b; }
- (void)viewDidLoad {
    [super viewDidLoad];
    _mini = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)]; _mini.hidden = YES;
    _gl = [CAGradientLayer layer]; [_mini.layer addSublayer:_gl];
    _mArt = [[UIImageView alloc] initWithFrame:CGRectZero]; _mArt.clipsToBounds = YES; [_mini addSubview:_mArt];
    _mT = [[UILabel alloc] initWithFrame:CGRectZero]; _mT.backgroundColor = [UIColor clearColor]; [_mini addSubview:_mT];
    _mA = [[UILabel alloc] initWithFrame:CGRectZero]; _mA.backgroundColor = [UIColor clearColor]; [_mini addSubview:_mA];
    _mPrev = [self mb:@selector(mPrev)]; _mPlay = [self mb:@selector(mPlay)]; _mNext = [self mb:@selector(mNext)];
    _mBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 2)]; [_mini addSubview:_mBar];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openNP)]; [_mini addGestureRecognizer:tap];
    [self.view addSubview:_mini];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updMini) name:TBPlayerChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showQueue) name:@"TBShowQueue" object:nil];
    _mt = [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(progress) userInfo:nil repeats:YES];
    [self updMini];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    TBTheme *T = TH; CGFloat w = self.view.bounds.size.width, h = T.miniH, tabY = self.tabBar.frame.origin.y;
    _mini.frame = T.floatMini ? CGRectMake(8, tabY - h - 6, w - 16, h) : CGRectMake(0, tabY - h, w, h);
    _mini.layer.cornerRadius = T.floatMini ? 8 : 0; _mini.clipsToBounds = T.floatMini;
    if (T.floatMini) { _mini.layer.borderWidth = T.kind == 1 && !T.dark ? 1 : 0; _mini.layer.borderColor = RGB(220, 220, 225).CGColor; }
    else { _mini.layer.borderWidth = T.kind == 4 ? 0 : 0; }
    _gl.frame = _mini.bounds; _gl.colors = @[(id)T.miniA.CGColor, (id)T.miniB.CGColor];
    CGFloat mw = _mini.bounds.size.width;
    _mArt.frame = CGRectMake(0, 0, h, h); _mArt.layer.cornerRadius = T.circleArt ? h / 2 : 0;
    _mT.frame = CGRectMake(h + 8, h / 2 - 18, mw - h - 138, 18); _mA.frame = CGRectMake(h + 8, h / 2, mw - h - 138, 16);
    _mT.font = F(T.fTitle, 14, YES); _mA.font = F(T.fSub, 12, NO); _mT.textColor = T.miniText; _mA.textColor = T.miniSub;
    _mPrev.frame = CGRectMake(mw - 126, 0, 42, h); _mPlay.frame = CGRectMake(mw - 84, 0, 42, h); _mNext.frame = CGRectMake(mw - 42, 0, 42, h);
    _mBar.backgroundColor = T.accent;
    [_mPrev setImage:Glyph(0, 20, T.miniText) forState:UIControlStateNormal]; [_mNext setImage:Glyph(1, 20, T.miniText) forState:UIControlStateNormal];
    [self.view bringSubviewToFront:_mini];
}
- (void)updMini {
    TBTheme *T = TH; NSDictionary *s = [ST song:PL.curId]; _mini.hidden = (s == nil); if (!s) return;
    _mArt.image = [ST thumbForSong:s]; _mT.text = T.upper ? [s[@"title"] uppercaseString] : s[@"title"]; _mA.text = s[@"artist"];
    [_mPlay setImage:Glyph(PL.playing ? 3 : 2, 22, T.miniText) forState:UIControlStateNormal];
}
- (void)progress { double d = PL.duration; _mBar.frame = CGRectMake(0, 0, d > 0 ? _mini.bounds.size.width * (PL.position / d) : 0, TH.kind == 4 ? 4 : 2); }
- (void)mPrev { [PL prev]; } - (void)mPlay { [PL toggle]; } - (void)mNext { [PL next]; }
- (void)openNP { if (PL.curId && !self.presentedViewController) [self presentViewController:[NowPlayingVC new] animated:YES completion:nil]; }
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents]; [self becomeFirstResponder];
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
- (void)dealloc { [_mt invalidate]; [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

void TBStyleAppearance(void) { [TBTheme reload]; [[TBTheme cur] applyAppearance]; }

UITabBarController *TBMakeTabs(void) {
    TBTheme *T = TH; BOOL sp = (T.kind == 2);   // Spotify: Home, Search, Your Library, Premium, More (Create lives behind the + in Library)
    NSArray *roots = @[[HomeVC new], [SearchVC new],
        [[MenuVC alloc] initTitle:@"Library" rows:@[@"Playlists", @"Songs", @"Artists", @"Albums"]],
        sp ? (UIViewController *)[PremiumVC new] : (UIViewController *)[CreateVC new],
        [[MenuVC alloc] initTitle:@"More" rows:@[@"Equalizer", @"Queue", @"Sleep Timer", @"Theme", @"Light / Dark", @"Settings"]]];
    NSArray *names = @[@"Home", @"Search", @"Library", sp ? @"Premium" : @"Create", @"More"]; NSMutableArray *vcs = [NSMutableArray array];
    NSString *tf = T.kind == 3 ? @"Georgia-Bold" : (T.kind == 4 ? @"HelveticaNeue-CondensedBlack" : @"HelveticaNeue-Bold");
    for (int i = 0; i < 5; i++) {
        UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:roots[i]];
        int ik = (i == 3 && sp) ? 5 : i;
        UITabBarItem *it = [[UITabBarItem alloc] initWithTitle:T.upper ? [names[i] uppercaseString] : names[i] image:nil tag:i];
        if (T.kind == 0) it.image = Icon(ik, [UIColor blackColor]);
        else {
            [it setFinishedSelectedImage:Icon(ik, T.tabSel) withFinishedUnselectedImage:Icon(ik, T.tabText)];
            [it setTitleTextAttributes:@{UITextAttributeTextColor:T.tabText, UITextAttributeFont:F(tf, T.kind == 4 ? 12 : 10, YES), UITextAttributeTextShadowColor:[UIColor clearColor]} forState:UIControlStateNormal];
            [it setTitleTextAttributes:@{UITextAttributeTextColor:T.tabSel, UITextAttributeFont:F(tf, T.kind == 4 ? 12 : 10, YES), UITextAttributeTextShadowColor:[UIColor clearColor]} forState:UIControlStateSelected];
        }
        n.tabBarItem = it; [vcs addObject:n];
    }
    TBTabs *t = [TBTabs new]; t.viewControllers = vcs;
    if (T.kind != 0) { t.tabBar.backgroundImage = [T tabBgImage]; t.tabBar.selectionIndicatorImage = [T tabSelImage]; }
    return t;
}

void TBApplyTheme(BOOL fromSettings) {
    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    UITabBarController *old = (UITabBarController *)w.rootViewController; NSUInteger sel = [old isKindOfClass:[UITabBarController class]] ? old.selectedIndex : 0;
    [TBTheme reload]; [[TBTheme cur] applyAppearance];
    UITabBarController *nt = TBMakeTabs(); nt.selectedIndex = fromSettings ? 4 : sel;
    [UIView transitionWithView:w duration:.35 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{ w.rootViewController = nt; } completion:nil];
    if (fromSettings) { UINavigationController *n = (UINavigationController *)nt.selectedViewController; [n pushViewController:[SettingsVC new] animated:NO]; }
}
void TBThemeTick(void) {
    if (ST.mode != 2) return;
    BOOL was = [TBTheme cur].dark; [TBTheme reload];
    if ([TBTheme cur].dark != was) TBApplyTheme(NO);
}
