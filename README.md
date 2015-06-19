# HWDecoder
This class demo how to use VideoToolbox to make iOS hardware decode

## HWDecoder Step
    // 1. Get SPS,PPS form stream data, and create CMFormatDescription, VTDecompressionSession
    // 2. create  CMFormatDescription
    // 3. create VTDecompressionSession
    // 4. get NALUnit payload into a CMBlockBuffer
    // 5.  making sure to replace the separator code with a 4 byte length code (the length of the NalUnit including the unit code)
    // 6. create a CMSampleBuffer
    // 7. use VTDecompressionSessionDecodeFrame
    // 8. use VideoToolBox Decompress Frame CallBack to get CVImageBufferRef
    
