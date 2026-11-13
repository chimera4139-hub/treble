#import "TBTheme.h"
#import "TBStore.h"
#import <QuartzCore/QuartzCore.h>

#define RGB(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define RGBA(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]
#define WH(w) [UIColor colorWithWhite:(w) alpha:1]

static TBTheme *gCur;

#pragma mark image helpers
static UIImage *Grad(CGSize sz, UIColor *a, UIColor *b, UIColor *line, BOOL lineTop) {
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0); CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); NSArray *cols = @[(id)a.CGColor, (id)b.CGColor];
    CGGradientRef g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)cols, NULL);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, sz.height), 0);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
    if (line) { [line setFill]; UIRectFill(CGRectMake(0, lineTop ? 0 : sz.height - 1, sz.width, 1)); }
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return im;
}
static UIImage *Wood(BOOL dark) {
    CGFloat S = 128;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(S, S), YES, 0); CGContextRef c = UIGraphicsGetCurrentContext();
    [dark ? RGB(66, 40, 20) : RGB(139, 90, 46) setFill]; UIRectFill(CGRectMake(0, 0, S, S));
    uint32_t r = 12345;
    for (int i = 0; i < 48; i++) {
        r = r * 1664525u + 1013904223u; CGFloat y = ((r >> 8) & 0xFFFF) / 65536.0 * S;
        r = r * 1664525u + 1013904223u; CGFloat amp = 1 + ((r >> 8) & 0xFF) / 255.0 * 2.5;
        r = r * 1664525u + 1013904223u; CGFloat ph = ((r >> 8) & 0xFF) / 255.0 * 6.28;
        r = r * 1664525u + 1013904223u; int k = 1 + ((r >> 8) % 2);
        r = r * 1664525u + 1013904223u; CGFloat a = .05 + ((r >> 8) & 0xFF) / 255.0 * .16;
        [(i % 5 == 0) ? RGBA(255, 220, 170, a * .6) : RGBA(30, 12, 0, a) setStroke];
        CGContextSetLineWidth(c, .6 + ((r >> 12) & 3) * .4);
        CGContextMoveToPoint(c, 0, y);
        for (int x = 0; x <= 128; x += 4) CGContextAddLineToPoint(c, x, y + amp * sin(2 * M_PI * k * x / 128.0 + ph));
        CGContextStrokePath(c);
    }
    [RGBA(20, 8, 0, .45) setFill]; UIRectFill(CGRectMake(0, 0, S, 1)); UIRectFill(CGRectMake(0, 64, S, 1));
    [RGBA(255, 220, 170, .10) setFill]; UIRectFill(CGRectMake(0, 1, S, 1)); UIRectFill(CGRectMake(0, 65, S, 1));
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return im;
}

@implementation TBTheme

+ (NSArray *)names { return @[@"Old Apple", @"Modern", @"Spotify", @"FM", @"Poster"]; }
+ (NSArray *)modeNames { return @[@"Light", @"Dark", @"Auto"]; }
+ (TBTheme *)cur { if (!gCur) [self reload]; return gCur; }
+ (void)reload {
    TBStore *s = [TBStore shared]; BOOL dark = (s.mode == 1);
    if (s.mode == 2) { NSInteger h = [[NSCalendar currentCalendar] components:NSHourCalendarUnit fromDate:[NSDate date]].hour; dark = (h >= 19 || h < 7); }
    gCur = [self make:s.theme dark:dark];
}
+ (UIImage *)solid:(UIColor *)c { return Grad(CGSizeMake(4, 4), c, c, nil, NO); }
+ (UIImage *)vinyl:(CGFloat)S {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(S, S), NO, 0); CGContextRef c = UIGraphicsGetCurrentContext();
    [RGB(16, 12, 10) setFill]; CGContextFillEllipseInRect(c, CGRectMake(0, 0, S, S));
    CGContextSetLineWidth(c, .6);
    for (CGFloat r = S / 2 - 3; r > S * .3; r -= 3.2) { [RGBA(255, 255, 255, ((int)r % 2) ? .07 : .03) setStroke]; CGContextStrokeEllipseInRect(c, CGRectMake(S / 2 - r, S / 2 - r, r * 2, r * 2)); }
    [RGBA(255, 255, 255, .10) setStroke]; CGContextSetLineWidth(c, 1.5);
    CGContextAddArc(c, S / 2, S / 2, S / 2 - 8, 3.6, 4.4, 0); CGContextStrokePath(c);
    [RGB(70, 70, 70) setStroke]; CGContextSetLineWidth(c, 1.5); CGContextStrokeEllipseInRect(c, CGRectMake(.75, .75, S - 1.5, S - 1.5));
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return im;
}

