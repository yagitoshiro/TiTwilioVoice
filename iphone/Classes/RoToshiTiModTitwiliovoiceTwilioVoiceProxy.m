/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2016年 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "RoToshiTiModTitwiliovoiceTwilioVoiceProxy.h"

@implementation RoToshiTiModTitwiliovoiceTwilioVoiceProxy

-(void)_initWithProperties:(NSDictionary *)properties{
    
    NSLog(@"======= module loaded ========");
    _authUrl = [properties objectForKey:@"url"];
    NSString *displayName = [properties objectForKey:@"displayName"];
    
    _voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    _voipRegistry.delegate = self;
    _voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:displayName];
    
    configuration.maximumCallGroups = 1;
    configuration.maximumCallsPerCallGroup = 1;
    _callKitProvider = [[CXProvider alloc] initWithConfiguration:configuration];
    [_callKitProvider setDelegate:self queue:nil];
    
    //_callKitCallController = [[CXCallController alloc] init];
    _callKitCallController = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
    [super _initWithProperties:properties];
}

- (NSString *)fetchAccessToken {
    // returns nil on error
    NSString *accessToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:_authUrl]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    return accessToken;
}

#pragma mark - Public API
- (void) connect:(id)args{
    ENSURE_UI_THREAD_1_ARG(args);
    ENSURE_SINGLE_ARG(args, NSDictionary);
    _uuid = [NSUUID UUID];
    NSString *handle = [args objectForKey:@"user"];
    [self performStartCallActionWithUUID: _uuid handle: handle];
}

- (void) disconnect:(id)args{
    [self performEndCallActionWithUUID:_uuid];
}

- (void) answer:(id)args{

}

- (void) ignore: (id)args{

}

#pragma mark - PKPushRegistryDelegate
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {
        _deviceTokenString = [credentials.token description];
        NSString *accessToken = [self fetchAccessToken];
        if (accessToken.length > 0) {
            [[VoiceClient sharedInstance] registerWithAccessToken:accessToken
                                                      deviceToken:_deviceTokenString
                                                       completion:^(NSError *error) {
                                                           if (error) {
                                                               NSLog(@"An error occurred while registering: %@", [error localizedDescription]);
                                                           }
                                                           else {
                                                               NSLog(@"Successfully registered for VoIP push notifications.");
                                                               [self fireEvent:@"register" withObject:@{@"token": _deviceTokenString}];
                                                           }
                                                       }];
        }
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {
        NSString *accessToken = [self fetchAccessToken];
        [[VoiceClient sharedInstance] unregisterWithAccessToken:accessToken
                                                    deviceToken:_deviceTokenString
                                                     completion:^(NSError * _Nullable error) {
                                                         if (error) {
                                                             NSLog(@"An error occurred while unregistering: %@", [error localizedDescription]);
                                                         }
                                                         else {
                                                             NSLog(@"Successfully unregistered for VoIP push notifications.");
                                                         }
                                                     }];
        
        _deviceTokenString = nil;
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {
        [[VoiceClient sharedInstance] handleNotification:payload.dictionaryPayload
                                                delegate:self];
    }
}

#pragma mark - TVONotificationDelegate
- (void)incomingCallReceived:(TVOIncomingCall *)incomingCall {
    [self fireEvent:@"incomingCallReceived"];
    _incomingCall = incomingCall;
    _incomingCall.delegate = self;
    
    // TODO FROM?
    [self reportIncomingCallFrom:[incomingCall from] withUUID:_incomingCall.uuid];
}

- (void)incomingCallCancelled:(TVOIncomingCall *)incomingCall {
    [self performEndCallActionWithUUID:incomingCall.uuid];
    _incomingCall = nil;
}

- (void)notificationError:(NSError *)error {
    [self fireEvent:@"notificationError" withObject:@{@"message": error.localizedDescription}];
}

#pragma mark - TVOIncomingCallDelegate
- (void)incomingCallDidConnect:(TVOIncomingCall *)incomingCall {
    [self fireEvent:@"incomingCallDidConnect" withObject:@{
                                                           @"from": incomingCall.from,
                                                           @"callSid": incomingCall.callSid,
                                                           @"to": incomingCall.to,
                                                           @"muted": @(incomingCall.muted)
                                                           }];
    [self routeAudioToSpeaker];
}

- (void)incomingCallDidDisconnect:(TVOIncomingCall *)incomingCall {
    [self performEndCallActionWithUUID:incomingCall.uuid];
    _incomingCall = nil;
}

- (void)incomingCall:(TVOIncomingCall *)incomingCall didFailWithError:(NSError *)error {
    [self performEndCallActionWithUUID:incomingCall.uuid];
    _incomingCall = nil;
    [self fireEvent:@"incomingCallDidFailWithError" withObject:@{@"message": error.localizedDescription}];
}

#pragma mark - TVOOutgoingCallDelegate
- (void)outgoingCallDidConnect:(TVOOutgoingCall *)outgoingCall {
    [self fireEvent:@"outgoingCallDidConnect" withObject:@{
                                                           @"callSid": outgoingCall.callSid,
                                                           @"muted": @(outgoingCall.muted)
                                                               }];
}

- (void)outgoingCallDidDisconnect:(TVOOutgoingCall *)outgoingCall {
    [self fireEvent:@"outgoingCallDidDisconnect" withObject:@{@"callSid": outgoingCall.callSid}];
    _outgoingCall = nil;
    [self routeAudioToSpeaker];
}

- (void)outgoingCall:(TVOOutgoingCall *)outgoingCall didFailWithError:(NSError *)error {
    [self performEndCallActionWithUUID:outgoingCall.uuid];
    _outgoingCall = nil;
    [self fireEvent:@"outgoingCallDidFailWithError" withObject:@{@"message": error.localizedDescription}];
}

#pragma mark - AVAudioSession
- (void)routeAudioToSpeaker {
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                          withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                                error:&error]) {
        NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
    }
}

