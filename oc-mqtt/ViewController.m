//
//  ViewController.m
//  oc-mqtt
//
//  Created by Li Meng on 2018/8/22.
//  Copyright © 2018年 Li Meng. All rights reserved.
//

#import "ViewController.h"
#import "MQTTClient.h"
#import "NSData+ZstdCompression.h"

@interface ViewController ()<MQTTSessionDelegate>{
    MQTTSession *session;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
//    [self setupSubViews];
    // Do any additional setup after loading the view, typically from a nib.
//    [self subscribeMQTT];
}

//- (void)viewWillAppear:(BOOL)animated{
//    [super viewWillAppear:animated];
//    [self.navigationController setNavigationBarHidden:NO animated:YES];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupSubViews {
    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    startBtn.frame = CGRectMake(0, 44, 44,44);
    [startBtn setTitle:@"开始" forState:UIControlStateNormal];
    [startBtn setBackgroundColor:[UIColor blackColor]];
    startBtn.contentMode = UIViewContentModeScaleToFill;
    [startBtn addTarget:self action:@selector(subscribeMQTT) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:startBtn];
}

- (void)setupNavigationBar {
//    [self.navigationController.navigationBar setBackgroundColor:[UIColor blackColor]];
//    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationItem.title = @"MQTT订阅";
}

- (void) subscribeMQTT {
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
