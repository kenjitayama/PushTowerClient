#import "PTClient.h"
#import <UIKit/UIApplication.h>
#import <objc/runtime.h>

@implementation PTClient

static IMP didRegisterOriginalMethod = NULL;

+ (void)load {
    NSLog(@"##### load");
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

        [PTClient setup];
    }];
}

+ (void)setup {
    UIApplication *app = [UIApplication sharedApplication];
    id<UIApplicationDelegate> appDelegate = app.delegate;


    // didRegisterForRemoteNotificationsWithDeviceToken swizzle
    Method didRegisterMethod = class_getInstanceMethod([PTClient class], @selector(my_application:didRegisterForRemoteNotificationsWithDeviceToken:));
    IMP didRegisterMethodImp = method_getImplementation(didRegisterMethod);
    const char* didRegisterTypes = method_getTypeEncoding(didRegisterMethod);

    Method didRegisterOriginal = class_getInstanceMethod(appDelegate.class, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    if (didRegisterOriginal) {
        didRegisterOriginalMethod = method_getImplementation(didRegisterOriginal);
        method_exchangeImplementations(didRegisterOriginal, didRegisterMethod);
    } else {
        class_addMethod(appDelegate.class, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:), didRegisterMethodImp, didRegisterTypes);
    }
}

- (void)my_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if (didRegisterOriginalMethod) {
        void (*originalImp)(id, SEL, UIApplication *, NSData *) = didRegisterOriginalMethod;
        originalImp(self, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:), application, deviceToken);
    }
    NSLog(@"###### %@", deviceToken);
}

@end