+ (TBTheme *)make:(int)k dark:(BOOL)d {
    TBTheme *t = [TBTheme new]; t.kind = k; t.dark = d;
    t.rowH = 60; t.artSize = 60; t.artPad = 0; t.artRadius = 0; t.hdrH = 22; t.bigH = 0; t.bigSize = 28; t.miniH = 44; t.miniInset = 44; t.chipH = 44; t.szTitle = 17; t.szSub = 14;
    t.largeTitle = NO; t.pills = NO; t.showSep = YES; t.floatMini = NO; t.circleArt = NO; t.upper = NO; t.customHeaders = NO;
    switch (k) {
    case 1: // ---------------- Modern (Apple Music style)
        t.rowH = 68; t.artSize = 52; t.artPad = 14; t.artRadius = 6; t.hdrH = 40; t.bigH = 46; t.bigSize = 32; t.miniH = 52; t.miniInset = 62;
        t.largeTitle = YES; t.pills = YES; t.floatMini = YES; t.customHeaders = YES; t.szTitle = 16; t.szSub = 13;
        t.fTitle = @"HelveticaNeue-Medium"; t.fSub = @"HelveticaNeue"; t.fHead = @"HelveticaNeue-Bold"; t.fBig = @"HelveticaNeue-Bold"; t.fNav = @"HelveticaNeue-Bold";
        if (!d) {
            t.bg = WH(1); t.rowBg = WH(1); t.text = WH(.07); t.sub = RGB(142, 142, 147); t.accent = RGB(250, 45, 72); t.warn = RGB(255, 59, 48); t.sep = RGB(229, 229, 234); t.hdrText = WH(.07);
            t.chipBg = RGB(240, 240, 245); t.chipText = WH(.25); t.chipSelBg = t.accent; t.chipSelText = WH(1); t.segTint = RGB(150, 150, 155);
            t.navA = RGB(252, 252, 252); t.navB = RGB(246, 246, 248); t.navLine = RGB(220, 220, 225); t.navText = WH(.07); t.navAccent = t.accent;
            t.tabA = RGB(249, 249, 250); t.tabB = RGB(243, 243, 246); t.tabText = RGB(142, 142, 147); t.tabSel = t.accent;
            t.miniA = RGB(248, 248, 250); t.miniB = RGB(234, 234, 239); t.miniText = WH(.07); t.miniSub = RGB(120, 120, 126);
            t.npA = WH(1); t.npB = RGB(240, 240, 245); t.npText = WH(.07); t.npSub = RGB(120, 120, 126);
        } else {
            t.bg = WH(0); t.rowBg = WH(0); t.text = WH(1); t.sub = RGB(152, 152, 157); t.accent = RGB(252, 60, 84); t.warn = RGB(255, 90, 80); t.sep = RGB(44, 44, 46); t.hdrText = WH(1);
            t.chipBg = RGB(44, 44, 46); t.chipText = WH(.9); t.chipSelBg = t.accent; t.chipSelText = WH(1); t.segTint = RGB(80, 80, 84);
            t.navA = RGB(30, 30, 32); t.navB = RGB(24, 24, 26); t.navLine = RGB(50, 50, 54); t.navText = WH(1); t.navAccent = t.accent;
            t.tabA = RGB(28, 28, 30); t.tabB = RGB(20, 20, 22); t.tabText = RGB(130, 130, 136); t.tabSel = t.accent;
            t.miniA = RGB(54, 54, 58); t.miniB = RGB(40, 40, 44); t.miniText = WH(1); t.miniSub = RGB(160, 160, 165);
            t.npA = RGB(56, 56, 62); t.npB = WH(0); t.npText = WH(1); t.npSub = RGB(160, 160, 165);
        }
        break;
    case 2: // ---------------- Spotify
        t.rowH = 62; t.artSize = 48; t.artPad = 12; t.artRadius = 2; t.hdrH = 44; t.bigH = 44; t.bigSize = 28; t.miniH = 50; t.miniInset = 62; t.chipH = 48;
        t.largeTitle = YES; t.pills = YES; t.showSep = NO; t.floatMini = YES; t.customHeaders = YES; t.szTitle = 16; t.szSub = 13;
        t.fTitle = @"HelveticaNeue-Bold"; t.fSub = @"HelveticaNeue"; t.fHead = @"HelveticaNeue-Bold"; t.fBig = @"HelveticaNeue-Bold"; t.fNav = @"HelveticaNeue-Bold";
        if (d) {
            t.bg = RGB(18, 18, 18); t.rowBg = t.bg; t.text = WH(1); t.sub = RGB(179, 179, 179); t.accent = RGB(30, 215, 96); t.warn = RGB(255, 90, 90); t.sep = [UIColor clearColor]; t.hdrText = WH(1);
            t.chipBg = RGB(42, 42, 42); t.chipText = WH(1); t.chipSelBg = t.accent; t.chipSelText = WH(0); t.segTint = RGB(70, 70, 70);
            t.navA = RGB(18, 18, 18); t.navB = RGB(18, 18, 18); t.navLine = nil; t.navText = WH(1); t.navAccent = WH(1);
            t.tabA = RGB(14, 14, 14); t.tabB = WH(0); t.tabText = RGB(167, 167, 167); t.tabSel = WH(1);
            t.miniA = RGB(66, 66, 66); t.miniB = RGB(50, 50, 50); t.miniText = WH(1); t.miniSub = RGB(190, 190, 190);
            t.npA = RGB(92, 92, 92); t.npB = RGB(18, 18, 18); t.npText = WH(1); t.npSub = RGB(179, 179, 179);
        } else {
            t.bg = WH(1); t.rowBg = WH(1); t.text = RGB(18, 18, 18); t.sub = RGB(106, 106, 106); t.accent = RGB(29, 185, 84); t.warn = RGB(210, 40, 40); t.sep = [UIColor clearColor]; t.hdrText = RGB(18, 18, 18);
            t.chipBg = RGB(235, 235, 235); t.chipText = RGB(18, 18, 18); t.chipSelBg = t.accent; t.chipSelText = WH(0); t.segTint = RGB(170, 170, 170);
            t.navA = WH(1); t.navB = WH(1); t.navLine = nil; t.navText = RGB(18, 18, 18); t.navAccent = RGB(18, 18, 18);
            t.tabA = WH(1); t.tabB = RGB(246, 246, 246); t.tabText = RGB(110, 110, 110); t.tabSel = RGB(18, 18, 18);
            t.miniA = RGB(242, 242, 242); t.miniB = RGB(228, 228, 228); t.miniText = RGB(18, 18, 18); t.miniSub = RGB(100, 100, 100);
            t.npA = RGB(205, 205, 205); t.npB = WH(1); t.npText = RGB(18, 18, 18); t.npSub = RGB(90, 90, 90);
        }
        break;
    case 3: // ---------------- FM (jukebox: oak, cream labels, brass, amber glow)
        t.rowH = 70; t.artSize = 54; t.artPad = 14; t.artRadius = 27; t.circleArt = YES; t.hdrH = 30; t.bigH = 46; t.bigSize = 30; t.miniH = 50; t.miniInset = 50;
        t.largeTitle = YES; t.pills = YES; t.showSep = NO; t.customHeaders = YES; t.szTitle = 16; t.szSub = 13;
        t.fTitle = @"Georgia-Bold"; t.fSub = @"Georgia-Italic"; t.fHead = @"Georgia-Bold"; t.fBig = @"Georgia-Bold"; t.fNav = @"Georgia-Bold";
        t.navLine = RGB(201, 162, 75); t.navText = RGB(255, 236, 190); t.navAccent = RGB(255, 196, 64); t.segTint = RGB(150, 100, 50);
        if (!d) {
            t.bg = [UIColor colorWithPatternImage:Wood(NO)]; t.rowBg = RGB(244, 229, 196); t.text = RGB(58, 36, 18); t.sub = RGB(125, 92, 58); t.accent = RGB(178, 34, 24); t.warn = RGB(150, 20, 20); t.sep = RGB(200, 170, 120); t.hdrText = RGB(255, 236, 190);
            t.chipBg = RGB(201, 162, 75); t.chipText = RGB(58, 36, 18); t.chipSelBg = RGB(255, 196, 64); t.chipSelText = RGB(58, 36, 18);
            t.navA = RGB(92, 54, 26); t.navB = RGB(52, 29, 13);
            t.tabA = RGB(70, 40, 18); t.tabB = RGB(34, 18, 8); t.tabText = RGB(190, 150, 90); t.tabSel = RGB(255, 196, 64);
            t.miniA = RGB(84, 48, 22); t.miniB = RGB(40, 22, 10); t.miniText = RGB(255, 214, 122); t.miniSub = RGB(200, 160, 100);
            t.npA = RGB(70, 40, 18); t.npB = RGB(30, 16, 6); t.npText = RGB(255, 236, 190); t.npSub = RGB(214, 184, 130);
        } else {
            t.bg = [UIColor colorWithPatternImage:Wood(YES)]; t.rowBg = RGB(60, 38, 22); t.text = RGB(250, 230, 190); t.sub = RGB(190, 150, 100); t.accent = RGB(255, 176, 32); t.warn = RGB(255, 110, 80); t.sep = RGB(30, 18, 8); t.hdrText = RGB(255, 196, 64);
            t.chipBg = RGB(120, 90, 40); t.chipText = RGB(255, 236, 190); t.chipSelBg = RGB(255, 176, 32); t.chipSelText = RGB(40, 22, 8);
            t.navA = RGB(52, 30, 14); t.navB = RGB(26, 14, 6);
            t.tabA = RGB(40, 22, 10); t.tabB = RGB(18, 10, 4); t.tabText = RGB(160, 120, 70); t.tabSel = RGB(255, 176, 32);
            t.miniA = RGB(60, 34, 16); t.miniB = RGB(26, 14, 6); t.miniText = RGB(255, 196, 64); t.miniSub = RGB(180, 140, 90);
            t.npA = RGB(42, 24, 10); t.npB = WH(0); t.npText = RGB(250, 230, 190); t.npSub = RGB(190, 150, 100);
        }
        break;
    case 4: // ---------------- Poster (Swiss: flat, huge type, thick rules, one hot accent)
        t.rowH = 64; t.artSize = 52; t.artPad = 0; t.artRadius = 0; t.hdrH = 40; t.bigH = 56; t.bigSize = 44; t.miniH = 48; t.miniInset = 48;
        t.largeTitle = YES; t.pills = YES; t.showSep = NO; t.upper = YES; t.customHeaders = YES; t.szTitle = 18; t.szSub = 11;
        t.fTitle = @"HelveticaNeue-CondensedBold"; t.fSub = @"HelveticaNeue-Medium"; t.fHead = @"HelveticaNeue-CondensedBlack"; t.fBig = @"HelveticaNeue-CondensedBlack"; t.fNav = @"HelveticaNeue-CondensedBlack";
        if (!d) {
            t.bg = RGB(244, 241, 234); t.rowBg = t.bg; t.text = RGB(10, 10, 10); t.sub = RGB(95, 95, 90); t.accent = RGB(255, 75, 31); t.warn = t.accent; t.sep = RGB(10, 10, 10); t.hdrText = t.text;
            t.chipBg = t.bg; t.chipText = t.text; t.chipSelBg = t.text; t.chipSelText = t.bg; t.segTint = RGB(10, 10, 10);
            t.navA = t.bg; t.navB = t.bg; t.navLine = t.text; t.navText = t.text; t.navAccent = t.accent;
            t.tabA = RGB(10, 10, 10); t.tabB = RGB(10, 10, 10); t.tabText = RGB(200, 200, 195); t.tabSel = WH(1);
            t.miniA = RGB(10, 10, 10); t.miniB = RGB(10, 10, 10); t.miniText = t.bg; t.miniSub = RGB(170, 170, 165);
            t.npA = t.bg; t.npB = t.bg; t.npText = t.text; t.npSub = t.sub;
        } else {
            t.bg = RGB(10, 10, 10); t.rowBg = t.bg; t.text = RGB(244, 241, 234); t.sub = RGB(150, 150, 145); t.accent = RGB(255, 90, 44); t.warn = t.accent; t.sep = t.text; t.hdrText = t.text;
            t.chipBg = t.bg; t.chipText = t.text; t.chipSelBg = t.text; t.chipSelText = t.bg; t.segTint = RGB(90, 90, 90);
            t.navA = t.bg; t.navB = t.bg; t.navLine = t.text; t.navText = t.text; t.navAccent = t.accent;
            t.tabA = RGB(244, 241, 234); t.tabB = RGB(244, 241, 234); t.tabText = RGB(60, 60, 58); t.tabSel = RGB(10, 10, 10);
            t.miniA = RGB(244, 241, 234); t.miniB = RGB(244, 241, 234); t.miniText = RGB(10, 10, 10); t.miniSub = RGB(90, 90, 86);
            t.npA = t.bg; t.npB = t.bg; t.npText = t.text; t.npSub = t.sub;
        }
        break;
    default: // ---------------- Old Apple (iOS 6)
        if (!d) {
            t.bg = WH(1); t.rowBg = RGB(248, 248, 248); t.text = WH(.29); t.sub = WH(.48); t.accent = RGB(38, 102, 204); t.warn = RGB(190, 50, 50); t.sep = WH(.8); t.hdrText = WH(.33);
            t.miniA = WH(.38); t.miniB = WH(.13); t.miniText = WH(1); t.miniSub = WH(.75);
            t.npA = RGB(43, 47, 56); t.npB = WH(0); t.npText = WH(1); t.npSub = WH(.75);
            t.navAccent = WH(.6); t.segTint = WH(.6);
        } else {
            t.bg = WH(.11); t.rowBg = WH(.14); t.text = WH(.9); t.sub = WH(.6); t.accent = RGB(90, 162, 255); t.warn = RGB(255, 100, 100); t.sep = WH(.06); t.hdrText = WH(.85); t.customHeaders = YES;
            t.miniA = WH(.3); t.miniB = WH(.1); t.miniText = WH(1); t.miniSub = WH(.7);
            t.npA = WH(.2); t.npB = WH(0); t.npText = WH(1); t.npSub = WH(.7);
            t.navAccent = WH(.5); t.segTint = WH(.4);
        }
        t.tabText = WH(.6); t.tabSel = WH(1); t.chipBg = WH(.8); t.chipText = WH(.2); t.chipSelBg = WH(.3); t.chipSelText = WH(1);
        break;
    }
    return t;
}

