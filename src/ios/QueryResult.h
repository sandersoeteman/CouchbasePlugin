//
//  QueryResult.h
//  pictoplanner
//
//  Created by Sander Soeteman on 08-01-13.
//
//

#import <Foundation/Foundation.h>

@interface QueryResult : NSObject
@property (nonatomic, strong) NSError* error;
@property (nonatomic, strong) NSArray* resultSet;
@end
