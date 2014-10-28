//
//  PlanbordCouch.m
//  CoachendZorgen
//
//  Created by Sander Soeteman on 31-08-12.
//
//

#import "PlanbordCouch.h"
#import "AppDelegate.h"

@implementation PlanbordCouch


-(id)cast:(Class)requiredClass forObject:(id)object
{
    if( object && ! [object isKindOfClass: requiredClass] )
        object = nil;
    return object;
}
#define castIf(CLASSNAME,OBJ)      ((CLASSNAME*)([self cast:[CLASSNAME class] forObject:OBJ]))



- (void) setup:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    @try {
        // TouchDB instance en listener aan laten maken
        [TouchDBController doSetupto:^(NSString *couchDBServer, NSString *version, NSError *error) {
            CDVPluginResult* pluginResult;
            if(error != nil) {
                [self displayError:error];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            else if (couchDBServer == nil || version == nil) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"server en/of app version onbekend"];
            }
            else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                             messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:version, @"version", couchDBServer, @"couchAddress", nil]];
            }

            // hier javascript schrijven
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } @catch (NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[exception reason]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}



// maakt de userData database aan met zijn views en repliceert deze met de server
- (void) setupUser:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    @try {
        NSString* username = [command.arguments objectAtIndex:0];
        
        if (username != nil && [username length] > 0) {
            
            NSString* password = [TouchDBController getPasswordFor:username];
            
            if( password == nil || [password length] == 0) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"passwordNotFound"];
            }
            else {
            
                // heavy lifting
                [TouchDBController doSetupUser:username
                                   to:^(NSError *error) {
                    CDVPluginResult* pluginResult;
                    if(error != nil) {
                        [self displayError:error];
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
                    }
                    else {
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
                    }
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }];
            }
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Niet het benodigde aantal argumenten ontvangen voor initialisatie Couch"];
        }
    }
    @catch (NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[exception reason]];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void) exit:(CDVInvokedUrlCommand*)command
{
    exit(0);
}


- (void) saveUserCredentials:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    @try {
        NSString* username = [command.arguments objectAtIndex:0];
        NSString* password = [command.arguments objectAtIndex:1];
        
        if (username != nil && [username length] > 0 &&
            password != nil && [password length] > 0) {
            
            NSError* error = [TouchDBController saveUsername:username withPassword:password];
            if(error != nil) {
                [self displayError:error];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
            }
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Niet het benodigde aantal argumenten ontvangen voor initialisatie Couch"];
        }
    }
    @catch (NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[exception reason]];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setupReplicationForUser:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    @try {
        NSString* username = [command.arguments objectAtIndex:0];
        NSString* password = [TouchDBController getPasswordFor:username];
        NSString* server = [command.arguments objectAtIndex:1];
        NSArray* planningDBs = [command.arguments objectAtIndex:2];
        NSArray* imageDBs = [command.arguments objectAtIndex:3];

        if( password == nil || [password length] == 0) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"passwordNotFound"];
        }
        else if (username != nil && [username length] > 0 &&
            server != nil && [server length] > 0 &&
            planningDBs != nil && [planningDBs count] > 0 &&
            imageDBs != nil && [imageDBs count] > 0) {
            
            // heavy lifting
            [TouchDBController doSetupReplicationForUser:username
                                                     andPassword:password
                                                        onServer:server
                                                withPlanningDBs:planningDBs
                                           withImageDBs:imageDBs];

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Niet het benodigde aantal argumenten ontvangen voor initialisatie Couch"];
        }
    }
    @catch (NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[exception reason]];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) stopReplications:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    @try {
        // heavy lifting
        [TouchDBController stopReplications];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
    }
    @catch (NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[exception reason]];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


// NOTIFICATIONS
- (void) makeNotifications:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    @try {
        [self cancelNotifications];

        QueryResult* result = [TouchDBController getNextActivities:32];
        
        if (result.error){
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[result.error localizedDescription]];
        }
        else {
            NSEnumerator* e = [result.resultSet objectEnumerator];
            NSDictionary* act;
            while((act = [e nextObject])) {
                // datum uit key halen
                NSDate* date = castIf(NSDate, [act objectForKey:@"StartDatum"]);
                
                [self makeNotificationForActivity:act onDate:date];
            }
            
            NSError* saveError = [TouchDBController resaveHorizonActivities];
            if(saveError) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[saveError localizedDescription]];
            }
            else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
            }
        }
    } @catch (NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[exception reason]];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) cancelNotifications:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    @try {
        [self cancelNotifications];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
    }
    @catch (NSException* exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION messageAsString:[exception reason]];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void) cancelNotifications
{
    for(UILocalNotification *aNotif in [[UIApplication sharedApplication] scheduledLocalNotifications]) {
        [[UIApplication sharedApplication] cancelLocalNotification:aNotif];
    }
}


- (void) makeNotificationForActivity:(NSDictionary*) doc onDate:(NSDate*) date
{
    // tijd uit doc halen
    NSString* tijdStr = castIf(NSString, [doc objectForKey:@"Starttijd"]);
    bool playSound = [[doc objectForKey:@"PlaySound"] boolValue];
    NSArray* split = [tijdStr componentsSeparatedByString:@":"];
    if(split.count == 2) {
        // we hebben een starttijd
        NSString *uurStr = [split objectAtIndex:0];
        NSString *minStr = [split objectAtIndex:1];
        
        
        NSCalendar *gregorian = [[NSCalendar alloc]
                                 initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *timeComp = [[NSDateComponents alloc] init];
        [timeComp setHour:[uurStr intValue]];
        [timeComp setMinute:[minStr intValue]];
        NSDate *alertDateTime = [gregorian dateByAddingComponents:timeComp
                                                           toDate:date options:0];
        
        NSDate* today = [[NSDate alloc] init];
        if([today laterDate:alertDateTime] == alertDateTime) {
            // reminder datetime bepalen
            NSNumber* reminder = castIf(NSNumber, [doc objectForKey:@"Reminder"]);
            
            // titel en omschrijving uit doc halen
            NSString* titel = [doc objectForKey:@"Naam"];
            
            // notification aanmaken en schedulen
            UILocalNotification* notification = [[UILocalNotification alloc] init];
            notification.fireDate = alertDateTime;
            notification.alertBody = titel;
            notification.soundName = (playSound ? @"www/resources/sound/alert.mp3" : nil);
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
            
            if(reminder != nil && [reminder intValue] != 0) {
                NSDateComponents *remComp = [[NSDateComponents alloc] init];
                [remComp setMinute:-[reminder intValue]];
                NSDate *reminderDateTime = [gregorian dateByAddingComponents:remComp
                                                                      toDate:alertDateTime options:0];
                
                UILocalNotification* reminderNotification = [notification copy];
                reminderNotification.fireDate = reminderDateTime;
                reminderNotification.soundName = (playSound ? @"www/resources/sound/reminder.mp3" : nil);
                [[UIApplication sharedApplication] scheduleLocalNotification:reminderNotification];
            }
        }
    }
}



- (void) displayError:(NSError*) error
{
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                         message:error.localizedDescription
                                                        delegate:nil
                                               cancelButtonTitle:@"OK"
                                               otherButtonTitles:nil];
    [errorAlert show];
}

@end
