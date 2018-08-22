//
//  AppDelegate.h
//  oc-mqtt
//
//  Created by Li Meng on 2018/8/22.
//  Copyright © 2018年 Li Meng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