#pragma mark fonts
- (UIFont *)f:(NSString *)n size:(CGFloat)s bold:(BOOL)b {
    if (n) { UIFont *f = [UIFont fontWithName:n size:s]; if (f) return f; }
    return b ? [UIFont boldSystemFontOfSize:s] : [UIFont systemFontOfSize:s];
}
- (UIFont *)titleFont { return [self f:_fTitle size:_szTitle bold:YES]; }
- (UIFont *)subFont   { return [self f:_fSub size:_szSub bold:NO]; }
- (UIFont *)headFont  { return [self f:_fHead size:_kind == 4 ? 26 : (_kind == 3 ? 14 : 20) bold:YES]; }
- (UIFont *)bigFont   { return [self f:_fBig size:_bigSize bold:YES]; }
- (UIFont *)navFont   { return [self f:_fNav size:_kind == 4 ? 22 : 17 bold:YES]; }
- (UIFont *)chipFont  { return [self f:_kind == 4 ? @"HelveticaNeue-CondensedBold" : (_kind == 3 ? @"Georgia-Bold" : @"HelveticaNeue-Bold") size:_kind == 4 ? 16 : 13 bold:YES]; }
- (UIColor *)bgColor { return _bg; }

#pragma mark artwork
- (UIImage *)art:(UIImage *)src {
    if (!src || _kind == 0) return src;
    static NSCache *cache; if (!cache) cache = [NSCache new];
    NSString *key = [NSString stringWithFormat:@"%p|%d|%d", (__bridge void *)src, _kind, _dark];
    UIImage *hit = [cache objectForKey:key]; if (hit) return hit;
    CGFloat s = _artSize, p = _artPad; CGRect r = CGRectMake(p, 0, s, s);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(p + s, s), NO, 0); CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);
    if (_circleArt) [[UIBezierPath bezierPathWithOvalInRect:r] addClip];
    else if (_artRadius > 0) [[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:_artRadius] addClip];
    [src drawInRect:r];
    CGContextRestoreGState(c);
    if (_kind == 4) { [_text setStroke]; CGContextSetLineWidth(c, 2); CGContextStrokeRect(c, CGRectInset(r, 1, 1)); }
    if (_kind == 3) {
        [RGB(20, 12, 6) setStroke]; CGContextSetLineWidth(c, 2); CGContextStrokeEllipseInRect(c, CGRectInset(r, 1, 1));
        CGPoint m = CGPointMake(p + s / 2, s / 2);
        [RGB(244, 229, 196) setFill]; CGContextFillEllipseInRect(c, CGRectMake(m.x - 5, m.y - 5, 10, 10));
        [RGB(30, 20, 10) setFill]; CGContextFillEllipseInRect(c, CGRectMake(m.x - 2.5, m.y - 2.5, 5, 5));
    }
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    [cache setObject:im forKey:key]; return im;
}

