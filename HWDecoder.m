//
//  HWDecoder.m
//  testFrameExtractor
//
//  Created by htaiwan on 6/19/15.
//  Copyright (c) 2015 appteam. All rights reserved.
//

#import "HWDecoder.h"

@interface HWDecoder ()
{
    AVFormatContext *pFormatCtx;
    AVCodecContext *pCodecCtx;
    AVPacket packet;
    CMVideoFormatDescriptionRef videoFormatDescr;
    VTDecompressionSessionRef session;
    OSStatus status;
}
@end


@implementation HWDecoder

- (void) iOS8HWDecode:(NSData *) spsData ppsData:(NSData*) ppsData
{
    // 1. Get SPS,PPS form stream data, and create CMFormatDescription, VTDecompressionSession
    if (spsData == nil && ppsData == nil) {
        uint8_t *data = pCodecCtx -> extradata;
        int size = pCodecCtx -> extradata_size;
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < size; i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",data[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        
        NSLog(@"size ---->>%i",size);
        NSLog(@"%@",tmp3);
        
        int startCodeSPSIndex = 0;
        int startCodePPSIndex = 0;
        int spsLength = 0;
        int ppsLength = 0;
        
        for (int i = 0; i < size; i++) {
            if (i >= 3) {
                if (data[i] == 0x01 && data[i-1] == 0x00 && data[i-2] == 0x00 && data[i-3] == 0x00) {
                    if (startCodeSPSIndex == 0) {
                        startCodeSPSIndex = i;
                    }
                    if (i > startCodeSPSIndex) {
                        startCodePPSIndex = i;
                    }
                }
            }
        }
        
        spsLength = startCodePPSIndex - startCodeSPSIndex - 4;
        ppsLength = size - (startCodePPSIndex + 1);
        
        NSLog(@"startCodeSPSIndex --> %i",startCodeSPSIndex);
        NSLog(@"startCodePPSIndex --> %i",startCodePPSIndex);
        NSLog(@"spsLength --> %i",spsLength);
        NSLog(@"ppsLength --> %i",ppsLength);
        
        int nalu_type;
        nalu_type = ((uint8_t) data[startCodeSPSIndex + 1] & 0x1F);
        NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
        if (nalu_type == 7) {
            spsData = [NSData dataWithBytes:&(data[startCodeSPSIndex + 1]) length: spsLength];
        }
        
        nalu_type = ((uint8_t) data[startCodePPSIndex + 1] & 0x1F);
        NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
        if (nalu_type == 8) {
            ppsData = [NSData dataWithBytes:&(data[startCodePPSIndex + 1]) length: ppsLength];
        }
        
        // 2. create  CMFormatDescription
        if (spsData != nil && ppsData != nil) {
            const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)[spsData bytes], (const uint8_t*)[ppsData bytes] };
            const size_t parameterSetSizes[2] = { [spsData length], [ppsData length] };
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &videoFormatDescr);
                NSLog(@"Found all data for CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
        }
        
        // 3. create VTDecompressionSession
        VTDecompressionOutputCallbackRecord callback;
        callback.decompressionOutputCallback = didDecompress;
        callback.decompressionOutputRefCon = (__bridge void *)self;
        NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],(id)kCVPixelBufferOpenGLESCompatibilityKey,[NSNumber numberWithInt:kCVPixelFormatType_32BGRA],(id)kCVPixelBufferPixelFormatTypeKey,nil];
        status = VTDecompressionSessionCreate(kCFAllocatorDefault, videoFormatDescr, NULL, (__bridge CFDictionaryRef)destinationImageBufferAttributes, &callback, &session);
        NSLog(@"Creating Video Decompression Session: %@.", (status == noErr) ? @"successfully." : @"failed.");
        
        
        int32_t timeSpan = 90000;
        CMSampleTimingInfo timingInfo;
        timingInfo.presentationTimeStamp = CMTimeMake(0, timeSpan);
        timingInfo.duration =  CMTimeMake(3000, timeSpan);
        timingInfo.decodeTimeStamp = kCMTimeInvalid;
    }
    
    int startCodeIndex = 0;
    for (int i = 0; i < 5; i++) {
        if (packet.data[i] == 0x01) {
            startCodeIndex = i;
            break;
        }
    }
    int nalu_type = ((uint8_t)packet.data[startCodeIndex + 1] & 0x1F);
    NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
    
    if (nalu_type == 1 || nalu_type == 5) {
        // 4. get NALUnit payload into a CMBlockBuffer,
        CMBlockBufferRef videoBlock = NULL;
        status = CMBlockBufferCreateWithMemoryBlock(NULL, packet.data, packet.size, kCFAllocatorNull, NULL, 0, packet.size, 0, &videoBlock);
        NSLog(@"BlockBufferCreation: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
        
        // 5.  making sure to replace the separator code with a 4 byte length code (the length of the NalUnit including the unit code)
        int reomveHeaderSize = packet.size - 4;
        const uint8_t sourceBytes[] = {(uint8_t)(reomveHeaderSize >> 24), (uint8_t)(reomveHeaderSize >> 16), (uint8_t)(reomveHeaderSize >> 8), (uint8_t)reomveHeaderSize};
        status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
        NSLog(@"BlockBufferReplace: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
        
        NSString *tmp3 = [NSString new];
        for(int i = 0; i < sizeof(sourceBytes); i++) {
            NSString *str = [NSString stringWithFormat:@" %.2X",sourceBytes[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        NSLog(@"size = %i , 16Byte = %@",reomveHeaderSize,tmp3);
        
        // 6. create a CMSampleBuffer.
        CMSampleBufferRef sbRef = NULL;
        const size_t sampleSizeArray[] = {packet.size};
        status = CMSampleBufferCreate(kCFAllocatorDefault, videoBlock, true, NULL, NULL, videoFormatDescr, 1, 0, NULL, 1, sampleSizeArray, &sbRef);
        
        NSLog(@"SampleBufferCreate: %@", (status == noErr) ? @"successfully." : @"failed.");
        
        // 7. use VTDecompressionSessionDecodeFrame
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        VTDecodeInfoFlags flagOut;
        status = VTDecompressionSessionDecodeFrame(session, sbRef, flags, &sbRef, &flagOut);
        NSLog(@"VTDecompressionSessionDecodeFrame: %@", (status == noErr) ? @"successfully." : @"failed.");
        CFRelease(sbRef);
        
        [self.delegate startDecodeData];
        
        //        /* Flush in-process frames. */
        //        VTDecompressionSessionFinishDelayedFrames(session);
        //        /* Block until our callback has been called with the last frame. */
        //        VTDecompressionSessionWaitForAsynchronousFrames(session);
        //
        //        /* Clean up. */
        //        VTDecompressionSessionInvalidate(session);
        //        CFRelease(session);
        //        CFRelease(videoFormatDescr);
        
        
        NSLog(@"========================================================================");
        NSLog(@"========================================================================");
    }

}

#pragma mark - VideoToolBox Decompress Frame CallBack
/*
 This callback gets called everytime the decompresssion session decodes a frame
 */
void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration )
{
    if (status != noErr || !imageBuffer) {
        // error -8969 codecBadDataErr
        // -12909 The operation couldn’t be completed. (OSStatus error -12909.)
        NSLog(@"Error decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
        return;
    }
    
    NSLog(@"Got frame data.\n");
    NSLog(@"Success decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
    __weak __block HWDecoder *weakSelf = (__bridge HWDecoder *)decompressionOutputRefCon;
    [weakSelf.delegate getDecodeImageData:imageBuffer];
}

NSString * const naluTypesStrings[] = {
    @"Unspecified (non-VCL)",
    @"Coded slice of a non-IDR picture (VCL)",
    @"Coded slice data partition A (VCL)",
    @"Coded slice data partition B (VCL)",
    @"Coded slice data partition C (VCL)",
    @"Coded slice of an IDR picture (VCL)",
    @"Supplemental enhancement information (SEI) (non-VCL)",
    @"Sequence parameter set (non-VCL)",
    @"Picture parameter set (non-VCL)",
    @"Access unit delimiter (non-VCL)",
    @"End of sequence (non-VCL)",
    @"End of stream (non-VCL)",
    @"Filler data (non-VCL)",
    @"Sequence parameter set extension (non-VCL)",
    @"Prefix NAL unit (non-VCL)",
    @"Subset sequence parameter set (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
    @"Coded slice extension (non-VCL)",
    @"Coded slice extension for depth view components (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
};


@end
