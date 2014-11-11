//
//  TouchDBController.m
//  pictoplanner
//
//  Created by Sander Soeteman on 08-01-13.
//
//

#import "TouchDBController.h"

#import "CouchbaseLite.h"
#import <Security/Security.h>
#import "SSKeychain.h"
#import "SSKeychainQuery.h"


@implementation TouchDBController

NSString * const serviceName = @"Pictoplanner login";

- (id)cast:(Class)requiredClass forObject:(id)object
{
    if( object && ! [object isKindOfClass: requiredClass] )
        object = nil;
    return object;
}
#define castIf(CLASSNAME,OBJ)      ((CLASSNAME*)([self cast:[CLASSNAME class] forObject:OBJ]))


- (NSError*) saveUsername:(NSString *)username withPassword:(NSString *)password
{
    NSError *error = nil;
    error = [self deleteAllAccounts];
    if(error == nil) {
        [SSKeychain setPassword:password forService:serviceName account:username error:&error];
    }
    return error;
}


- (NSString*) getUsername
{
    NSArray* accounts = [SSKeychain accountsForService:serviceName];
    
    if(accounts.count != 1) {
        return nil;
    }
    
    NSDictionary* dict = [accounts objectAtIndex:0];
    return [dict valueForKey: kSSKeychainAccountKey];
}


- (NSError*) deleteAllAccounts
{
    NSError *error = nil;
    SSKeychainQuery *query = [[SSKeychainQuery alloc] init];
    query.service = serviceName;
    
    NSArray* result = [query fetchAll:&error];
    if ([error code] == errSecItemNotFound) {
        return nil;
    } else if (error != nil) {
        return error;
    }
    
    if(result.count > 0) {
        NSEnumerator* e = [result objectEnumerator];
        NSDictionary* dict;
        while ((dict = [e nextObject]) && error == nil) {
            query.account = [dict valueForKey: kSSKeychainAccountKey];
            [query deleteItem:&error];
        }
    }
    
    return error;
}


- (NSString*) getPasswordFor:(NSString *)username
{
    NSError *error = nil;
    SSKeychainQuery *query = [[SSKeychainQuery alloc] init];
    query.service = serviceName;
    query.account = username;
    [query fetch:&error];
    
    if ([error code] == errSecItemNotFound) {
        NSLog(@"Password not found");
    } else if (error != nil) {
        [self displayError:error];
        NSLog(@"Some other error occurred: %@", [error localizedDescription]);
    }

    return [query password];
}