#pragma mark cells / headers
- (void)styleCell:(UITableViewCell *)c {
    c.textLabel.backgroundColor = [UIColor clearColor]; c.detailTextLabel.backgroundColor = [UIColor clearColor];
    c.textLabel.textColor = c.tag == 1 ? _warn : (c.tag == 2 ? _accent : _text);
    c.detailTextLabel.textColor = _sub;
    c.textLabel.font = [self titleFont]; c.detailTextLabel.font = [self subFont];
    if (_upper && c.textLabel.text) c.textLabel.text = [c.textLabel.text uppercaseString];
    CGFloat h = c.bounds.size.height > 1 ? c.bounds.size.height : _rowH;
    UIView *sel = [UIView new]; sel.backgroundColor = _kind == 4 ? _accent : [_accent colorWithAlphaComponent:.28];
    if (_kind == 3) {
        c.backgroundColor = [UIColor clearColor];
        UIView *bv = [[UIView alloc] initWithFrame:c.bounds]; bv.backgroundColor = [UIColor clearColor];
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(6, 3, c.bounds.size.width - 12, h - 6)];
        card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        card.backgroundColor = _rowBg; card.layer.cornerRadius = 8; card.layer.borderWidth = 1; card.layer.borderColor = _sep.CGColor;
        [bv addSubview:card]; c.backgroundView = bv;
        UIView *sv = [[UIView alloc] initWithFrame:c.bounds]; UIView *sc = [[UIView alloc] initWithFrame:CGRectMake(6, 3, c.bounds.size.width - 12, h - 6)];
        sc.autoresizingMask = card.autoresizingMask; sc.backgroundColor = [RGB(255, 196, 64) colorWithAlphaComponent:.55]; sc.layer.cornerRadius = 8; [sv addSubview:sc]; c.selectedBackgroundView = sv;
    } else if (_kind == 4) {
        UIView *bv = [[UIView alloc] initWithFrame:c.bounds]; bv.backgroundColor = c.tag == 2 ? [_accent colorWithAlphaComponent:.14] : _rowBg;
        UIView *rule = [[UIView alloc] initWithFrame:CGRectMake(0, h - 2, c.bounds.size.width, 2)]; rule.backgroundColor = _text;
        rule.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin; [bv addSubview:rule]; c.backgroundView = bv; c.selectedBackgroundView = sel;
    } else {
        c.backgroundColor = _rowBg;
        if (_kind != 0) c.selectedBackgroundView = sel;
    }
}
- (UIView *)headerView:(NSString *)t {
    if (!t.length) return nil;
    CGFloat h = _hdrH; UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, h)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 288, h)]; l.backgroundColor = [UIColor clearColor]; l.font = [self headFont]; l.text = _upper || _kind == 3 ? [t uppercaseString] : t;
    switch (_kind) {
        case 3: {
            UIImageView *iv = [[UIImageView alloc] initWithImage:Grad(CGSizeMake(4, h), RGB(222, 188, 100), RGB(168, 128, 48), RGB(110, 80, 24), NO)]; iv.frame = v.bounds; [v addSubview:iv];
            l.textColor = RGB(58, 36, 18); l.shadowColor = RGBA(255, 240, 200, .7); l.shadowOffset = CGSizeMake(0, 1); break; }
        case 4: v.backgroundColor = _bg; { UIView *r = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 3)]; r.backgroundColor = _text; [v addSubview:r]; } l.frame = CGRectMake(16, 3, 288, h - 3); l.textColor = _text; break;
        case 0: { UIImageView *iv = [[UIImageView alloc] initWithImage:Grad(CGSizeMake(4, h), WH(.34), WH(.22), nil, NO)]; iv.frame = v.bounds; [v addSubview:iv]; l.textColor = WH(.85); l.font = [UIFont boldSystemFontOfSize:15]; break; }
        default: v.backgroundColor = _bg; l.textColor = _text; l.frame = CGRectMake(16, 8, 288, h - 8); break;
    }
    [v addSubview:l]; return v;
}
- (UIView *)footerView:(NSString *)t {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 4, 288, 40)]; l.backgroundColor = [UIColor clearColor]; l.numberOfLines = 2; l.font = [self f:_fSub size:12 bold:NO];
    l.textColor = _kind == 3 ? _hdrText : _sub; l.text = t;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)]; [v addSubview:l]; return v;
}
- (UILabel *)bigLabel:(NSString *)t {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 2, 288, _bigH)]; l.backgroundColor = [UIColor clearColor]; l.font = [self bigFont];
    l.text = _upper ? [t uppercaseString] : t; l.textColor = _kind == 3 ? _hdrText : _text; l.adjustsFontSizeToFitWidth = YES; l.minimumScaleFactor = .6;
    if (_kind == 3) { l.shadowColor = [UIColor blackColor]; l.shadowOffset = CGSizeMake(0, 1); }
    return l;
}

