//
//  AppDelegate.m
//  EventDemo
//
//  Created by Anton Bohomol on 10/30/15.
//  Copyright © 2015 CYBERVISION INC. All rights reserved.
//

#import "AppDelegate.h"
#import <Kaa/Kaa.h>

#define USER_EXTERNAL_ID    @"user@email.com"
#define USER_ACCESS_TOKEN   @"token"

@interface AppDelegate () <KaaClientStateDelegate,UserAttachDelegate,ThermostatEventClassFamilyDelegate,FindEventListenersDelegate>

@property (nonatomic,strong) id<KaaClient> kaaClient;
@property (nonatomic,strong) ThermostatEventClassFamily *tecf;
@property (nonatomic,strong) EventFamilyFactory *eventFamilyFactory;

- (void)onUserAttached;

@end

@implementation AppDelegate

- (void)onAttachResult:(UserAttachResponse *)response {
    NSLog(@"Attach response: %i", response.result);
    
    if (response.result == SYNC_RESPONSE_RESULT_TYPE_SUCCESS) {
        NSLog(@"Endpoint successfully attached!");
        [self onUserAttached];
    } else {
        NSLog(@"Endpoint attach failed: event demo stopped");
    }
}

- (void)onStarted {
    NSLog(@"Kaa client started");
}

- (void)onStartFailure:(NSException *)exception {
    NSLog(@"START FAILURE: %@ : %@", exception.name, exception.reason);
}

- (void)onResume {
    
}

- (void)onResumeFailure:(NSException *)exception {
    
}

- (void)onStopped {
    NSLog(@"Kaa client stopped");
}

- (void)onStopFailure:(NSException *)exception {
    NSLog(@"STOP FAILURE: %@ : %@", exception.name, exception.reason);
}

- (void)onPaused {
    
}

- (void)onPauseFailure:(NSException *)exception {
    
}

- (void)onThermostatInfoRequest:(ThermostatInfoRequest *)event from:(NSString *)source {
    NSLog(@"onThermostatInfoRequest event received! Sender: %@", source);
    
    ThermostatInfo *info = [[ThermostatInfo alloc] init];
    info.degree = [KAAUnion unionWithBranch:KAA_UNION_INT_OR_NULL_BRANCH_0 andData:[NSNumber numberWithInt:-95]];
    info.targetDegree = [KAAUnion unionWithBranch:KAA_UNION_INT_OR_NULL_BRANCH_0 andData:[NSNumber numberWithInt:-96]];
    info.isSetManually = [KAAUnion unionWithBranch:KAA_UNION_BOOLEAN_OR_NULL_BRANCH_0 andData:[NSNumber numberWithBool:YES]];
    
    ThermostatInfoResponse *response = [[ThermostatInfoResponse alloc] init];
    response.thermostatInfo = [KAAUnion unionWithBranch:KAA_UNION_THERMOSTAT_INFO_OR_NULL_BRANCH_0 andData:info];
    
    [self.tecf sendThermostatInfoResponse:response to:source];
}
- (void)onThermostatInfoResponse:(ThermostatInfoResponse *)event from:(NSString *)source {
    NSLog(@"ThermostatInfoResponse event received! Thermostat info: %@, sender: %@", (ThermostatInfo *)event.thermostatInfo.data, source);
    
}
- (void)onChangeDegreeRequest:(ChangeDegreeRequest *)event from:(NSString *)source {
    NSLog(@"ChangeDegreeRequest event received! change temperature by %@ degrees, sender: %@", ((NSNumber *)event.degree.data), source);
}

- (void)onUserAttached {
    NSArray *listenerFQNs = [NSArray arrayWithObjects:[ThermostatInfoRequest FQN], [ChangeDegreeRequest FQN], nil];
    
    //Obtain the event family factory.
    self.eventFamilyFactory = [self.kaaClient getEventFamilyFactory];
    //Obtain the concrete event family.
    self.tecf = [self.eventFamilyFactory getThermostatEventClassFamily];
    
    // Broadcast the ChangeDegreeRequest event.
    ChangeDegreeRequest *changeDegree = [[ChangeDegreeRequest alloc] init];
    changeDegree.degree = [KAAUnion unionWithBranch:KAA_UNION_INT_OR_NULL_BRANCH_0 andData:[NSNumber numberWithInt:-97]];
    [self.tecf sendChangeDegreeRequestToAll:changeDegree];
    NSLog(@"Broadcast ChangeDegreeRequest sent");

    // Add event listeners to the family factory.
    [self.tecf addDelegate:self];
    
    //Find all the listeners listening to the events from the FQNs list.
    [self.kaaClient findEventListeners:listenerFQNs delegate:self];
}

- (void)onEventListenersReceived:(NSArray *)eventListeners {
    NSLog(@"%i event listeners received", (int)[eventListeners count]);
    for (NSString *listener in eventListeners) {
        TransactionId *trxId = [self.eventFamilyFactory startEventsBlock];
        // Add a targeted events to the block.
        [self.tecf addThermostatInfoRequestToBlock:[[ThermostatInfoRequest alloc] init] withTransactionId:trxId andTarget:listener];
        ChangeDegreeRequest *request = [[ChangeDegreeRequest alloc] init];
        request.degree = [KAAUnion unionWithBranch:KAA_UNION_INT_OR_NULL_BRANCH_0 andData:[NSNumber numberWithInt:-98]];
        [self.tecf addChangeDegreeRequestToBlock:request withTransactionId:trxId andTarget:listener];
        
        // Send the added events in a batch.
        [self.eventFamilyFactory submitEventsBlock:trxId];
        NSLog(@"ThermostatInfoRequest & ChangeDegreeRequest sent to endpoint with id [%@]", listener);
        // Dismiss the event batch (if the batch was not submitted as shown in the previous line).
        //[self.eventFamilyFactory removeEventsBlock:trxId];
    }
}

- (void)onRequestFailed {
    NSLog(@"Request failed!");
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"Event demo started");
    self.kaaClient = [Kaa clientWithContext:[[DefaultKaaPlatformContext alloc] init] andStateDelegate:self];
    [self.kaaClient start];
    
    [self.kaaClient attachUser:USER_EXTERNAL_ID token:USER_ACCESS_TOKEN delegate:self];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self.kaaClient stop];
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