#pragma mark - CXProviderDelegate
- (void)providerDidReset:(CXProvider *)provider {
    
}

- (void)providerDidBegin:(CXProvider *)provider {
    
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    [[VoiceClient sharedInstance] startAudioDevice];
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {
    
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    [[VoiceClient sharedInstance] configureAudioSession];
    _outgoingCall = [[VoiceClient sharedInstance] call: [self fetchAccessToken] params:@{} delegate:self];
    
    if (!_outgoingCall) {
        [action fail];
    } else {
        _outgoingCall.uuid = action.callUUID;
        [action fulfillWithDateStarted:[NSDate date]];
    }
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    [_incomingCall acceptWithDelegate:self];
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    [[VoiceClient sharedInstance] stopAudioDevice];
    
    if (_incomingCall) {
        if (_incomingCall.state == TVOIncomingCallStatePending) {
            [_incomingCall reject];
        } else {
            [_incomingCall disconnect];
        }
    } else if (_outgoingCall) {
        [_outgoingCall disconnect];
    }
    [action fulfill];
}

#pragma mark - CallKit Actions
- (void)performStartCallActionWithUUID:(NSUUID *)uuid handle:(NSString *)handle {
    ENSURE_UI_THREAD_WITH_OBJ(performStartCallActionWithUUID, uuid, handle);
    if (uuid == nil || handle == nil) {
        return;
    }
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:handle];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:callHandle];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"StartCallAction transaction request failed: %@", [error localizedDescription]);
        } else {
            NSLog(@"StartCallAction transaction request successful");
            
            CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
            callUpdate.remoteHandle = callHandle;
            callUpdate.supportsDTMF = YES;
            callUpdate.supportsHolding = NO;
            callUpdate.supportsGrouping = NO;
            callUpdate.supportsUngrouping = NO;
            callUpdate.hasVideo = NO;
            
            [self.callKitProvider reportCallWithUUID:uuid updated:callUpdate];
        }
    }];
}

- (void)reportIncomingCallFrom:(NSString *) from withUUID:(NSUUID *)uuid {
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:from];
    
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle = callHandle;
    callUpdate.supportsDTMF = YES;
    callUpdate.supportsHolding = NO;
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;
    callUpdate.hasVideo = NO;
    
    [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError *error) {
        if (!error) {
            [[VoiceClient sharedInstance] configureAudioSession];
        } else {
            [self fireEvent:@"errorReportIncomingCallWithUUID" withObject:@{@"message": error.localizedDescription}];
        }
    }];
}

- (void)performEndCallActionWithUUID:(NSUUID *)uuid {
    if (uuid == nil) {
        return;
    }
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"EndCallAction transaction request failed: %@", [error localizedDescription]);
            [self fireEvent:@"errorperformEndCallActionWithUUID" withObject:@{@"message": error.localizedDescription}];
        }
        else {
            NSLog(@"EndCallAction transaction request successful");
        }
    }];
}


@end
