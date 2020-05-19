#import <Flutter/Flutter.h>
#import <ChatProvidersSDK/ChatProvidersSDK.h>

@interface EventChannelStreamHandler : NSObject <FlutterStreamHandler>
@property (nonatomic, strong) FlutterEventSink eventSink;
- (void) send:(NSObject*)event;
@end

@interface ZendeskFlutterPlugin : NSObject<FlutterPlugin>

@property (nonatomic, strong) NSString *accountKey;

@property (nonatomic, strong) EventChannelStreamHandler *connectionStreamHandler;
@property (nonatomic, strong) EventChannelStreamHandler *accountStreamHandler;
@property (nonatomic, strong) EventChannelStreamHandler *agentsStreamHandler;
@property (nonatomic, strong) EventChannelStreamHandler *chatItemsStreamHandler;

@property(nonatomic, retain) ZDKObservationToken *connectionToken;
@property(nonatomic, retain) ZDKObservationToken *accountToken;
@property(nonatomic, retain) ZDKObservationToken *chatToken;

+ (void) registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar;

@end
