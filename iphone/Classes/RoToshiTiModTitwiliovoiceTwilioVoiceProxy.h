/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2016年 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiProxy.h"

#import <AVFoundation/AVFoundation.h>
#import <CallKit/CallKit.h>
#import <PushKit/PushKit.h>

#import <TwilioVoiceClient/TwilioVoiceClient.h>

@interface RoToshiTiModTitwiliovoiceTwilioVoiceProxy : TiProxy <PKPushRegistryDelegate, TVONotificationDelegate, TVOIncomingCallDelegate, TVOOutgoingCallDelegate, CXProviderDelegate>{

}
@property (nonatomic, strong) NSString *deviceTokenString;
@property (nonatomic, strong) NSString *authUrl;
@property (nonatomic, strong) NSUUID *uuid;

@property (nonatomic, strong) PKPushRegistry *voipRegistry;

@property (nonatomic, strong) TVOIncomingCall *incomingCall;
@property (nonatomic, strong) TVOOutgoingCall *outgoingCall;

@property (nonatomic, strong) CXProvider *callKitProvider;
@property (nonatomic, strong) CXCallController *callKitCallController;
@end
