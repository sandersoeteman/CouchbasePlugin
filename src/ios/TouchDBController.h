//
//  TouchDBController.h
//  pictoplanner
//
//  Created by Sander Soeteman on 08-01-13.
//
//

#import <Foundation/Foundation.h>
#import "QueryResult.h"

@interface TouchDBController : NSObject

+ (void) doSetupto: (void (^)(NSString* couchDBServer, NSString* version, NSError* error))callback;
+ (void) doSetupUser:(NSString*) username to: (void (^)(NSError* error))callback;
+ (NSError*) doSetupReplicationForUser:(NSString*)username andPassword:(NSString*)password onServer:(NSString*) remoteServer withPlanningDBs:(NSArray*) planningDBs withImageDBs:(NSArray*) imageDBs;
+ (void) stopReplications;
+ (void) compact;
+ (QueryResult*) getNextActivities:(int) count;
+ (NSError*) resaveHorizonActivities;

+ (NSString*) getUsername;
+ (NSString*) getPasswordFor:(NSString *)username;
+ (NSError*) saveUsername:(NSString *)username withPassword:(NSString *)password;
+ (NSError*) deleteAlAccounts;



@end
