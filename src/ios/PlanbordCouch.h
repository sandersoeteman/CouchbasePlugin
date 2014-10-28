//
//  PlanbordCouch.h
//  CoachendZorgen
//
//  Created by Sander Soeteman on 31-08-12.
//
//

#import <Cordova/CDVPlugin.h>

@interface PlanbordCouch : CDVPlugin

- (void) setup:(CDVInvokedUrlCommand*)command;
- (void) setupUser:(CDVInvokedUrlCommand*)command;
- (void) setupReplicationForUser:(CDVInvokedUrlCommand*)command;
- (void) stopReplications:(CDVInvokedUrlCommand*)command;
- (void) saveUserCredentials:(CDVInvokedUrlCommand*)command;
- (void) makeNotifications:(CDVInvokedUrlCommand*)command;
- (void) cancelNotifications:(CDVInvokedUrlCommand*)command;
- (void) exit:(CDVInvokedUrlCommand*)command;

@end
