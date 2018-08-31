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
    NSString *topic;
    UITextField *topicField;
    UITextView *textView;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupNavigationBar];
    [self setupSubViews];
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
    CGFloat barHeight = [[UIApplication sharedApplication] statusBarFrame].size.height + self.navigationController.navigationBar.frame.size.height;
    //输入框
    CGFloat heightCursor = barHeight;
    CGFloat fieldHeight = 52;
    CGFloat width = [UIScreen mainScreen].bounds.size.width - 30;
    topicField = [[UITextField alloc] initWithFrame:CGRectMake(15, heightCursor, width, fieldHeight)];
    topicField.placeholder = @"请输入topic";
    topicField.text = @"600298.sh";
    
    [self.view addSubview:topicField];
    heightCursor += fieldHeight;
    
    //按钮
    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    startBtn.frame = CGRectMake(15, heightCursor, width/2, fieldHeight);
    [startBtn setTitle:@"开始" forState:UIControlStateNormal];
    [startBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [startBtn addTarget:self action:@selector(subscribeMQTT) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:startBtn];
    
    UIButton *endBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    endBtn.frame = CGRectMake(15 + width/2, heightCursor, width/2, fieldHeight);
    [endBtn setTitle:@"结束" forState:UIControlStateNormal];
    [endBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [endBtn addTarget:self action:@selector(unsubscribeMQTT) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:endBtn];
    heightCursor += fieldHeight;
    
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    textView = [[UITextView alloc] init];
    textView.frame = CGRectMake(15, heightCursor, width, screenHeight - heightCursor);
    textView.textColor = [UIColor blackColor];
    textView.font = [UIFont boldSystemFontOfSize:16];
    [textView setEditable:NO];
    textView.scrollEnabled = YES;
    
    [self.view addSubview:textView];
    
//    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    startBtn.frame = CGRectMake(0, 44, 44,44);
//    [startBtn setTitle:@"开始" forState:UIControlStateNormal];
//    [startBtn setBackgroundColor:[UIColor blackColor]];
//    startBtn.contentMode = UIViewContentModeScaleToFill;
//    [startBtn addTarget:self action:@selector(subscribeMQTT) forControlEvents:UIControlEventTouchUpInside];
//
//    [self.view addSubview:startBtn];
}

- (void)setupNavigationBar {
//    [self.navigationController.navigationBar setBackgroundColor:[UIColor blackColor]];
//    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.title = @"MQTT订阅";
//    self.navigationItem.title = @"MQTT订阅";
}

- (void) unsubscribeMQTT {
    [session unsubscribeTopic:topic unsubscribeHandler:^(NSError *error) {
        if (error) {
            NSLog(@"unsubscribeTopic failed %@", error.localizedDescription);
        }
        [self->session disconnect];
    }];
}

- (void) alertString:(NSString *)content{
    //初始化提示框；
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:content preferredStyle:  UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //点击按钮的响应事件；
    }]];
    
    //弹出提示框；
    [self presentViewController:alert animated:true completion:nil];

}

- (void) subscribeMQTT {
    topic = [topicField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(topic == nil || topic.length == 0){
        [self alertString:@"topic不能为空"];
        return;
    }
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
        [self->session subscribeToTopic:self->topic atLevel:MQTTQosLevelAtMostOnce subscribeHandler:^(NSError *error, NSArray<NSNumber *> *gQoss) {
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
    NSMutableString *content = [NSMutableString stringWithCapacity:100];
    for (NSData *row in arr) {
        NSString *tmp = [[NSString alloc] initWithData:row encoding:NSUTF8StringEncoding];
        [content appendString:tmp];
        [content appendString:@";"];
//        NSLog(@"%@",tmp);
    }
    textView.text = content;
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
