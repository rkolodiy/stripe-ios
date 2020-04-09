//
//  STPBSBNumberValidator.m
//  StripeiOS
//
//  Created by Cameron Sabol on 3/5/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

#import "STPBSBNumberValidator.h"

#import "STPAPIClient.h"
#import "NSString+Stripe.h"
#import "NSBundle+Stripe_AppName.h"
#import "STPAPIClient.h"
#import "STPBundleLocator.h"
#import "STPImageLibrary+Private.h"
#import "STPResourceManager.h"

NS_ASSUME_NONNULL_BEGIN

static const NSUInteger kBSBNumberLength = 6;
static const NSUInteger kBSBNumberDashIndex = 3;

@implementation STPBSBNumberValidator

+ (STPTextValidationState)validationStateForText:(NSString *)text {
    NSString *numericText = [self sanitizedNumericStringForString:text];
    if (numericText.length == 0) {
        return STPTextValidationStateEmpty;
    } else if (numericText.length > kBSBNumberLength) {
        return STPTextValidationStateInvalid;
    } else {
        if (![self _isPossibleValidBSBNumber:numericText]) {
            return STPTextValidationStateInvalid;
        } else {
            return (numericText.length == kBSBNumberLength) ? STPTextValidationStateComplete : STPTextValidationStateIncomplete;
        }
    }
}

+ (BOOL)_isPossibleValidBSBNumber:(NSString *)text {
    if (text.length == 0 || [self identityForText:text] != nil) {
        // this is faster than iterating through keys so try it first
        return YES;
    } else {
        NSDictionary *bsbData = [self _BSBData];
        for (NSString *key in bsbData.allKeys) {
            if (key.length > text.length && [key hasPrefix:text]) {
                return YES;
            }
        }
        return NO;
    }

}

+ (nullable NSString *)formattedSantizedTextFromString:(NSString *)string {
    NSMutableString *numericText = [[[self sanitizedNumericStringForString:string] stp_safeSubstringToIndex:kBSBNumberLength] mutableCopy];
    if (numericText.length >= kBSBNumberDashIndex) {
        [numericText insertString:@"-" atIndex:kBSBNumberDashIndex];
    }

    return [numericText copy];
}

+ (nullable NSDictionary *)_BSBData {
    NSDictionary *sBSBData = [[STPResourceManager sharedManager] jsonNamed:@"au_becs_bsb.json" updateHandler:^(__unused NSDictionary *newDictionary) {
        [STPBSBNumberValidator _regenerateBSBKeyLenghts];
    }];

    if ([[Stripe defaultPublishableKey] containsString:@"_test_"]) {
        NSMutableDictionary *editedBSBData = [sBSBData mutableCopy];
        // Add Stripe Test Bank
        [editedBSBData setObject:@{@"name": @"Stripe Test Bank", @"icon": @"stripe"} forKey:@"00"];
        return [editedBSBData copy];
    }

    return sBSBData;
}

static NSOrderedSet *sBSBKeyLengths = nil;

+ (void)_regenerateBSBKeyLenghts {
    NSDictionary *bsbData = [self _BSBData];
    
    NSMutableOrderedSet<NSNumber *> *keyLengths = [[NSMutableOrderedSet alloc] init];
    for (NSString *bsbKey in bsbData.allKeys) {
        [keyLengths addObject:@(bsbKey.length)];
    }
    [keyLengths sortUsingComparator:^NSComparisonResult(NSNumber *  _Nonnull obj1, NSNumber *  _Nonnull obj2) {
        // obj2 first so we get highest to lowest
        return [obj2 compare:obj1];
    }];
    sBSBKeyLengths = [keyLengths copy];
}

+ (nullable NSDictionary *)_dataForText:(NSString *)text {
    NSDictionary *bsbData = [self _BSBData];

    if (sBSBKeyLengths == nil) {
        [STPBSBNumberValidator _regenerateBSBKeyLenghts];
    }

    for (NSNumber *keyLength in sBSBKeyLengths) {
        NSString *subString = [text stp_safeSubstringToIndex:[keyLength unsignedIntegerValue]];
        if ([bsbData objectForKey:subString] != nil) {
            return [bsbData objectForKey:subString];
        }
    }

    return nil;
}

+ (nullable NSString *)identityForText:(NSString *)text {
    return [[self _dataForText:text] objectForKey:@"name"];
}
+ (UIImage *)iconForText:(nullable __unused  NSString *)text {

    NSString *iconName = [[self _dataForText:text] objectForKey:@"icon"];
    if (iconName != nil) {
        return [STPImageLibrary safeImageNamed:iconName templateIfAvailable:NO];
    } else {
        return [STPImageLibrary safeImageNamed:@"stp_icon_bank" templateIfAvailable:NO];
    }
}

@end

NS_ASSUME_NONNULL_END
