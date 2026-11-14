#import <UIKit/UIKit.h>
#import "Screens.h"
#import "TBStore.h"
#import "TBPlayer.h"
#import "TBTheme.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o {
    TBStyleAppearance();
    [[TBPlayer shared] startSession];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = TBMakeTabs();
    [self.window makeKeyAndVisible];
    [[TBStore shared] scan];
    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(themeTick) userInfo:nil repeats:YES];
    return YES;
}
- (void)themeTick { TBThemeTick(); }
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)a { [[TBStore shared] purge]; [TBTheme purge]; }
- (void)applicationDidBecomeActive:(UIApplication *)a { TBThemeTick(); }
- (void)applicationDidEnterBackground:(UIApplication *)a { [[TBStore shared] save]; }
- (void)applicationWillEnterForeground:(UIApplication *)a { [[TBStore shared] scan]; }
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
