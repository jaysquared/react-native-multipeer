#import "RCTMultipeerConnectivity.h"
#import "RCTEventDispatcher.h"
//#import "ObjectStore.h"

@implementation RCTMultipeerConnectivity

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(advertise:(NSString *)channel data:(NSDictionary *)data) {
    self.advertiser =
    [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerID discoveryInfo:data serviceType:channel];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
}

RCT_EXPORT_METHOD(stopAdvertising)
{
    self.advertiser.delegate = nil;
    [self.advertiser stopAdvertisingPeer];
    self.advertiser = nil;
}

RCT_EXPORT_METHOD(browse:(NSString *)channel)
{
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.peerID serviceType:channel];
    self.browser.delegate = self;
    [self.browser startBrowsingForPeers];
}

RCT_EXPORT_METHOD(stopBrowsing)
{
    self.browser.delegate = nil;
    [self.browser stopBrowsingForPeers];
    self.browser = nil;
}

//RCT_EXPORT_METHOD(logSessionInfo)
//{
//    NSLog(@"Session Info:%@", self.session);
//}

RCT_EXPORT_METHOD(invite:(NSString *)peerUUID callback:(RCTResponseSenderBlock)callback) {
    MCPeerID *peerID = [self.peers valueForKey:peerUUID];
    MCSession *session = [self.peerSessions valueForKey:peerID.displayName];
    [self.browser invitePeer:peerID toSession:session withContext:nil timeout:30];
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(rsvp:(NSString *)inviteID accept:(BOOL)accept callback:(RCTResponseSenderBlock)callback) {
    if ([self.invitationHandlers objectForKey:inviteID]) {
        void (^invitationHandler)(BOOL, MCSession *) = [self.invitationHandlers valueForKey:inviteID];
        NSString *peerName = [self.peerIDByInvite valueForKey:inviteID];
        NSLog(@"Found peer %@", peerName);
        MCSession *session = [self.peerSessions valueForKey:peerName];
        NSLog(@"Found session %@", session);
        invitationHandler(accept, session);
        [self.invitationHandlers removeObjectForKey:inviteID];
        [self.peerIDByInvite removeObjectForKey:inviteID];

        callback(@[[NSNull null]]);
    }
}

RCT_EXPORT_METHOD(sendToConnectedPeers:(NSDictionary *)data callback:(RCTResponseSenderBlock)callback) {
    [self sendDataToConnectedPeers:data callback:callback];
}

RCT_EXPORT_METHOD(disconnectFromPeer:(NSString *)peerName callback:(RCTResponseSenderBlock)callback) {
    MCSession *session = [self.peerSessions valueForKey:peerName];
    [session disconnect];
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(disconnectFromAll:(RCTResponseSenderBlock)callback) {
    for (NSString *peerUUID in self.peerSessions) {
        MCSession *session = [self.peerSessions valueForKey:peerUUID];
        [session disconnect];
    }
    callback(@[[NSNull null]]);
}

- (instancetype)init {
    self = [super init];
    self.peers = [NSMutableDictionary dictionary];
    self.connectedPeers = [NSMutableDictionary dictionary];
    self.invitationHandlers = [NSMutableDictionary dictionary];
    self.peerSessions = [NSMutableDictionary dictionary];
    self.peerIDByInvite = [NSMutableDictionary dictionary];
    self.peerID = [[MCPeerID alloc] initWithDisplayName:[[NSUUID UUID] UUIDString]];
    self.certs = [NSArray arrayWithObject:(id)self.getClientCertificate];
    
    return self;
}

- (SecIdentityRef)getClientCertificate
{
    SecIdentityRef identity = nil;
    /* TODO: Rename the cert. Figure out if this is the best way to add it */
    NSString *myFilePath = [[NSBundle mainBundle] pathForResource:@"aps" ofType:@"p12"];
    NSData *PKCS12Data = [NSData dataWithContentsOfFile:myFilePath];
    
    CFDataRef inPKCS12Data = (__bridge CFDataRef)PKCS12Data;
    CFStringRef password = CFSTR("p");
    const void *keys[] = { kSecImportExportPassphrase };//kSecImportExportPassphrase };
    const void *values[] = { password };
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus securityError = SecPKCS12Import(inPKCS12Data, options, &items);
    CFRelease(options);
    CFRelease(password);
    if (securityError == errSecSuccess) {
        CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
        identity = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
    } else {
        NSLog(@"!!!!!!!!Error opening Certificate.");
    }
    
    return identity;
}

- (void)sendDataToConnectedPeers:(NSDictionary *)data callback:(RCTResponseSenderBlock)callback {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];
    for (NSString *peerUUID in self.peerSessions) {
        MCSession *session = [self.peerSessions valueForKey:peerUUID];
        if([session.connectedPeers count] > 0)
        {
            NSLog(@"sending Data to peer: %@", peerUUID);
            [session sendData:jsonData toPeers:session.connectedPeers withMode:MCSessionSendDataReliable error:&error];
            
        }
    }
    callback(@[[NSNull null]]);
}

//- (void)sendData:(NSArray *)recipients data:(NSDictionary *)data callback:(RCTResponseSenderBlock)callback {
//    NSError *error = nil;
//
//    //NSMutableArray *peers = [NSMutableArray array];
//    for (NSString *peerUUID in self.peerSessions) {
//        NSMutableArray *peer = [NSMutableArray array];
//        MCSession *session = [self.peerSessions valueForKey:peerUUID];
//
//        if session.connectedPeers
//        [peer addObject:[self.peers valueForKey:peerUUID]];
//
//        [session sendData:jsonData toPeers:peer withMode:MCSessionSendDataReliable error:&error];
//    }


- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    if ([peerID.displayName isEqualToString:self.peerID.displayName]) return;
    [self.peers setValue:peerID forKey:peerID.displayName];
    
    //Create session for the peer in our dictionary
    MCSession *session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:self.certs encryptionPreference:MCEncryptionRequired];
    session.delegate = self;
    [self.peerSessions setValue:session forKey:peerID.displayName];
    
    if (info == nil) {
        info = [NSDictionary dictionary];
    }
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTMultipeerConnectivityPeerFound"
                                                    body:@{
                                                           @"peer": @{
                                                                   @"id": peerID.displayName,
                                                                   @"info": info
                                                                   }
                                                           }];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    if ([peerID.displayName isEqualToString:self.peerID.displayName]) return;
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTMultipeerConnectivityPeerLost"
                                                    body:@{
                                                           @"peer": @{
                                                                   @"id": peerID.displayName
                                                                   }
                                                           }];
    [self.peers removeObjectForKey:peerID.displayName];
    [self.peerSessions removeObjectForKey:peerID.displayName];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
    NSString *invitationUUID = [[NSUUID UUID] UUIDString];
    [self.invitationHandlers setValue:[invitationHandler copy] forKey:invitationUUID];
    
    //Create session on the advertiser side for the invite
    //Associate both the session and the invite to a peer
    //How do we clean this up after the peers no longer see each other?
    MCSession *session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:self.certs encryptionPreference:MCEncryptionRequired];
    session.delegate = self;
    [self.peerSessions setValue:session forKey:peerID.displayName];
    [self.peerIDByInvite setValue:peerID.displayName forKey:invitationUUID];
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTMultipeerConnectivityInviteReceived"
                                                    body:@{
                                                           @"invite": @{
                                                                   @"id": invitationUUID
                                                                   },
                                                           @"peer": @{
                                                                   @"id": peerID.displayName
                                                                   }
                                                           }];
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if ([peerID.displayName isEqualToString:self.peerID.displayName]) return;
    if (state == MCSessionStateConnected) {
        [self.connectedPeers setValue:peerID forKey:peerID.displayName];
        [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTMultipeerConnectivityPeerConnected"
                                                        body:@{
                                                               @"peer": @{
                                                                       @"id": peerID.displayName
                                                                       }
                                                               }];
    }
    else if (state == MCSessionStateConnecting) {
        [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTMultipeerConnectivityPeerConnecting"
                                                        body:@{
                                                               @"peer": @{
                                                                       @"id": peerID.displayName
                                                                       }
                                                               }];
    }
    else if (state == MCSessionStateNotConnected) {
        [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTMultipeerConnectivityPeerDisconnected"
                                                        body:@{
                                                               @"peer": @{
                                                                       @"id": peerID.displayName
                                                                       }
                                                               }];
        [self.connectedPeers removeObjectForKey:peerID.displayName];
        [self resetSession:peerID];
        
    }
}

