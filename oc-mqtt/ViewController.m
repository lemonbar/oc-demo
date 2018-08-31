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
    transport.host = @"132.232.34.246";
    transport.port = 1883;
    
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
        [self handleRowContent:tmp];
        [content appendString:tmp];
        [content appendString:@";"];
    }
    textView.text = content;
}

- (void) handleRowContent:(NSString *)content {
    NSLog(@"%@",content);
    if (content.length == 0) {
        return;
    }
    NSUInteger sepLoc = [content rangeOfString:@"="].location;
    if (sepLoc == NSNotFound) {
        return;
    }
    NSString *keyString = [content substringToIndex:sepLoc];
    NSString *valueString = [content substringFromIndex:sepLoc+1];
    if ([keyString isEqualToString:@"tbq"]) {
        NSString *decodeValueString = [self decodeString:valueString];
        NSLog(@"%@",decodeValueString);
    }
}

#define BASE_POW_MAX_LEN  (30)
#define NUMBER_LEN 128

static const char BaseIndex [] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,1,2,3,4,5,6,7,8,9,0,10,11,12,
    13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,
    29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,
    45,46,47,48,49,50,51,52,53,54,55,0,56,0,57,58,
    59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,
    75,76,77,78,79,80,81,82,83,84,85,0,0,0,86,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
};

// 0 ~ BASE_POW_MAX_LEN
const char *BasePowList [BASE_POW_MAX_LEN+1] = {
    "1",
    "87",
    "7569",
    "658503",
    "57289761",
    "4984209207",
    "433626201009",
    "37725479487783",
    "3282116715437121",
    "285544154243029527",
    "24842341419143568849",
    "2161283703465490489863",
    "188031682201497672618081",
    "16358756351530297517773047",
    "1423211802583135884046255089",
    "123819426824732821912024192743",
    "10772290133751755506346104768641",
    "937189241636402729052111114871767",
    "81535464022367037427533666993843729",
    "7093585369945932256195429028464404423",
    "617141927185296106289002325476403184801",
    "53691347665120761247143202316447077077687",
    "4671147246865506228501458601530895705758769",
    "406389810477299041879626898333187926401012903",
    "35355913511525016643527540154987349596888122561",
    "3075964475502676447986895993483899414929266662807",
    "267608909368732850974859951433099249098846199664209",
    "23281975115079758034812815774679634671599619370786183",
    "2025531835011938949028714972397128216429166885258397921",
    "176221269646038688565498202598550154829337519017480619127",
    "15331250459205365905198343626073863470152364154520813864049",
};

static char *getBaseIndexCharFormBaseChar(char s){
    char *ret;
    asprintf(&ret,"%d", BaseIndex[s]);
    return ret;
}

static char* Add(char* a,char* b){
    int maxlen = fmax(strlen(a),strlen(b));
    char* p = (char*) malloc(maxlen+2);
    char* pA=a+strlen(a)-1;
    char* pB=b+strlen(b)-1;
    int m=0;
    int n=0;
    int c=0;
    int i=0;
    
    memset(p, 0,maxlen+2);
    for (i=0;i<maxlen;i++){
        m = n = 0;
        if ((pA+1) != a){
            m = *pA - 48;
            pA--;
        }
        
        if ((pB+1) != b){
            n = *pB - 48;
            pB--;
        }
        
        *(p+i) = (m+n+c) % 10 + 48;
        c = (m+n+c) / 10;
    }
    if (c>0){
        *(p+i) = 48 + c;
        *(p+i+1) = '\0';
    }
    else{
        *(p+i) = '\0';
    }
    Reverse(p);
    return p;
}

void Reverse(char* a){
    int len1=strlen(a)-1;
    int len2=(len1+1)/2;
    char temp;
    int i;
    for (i=0;i<len2;i++){
        temp=a[i];
        a[i]=a[len1-i];
        a[len1-i]=temp;
    }
    return;
}