#pragma mark chips / buttons
- (void)styleChip:(UIButton *)b sel:(BOOL)s {
    b.backgroundColor = s ? _chipSelBg : _chipBg; [b setTitleColor:s ? _chipSelText : _chipText forState:UIControlStateNormal];
    b.layer.cornerRadius = _kind == 4 ? 0 : (_kind == 3 ? 6 : 15);
    b.layer.borderWidth = _kind == 4 ? 2 : (_kind == 3 ? 1 : 0); b.layer.borderColor = (_kind == 4 ? _text : RGB(110, 80, 24)).CGColor;
    b.layer.shadowColor = RGB(255, 190, 60).CGColor; b.layer.shadowOpacity = (_kind == 3 && s) ? 1 : 0; b.layer.shadowRadius = 7; b.layer.shadowOffset = CGSizeZero;
}
- (UIView *)chipBar:(id)target action:(SEL)act selected:(int)sel {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, _chipH)]; sv.showsHorizontalScrollIndicator = NO; sv.backgroundColor = [UIColor clearColor];
    NSArray *t = @[@"All", @"Music", @"Podcasts", @"Audiobooks"]; CGFloat x = 14;
    for (int i = 0; i < 4; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; b.tag = i;
        [b setTitle:_upper ? [t[i] uppercaseString] : t[i] forState:UIControlStateNormal]; b.titleLabel.font = [self chipFont];
        CGFloat w = [b.titleLabel.text sizeWithFont:b.titleLabel.font].width + 28; b.frame = CGRectMake(x, (_chipH - 30) / 2, w, 30);
        [b addTarget:target action:act forControlEvents:UIControlEventTouchUpInside]; [sv addSubview:b]; x += w + 8; [self styleChip:b sel:i == sel];
    }
    sv.contentSize = CGSizeMake(x + 6, _chipH); return sv;
}
- (void)selectChips:(UIView *)bar index:(int)i { for (UIView *v in bar.subviews) if ([v isKindOfClass:[UIButton class]]) [self styleChip:(UIButton *)v sel:v.tag == i]; }
- (UIButton *)button:(NSString *)t primary:(BOOL)p {
    if (_kind == 0) { UIButton *b = [UIButton buttonWithType:UIButtonTypeRoundedRect]; [b setTitle:t forState:UIControlStateNormal]; b.titleLabel.font = [UIFont boldSystemFontOfSize:12]; return b; }
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom]; [b setTitle:_upper ? [t uppercaseString] : t forState:UIControlStateNormal];
    b.titleLabel.font = [self chipFont]; [self styleChip:b sel:p]; if (_kind == 3 || _kind == 4) b.layer.shadowOpacity = 0; return b;
}