- (void)resetSession:(MCPeerID *)peerID {
    //Create session for the peer in our dictionary
    MCSession *session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:self.certs encryptionPreference:MCEncryptionRequired];
    session.delegate = self;
    [self.peerSessions setValue:session forKey:peerID.displayName];
    
}

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:     (MCPeerID *)peerID certificateHandler:(void (^)(BOOL accept))certificateHandler
{
    SecCertificateRef myCert;
    myCert = (__bridge SecCertificateRef)[certificate objectAtIndex:0];    // 1
    
    // TODO: DO we care about SSL host name checking?
    SecPolicyRef myPolicy = SecPolicyCreateBasicX509();         // 2
    
    SecCertificateRef certArray[1] = { myCert };
    CFArrayRef myCerts = CFArrayCreate(
                                       NULL, (void *)certArray,
                                       1, NULL);

    SecTrustRef myTrust;
    OSStatus status = SecTrustCreateWithCertificates(
                                                     myCerts,
                                                     myPolicy,
                                                     &myTrust);  // 3
    NSArray* anchors = @[ (__bridge id)myCert ]; // TODO: SHould this check against self.certs
    SecTrustSetAnchorCertificates(myTrust,(__bridge CFTypeRef)anchors);
    
    SecTrustResultType trustResult;
    if (status == noErr) {
        status = SecTrustEvaluate(myTrust, &trustResult);       // 4
    }
    
    status = SecTrustGetTrustResult(myTrust, &trustResult);
    
    //...
    if (trustResult == kSecTrustResultConfirm || trustResult == kSecTrustResultProceed || trustResult == kSecTrustResultUnspecified)                           // 5
    {
        certificateHandler(YES);
    }
    
    // ...
    if (myPolicy)
        CFRelease(myPolicy);
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    NSDictionary *parsedJSON = [NSDictionary dictionary];
    
    if([object isKindOfClass:[NSDictionary class]]) {
        parsedJSON = object;
    }
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"RCTMultipeerConnectivityDataReceived"
                                                    body:@{
                                                           @"peer": @{
                                                                   @"id": peerID.displayName
                                                                   },
                                                           @"data": parsedJSON
                                                           }];
}

@end
