#import "PTClient.h"
#import <UIKit/UIApplication.h>
#import <objc/runtime.h>

@implementation PTClient

static IMP didRegisterOriginalMethod = NULL;

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

#ifdef DEBUG
        [PTClient setup];
#endif
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

    // URL
    NSString *putDeviceTokenURLString = [[[NSProcessInfo processInfo]environment]objectForKey:@"PUSHTOWER_PUT_TOKEN_URL"];
    NSURL *putDeviceTokenURL = [NSURL URLWithString:putDeviceTokenURLString];
    if (!putDeviceTokenURL) {
        NSLog(@"URL from environment variable PUSHTOWER_PUT_TOKEN_URL is invalid: %@", putDeviceTokenURLString);
        return;
    }

    // x-topic header
    NSString *topic = [[NSBundle mainBundle] bundleIdentifier];

    // body
    NSString *deviceTokenKey = [[UIDevice currentDevice] name]; // use device name
    NSString *deviceTokenHex = [self stringWithDeviceToken:deviceToken];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    [dict setValue:deviceTokenKey forKey:@"key"];
    [dict setValue:deviceTokenHex forKey:@"device_token"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict
                                                   options:kNilOptions
                                                     error:nil];

    // request
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:putDeviceTokenURL];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:topic forHTTPHeaderField:@"x-topic"];
    [request setHTTPBody:data];

    // send
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:nil
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionTask *task = [session dataTaskWithRequest:request
                                        completionHandler:^(NSData * _Nullable data,
                                                            NSURLResponse * _Nullable response,
                                                            NSError * _Nullable error) {

                                            if (error) {
                                                NSLog(@"error: %@", error);
                                            }
                                        }];
    [task resume];
}

- (NSString *)stringWithDeviceToken:(NSData *)deviceToken {
    const char *data = [deviceToken bytes];
    NSMutableString *token = [NSMutableString string];
    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [token appendFormat:@"%02.2hhX", data[i]];
    }
    return [token copy];
}

@end