#pragma mark bars
- (UIImage *)tabBgImage { return Grad(CGSizeMake(4, 49), _tabA, _tabB, _kind == 3 ? RGB(201, 162, 75) : (_kind == 1 ? _navLine : nil), YES); }
- (UIImage *)tabSelImage {
    if (_kind == 4) return [[TBTheme solid:_accent] resizableImageWithCapInsets:UIEdgeInsetsZero];
    if (_kind == 3) return [[TBTheme solid:RGBA(255, 176, 32, .20)] resizableImageWithCapInsets:UIEdgeInsetsZero];
    return [[TBTheme solid:[UIColor clearColor]] resizableImageWithCapInsets:UIEdgeInsetsZero];
}
- (UIImage *)fieldImage {
    CGFloat r = _kind == 4 ? 0 : (_kind == 3 ? 6 : 14);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(.5, 3.5, 29, 23) cornerRadius:r];
    UIColor *f = _kind == 3 ? RGB(244, 229, 196) : (_kind == 4 ? _bg : (_dark ? RGB(44, 44, 46) : RGB(236, 236, 240)));
    [f setFill]; [p fill]; if (_kind == 4) { [_text setStroke]; p.lineWidth = 2; [p stroke]; }
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    return [im resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 14, 14)];
}
- (void)styleSearchBar:(UISearchBar *)b {
    if (_kind == 0) { b.tintColor = WH(.7); return; }
    [b setBackgroundImage:[TBTheme solid:_kind == 3 ? RGB(70, 40, 18) : _bg]];
    [b setSearchFieldBackgroundImage:[self fieldImage] forState:UIControlStateNormal];
    for (UIView *v in b.subviews) if ([v isKindOfClass:[UITextField class]]) { UITextField *tf = (UITextField *)v; tf.textColor = _kind == 3 ? RGB(58, 36, 18) : _text; tf.font = [self f:_fSub size:15 bold:NO]; }
    b.tintColor = _kind == 3 ? RGB(201, 162, 75) : _chipBg;
}
- (UIImage *)backImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0); CGContextRef c = UIGraphicsGetCurrentContext();
    [_navAccent setStroke]; CGContextSetLineWidth(c, 3); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
    CGContextMoveToPoint(c, 14, 7); CGContextAddLineToPoint(c, 7, 15); CGContextAddLineToPoint(c, 14, 23); CGContextStrokePath(c);
    UIImage *im = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    return [im resizableImageWithCapInsets:UIEdgeInsetsMake(0, 22, 0, 4)];
}

