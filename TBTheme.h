#import <UIKit/UIKit.h>
// 0 Old Apple (iOS 6), 1 Modern, 2 Spotify, 3 FM (jukebox), 4 Poster
@interface TBTheme : NSObject
@property (nonatomic) int kind;
@property (nonatomic) BOOL dark;
@property (nonatomic, strong) UIColor *bg, *rowBg, *text, *sub, *accent, *warn, *sep, *hdrText;
@property (nonatomic, strong) UIColor *chipBg, *chipText, *chipSelBg, *chipSelText, *segTint;
@property (nonatomic, strong) UIColor *miniA, *miniB, *miniText, *miniSub, *npA, *npB, *npText, *npSub;
@property (nonatomic, strong) UIColor *tabA, *tabB, *tabText, *tabSel, *navA, *navB, *navLine, *navText, *navAccent;
@property (nonatomic) CGFloat rowH, artSize, artPad, artRadius, hdrH, bigH, bigSize, miniH, miniInset, chipH, szTitle, szSub;
@property (nonatomic) BOOL largeTitle, pills, showSep, floatMini, circleArt, upper, customHeaders;
@property (nonatomic, copy) NSString *fTitle, *fSub, *fHead, *fBig, *fNav;
+ (TBTheme *)cur;
+ (void)reload;
+ (NSArray *)names;
+ (NSArray *)modeNames;
+ (void)purge;
+ (UIImage *)solid:(UIColor *)c;
+ (UIImage *)vinyl:(CGFloat)s;
- (UIColor *)bgColor;                       // pattern (wood) or plain
- (UIFont *)titleFont; - (UIFont *)subFont; - (UIFont *)headFont; - (UIFont *)bigFont; - (UIFont *)navFont; - (UIFont *)chipFont;
- (UIImage *)art:(UIImage *)src;           // themed row artwork
- (void)styleCell:(UITableViewCell *)c;
- (UIView *)headerView:(NSString *)t;
- (UIView *)footerView:(NSString *)t;
- (UILabel *)bigLabel:(NSString *)t;
- (UIView *)chipBar:(id)target action:(SEL)act selected:(int)sel;
- (void)selectChips:(UIView *)bar index:(int)i;
- (UIButton *)button:(NSString *)t primary:(BOOL)p;
- (UIImage *)tabBgImage;
- (UIImage *)tabSelImage;
- (UIImage *)fieldImage;
- (void)styleSearchBar:(UISearchBar *)b;
- (void)applyAppearance;
@end