// maakt de touchDB server aan en initialiseert de listener
- (void) doSetupto: (void (^)(NSString* couchDBServer, NSString* version, NSError* error))callback;
{
    NSError *error;
    
    // determine app version
    NSString *version =[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
    
    CBLManager *manager = [CBLManager sharedInstance];

    // we roepen in appgyver vanaf http aan
    [manager.customHTTPHeaders setObject:@"*" forKey:@"Access-Control-Allow-Origin"];
    [manager.customHTTPHeaders setObject:@"Origin,X-Requested-With,Content-Type,Accept" forKey:@"Access-Control-Allow-Headers"];
    [manager.customHTTPHeaders setObject:@"OPTIONS,GET,POST,PUT,DELETE" forKey:@"Access-Control-Allow-Methods"];

    // databases aanmaken wanneer ze niet al bestaan
    CBLDatabase* dbase_App = [manager databaseNamed: @"app"
                                              error: &error];
    if (!dbase_App){
        NSLog(@"FATAL: Error initializing TouchDB dbase app: %@", error);
        callback(nil, nil, error);
        return;
    }
    
    CBLDatabase* dbase_User = [manager databaseNamed: @"planbord_user"
                                               error: &error];
    if (!dbase_User){
        NSLog(@"FATAL: Error initializing TouchDB dbase _local: %@", error);
        callback(nil, nil, error);
        return;
    }
    
    // planbord_user allUsers
    CBLView* viewUsers = [dbase_User viewNamed: @"planbord_user/allUsers"];
    [viewUsers setMapBlock: MAPBLOCK({
            if ([[doc valueForKey:@"type"] isEqualToString:@"user"]) {
                NSNumber* lGebruikerID = castIf(NSNumber, [doc valueForKey: @"GebruikerID"]);
                emit(lGebruikerID, doc);
            }
    }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
    
    
    // planbord_app allClients
    CBLView* viewApp = [dbase_App viewNamed: @"app/allClients"];
    [viewApp setMapBlock: MAPBLOCK({
        if ([[doc valueForKey:@"type"] isEqualToString:@"client"]) {
            NSNumber* lGebruikerID = castIf(NSNumber, [doc valueForKey: @"GebruikerID"]);
            emit(lGebruikerID, doc);
        }
    }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
    
    
    // planbord_app allVersionDocs
    CBLView* viewVersionDocs = [dbase_App viewNamed: @"app/allVersionDocs"];
    [viewVersionDocs setMapBlock: MAPBLOCK({
        if ([[doc valueForKey:@"type"] isEqualToString:@"version"]) {
            NSString* docID = castIf(NSString, [doc valueForKey: @"_id"]);
            emit(docID, doc);
        }
    }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
    
    // compacten wanneer de app in de achtergrond terecht komt
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnteredBackground:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
       
    // URL aan webview teruggeven
    callback([[manager internalURL] absoluteString], version, nil);
}


- (void) handleEnteredBackground:(UIApplication *)application
{
    [self compact];
}


- (void) doRegisterViewsForImageDB: (NSString*) imagesDBName forPlanningDB:(NSString*) planningDBName To:(void (^)(NSError *))callback
{
    NSError* error;
    CBLManager* manager = [CBLManager sharedInstance];
    // register the map reduce functions
    
    CBLDatabase* dbase_Images = [manager databaseNamed: imagesDBName error:&error];
    
    // init dbase
    if (dbase_Images){
        
        // imagesByTag
        CBLView* viewImagesByTag = [dbase_Images viewNamed: @"images/imagesByTag"];
        [viewImagesByTag setMapBlock: MAPBLOCK({
            if ([[doc valueForKey:@"type"] isEqualToString:@"image"]) {
                NSArray* tags = castIf(NSArray, [doc valueForKey: @"Tags"]);
                NSEnumerator* e = [tags objectEnumerator];
                NSString* tag;
                while (tag = [e nextObject]) {
                    emit([NSArray arrayWithObjects:tag, nil], [NSNumber numberWithInt:1]);
                }
            }
        }) reduceBlock:REDUCEBLOCK({
            //    _sum
            return [CBLView totalValues: values];
        }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
        
        // allImages
        CBLView* viewAllImages = [dbase_Images viewNamed: @"images/allImages"];
        [viewAllImages setMapBlock: MAPBLOCK({
            if ([[doc valueForKey:@"type"] isEqualToString:@"image"]) {
                NSString *id = castIf(NSString, [doc valueForKey: @"_id"]);
                emit([NSArray arrayWithObjects:id, nil], nil);
            }
        }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
        
        
        // IMAGES Filter
        [dbase_Images setFilterNamed:@"images/imageFilter" asBlock:^BOOL(CBLRevision *revision, NSDictionary *params) {
            // GebruikerID uit params halen
            NSNumber* id = castIf(NSNumber, [params valueForKey:@"GebruikerID"]);
            
            // als we niet weten voor wie we dit doen, niet syncen
            if ([id integerValue] == -1) {
                return false;
            }

            // type uit document halen
            NSString* type = castIf(NSString, [revision.properties valueForKey:@"type"]);
            if(!([type isEqualToString:@"image"] || [type isEqualToString:@"user_image"])) {
                return false;
            }
            
            // gebruikers uit document halen
            NSArray* gebruikers = castIf(NSArray, [revision.properties valueForKey:@"Gebruikers"]);
            
            // als het document geen eigenaar heeft, NIET syncen
            if (gebruikers == nil || [gebruikers count] == 0) {
                return false;
            }
            
            // als de gebruiker onderdeel is van de gemachtigde gebruikers, syncen
            if ([gebruikers containsObject:id]) {
                return true;
            }
            
            // in alle andere gevallen...
            return false;
        }];
        
        
        // PLANNING
        CBLDatabase* dbase_Planning = [manager databaseNamed:planningDBName error:&error];
        
        if(dbase_Planning) {
            
            // allActiviteiten
            CBLView* viewAllActiviteiten = [dbase_Planning viewNamed: @"planning/allActiviteiten"];
            [viewAllActiviteiten setMapBlock: MAPBLOCK({
                if ([[doc valueForKey:@"type"] isEqualToString:@"activiteit"]) {
                    NSString* activiteitID = castIf(NSString, [doc valueForKey: @"_id"]);
                    emit(activiteitID, doc);
                }
            }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
            
            
            // activiteitenByDate
            CBLView* activiteitenByDate = [dbase_Planning viewNamed: @"planning/activiteitenByDate"];
            [activiteitenByDate setMapBlock: MAPBLOCK({
                if ([[doc valueForKey:@"type"] isEqualToString:@"activiteit"]) {
                    
                    NSArray* datums = [self getActivityDatesForDoc:doc];
                    NSEnumerator* d = [datums objectEnumerator];
                    NSString* datum;
                    NSString* lastDatumStr = nil;
                    while(datum = [d nextObject]) {
                        lastDatumStr = datum;
                        emit([NSArray arrayWithObjects:datum, nil], nil);
                    }
                    
                    // emit de laatste datum waarop we deze activiteit berekend hebben.
                    // Bij notifications berekenen bekijken of dit nog binnen de horizon ligt
                    // herberekenen van de planning als voor alle documenten waarvoor geldt: "planningshorizon < vandaag + 1 jaar"
                    NSString* recurringType = castIf(NSString, [doc valueForKey:@"RecurringType"]);
                    if (nil != lastDatumStr && ![recurringType isEqualToString:@"Geen_herhaling"])
                    {
                        //einddatum?
                        NSString* recurringEndDateString = castIf(NSString, [doc valueForKey:@"RecurringEndDate"]);
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                        NSDate *recurringEndDate = [dateFormatter dateFromString:recurringEndDateString];
                        NSDate* lastDatum = [dateFormatter dateFromString:lastDatumStr]; 
                        
                        // omdat lastdate altijd ten hoogste einddatum-1 kan zijn
                        if(recurringEndDate != nil) {
                            NSCalendar *gregorian = [[NSCalendar alloc]
                                                     initWithCalendarIdentifier:NSGregorianCalendar];
                            NSDateComponents *offsetComponent = [[NSDateComponents alloc] init];
                            [offsetComponent setDay:-2];
                            recurringEndDate = [gregorian dateByAddingComponents:offsetComponent toDate:recurringEndDate options:0];
                        }
                        
                        if(recurringEndDate == nil || [lastDatum laterDate:recurringEndDate] == recurringEndDate) {
                            emit([NSArray arrayWithObjects:@"planningshorizon", lastDatumStr, nil], nil);
                        }
                    }

                }
            }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
            
            // dienstsoortByDatum
            CBLView* viewdienstsoortByDatum = [dbase_Planning viewNamed: @"planning/dienstsoortByDatum"];
            [viewdienstsoortByDatum setMapBlock: MAPBLOCK({
                NSNumber* status = castIf(NSNumber, [doc valueForKey: @"Status"]);
                if ([[doc valueForKey:@"type"] isEqualToString:@"dienst"] && [status isEqualToNumber:[NSNumber numberWithInt:1]]) {
                    NSArray* datums = [self getDatesForDienstsoortDoc:doc];
                    NSEnumerator* d = [datums objectEnumerator];
                    NSString* datum;
                    while(datum = [d nextObject]) {
                        emit([NSArray arrayWithObjects:datum, nil], nil);
                    }
                }
                else if ([[doc valueForKey:@"type"] isEqualToString:@"extradienst"] && [status isEqualToNumber:[NSNumber numberWithInt:1]]) {
                    NSDictionary* diensten = castIf(NSDictionary, [doc valueForKey:@"Diensten"]);
                    NSEnumerator* keys = [diensten keyEnumerator];
                    NSString* key;
                    while(key = [keys nextObject]) {
                        emit([NSArray arrayWithObjects:key, nil], nil);
                    }
                }

            }) version:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
            
            // Planning Filter
            [dbase_Planning setFilterNamed:@"planning/planningFilter" asBlock:^BOOL(CBLRevision *revision, NSDictionary *params) {
                // GebruikerID uit params halen
                NSNumber* id = castIf(NSNumber, [params valueForKey:@"GebruikerID"]);
                
                // als we niet weten voor wie we dit doen, niet syncen
                if ([id integerValue] == -1) {
                    return false;
                }
                
                // type uit document halen
                NSString* type = castIf(NSString, [revision.properties valueForKey:@"type"]);
                if(![type isEqualToString:@"activiteit"]) {
                    return false;
                }
                
                // gebruikers uit document halen
                NSArray* gebruikers = castIf(NSArray, [revision.properties valueForKey:@"Gebruikers"]);
                
                // als het document geen eigenaar heeft, NIET syncen
                if (gebruikers == nil || [gebruikers count] == 0) {
                    return false;
                }
                
                // als de gebruiker onderdeel is van de gemachtigde gebruikers, syncen
                if ([gebruikers containsObject:id]) {
                    return true;
                }
                
                // in alle andere gevallen...
                return false;
            }];
            
            // view planning aanroepen en daardoor initialiseren voordat de javascript app dit gaat doen
            [self touchViewsForImageDB:imagesDBName forPlanningDB:planningDBName];
            
            callback(nil);
        }
        else {
            callback(error);
        }
    }
    else {
        callback(error);
    }
}

- (void) doSetupUser:(NSString *)username to:(void (^)(NSError *))callback
{
    NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    
    NSString* planningDBName = [NSString stringWithFormat:@"planning_%@", username];
    NSString* imagesDBName = [NSString stringWithFormat:@"images_%@", username];
    
    [self doRegisterViewsForImageDB:imagesDBName forPlanningDB:planningDBName To:^(NSError * registerError) {
        callback(registerError);
    }];
}


- (NSError*) doSetupReplicationForUser:(NSString*)username andPassword:(NSString*)thePassword onServer:(NSString*) remoteServer withPlanningDBs:(NSArray*) planningDBs withImageDBs:(NSArray*) imageDBs
{
    NSNumberFormatter* f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber* gebruikerID = [[f numberFromString:username] copy];
    NSString* password = [self getPasswordFor:username];
    
    if(gebruikerID != nil) {
        
        // CouchbaseLite wrapper
        CBLManager* manager = [CBLManager sharedInstance];
        NSError* error;
        
        NSString* planningDBName = [[NSString stringWithFormat:@"planning_%@", username] copy];
        NSString* imagesDBName = [[NSString stringWithFormat:@"images_%@", username] copy];
        
        CBLDatabase* dbase_Planning = [manager existingDatabaseNamed:planningDBName error:&error];
        if (!dbase_Planning){
            NSLog(@"FATAL: Error initializing TouchDB dbase planning: %@", error);
            return error;
        }
        CBLDatabase* dbase_Images = [manager existingDatabaseNamed:imagesDBName error:&error];
        if (!dbase_Images){
            NSLog(@"FATAL: Error initializing TouchDB dbase images: %@", error);
            return error;
        }
        
        NSArray* split = [remoteServer componentsSeparatedByString:@"://"];
        NSAssert(split.count == 2, @"remote server address doesn't contain scheme");
        NSString *scheme = [split objectAtIndex:0];
        NSString *hostname = [split objectAtIndex:1];
        
//        int port = [scheme isEqual: @"https"] ? 443 : 80;
        
//        // credentials aan keychain toevoegen
//        NSURLCredential* cred;
//        cred = [NSURLCredential credentialWithUser: username
//                                          password: password
//                                       persistence: NSURLCredentialPersistencePermanent];
//
//        NSURLProtectionSpace* space;
//        space = [[NSURLProtectionSpace alloc] initWithHost: hostname
//                                                       port: port
//                                                   protocol: scheme
//                                                      realm: @"administrator"
//                                       authenticationMethod: NSURLAuthenticationMethodDefault];
//
//        [[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential: cred
//                                                            forProtectionSpace: space];
        
        // Images database repliceren vanaf server
        NSDictionary* filterParams = [[NSDictionary alloc] initWithObjectsAndKeys:gebruikerID, @"GebruikerID", nil];

        NSEnumerator* imageDBEnum = [imageDBs objectEnumerator];
        NSString* remoteImagesDBName;
        while(remoteImagesDBName = [imageDBEnum nextObject]) {
            
            NSString* pbImagesServerAddress = [[NSArray arrayWithObjects:scheme, @"://", username, @":", password, @"@", hostname, @"/", remoteImagesDBName, nil] componentsJoinedByString:@""];
            
            // filter from
            CBLReplication* imgRepFrom = [dbase_Images createPullReplication:[NSURL URLWithString:pbImagesServerAddress]];
            imgRepFrom.continuous = YES;
            [imgRepFrom start];
            
            // alleen pushen naar eigen db
            if([imagesDBName isEqual:remoteImagesDBName]) {
                // filter to
                CBLReplication* imgRepTo = [dbase_Images createPushReplication:[NSURL URLWithString:pbImagesServerAddress]];
                imgRepTo.filter = @"images/imageFilter";
                imgRepTo.filterParams = filterParams;
                imgRepTo.continuous = YES;
                [imgRepTo start];
            }
        }
        
        NSEnumerator* planningDBEnum = [planningDBs objectEnumerator];
        NSString* remotePlanningDBName;
        while(remotePlanningDBName = [planningDBEnum nextObject]) {
        
            NSString* pbPlanningServerAddress = [[NSArray arrayWithObjects:scheme, @"://", username, @":", password, @"@", hostname, @"/", remotePlanningDBName, nil] componentsJoinedByString:@""];

            // persisten maken
            CBLReplication* planningRepFrom = [dbase_Planning createPullReplication:[NSURL URLWithString:pbPlanningServerAddress]];
            planningRepFrom.continuous = YES;
            [planningRepFrom start];
            
            if([planningDBName isEqual:remotePlanningDBName]) {
                CBLReplication* planningRepTo = [dbase_Planning createPushReplication:[NSURL URLWithString:pbPlanningServerAddress]];
                planningRepTo.filter = @"planning/planningFilter";
                planningRepTo.filterParams = filterParams;
                planningRepTo.continuous = YES;
                [planningRepTo start];
            }
        }        
    }
    
    return nil;
}


- (void) stopReplications
{
    CBLManager* manager = [CBLManager sharedInstance];
    
    // alle bestaande replications weggooien
    NSArray* dbs = [manager allDatabaseNames];
    NSEnumerator* dbEnum = [dbs objectEnumerator];
    NSString* dbName;
    NSError* error;
    while(dbName = [dbEnum nextObject]) {
        CBLDatabase* db = [manager existingDatabaseNamed:dbName error:&error];
        if(db && db.allReplications != nil && [db.allReplications count] > 0) {
            NSEnumerator* repEnum = [db.allReplications objectEnumerator];
            CBLReplication* repl;
            while(repl = [repEnum nextObject]) {
                [repl stop];
            }
        }
    }    
}


- (void) compact
{
    NSDate *today = [[NSDate alloc] init];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString* todayStr = [dateFormatter stringFromDate:today];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* lastStr = [userDefaults stringForKey:@"lastCompaction"];
    bool isLarger = false;
    
    if(lastStr != nil) {
        NSComparisonResult result = [todayStr compare:lastStr];
        isLarger = result == NSOrderedDescending;
    }
    
    if(lastStr == nil || isLarger) {
        CBLManager* manager = [CBLManager sharedInstance];
        
        // alle bestaande replications weggooien
        NSArray* dbs = [manager allDatabaseNames];
        NSEnumerator* dbEnum = [dbs objectEnumerator];
        NSString* dbName;
        NSError* error;
        while(dbName = [dbEnum nextObject]) {
            CBLDatabase* db = [manager existingDatabaseNamed:dbName error:&error];
            if(db) {
                [db compact:&error];
            }
        }
        
        [userDefaults setObject:todayStr forKey:@"lastCompaction"];
    }
}



- (QueryResult*) getNextActivities:(int)count
{
    NSMutableArray* activities = [[NSMutableArray alloc] init];
    // CouchbaseLite wrapper
    CBLManager* manager = [CBLManager sharedInstance];
    
    NSString* username = [self getUsername];
    NSString* planningDBName = [NSString stringWithFormat:@"planning_%@", username];
    
    NSError *error;
    CBLDatabase* dbase_Planning = [manager databaseNamed: planningDBName error: &error];
    if (!dbase_Planning){
        NSLog(@"FATAL: Error initializing TouchDB dbase planning: %@", error);
        QueryResult* result = [[QueryResult alloc] init];
        result.error = error;
        return result;
    }
    
    // opzoeken eerste 64 activiteiten waarvoor notifications aangemaakt moeten worden
    NSDate *today = [[NSDate alloc] init];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    CBLView* view = [dbase_Planning viewNamed:@"planning/activiteitenByDate"];
    CBLQuery* query = [view createQuery];
    query.startKey = [NSArray arrayWithObjects:[dateFormatter stringFromDate:today], nil];
    query.limit = count;
    query.prefetch = YES;
    
    CBLQueryEnumerator* rows = [query run:&error];
    CBLQueryRow* row;
    while((row = [rows nextRow])) {
        if([row.key isKindOfClass:[NSString class]]) {
            // datum uit key halen
            NSDate* date = [dateFormatter dateFromString:[row.key objectAtIndex:0]];
            NSMutableDictionary* dict = [row.document.properties mutableCopy];
            [dict setObject:date forKey:@"StartDatum"];
            
            [activities addObject:dict];
        }

    }
    
    QueryResult* result = [[QueryResult alloc] init];
    result.resultSet = activities;
    
    return result;
}


- (NSError*) resaveHorizonActivities
{
    // CouchbaseLite wrapper
    CBLManager* manager = [CBLManager sharedInstance];

    NSString* username = [self getUsername];
    NSString* planningDBName = [NSString stringWithFormat:@"planning_%@", username];
    
    NSError *error;
    CBLDatabase* dbase_Planning = [manager databaseNamed: planningDBName error: &error];
    if (!dbase_Planning){
        NSLog(@"FATAL: Error initializing TouchDB dbase planning: %@", error);
        return error;
    }
    
    NSDate *today = [[NSDate alloc] init];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    
    
    // opnieuw opslaan van activiteiten die buiten de horizon zijn verdwenen
    // emit([NSArray arrayWithObjects:@"planningshorizon", datum, nil], [doc valueForKey:@"ActiviteitID"]);
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *horizonComp = [[NSDateComponents alloc] init];
    [horizonComp setYear:1];
    NSDate *horizon = [gregorian dateByAddingComponents:horizonComp
                                                 toDate:today options:0];
    
    CBLView* view = [dbase_Planning viewNamed:@"planning/activiteitenByDate"];
    CBLQuery* query = [view createQuery];
    query.startKey = [NSArray arrayWithObjects:@"planningshorizon", nil];
    query.endKey = [NSArray arrayWithObjects:@"planningshorizon", [dateFormatter stringFromDate:horizon], nil];
    query.prefetch = YES;
    
    CBLQueryEnumerator* rows = [query run:&error];
    CBLQueryRow* row;
    while((row = [rows nextRow])) {
        NSLog(@"resaveHorizonActivity");
        // opnieuw opslaan document
        
        CBLDocument* doc = row.document;
        NSString* recurringType = [doc.properties valueForKey:@"RecurringType"];
        
        if ([recurringType isEqualToString:@"Jaarlijks"]) {
            // datum uit key halen
            NSArray* key = row.key;
            NSString* dateStr = [key objectAtIndex:1];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            NSDate *horizonDate = [dateFormatter dateFromString:dateStr];
            
            // vandaag plus 5 maand
            NSDateComponents *windowComp = [[NSDateComponents alloc] init];
            [windowComp setMonth:5];
            NSDate *window = [gregorian dateByAddingComponents:windowComp
                                                         toDate:today options:0];
            if([window laterDate:horizonDate] == window) {
                NSLog(@"emitting...");
                NSMutableDictionary* props = [doc.properties mutableCopy];
                [doc.currentRevision createRevisionWithProperties:props error: &error];
            }
        }
        else {
            NSLog(@"emitting2...");
            NSMutableDictionary* props = [doc.properties mutableCopy];
            [doc.currentRevision createRevisionWithProperties:props error: &error];
        }
    }
    
    return nil;
}

- (NSArray*) getDatesForDienstsoortDoc:(NSDictionary*) doc
{
    NSMutableArray* dates = [[NSMutableArray alloc] init];
    
    // periode waarvoor de dates berekend gaan worden
    NSInteger leftExtentPeriod = [[NSNumber numberWithInt:20] integerValue];
    NSInteger rightExtentPeriod = [[NSNumber numberWithInt:60] integerValue];
    
    NSDate *today = [[NSDate alloc] init];
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *offsetLeftComponents = [[NSDateComponents alloc] init];
    NSDateComponents *offsetRightComponents = [[NSDateComponents alloc] init];
    [offsetLeftComponents setDay:-leftExtentPeriod];
    [offsetRightComponents setDay:rightExtentPeriod];
    NSDate *leftExtent = [gregorian dateByAddingComponents:offsetLeftComponents
                                                    toDate:today options:0];
    NSDate *rightExtent = [gregorian dateByAddingComponents:offsetRightComponents
                                                     toDate:today options:0];
    
    // left en right extent op 00:00
    NSDateComponents *components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate: leftExtent];
    leftExtent = [gregorian dateFromComponents:components];
    components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate: rightExtent];
    rightExtent = [gregorian dateFromComponents:components];
    NSDate* docDatum = [[NSDate alloc] initWithTimeInterval:0 sinceDate:leftExtent];
    
    NSDateComponents *offsetComponent = [[NSDateComponents alloc] init];
    [offsetComponent setWeek:1];
    
    bool ma = [castIf(NSNumber, [doc valueForKey:@"ma"]) boolValue];
    bool di = [castIf(NSNumber, [doc valueForKey:@"di"]) boolValue];
    bool wo = [castIf(NSNumber, [doc valueForKey:@"wo"]) boolValue];
    bool don = [castIf(NSNumber, [doc valueForKey:@"don"]) boolValue];
    bool vr = [castIf(NSNumber, [doc valueForKey:@"vr"]) boolValue];
    bool za = [castIf(NSNumber, [doc valueForKey:@"za"]) boolValue];
    bool zo = [castIf(NSNumber, [doc valueForKey:@"zo"]) boolValue];
    NSMutableArray* dagen = [[NSMutableArray alloc] init];
    
    if(zo) {
        [dagen addObject:[NSNumber numberWithInt:1]];
    }
    if(ma) {
        [dagen addObject:[NSNumber numberWithInt:2]];
    }
    if(di) {
        [dagen addObject:[NSNumber numberWithInt:3]];
    }
    if(wo) {
        [dagen addObject:[NSNumber numberWithInt:4]];
    }
    if(don) {
        [dagen addObject:[NSNumber numberWithInt:5]];
    }
    if(vr) {
        [dagen addObject:[NSNumber numberWithInt:6]];
    }
    if(za) {
        [dagen addObject:[NSNumber numberWithInt:7]];
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    
    // vanaf docDatum emitten
    do {
        // Get the weekday component of the current date
        NSDateComponents *weekdayComponents = [gregorian components:NSWeekdayCalendarUnit fromDate:docDatum];
        // elke geselecteerde dag in deze week langs
        NSEnumerator* dagenEnum = [dagen objectEnumerator];
        NSNumber* dag;
        while(dag = [dagenEnum nextObject]) {
            /*
             Create a date components to represent the number of days to subtract from the current date.
             The weekday value for Sunday in the Gregorian calendar is 1, so subtract 1 from the number of days to subtract from the date in question.  (If today is Sunday, subtract 0 days.)
             */
            NSDateComponents *componentsToSubtract = [[NSDateComponents alloc] init];
            [componentsToSubtract setDay: [dag integerValue] - [weekdayComponents weekday]];
            
            NSDate *weekDag = [gregorian dateByAddingComponents:componentsToSubtract
                                                         toDate:docDatum options:0];
            if([weekDag laterDate:leftExtent] == weekDag &&
               [rightExtent laterDate:weekDag] == rightExtent) {
                
                [dates addObject:[dateFormatter stringFromDate:weekDag]];
            }
        }
        
        // advance docDatum
        docDatum = [gregorian dateByAddingComponents:offsetComponent toDate:docDatum options:0];
        
    } while ([rightExtent laterDate:docDatum] == rightExtent);
    
    return dates;
}


/*
 Bepalen datums activiteiten
 */

// retourneert een array met date strings
- (NSArray*) getActivityDatesForDoc:(NSDictionary*) doc
{
    NSMutableArray* dates = [[NSMutableArray alloc] init];
    
    // periode waarvoor de dates berekend gaan worden
    NSInteger leftExtentPeriod = [[NSNumber numberWithInt:120] integerValue];
    NSInteger rightExtentPeriod = [[NSNumber numberWithInt:420] integerValue];
    
    NSString* recurringType = castIf(NSString, [doc valueForKey:@"RecurringType"]);
    NSString* datum = castIf(NSString, [doc valueForKey:@"Datum"]);
    
    if([recurringType isEqualToString:@"Geen_herhaling"]) {
        [dates addObject:datum];
    }
    
    else {
        
        // bounding box (extent) bepalen
        NSDate *today = [[NSDate alloc] init];
        NSCalendar *gregorian = [[NSCalendar alloc]
                                 initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *offsetLeftComponents = [[NSDateComponents alloc] init];
        NSDateComponents *offsetRightComponents = [[NSDateComponents alloc] init];
        [offsetLeftComponents setDay:-leftExtentPeriod];
        [offsetRightComponents setDay:rightExtentPeriod];
        NSDate *leftExtent = [gregorian dateByAddingComponents:offsetLeftComponents
                                                        toDate:today options:0];
        NSDate *rightExtent = [gregorian dateByAddingComponents:offsetRightComponents
                                                         toDate:today options:0];
        
        // left en right extent op 00:00
        NSDateComponents *components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate: leftExtent];
        leftExtent = [gregorian dateFromComponents:components];
        components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate: rightExtent];
        rightExtent = [gregorian dateFromComponents:components];
        
        // einddatum voor herhaalpatroon?
        NSString* recurringEndDateString = castIf(NSString, [doc valueForKey:@"RecurringEndDate"]);
        NSDictionary* recurringPattern = castIf(NSDictionary, [doc valueForKey:@"RecurringPattern"]);
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        NSDate *recurringEndDate = [dateFormatter dateFromString:recurringEndDateString];
        NSDate* docDatum = [dateFormatter dateFromString:datum];
        NSDate* origDocDatum = [dateFormatter dateFromString:datum];
        
        if(recurringPattern != nil) {
            NSNumber* per_n = castIf(NSNumber, [recurringPattern valueForKey:@"per_n"]);
            
            // einddatum rechts van begin venster en begindatum links van eind venster?
            if(docDatum != nil &&
               (recurringEndDate == nil ||
                (([recurringEndDate laterDate:leftExtent] == recurringEndDate) && ([rightExtent laterDate:docDatum] == rightExtent)))) {
                   
                   // DAGELIJKS
                   if ([recurringType isEqualToString:@"Dagelijks"]) {
                       NSDateComponents *offsetComponent = [[NSDateComponents alloc] init];
                       [offsetComponent setDay:[per_n integerValue]];
                       
                       // vanaf docDatum emitten
                       do {
                           if(![self isIgnoredDate:docDatum inDoc:doc] && [docDatum laterDate:leftExtent] == docDatum && [rightExtent laterDate:docDatum] == rightExtent) {
                               
                               [dates addObject:[dateFormatter stringFromDate:docDatum]];
                           }
                           
                           // advance docDatum
                           docDatum = [gregorian dateByAddingComponents:offsetComponent toDate:docDatum options:0];
                           
                       } while ([rightExtent laterDate:docDatum] == rightExtent &&
                                (recurringEndDate == nil || [recurringEndDate laterDate:docDatum] == recurringEndDate));
                   }
                   
                   
                   // WEKELIJKS
                   else if ([recurringType isEqualToString:@"Wekelijks"]) {
                       NSDateComponents *offsetComponent = [[NSDateComponents alloc] init];
                       [offsetComponent setWeek:[per_n integerValue]];
                       
                       bool ma = [castIf(NSNumber, [recurringPattern valueForKey:@"ma"]) boolValue];
                       bool di = [castIf(NSNumber, [recurringPattern valueForKey:@"di"]) boolValue];
                       bool wo = [castIf(NSNumber, [recurringPattern valueForKey:@"wo"]) boolValue];
                       bool don = [castIf(NSNumber, [recurringPattern valueForKey:@"don"]) boolValue];
                       bool vr = [castIf(NSNumber, [recurringPattern valueForKey:@"vr"]) boolValue];
                       bool za = [castIf(NSNumber, [recurringPattern valueForKey:@"za"]) boolValue];
                       bool zo = [castIf(NSNumber, [recurringPattern valueForKey:@"zo"]) boolValue];
                       NSMutableArray* dagen = [[NSMutableArray alloc] init];
                       
                       if(zo) {
                           [dagen addObject:[NSNumber numberWithInt:1]];
                       }
                       if(ma) {
                           [dagen addObject:[NSNumber numberWithInt:2]];
                       }
                       if(di) {
                           [dagen addObject:[NSNumber numberWithInt:3]];
                       }
                       if(wo) {
                           [dagen addObject:[NSNumber numberWithInt:4]];
                       }
                       if(don) {
                           [dagen addObject:[NSNumber numberWithInt:5]];
                       }
                       if(vr) {
                           [dagen addObject:[NSNumber numberWithInt:6]];
                       }
                       if(za) {
                           [dagen addObject:[NSNumber numberWithInt:7]];
                       }
                       
                       // vanaf docDatum emitten
                       do {
                           // Get the weekday component of the current date
                           NSDateComponents *weekdayComponents = [gregorian components:NSWeekdayCalendarUnit fromDate:docDatum];
                           // elke geselecteerde dag in deze week langs
                           NSEnumerator* dagenEnum = [dagen objectEnumerator];
                           NSNumber* dag;
                           while(dag = [dagenEnum nextObject]) {
                               /*
                                Create a date components to represent the number of days to subtract from the current date.
                                The weekday value for Sunday in the Gregorian calendar is 1, so subtract 1 from the number of days to subtract from the date in question.  (If today is Sunday, subtract 0 days.)
                                */
                               NSDateComponents *componentsToSubtract = [[NSDateComponents alloc] init];
                               [componentsToSubtract setDay: [dag integerValue] - [weekdayComponents weekday]];
                               
                               NSDate *weekDag = [gregorian dateByAddingComponents:componentsToSubtract
                                                                            toDate:docDatum options:0];
                               if(![self isIgnoredDate:weekDag inDoc:doc] &&
                                  [weekDag laterDate:origDocDatum] == weekDag &&
                                  [weekDag laterDate:leftExtent] == weekDag &&
                                  [rightExtent laterDate:weekDag] == rightExtent &&
                                  (recurringEndDate == nil || [recurringEndDate laterDate:weekDag] == recurringEndDate)) {
                                   
                                   [dates addObject:[dateFormatter stringFromDate:weekDag]];
                               }
                           }
                           
                           // advance docDatum
                           docDatum = [gregorian dateByAddingComponents:offsetComponent toDate:docDatum options:0];
                           
                       } while ([rightExtent laterDate:docDatum] == rightExtent &&
                                (recurringEndDate == nil || [recurringEndDate laterDate:docDatum] == recurringEndDate));
                   }
                   
                   
                   // maandelijks
                   else if ([recurringType isEqualToString:@"Maandelijks"]) {
                       // telkens n maanden verspringen
                       NSDateComponents *offsetComponent = [[NSDateComponents alloc] init];
                       [offsetComponent setMonth:[per_n integerValue]];
                       
                       // dag van de maand bepalen adhv originele docDatum
                       NSDateComponents *dayComp = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                                fromDate:docDatum];
                       int dayOfMonth = [dayComp day];
                       // docdatum naar eerste van de maand verplaatsen
                       [dayComp setDay:1];
                       docDatum = [gregorian dateFromComponents:dayComp];
                       
                       // loopen over bereik
                       do {
                           NSRange rng = [gregorian rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:docDatum];
                           NSUInteger numberOfDaysInMonth = rng.length;
                           
                           dayComp = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                  fromDate:docDatum];
                           
                           if(numberOfDaysInMonth >= dayOfMonth) {
                               
                               [dayComp setDay:dayOfMonth];
                               docDatum = [gregorian dateFromComponents:dayComp];
                               
                               if(![self isIgnoredDate:docDatum inDoc:doc] &&
                                  [docDatum laterDate:leftExtent] == docDatum &&
                                  [rightExtent laterDate:docDatum] == rightExtent &&
                                  (recurringEndDate == nil || [recurringEndDate laterDate:docDatum] == recurringEndDate)) {
                                   
                                   [dates addObject:[dateFormatter stringFromDate:docDatum]];
                               }
                           }
                           
                           // docDatum eerst weer op de eerste dag van de maand zetten
                           dayComp = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                  fromDate:docDatum];
                           [dayComp setDay:1];
                           // advance docDatum
                           docDatum = [gregorian dateFromComponents:dayComp];
                           docDatum = [gregorian dateByAddingComponents:offsetComponent toDate:docDatum options:0];
                           
                       } while ([rightExtent laterDate:docDatum] == rightExtent &&
                                (recurringEndDate == nil || [recurringEndDate laterDate:docDatum] == recurringEndDate));
                   }
                   
                   // jaarlijks
                   else if ([recurringType isEqualToString:@"Jaarlijks"]) {
                       // telkens n jaren verspringen
                       NSDateComponents *offsetComponent = [[NSDateComponents alloc] init];
                       [offsetComponent setYear:[per_n integerValue]];
                       
                       // dag van de maand bepalen adhv originele docDatum
                       NSDateComponents *dayComp = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                                fromDate:docDatum];
                       int dayOfMonth = [dayComp day];
                       // docdatum naar eerste van de maand verplaatsen
                       [dayComp setDay:1];
                       docDatum = [gregorian dateFromComponents:dayComp];
                       
                       // loopen over bereik
                       do {
                           NSRange rng = [gregorian rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:docDatum];
                           NSUInteger numberOfDaysInMonth = rng.length;
                           
                           dayComp = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                  fromDate:docDatum];
                           
                           if(numberOfDaysInMonth >= dayOfMonth) {
                               
                               [dayComp setDay:dayOfMonth];
                               docDatum = [gregorian dateFromComponents:dayComp];
                               
                               if(![self isIgnoredDate:docDatum inDoc:doc] &&
                                  [docDatum laterDate:leftExtent] == docDatum &&
                                  [rightExtent laterDate:docDatum] == rightExtent &&
                                  (recurringEndDate == nil || [recurringEndDate laterDate:docDatum] == recurringEndDate)) {
                                   
                                   [dates addObject:[dateFormatter stringFromDate:docDatum]];
                               }
                           }
                           
                           // docDatum eerst weer op de eerste dag van de maand zetten
                           dayComp = [gregorian components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
                                                  fromDate:docDatum];
                           [dayComp setDay:1];
                           // advance docDatum
                           docDatum = [gregorian dateFromComponents:dayComp];
                           docDatum = [gregorian dateByAddingComponents:offsetComponent toDate:docDatum options:0];
                           
                       } while ([rightExtent laterDate:docDatum] == rightExtent &&
                                (recurringEndDate == nil || [recurringEndDate laterDate:docDatum] == recurringEndDate));
                   }
                   
                   // fout
                   else {
                       // fout
                   }
               }
        }
    }
    
    return dates;
}


- (BOOL) isIgnoredDate:(NSDate*) date inDoc:(NSDictionary*) doc
{
    NSArray* datesToIgnoreArray = castIf(NSArray, [doc valueForKey:@"DatesToIgnore"]);
    if(datesToIgnoreArray == nil || [datesToIgnoreArray count] == 0) {
        return NO;
    }
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    
    NSString* dateStr = [dateFormatter stringFromDate:date];
    NSEnumerator* datesToIgnore = [datesToIgnoreArray objectEnumerator];
    NSDictionary* dateToIgnoreStruct;
    NSString* dateToIgnore;
    while (dateToIgnoreStruct = [datesToIgnore nextObject]) {
        dateToIgnore = castIf(NSString, [dateToIgnoreStruct valueForKey:@"Datum"]);
        if([dateStr isEqualToString:dateToIgnore]) {
            return YES;
        }
    }
    
    return NO;
}


- (NSString*) touchViewsForImageDB: (NSString*) imagesDBName forPlanningDB:(NSString*) planningDBName
{
    // CouchbaseLite wrapper
    CBLManager* manager = [CBLManager sharedInstance];
    
    NSError *error;
    CBLDatabase* dbase_Planning = [manager databaseNamed: planningDBName error: &error];
    if (!dbase_Planning){
        return [error localizedDescription];
    }
    CBLDatabase* dbase_Images = [manager databaseNamed: imagesDBName error: &error];
    if (!dbase_Images){
        return [error localizedDescription];
    }
    
    // opzoeken activiteiten
    NSDate *today = [[NSDate alloc] init];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    CBLView* viewActiviteiten = [dbase_Planning viewNamed:@"planning/activiteitenByDate"];
    CBLQuery* query = [viewActiviteiten createQuery];
    query.startKey = [NSArray arrayWithObjects:[dateFormatter stringFromDate:today], nil];
    query.endKey = [NSArray arrayWithObjects:[dateFormatter stringFromDate:today], nil];
    query.limit = 1;
    @try {
        CBLQueryEnumerator* rows = [query run:&error];
    }
    @catch (NSException *exception) {
        return [exception description];
    }
    
    CBLView* viewImages = [dbase_Images viewNamed:@"images/imagesByTag"];
    CBLQuery* query2 = [viewImages createQuery];
    query2.startKey = [NSArray arrayWithObjects:@"test", nil];
    query2.endKey = [NSArray arrayWithObjects:@"test", nil];
    query2.limit = 1;
    @try {
        CBLQueryEnumerator* rows2 = [query2 run:&error];
    }
    @catch (NSException *exception) {
        return [exception description];
    }
    
    return nil;
}


/*
 Utility methods
 */

- (NSString*) GetServerPath
{
    NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID)
        bundleID = @"com.couchbase.TouchServ";
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString* path = paths[0];
    path = [path stringByAppendingPathComponent: bundleID];
    path = [path stringByAppendingPathComponent: @"TouchDB"];
    NSError* error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath: path
                                   withIntermediateDirectories: YES
                                                    attributes: nil error: &error]) {
        NSLog(@"FATAL: Couldn't create TouchDB server dir at %@", path);
        exit(1);
    }
    return path;
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