- (void)applyAppearance {
    UINavigationBar *nb = [UINavigationBar appearance]; UIBarButtonItem *bi = [UIBarButtonItem appearance];
    UIOffset z = UIOffsetZero;
    if (_kind == 0) {
        [nb setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault]; [nb setShadowImage:nil];
        [nb setTintColor:_dark ? WH(.28) : WH(.78)];
        [nb setTitleTextAttributes:@{UITextAttributeTextColor:_dark ? WH(.92) : WH(.3), UITextAttributeTextShadowColor:_dark ? WH(0) : WH(1), UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0, _dark ? -1 : 1)], UITextAttributeFont:[UIFont boldSystemFontOfSize:20]}];
        [bi setTintColor:_dark ? WH(.45) : WH(.6)];
        [bi setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [bi setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [bi setBackButtonBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [bi setTitleTextAttributes:nil forState:UIControlStateNormal];
        [bi setBackButtonTitlePositionAdjustment:z forBarMetrics:UIBarMetricsDefault];
        [[UITabBar appearance] setBackgroundImage:nil]; [[UITabBar appearance] setSelectionIndicatorImage:nil];
    } else {
        [nb setBackgroundImage:[Grad(CGSizeMake(4, 44), _navA, _navB, _navLine, NO) resizableImageWithCapInsets:UIEdgeInsetsMake(0, 1, 0, 1)] forBarMetrics:UIBarMetricsDefault];
        [nb setShadowImage:[UIImage new]];
        [nb setTitleTextAttributes:@{UITextAttributeTextColor:_navText, UITextAttributeFont:[self navFont], UITextAttributeTextShadowColor:_kind == 3 ? RGBA(0, 0, 0, .7) : [UIColor clearColor], UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0, _kind == 3 ? -1 : 0)]}];
        UIImage *clear = [[TBTheme solid:[UIColor clearColor]] resizableImageWithCapInsets:UIEdgeInsetsZero];
        [bi setBackgroundImage:clear forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [bi setBackgroundImage:clear forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        NSDictionary *ta = @{UITextAttributeTextColor:_navAccent, UITextAttributeFont:[self f:_fTitle size:_kind == 4 ? 17 : 16 bold:YES], UITextAttributeTextShadowColor:[UIColor clearColor], UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:z]};
        [bi setTitleTextAttributes:ta forState:UIControlStateNormal]; [bi setTitleTextAttributes:ta forState:UIControlStateHighlighted];
        [bi setBackButtonBackgroundImage:[self backImage] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [bi setBackButtonTitlePositionAdjustment:UIOffsetMake(2, 0) forBarMetrics:UIBarMetricsDefault];
        [[UITabBar appearance] setBackgroundImage:[self tabBgImage]]; [[UITabBar appearance] setSelectionIndicatorImage:[self tabSelImage]];
    }
    [[UISegmentedControl appearance] setTintColor:_segTint];
    BOOL darkBar = _dark || _kind == 3 || (_kind == 4 && _dark);
    [[UIApplication sharedApplication] setStatusBarStyle:darkBar ? UIStatusBarStyleBlackOpaque : UIStatusBarStyleDefault];
}
@end
