#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
extern NSString *const TBChanged;
NSString *TBRoot(void);
NSArray *TBPresetNames(void);
NSArray *TBPresetGains(NSString *name);
@interface TBStore : NSObject
@property NSMutableDictionary *songs;   // id -> song dict
@property NSMutableArray *pls;          // playlist dicts
@property NSMutableDictionary *queue;   // {ids:[...]}
@property NSMutableDictionary *plays;   // id -> count
@property NSMutableArray *recent;
@property NSMutableArray *searches;
@property double secs;
@property int impMode;                  // 0 = folders become playlists, 1 = songs only
@property NSString *impKind;            // music / podcast / book
@property NSString *kind;               // UI filter: all / music / podcast / book
@property BOOL eqOn, keepPitch;
@property NSString *eqPreset;
@property NSMutableArray *eqGains;
+ (TBStore *)shared;
- (void)save;
- (void)scan;
- (NSDictionary *)song:(NSString *)sid;
- (NSArray *)allIds;
- (NSArray *)sorted:(NSArray *)ids by:(NSString *)key;
- (NSMutableDictionary *)newPlaylistNamed:(NSString *)n ids:(NSArray *)ids kind:(NSString *)k;
- (NSString *)path:(NSDictionary *)song;
- (UIImage *)thumbForSong:(NSDictionary *)s;
- (UIImage *)thumbForPlaylist:(NSDictionary *)p;
- (void)saveCover:(UIImage *)im forPlaylist:(NSMutableDictionary *)p;
- (void)deleteSong:(NSString *)sid;
@end