static char* Mult(char* a,char* b){
    int lenA =strlen(a);
    int lenB =strlen(b);
    
    char* p = (char*) malloc(lenA+lenB+1);
    memset(p, 0, lenA+lenB+1);
    
    char* pA=a+lenA-1;
    char* pB=b+lenB-1;
    int m=0;
    int n=0;
    int c=0;
    
    int s=0;
    int i=0;
    int j=0;
    for (i=0;i<lenA;i++){
        m = *(pA-i) - 48;
        c=0;
        for (j=0;j<lenB;j++)    {
            n = *(pB-j) - 48;
            if((*(p+i+j)>='0')&&(*(p+i+j)<='9')){
                s = *(p+i+j) - 48;
            }
            else{
                s = 0;
            }
            *(p+i+j) = (m*n+c+s) % 10 + 48;
            c = (m*n+c+s) / 10;
        }
        *(p+i+j) = 48 + c;
    }
    if (c>0){
        *(p+i+j) = '\0';
    }
    else{
        *(p+i+j-1) = '\0';
    }
    Reverse(p);
    return p;
}

- (NSString *) decodeString:(NSString *)str {
    NSString *filterString = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    char *cStr = (char *)[filterString cStringUsingEncoding:NSASCIIStringEncoding];
    
    size_t baseStrLen = strlen(cStr);
    if (baseStrLen < 1 || baseStrLen > BASE_POW_MAX_LEN) {
        return filterString;
    }
    
    bool isFoundNeg = 0;
    if(baseStrLen > 1 && cStr[0]==BaseChar[0]){
        isFoundNeg = 1;
        baseStrLen-=1;
        memcpy(cStr, cStr+1, baseStrLen);
    }
    
    int i,j;
    //char baseArray[NUMBER_LEN];
    char *baseArray = (char *)malloc(NUMBER_LEN);
    memset(baseArray, 0, NUMBER_LEN);
    //char *baseArray = (char *)"";
    
    char *dat;
    char *pow;
    char *m;
    char *add;
    for(i = 0 ; i < baseStrLen; ++i){
        
        dat = getBaseIndexCharFormBaseChar(cStr[i]);
        if(i>0 && dat[0] == '0'){
            if(dat != NULL){free(dat);}
            continue;
        }
        
        pow = (char*)BasePowList[baseStrLen -1 -i];
        m = Mult(dat, pow);
        
        add = Add(baseArray, m);
        
        memcpy(baseArray, add, strlen(add));
        
        if(dat != NULL){free(dat);}
        if(m != NULL){free(m);}
        if(add != NULL){free(add);}
    }
    
    //printf("==>> %s, %d, %x\n", baseArray, (baseArray[0]!=0), baseArray[0]);
    
    if(isFoundNeg){
        if(baseArray[0]!='0'){
            memcpy(baseArray+1, baseArray, strlen(baseArray));
            baseArray[0]='-';
        }
    }
    
    if (baseArray) {
        NSString *decodeString = [NSString stringWithCString:baseArray encoding:NSASCIIStringEncoding];
        free(baseArray);
        baseArray = NULL;
        return decodeString;
    }
    
    return filterString;
}

static int *initBaseArray(char *decStr, int lenDecStr){
    int * pArray = NULL;
    int i;
    
    pArray = (int *) calloc (lenDecStr,  sizeof (int));
    
    for (i = 0; i < lenDecStr; i++){
        addDecValue (pArray, lenDecStr, decStr[i] - '0');
    }
    return (pArray);
}

//ascii 32~126
static const char BaseChar [] = {
    //' ',
    '!',
    //'"',
    '#', '$', '%', '&', 0x27, '(', ')', '*', '+',   //12
    
    //',',
    
    '-', '.', '/',  // 3
    
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',  // 10
    
    ':', ';', '<', '=', '>', '?', '@',  //7
    
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',  // 26
    
    //'[',
    
    '\\',
    
    //']',
    
    '^', '_', 0x60,
    
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',  // 26
    
    //'{', '|',    '}',
    
    '~',
};

static int BASE = sizeof(BaseChar);

static void addDecValue (int * pArray, int n, int carry){
    int tmp = 0;
    int i;
    
    for (i = (n-1); (i >= 0); i--){
        tmp = (pArray[i] * 10) + carry;
        pArray[i] = tmp % BASE;
        carry = tmp / BASE;
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
