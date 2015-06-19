//
//  HWDecoder.h
//  testFrameExtractor
//
//  Created by htaiwan on 6/19/15.
//  Copyright (c) 2015 appteam. All rights reserved.
//

#import <Foundation/Foundation.h>

@import AudioToolbox;
@import VideoToolbox;
@import CoreGraphics;
@import UIKit;
@import Foundation;

@protocol HWDecoderDelegate <NSObject>
@optional

-(void) startDecodeData;
-(void) getDecodeImageData:(CVImageBufferRef) imageBuffer;

@end

@interface HWDecoder : NSObject

@property (nonatomic, strong) id <HWDecoderDelegate> delegate;

- (void) iOS8HWDecode:(NSData *) spsData ppsData:(NSData*) ppsData;

@end
