// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FWFUIDelegateHostApi.h"
#import "FWFDataConverters.h"
#import <UIKit/UIKit.h>

@interface FWFUIDelegateFlutterApiImpl ()
// BinaryMessenger must be weak to prevent a circular reference with the host API it
// references.
@property(nonatomic, weak) id<FlutterBinaryMessenger> binaryMessenger;
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFUIDelegateFlutterApiImpl
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self initWithBinaryMessenger:binaryMessenger];
  if (self) {
    _binaryMessenger = binaryMessenger;
    _instanceManager = instanceManager;
    _webViewConfigurationFlutterApi =
        [[FWFWebViewConfigurationFlutterApiImpl alloc] initWithBinaryMessenger:binaryMessenger
                                                               instanceManager:instanceManager];
  }
  return self;
}

- (long)identifierForDelegate:(FWFUIDelegate *)instance {
  return [self.instanceManager identifierWithStrongReferenceForInstance:instance];
}

- (void)onCreateWebViewForDelegate:(FWFUIDelegate *)instance
                           webView:(WKWebView *)webView
                     configuration:(WKWebViewConfiguration *)configuration
                  navigationAction:(WKNavigationAction *)navigationAction
                        completion:(void (^)(FlutterError *_Nullable))completion {
  NSLog(@"onCreateWebViewForDelegate called");
  if (![self.instanceManager containsInstance:configuration]) {
    [self.webViewConfigurationFlutterApi createWithConfiguration:configuration
                                                      completion:^(FlutterError *error) {
                                                        NSAssert(!error, @"%@", error);
                                                      }];
  }

  NSNumber *configurationIdentifier =
      @([self.instanceManager identifierWithStrongReferenceForInstance:configuration]);
  FWFWKNavigationActionData *navigationActionData =
      FWFWKNavigationActionDataFromNativeWKNavigationAction(navigationAction);

  [self onCreateWebViewForDelegateWithIdentifier:@([self identifierForDelegate:instance])
                               webViewIdentifier:
                                   @([self.instanceManager
                                       identifierWithStrongReferenceForInstance:webView])
                         configurationIdentifier:configurationIdentifier
                                navigationAction:navigationActionData
                                      completion:completion];
}

- (void)requestMediaCapturePermissionForDelegateWithIdentifier:(FWFUIDelegate *)instance
                                                       webView:(WKWebView *)webView
                                                        origin:(WKSecurityOrigin *)origin
                                                         frame:(WKFrameInfo *)frame
                                                          type:(WKMediaCaptureType)type
                                                    completion:
                                                        (void (^)(WKPermissionDecision))completion
    API_AVAILABLE(ios(15.0)) {
  [self
      requestMediaCapturePermissionForDelegateWithIdentifier:@([self
                                                                 identifierForDelegate:instance])
                                           webViewIdentifier:
                                               @([self.instanceManager
                                                   identifierWithStrongReferenceForInstance:
                                                       webView])
                                                      origin:
                                                          FWFWKSecurityOriginDataFromNativeWKSecurityOrigin(
                                                              origin)
                                                       frame:
                                                           FWFWKFrameInfoDataFromNativeWKFrameInfo(
                                                               frame)
                                                        type:
                                                            FWFWKMediaCaptureTypeDataFromNativeWKMediaCaptureType(
                                                                type)
                                                  completion:^(
                                                      FWFWKPermissionDecisionData *decision,
                                                      FlutterError *error) {
                                                    NSAssert(!error, @"%@", error);
                                                    completion(
                                                        FWFNativeWKPermissionDecisionFromData(
                                                            decision));
                                                  }];
}
@end

@implementation FWFUIDelegate
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [super initWithBinaryMessenger:binaryMessenger instanceManager:instanceManager];
  if (self) {
    _UIDelegateAPI = [[FWFUIDelegateFlutterApiImpl alloc] initWithBinaryMessenger:binaryMessenger
                                                                  instanceManager:instanceManager];
  }
  return self;
}

- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)windowFeatures {

  NSLog(@"createWebViewWithConfiguration called test");
  NSLog(@"URL: %@", navigationAction.request.URL);
  NSLog(@"navigationAction.request: %@", navigationAction.request);
  NSLog(@"navigationAction.request.URL.absoluteString: %@", navigationAction.request.URL.absoluteString);
  NSLog(@"navigationAction.request.mainDocumentURL: %@", navigationAction.request.mainDocumentURL);
  NSLog(@"navigationAction.navigationType: %ld", (long)navigationAction.navigationType);
  NSLog(@"targetFrame.isMainFrame: %d", navigationAction.targetFrame.isMainFrame);

  if (navigationAction.request.URL) {
    NSURL *url = navigationAction.request.URL;
    if (url && (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"])) {
      if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
      } else {
        NSLog(@"Invalid URL: %@", url);
      }
      return nil;
    }
  }

  if (!navigationAction.targetFrame.isMainFrame) {
    NSLog(@"Opening in external browser");

    NSURL *url = navigationAction.request.URL ?: navigationAction.request.mainDocumentURL;
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
      [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
      NSLog(@"Invalid URL: %@", url);
    }

    return nil;
  }

  return nil;
}



- (void)webView:(WKWebView *)webView
    requestMediaCapturePermissionForOrigin:(WKSecurityOrigin *)origin
                          initiatedByFrame:(WKFrameInfo *)frame
                                      type:(WKMediaCaptureType)type
                           decisionHandler:(void (^)(WKPermissionDecision))decisionHandler
    API_AVAILABLE(ios(15.0)) {
  [self.UIDelegateAPI
      requestMediaCapturePermissionForDelegateWithIdentifier:self
                                                     webView:webView
                                                      origin:origin
                                                       frame:frame
                                                        type:type
                                                  completion:^(WKPermissionDecision decision) {
                                                    decisionHandler(decision);
                                                  }];
}
@end

@interface FWFUIDelegateHostApiImpl ()
// BinaryMessenger must be weak to prevent a circular reference with the host API it
// references.
@property(nonatomic, weak) id<FlutterBinaryMessenger> binaryMessenger;
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFUIDelegateHostApiImpl
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self init];
  if (self) {
    _binaryMessenger = binaryMessenger;
    _instanceManager = instanceManager;
  }
  return self;
}

- (FWFUIDelegate *)delegateForIdentifier:(NSNumber *)identifier {
  return (FWFUIDelegate *)[self.instanceManager instanceForIdentifier:identifier.longValue];
}

- (void)createWithIdentifier:(nonnull NSNumber *)identifier
                       error:(FlutterError *_Nullable *_Nonnull)error {
  FWFUIDelegate *uIDelegate = [[FWFUIDelegate alloc] initWithBinaryMessenger:self.binaryMessenger
                                                             instanceManager:self.instanceManager];
  [self.instanceManager addDartCreatedInstance:uIDelegate withIdentifier:identifier.longValue];
}
@end
