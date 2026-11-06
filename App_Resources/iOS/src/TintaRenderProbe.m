#import "TintaCanvas.h"
#import <CoreImage/CoreImage.h>
#import <mach/mach.h>
#import <stdatomic.h>

static atomic_bool probeActive = false;
static double residentMiB(void) {
    mach_task_basic_info_data_t info; mach_msg_type_number_t count=MACH_TASK_BASIC_INFO_COUNT;
    return task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&info,&count)==KERN_SUCCESS ? info.resident_size/1048576. : -1;
}
static double settledRSS(void) {
    double samples[7]; for(int i=0;i<7;i++){samples[i]=residentMiB();[NSThread sleepForTimeInterval:.12];}
    for(int i=0;i<7;i++)for(int j=i+1;j<7;j++)if(samples[j]<samples[i]){double tmp=samples[i];samples[i]=samples[j];samples[j]=tmp;}
    return samples[3];
}
@implementation TintaRenderProbe
+ (void)runInDirectory:(NSString *)directory progress:(void (^)(NSInteger, NSString *))progress completion:(void (^)(NSString *))completion {
    if(atomic_exchange(&probeActive,true)){completion(@"{\"error\":\"A run is already active\"}");return;}
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        @autoreleasepool {
            const NSInteger size=512, frames=450;
            const size_t length=size*size*4;
            uint8_t *input=malloc(length), *output=malloc(length);
            if(!input || !output){free(input);free(output);atomic_store(&probeActive,false);dispatch_async(dispatch_get_main_queue(),^{completion(@"{\"error\":\"Buffer allocation failed\"}");});return;}
            CIContext *context=[CIContext contextWithOptions:@{kCIContextWorkingColorSpace:NSNull.null,kCIContextOutputColorSpace:NSNull.null,kCIContextCacheIntermediates:@NO}];
            NSMutableArray *samples=[NSMutableArray array];
            __block BOOL pixelsValid=YES;
            BOOL skipBlur=[NSProcessInfo.processInfo.arguments containsObject:@"--tinta-no-blur"];
            NSMutableArray *checks=[NSMutableArray array];
            void (^render)(NSInteger,BOOL) = ^(NSInteger frame,BOOL verify){
                @autoreleasepool {
                    uint8_t blue=frame%256;
                    for(NSInteger y=0;y<size;y++)for(NSInteger x=0;x<size;x++){
                        size_t i=(y*size+x)*4;input[i]=y<size/2?0:255;input[i+1]=input[i];input[i+2]=blue;input[i+3]=255;
                    }
                    NSData *data=[NSData dataWithBytesNoCopy:input length:length freeWhenDone:NO];
                    CIImage *source=[CIImage imageWithBitmapData:data bytesPerRow:size*4 size:CGSizeMake(size,size) format:kCIFormatRGBA8 colorSpace:NULL];
                    CIImage *blur=skipBlur ? source : [[source imageByClampingToExtent] imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{kCIInputRadiusKey:@4}];
                    NSInteger x=frame%2==0?0:size-32;
                    // Core Image's Y axis points up; the readback starts at the top row.
                    CIImage *rectangle=[[CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0 alpha:1]] imageByCroppingToRect:CGRectMake(x,size-32,32,32)];
                    CIImage *composite=[rectangle imageByCompositingOverImage:blur];
                    [context render:composite toBitmap:output rowBytes:size*4 bounds:CGRectMake(0,0,size,size) format:kCIFormatRGBA8 colorSpace:NULL];
                    if(verify){
                        size_t red=(x+16+16*size)*4, bg=(size/2+(size/4)*size)*4, edge=(size/2+(size/2)*size)*4;
                        BOOL valid=output[red]==255 && output[red+1]==0 && output[bg]==0 && abs(output[bg+2]-blue)<=1 && output[edge]>32 && output[edge]<223;
                        pixelsValid=pixelsValid && valid;
                        [checks addObject:@{@"frame":@(frame),@"valid":@(valid),@"red":@(output[red]),@"green":@(output[red+1]),@"blue":@(output[bg+2]),@"boundaryRed":@(output[edge])}];
                    }
                }
            };
            dispatch_async(dispatch_get_main_queue(),^{progress(0,@"warmup");});
            for(NSInteger frame=0;frame<60;frame++)render(frame,NO);
            [NSThread sleepForTimeInterval:2];
            double before=settledRSS(), peak=before;
            NSTimeInterval started=NSProcessInfo.processInfo.systemUptime;
            for(NSInteger frame=0;frame<frames;frame++){
                render(frame,frame<2 || frame==frames-1);
                if(frame%15==0){double rss=residentMiB();peak=MAX(peak,rss);[samples addObject:@{ @"frame":@(frame+1),@"rssMiB":@(rss)}];dispatch_async(dispatch_get_main_queue(),^{progress(frame+1,@"rendering");});}
                [NSThread sleepForTimeInterval:.15];
            }
            dispatch_async(dispatch_get_main_queue(),^{progress(frames,@"settling");});
            [NSThread sleepForTimeInterval:2];
            double after=settledRSS();
            NSDictionary *result=@{@"schema":@1,@"renderer":@"Core Image",@"frames":@(frames),@"warmupFrames":@60,@"width":@(size),@"height":@(size),@"blurRadius":@(skipBlur?0:4),@"checks":checks,@"intervalMs":@150,@"pixelsValid":@(pixelsValid),@"baselineRSSMiB":@(before),@"settledRSSMiB":@(after),@"growthMiB":@(after-before),@"peakRSSMiB":@(peak),@"elapsedSeconds":@(NSProcessInfo.processInfo.systemUptime-started),@"samples":samples,@"os":NSProcessInfo.processInfo.operatingSystemVersionString,@"pid":@(NSProcessInfo.processInfo.processIdentifier),@"passed":@(pixelsValid && before>=0 && after-before<=30)};
            NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
            [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
            [json writeToFile:[directory stringByAppendingPathComponent:@"render-probe.json"] atomically:YES];
            NSString *text=[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding];
            [context clearCaches]; free(input); free(output); atomic_store(&probeActive,false);
            dispatch_async(dispatch_get_main_queue(),^{completion(text);});
        }
    });
}
@end
