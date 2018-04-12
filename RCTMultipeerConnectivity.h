#import <React/RCTBridgeModule.h>

@import MultipeerConnectivity;

@interface RCTMultipeerConnectivity : NSObject <RCTBridgeModule, NSStreamDelegate, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate>

@property (nonatomic, strong) NSMutableDictionary *peers;
@property (nonatomic, strong) NSMutableDictionary *connectedPeers;
@property (nonatomic, strong) NSMutableDictionary *invitationHandlers;
@property (nonatomic, strong) NSMutableDictionary *peerSessions;
@property (nonatomic, strong) NSMutableDictionary *peerIDByInvite;
@property (nonatomic, strong) NSArray *certs;
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;

@end
