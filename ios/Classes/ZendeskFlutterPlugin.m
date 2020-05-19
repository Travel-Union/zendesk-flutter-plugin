#import "ZendeskFlutterPlugin.h"

@implementation EventChannelStreamHandler

- (void) send:(NSObject*)event {
  if (self.eventSink) {
    self.eventSink(event);
  }
}

- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events {
  self.eventSink = events;
  return nil;
}

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

@end

@implementation ZendeskFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* callsChannel = [FlutterMethodChannel
      methodChannelWithName:@"plugins.flutter.zendesk_chat_api/calls"
      binaryMessenger:[registrar messenger]];

  FlutterEventChannel* connectionStatusEventsChannel = [FlutterEventChannel
      eventChannelWithName:@"plugins.flutter.zendesk_chat_api/connection_status_events"
      binaryMessenger:[registrar messenger]];

  FlutterEventChannel* accountStatusEventsChannel = [FlutterEventChannel
      eventChannelWithName:@"plugins.flutter.zendesk_chat_api/account_status_events"
      binaryMessenger:[registrar messenger]];

  FlutterEventChannel* agentEventsChannel = [FlutterEventChannel
      eventChannelWithName:@"plugins.flutter.zendesk_chat_api/agent_events"
      binaryMessenger:[registrar messenger]];
      
  FlutterEventChannel* chatItemsEventsChannel = [FlutterEventChannel
      eventChannelWithName:@"plugins.flutter.zendesk_chat_api/chat_items_events"
      binaryMessenger:[registrar messenger]];

  ZendeskFlutterPlugin* instance = [[ZendeskFlutterPlugin alloc] init];
  
  instance.connectionStreamHandler = [[EventChannelStreamHandler alloc] init];
  instance.accountStreamHandler = [[EventChannelStreamHandler alloc] init];
  instance.agentsStreamHandler = [[EventChannelStreamHandler alloc] init];
  instance.chatItemsStreamHandler = [[EventChannelStreamHandler alloc] init];
  
  [registrar addMethodCallDelegate:instance channel:callsChannel];
  [connectionStatusEventsChannel setStreamHandler:instance.connectionStreamHandler];
  [accountStatusEventsChannel setStreamHandler:instance.accountStreamHandler];
  [agentEventsChannel setStreamHandler:instance.agentsStreamHandler];
  [chatItemsEventsChannel setStreamHandler:instance.chatItemsStreamHandler];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"init" isEqualToString:call.method]) {
    self.accountKey = call.arguments[@"accountKey"];
    result(nil);
  } else if ([@"startChat" isEqualToString:call.method]) {
    if ([self.accountKey length] == 0) {
      result([FlutterError errorWithCode:@"NOT_INITIALIZED" message:nil details:nil]);
      return;
    }
    
    if (ZDKChat.instance) {
      result([FlutterError errorWithCode:@"CHAT_SESSION_ALREADY_OPEN" message:nil details:nil]);
      return;
    }
      
    [ZDKChat initializeWithAccountKey:self.accountKey queue:dispatch_get_main_queue()];
      
    ZDKChatAPIConfiguration *chatAPIConfiguration = [[ZDKChatAPIConfiguration alloc] init];
    chatAPIConfiguration.department = [self argumentAsString:call forName:@"department"];
    chatAPIConfiguration.visitorInfo = [[ZDKVisitorInfo alloc] initWithName:[self argumentAsString:call forName:@"visitorName"]
                                                                        email:[self argumentAsString:call forName:@"visitorEmail"]
                                                                  phoneNumber:[self argumentAsString:call forName:@"visitorPhone"]];
    
    NSString *tags = [self argumentAsString:call forName:@"tags"];
    if ([tags length] != 0) {
      chatAPIConfiguration.tags = [tags componentsSeparatedByString:@","];
    }

    ZDKChat.instance.configuration = chatAPIConfiguration;
    
    [self bindChatListeners];
    [ZDKChat.connectionProvider connect];
    result(nil);
  } else if ([@"endChat" isEqualToString:call.method]) {
    if (ZDKChat.instance != nil) {
      [self unbindChatListeners];
      [ZDKChat.chatProvider endChat:nil];
    }
    result(nil);
  } else if ([@"sendMessage" isEqualToString:call.method]) {
    if (ZDKChat.instance == nil) {
      result([FlutterError errorWithCode:@"CHAT_NOT_STARTED" message:nil details:nil]);
      return;
    }
    [ZDKChat.chatProvider sendMessage:call.arguments[@"message"] completion:nil];
    result(nil);
  } else if ([@"resendMessage" isEqualToString:call.method]) {
     if (ZDKChat.instance == nil) {
       result([FlutterError errorWithCode:@"CHAT_NOT_STARTED" message:nil details:nil]);
       return;
     }
      //[ZDKChat.chatProvider resendFailedMessageWithId:call.arguments[@"messageId"]] completion:nil];
      result(nil);
   } else if ([@"sendComment" isEqualToString:call.method]) {
      if (ZDKChat.instance == nil) {
        result([FlutterError errorWithCode:@"CHAT_NOT_STARTED" message:nil details:nil]);
        return;
      }
      [ZDKChat.chatProvider sendChatComment:call.arguments[@"comment"] completion:nil];
      result(nil);
    } else if ([@"sendAttachment" isEqualToString:call.method]) {
    if (ZDKChat.instance == nil) {
      result([FlutterError errorWithCode:@"CHAT_NOT_STARTED" message:nil details:nil]);
      return;
    }
    NSString* pathname = [self argumentAsString:call forName:@"pathname"];
    if ([pathname length] == 0) {
      result([FlutterError errorWithCode:@"ATTACHMENT_EMPTY_PATHNAME" message:nil details:nil]);
      return;
    }
    NSString* filename = [pathname lastPathComponent];
    NSFileManager* filemgr = [NSFileManager defaultManager];
    if (![filemgr fileExistsAtPath:pathname]) {
      result([FlutterError errorWithCode:@"ATTACHMENT_FILE_MISSING" message:nil details:nil]);
      return;
    }
    [ZDKChat.chatProvider sendFileWithUrl:[filemgr contentsAtPath:pathname] onProgress:nil completion:nil];
    result(nil);
  } else if ([@"sendChatRating" isEqualToString:call.method]) {
    if (ZDKChat.instance == nil) {
      result([FlutterError errorWithCode:@"CHAT_NOT_STARTED" message:nil details:nil]);
      return;
    }
    NSString* rating = [self argumentAsString:call forName:@"rating"];
    [ZDKChat.chatProvider sendChatRating:[self toChatLogRating:rating] completion:nil];
    NSString* comment = [self argumentAsString:call forName:@"comment"];
    if (comment != nil) {
        [ZDKChat.chatProvider sendChatComment:comment completion:nil];
    }
    result(nil);
  } else if ([@"sendOfflineMessage" isEqualToString:call.method]) {
    if (ZDKChat.instance == nil) {
      result([FlutterError errorWithCode:@"CHAT_NOT_STARTED" message:nil details:nil]);
      return;
    }
    ZDKOfflineForm *form = [[ZDKOfflineForm alloc] initWithVisitorInfo:ZDKChat.instance.profileProvider.visitorInfo
                                                        departmentId:ZDKChat.instance.configuration.department
                                                        message:call.arguments[@"message"]];
    [ZDKChat.chatProvider sendOfflineForm:form completion:nil];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (NSString*) argumentAsString:(FlutterMethodCall*)call forName:(NSString*)argName {
  if ([call.arguments isKindOfClass:[NSNull class]]) {
    return nil;
  }
  NSString* value = call.arguments[argName];
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (NSData*) argumentAsBinary:(FlutterMethodCall*)call forName:(NSString*)argName {
  if ([call.arguments isKindOfClass:[NSNull class]]) {
    return nil;
  }
  NSObject* value = call.arguments[argName];
  if (![value isKindOfClass:[FlutterStandardTypedData class]]) {
    return nil;
  }
  return ((FlutterStandardTypedData*)value).data;
}

- (void) bindChatListeners {
    [self unbindChatListeners];
    
    _accountToken = [ZDKChat.accountProvider observeAccount:^(ZDKChatAccount *account) {
        [self.accountStreamHandler send:(account.accountStatus == ZDKChatAccountStatusOnline ? @("ONLINE") : @("OFFLINE"))];
    }];
    
    _chatToken = [ZDKChat.chatProvider observeChatState:^(ZDKChatState *chatState) {
        NSMutableArray* outAgents = [[NSMutableArray alloc] initWithCapacity:[chatState.agents count]];
        NSLog(@"Agent count:%tu", chatState.agents.count);
        [chatState.agents enumerateObjectsUsingBlock:^(ZDKAgent *agent, NSUInteger index, BOOL *stop) {
          NSMutableDictionary *agentDict = [[NSMutableDictionary alloc] init];
          [agentDict setValue:agent.displayName forKey:@"display_name"];
          [agentDict setValue:agent.avatar forKey:@"avatar_path"];
          [agentDict setValue:@(agent.isTyping) forKey:@"is_typing"];
          [agentDict setValue:agent.nick forKey:@"nick"];
          [outAgents addObject:agentDict];
        }];
        [self.agentsStreamHandler send:[self toJson:outAgents]];
        
        NSMutableArray* outLogs = [[NSMutableArray alloc] initWithCapacity:[chatState.logs count]];
        NSLog(@"Log count:%tu", chatState.logs.count);
        for (ZDKChatLog* event in chatState.logs) {
          NSMutableDictionary* chatItem = [[NSMutableDictionary alloc] init];
          [chatItem setValue:event.id forKey:@"id"];
          [chatItem setValue:@(event.createdTimestamp) forKey:@"create_timestamp"];
          [chatItem setValue:@(event.lastModifiedTimestamp) forKey:@"modify_timestamp"];
          [chatItem setValue:event.nick forKey:@"nick"];
          [chatItem setValue:event.displayName forKey:@"display_name"];
          [chatItem setValue:[self chatEventTypeToString:event.type] forKey:@"type"];
          [chatItem setValue:[self deliveryStatusToString:event.deliveryStatus] forKey:@"delivery_status"];
          [chatItem setValue:[self participantToString:event.participant] forKey:@"participant"];
            
          if ([chatItem isMemberOfClass:[ZDKChatMessage class]]) {
                ZDKChatMessage *message = (ZDKChatMessage *)chatItem;
                [chatItem setValue:message.message forKey:@"message"];
          }
            
          if ([chatItem isMemberOfClass:[ZDKChatRating class]]) {
                ZDKChatRating *rating = (ZDKChatRating *)chatItem;
                [chatItem setValue:[self chatLogRatingToString:rating.ratingValue] forKey:@"current_rating"];
          }
            
          if ([chatItem isMemberOfClass:[ZDKChatAttachmentMessage class]]) {
                //[chatItem setValue:[self attachmentToDictionary:event.attachment] forKey:@"attachment"];
          }
            
          if ([chatItem isMemberOfClass:[ZDKChatComment class]]) {
                ZDKChatComment *comment = (ZDKChatComment *)chatItem;
                [chatItem setValue:comment.comment forKey:@"new_comment"];
          }
          
          [outLogs addObject:chatItem];
        }
        [self.chatItemsStreamHandler send:[self toJson:outLogs]];
    }];
    
    _chatToken = [ZDKChat.connectionProvider observeConnectionStatus:^(enum ZDKConnectionStatus status) {
        NSString *value;
        switch (status) {
          case ZDKConnectionStatusConnecting:
            value = @("CONNECTING");
            break;
          case ZDKConnectionStatusConnected:
            value = @("CONNECTED");
            break;
          case ZDKConnectionStatusFailed:
            value = @("FAILED");
            break;
          case ZDKConnectionStatusDisconnected:
            value = @("DISCONNECTED");
            break;
          case ZDKConnectionStatusUnreachable:
            value = @("UNREACHABLE");
            break;
          case ZDKConnectionStatusReconnecting:
            value = @("RECONNECTING");
            break;
          default:
            value = @("UNKNOWN");
            break;
        }
        [self.connectionStreamHandler send:value];
    }];
}

- (void) unbindChatListeners {
  [_connectionToken cancel];
  [_accountToken cancel];
  [_chatToken cancel];
}

- (NSString*) chatEventTypeToString:(ZDKChatLogType)type {
  switch (type) {
    case ZDKChatLogTypeMessage:
      return @"MESSAGE";
    case ZDKChatLogTypeAttachmentMessage:
      return @"ATTACHMENT_MESSAGE";
    case ZDKChatLogTypeMemberJoin:
      return @"MEMEBER_JOIN";
    case ZDKChatLogTypeMemberLeave:
      return @"MEMBER_LEAVE";
    case ZDKChatLogTypeChatComment:
      return @"COMMENT";
    case ZDKChatLogTypeChatRating:
      return @"RATING";
    case ZDKChatLogTypeChatRatingRequest:
      return @"RATING_REQUEST";
    default:
      return @"UNKNOWN";
  }
}

- (NSString*) deliveryStatusToString:(ZDKDeliveryStatus)status {
  switch (status) {
    case ZDKDeliveryStatusPending:
      return @"PENDING";
    case ZDKDeliveryStatusDelivered:
      return @"DELIVERED";
    case ZDKDeliveryStatusFailed:
      return @"FAILED";
    default:
      return @"UNKNOWN";
  }
}

- (NSString*) participantToString:(ZDKChatParticipant)participant {
  switch (participant) {
    case ZDKChatParticipantVisitor:
      return @"VISITOR";
    case ZDKChatParticipantAgent:
      return @"AGENT";
    case ZDKChatParticipantTrigger:
      return @"TRIGGER";
    case ZDKChatParticipantSystem:
      return @"SYSTEM";
    default:
      return @"UNKNOWN";
  }
}

/*- (NSDictionary*) attachmentToDictionary:(ZDKChatAttachment*)attachment {
  if (attachment == nil) {
    return nil;
  }
  NSMutableDictionary* out = [[NSMutableDictionary alloc] init];
  [out setValue:attachment.url forKey:@"url"];
  [out setValue:attachment.thumbnailURL forKey:@"thumbnail_url"];
  [out setValue:attachment.fileSize forKey:@"size"];
  [out setValue:attachment.mimeType forKey:@"mime_type"];
  [out setValue:attachment.fileName forKey:@"name"];
  return out;
}*/

- (NSString*) toJson:(NSObject*)object {
  NSError *error = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
  if (error != nil) {
    NSLog(@("An json serialization error happened: %@"), error);
    return nil;
  } else if ([jsonData length] == 0) {
    return nil;
  } else {
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  }
}

- (ZDKRating) toChatLogRating:(NSString*) rating {
  if ([@"ChatRating.GOOD" isEqualToString:rating]) {
    return ZDKRatingGood;
  } else if ([@"ChatRating.BAD" isEqualToString:rating]) {
    return ZDKRatingBad;
  } else {
    return ZDKRatingNone;
  }
}

- (NSString*) chatLogRatingToString:(ZDKRating)rating {
  switch (rating) {
    case ZDKRatingGood:
      return @"GOOD";
    case ZDKRatingBad:
      return @"BAD";
    default:
      return nil;
  }
}

@end
