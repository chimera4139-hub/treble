#import <Foundation/Foundation.h>
extern NSString *const TBPlayerChanged;
@interface TBPlayer : NSObject
@property (readonly) NSString *curId;
@property (readonly) BOOL playing;
@property NSArray *list;
@property BOOL shuffle;
@property int repeat; // 0 off, 1 all, 2 one
+ (TBPlayer *)shared;
- (void)startSession;
- (void)play:(NSString *)sid inList:(NSArray *)l;
- (void)toggle;
- (void)next;
- (void)prev;
- (void)seek:(double)sec;
- (double)position;
- (double)duration;
- (void)setSpeed:(float)r;      // per song, remembered
- (void)applyEQ;
- (void)applyRate;
- (void)enqueue:(NSString *)sid atFront:(BOOL)front;
- (void)trackEnded;
@end
