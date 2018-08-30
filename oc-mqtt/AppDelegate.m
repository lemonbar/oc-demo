//
//  AppDelegate.m
//  oc-mqtt
//
//  Created by Li Meng on 2018/8/22.
//  Copyright © 2018年 Li Meng. All rights reserved.
//

#import "AppDelegate.h"
#import "MQTTClient.h"
#import "NSData+ZstdCompression.h"

@interface AppDelegate ()<MQTTSessionDelegate>{
    MQTTSession *session;
}

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    MQTTCFSocketTransport *transport = [[MQTTCFSocketTransport alloc] init];
    transport.host = @"58.63.252.24";
    transport.port = 22017;
    
    session = [[MQTTSession alloc] init];
    session.delegate = self;
    session.transport = transport;
    [session connectWithConnectHandler:^(NSError *error) {
        if(error){
            NSLog(@"connect failed %@", error.localizedDescription);
            return;
        }
        NSLog(@"connect successful");
        [self->session subscribeToTopic:@"600298.sh" atLevel:MQTTQosLevelAtMostOnce subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss) {
            if(error){
                NSLog(@"Subscription failed %@", error.localizedDescription);
            }else{
                NSLog(@"Subscription successful, granted Qos: %@",gQoss);
            }
        }];
    }];
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}


#pragma mark - Core Data stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
    // The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it.
    @synchronized (self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"oc_mqtt"];
            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
                if (error != nil) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    
                    /*
                     Typical reasons for an error here include:
                     * The parent directory does not exist, cannot be created, or disallows writing.
                     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                     * The device is out of space.
                     * The store could not be migrated to the current model version.
                     Check the error message to determine what the actual problem was.
                    */
                    NSLog(@"Unresolved error %@, %@", error, error.userInfo);
                    abort();
                }
            }];
        }
    }
    
    return _persistentContainer;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *context = self.persistentContainer.viewContext;
    NSError *error = nil;
    if ([context hasChanges] && ![context save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, error.userInfo);
        abort();
    }
}

#pragma MQTTSessionDelegate
-(void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid{
    NSLog(@"%lu",(unsigned long)data.length);
    NSData *d_data = [data decompressZstd];
    Byte b = 0x02;
    NSData *seperator = [NSData dataWithBytes:&b length:1];
    NSString *str = [[NSString alloc] initWithData:d_data encoding:NSUTF8StringEncoding];
    NSLog(@"topic: %@, content: %@",topic, str);
    NSArray *arr = [self componentsSeparatedByData:seperator forData:d_data];
    [self parseData:arr];
}

-(void)parseData:(NSArray *)arr {
    for (NSData *row in arr) {
        NSString *tmp = [[NSString alloc] initWithData:row encoding:NSUTF8StringEncoding];
        NSLog(@"%@",tmp);
    }
}

- (NSArray *)componentsSeparatedByData:(NSData *)data forData:(NSData *)raw {
    NSMutableArray *rows = [NSMutableArray array];
    
    NSInteger dataLength = [raw length];
    NSInteger splitDataLength = [data length];
    NSInteger currentLocation = 0;
    NSRange range = [raw rangeOfData:data options:0 range:NSMakeRange(
                                                                       currentLocation, dataLength - currentLocation
                                                                       )];
    while (range.location != NSNotFound) {
        NSData *d = [raw subdataWithRange:NSMakeRange(currentLocation, range.location-currentLocation)];
        
        [rows addObject:d];
        
        currentLocation = range.location + splitDataLength;
        range = [raw rangeOfData:data options:0 range:NSMakeRange (
                                                                    currentLocation, dataLength - currentLocation
                                                                    )];
        
    }
    if (currentLocation != dataLength) {
        NSData *d = [raw subdataWithRange:NSMakeRange(
                                                       currentLocation, dataLength - currentLocation
                                                       )];
        [rows addObject:d];
    }
    return rows;
}

@end
