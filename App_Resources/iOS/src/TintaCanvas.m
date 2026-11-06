#import "TintaCanvas.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>

@interface TintaCanvas () {
    CGContextRef _paper;
    CGImageRef _undoImage;
    CGSize _paperSize;
    CGFloat _pixelScale;
    CGFloat _splashTravel, _nextSplash;
    CGPoint _point, _previous;
    NSUInteger _idleFrames;
    double _lastTimestamp;
    NSUInteger _metricFrames;
    double _metricSeconds, _callbackFPS;
    BOOL _foreground, _capturing, _tracking;
    NSUInteger _captureFrames;
    double _captureSeconds, _captureMaxGap, _capturePaintMs;
    uint32_t _random;
}
@property(nonatomic, strong) CALayer *paperLayer;
@property(nonatomic, strong) CADisplayLink *clock;
@property(nonatomic, strong) NSMutableArray *captureSamples;
@end

@implementation TintaCanvas
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithRed:.976 green:.969 blue:.945 alpha:1];
        self.clipsToBounds = YES;
        self.multipleTouchEnabled = NO;
        _brushWidth = 3.2;
        _inkColor = [UIColor colorWithRed:.133 green:.196 blue:.91 alpha:1];
        _running = YES; _foreground = YES; _random = 71;
        _paperLayer = [CALayer layer]; [self.layer addSublayer:_paperLayer];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspend) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resume) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && !_clock) {
        _clock = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        _clock.preferredFramesPerSecond = 60;
        [_clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    } else if (!self.window) { [_clock invalidate]; _clock = nil; }
    [self updateClock];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    if (size.width < 1 || size.height < 1 || CGSizeEqualToSize(size, _paperSize)) return;
    CGImageRef old = _paper ? CGBitmapContextCreateImage(_paper) : NULL;
    if (_paper) CGContextRelease(_paper);
    if (_undoImage) { CGImageRelease(_undoImage); _undoImage = NULL; }
    _paperSize = size; _pixelScale = MIN(UIScreen.mainScreen.scale, 2);
    size_t width = ceil(size.width * _pixelScale), height = ceil(size.height * _pixelScale);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    _paper = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!_paper) { if (old) CGImageRelease(old); return; }
    CGContextScaleCTM(_paper, _pixelScale, _pixelScale);
    CGContextTranslateCTM(_paper, 0, size.height); CGContextScaleCTM(_paper, 1, -1);
    [self fillPaper];
    if (old) {
        CGContextSaveGState(_paper); CGContextTranslateCTM(_paper, 0, size.height); CGContextScaleCTM(_paper, 1, -1);
        CGContextDrawImage(_paper, self.bounds, old); CGContextRestoreGState(_paper); CGImageRelease(old);
    }
    _point = _previous = CGPointMake(size.width * .3, size.height * .5);
    _tracking = NO;
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _paperLayer.frame = self.bounds; [CATransaction commit];
    [self presentPaper];
}
- (void)fillPaper {
    CGContextSetRGBFillColor(_paper, .976, .969, .945, 1); CGContextFillRect(_paper, self.bounds);
    // A faint dot grid keeps the blank sheet from feeling like an empty screen.
    CGContextSetRGBFillColor(_paper, .64, .61, .54, .12);
    for (CGFloat x = 18; x < _paperSize.width; x += 24)
        for (CGFloat y = 18; y < _paperSize.height; y += 24) CGContextFillEllipseInRect(_paper, CGRectMake(x, y, .8, .8));
}
- (void)setMode:(NSInteger)mode { _mode = MAX(0,MIN(2,mode)); [self resetTracking]; }
- (void)setRunning:(BOOL)running {
    if (running && !_running) _tracking = NO;
    _running = running; _lastTimestamp = 0; _idleFrames = 0; [self updateClock];
}
- (CGPoint)currentPoint {
    CALayer *layer = self.trackedView.layer.presentationLayer ?: self.trackedView.layer;
    if (!layer) return _point;
    CGPoint center = CGPointMake(layer.position.x + layer.transform.m41, layer.position.y + layer.transform.m42);
    return [self convertPoint:center fromView:self.trackedView.superview];
}
- (void)resetTracking {
    _point = _previous = self.currentPoint; _tracking = NO; _splashTravel = 0; _lastTimestamp = 0; _idleFrames = 0; [self updateClock];
}
- (void)suspend { _foreground = NO; [self updateClock]; }
- (void)resume { _foreground = YES; _tracking = NO; _lastTimestamp = 0; [self updateClock]; }
- (void)updateClock {
    _clock.paused = !_foreground || !_running || !self.window || (_mode == 1 && _idleFrames >= 15);
    if (_clock.paused || !_clock) {
        _metricFrames = 0; _metricSeconds = 0; _callbackFPS = 0;
    }
}
- (double)callbackFPS { return _clock && !_clock.paused ? _callbackFPS : 0; }
- (double)processRSSMiB {
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return -1;
    return info.resident_size / 1048576.;
}
- (CGFloat)randomUnit { _random = 1664525 * _random + 1013904223; return (CGFloat)(_random >> 8) / 16777216.; }
- (void)scatterInkFrom:(CGPoint)start to:(CGPoint)end speed:(CGFloat)speed {
    if (speed < 45) { _splashTravel = 0; return; }
    CGFloat dx = end.x - start.x, dy = end.y - start.y;
    CGFloat distance = hypot(dx, dy);
    if (!_nextSplash) _nextSplash = 22 + [self randomUnit] * 18;
    _splashTravel += distance;
    CGContextSaveGState(_paper);
    CGContextSetFillColorWithColor(_paper, _inkColor.CGColor);
    // Space splashes along the stroke, including between display samples.
    // Fast movement throws ink farther; each splash has a few smaller drops.
    for (NSUInteger burst = 0; burst < 4 && _splashTravel >= _nextSplash; burst++) {
        CGFloat fraction = (distance - (_splashTravel - _nextSplash)) / distance;
        _splashTravel -= _nextSplash;
        _nextSplash = 22 + [self randomUnit] * 18;
        CGFloat angle = atan2(dy, dx) + ([self randomUnit] - .5) * M_PI * 2;
        CGFloat spread = 8 + [self randomUnit] * (18 + MIN(34, speed * .04));
        CGPoint center = CGPointMake(start.x + dx * fraction + cos(angle) * spread,
                                     start.y + dy * fraction + sin(angle) * spread);
        NSUInteger drops = 2 + ([self randomUnit] < .4 ? 1 : 0);
        for (NSUInteger drop = 0; drop < drops; drop++) {
            CGFloat variation = [self randomUnit];
            CGFloat radius = drop == 0 ? .9 + variation * variation * 2.8 : .4 + variation * 1.1;
            CGFloat stretch = drop == 0 && [self randomUnit] < .45 ? 1.3 + [self randomUnit] * MIN(1.3, speed / 500) : 1;
            CGFloat x = center.x, y = center.y;
            if (drop > 0) { x += ([self randomUnit] - .5) * 18; y += ([self randomUnit] - .5) * 18; }
            CGContextSaveGState(_paper);
            CGContextSetAlpha(_paper, .6 + [self randomUnit] * .4);
            CGContextTranslateCTM(_paper, x, y); CGContextRotateCTM(_paper, angle);
            CGContextFillEllipseInRect(_paper, CGRectMake(-radius * stretch, -radius, radius * stretch * 2, radius * 2));
            CGContextRestoreGState(_paper);
        }
    }
    // A delayed frame must not leave a backlog of splashes on the next one.
    _splashTravel = MIN(_splashTravel, _nextSplash);
    CGContextRestoreGState(_paper);
}
- (void)saveUndo {
    if (_undoImage) CGImageRelease(_undoImage);
    _undoImage = _paper ? CGBitmapContextCreateImage(_paper) : NULL;
}
- (void)tick:(CADisplayLink *)clock {
    @autoreleasepool {
        if (!_paper) return;
        double began = CACurrentMediaTime();
        double interval = _lastTimestamp ? clock.timestamp - _lastTimestamp : 1./60.;
        double dt = _lastTimestamp ? MIN(.033, clock.timestamp - _lastTimestamp) : 1./60.;
        _lastTimestamp = clock.timestamp; _previous = _point;
        _metricFrames++; _metricSeconds += interval;
        if (_metricSeconds >= 1) {
            _callbackFPS = _metricFrames / _metricSeconds;
            _metricFrames = 0; _metricSeconds = 0;
        }
        // Jolt owns the visible sphere. This view only rasterizes its presentation.
        _point = self.currentPoint;
        // A new layout or resumed animation needs one committed presentation
        // sample before it can form a segment with the next frame.
        if (!_tracking) { _previous = _point; _splashTravel = 0; _tracking = YES; }
        double distance = hypot(_point.x-_previous.x,_point.y-_previous.y);
        if (distance > .08) {
            CGFloat speed = distance/dt, thickness = _brushWidth * (1.25-MIN(.65,speed/900));
            CGContextSetStrokeColorWithColor(_paper,_inkColor.CGColor); CGContextSetLineCap(_paper,kCGLineCapRound);
            CGContextSetLineWidth(_paper,thickness); CGContextMoveToPoint(_paper,_previous.x,_previous.y);
            CGContextAddLineToPoint(_paper,_point.x,_point.y); CGContextStrokePath(_paper);
            [self scatterInkFrom:_previous to:_point speed:speed];
            [self presentPaper];
        }
        _idleFrames = distance < .01 ? _idleFrames + 1 : 0;
        if (_mode == 1 && _idleFrames >= 15) [self updateClock];
        if (_capturing) {
            _captureFrames++; _captureSeconds += interval;
            _captureMaxGap = MAX(_captureMaxGap,interval*1000);
            _capturePaintMs += (CACurrentMediaTime()-began)*1000;
            if (_captureFrames%60==0) {
                mach_task_basic_info_data_t info; mach_msg_type_number_t count=MACH_TASK_BASIC_INFO_COUNT;
                if(task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&info,&count)==KERN_SUCCESS)
                    [_captureSamples addObject:@{@"seconds":@(_captureSeconds),@"rssMiB":@(info.resident_size/1048576.)}];
            }
            if (_captureSeconds>=30) [self finishCapture];
        }
    }
}
- (void)presentPaper {
    if (!_paper) return;
    CGImageRef image = CGBitmapContextCreateImage(_paper);
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _paperLayer.contents = (__bridge id)image; [CATransaction commit];
    CGImageRelease(image);
}
- (void)clearPaper { if (!_paper) return; [self saveUndo]; [self fillPaper]; [self presentPaper]; }
- (BOOL)undo {
    if (!_undoImage || !_paper) return NO;
    CGContextSaveGState(_paper); CGContextTranslateCTM(_paper,0,_paperSize.height); CGContextScaleCTM(_paper,1,-1);
    CGContextDrawImage(_paper,self.bounds,_undoImage); CGContextRestoreGState(_paper);
    CGImageRelease(_undoImage); _undoImage=NULL; [self presentPaper]; return YES;
}
- (NSString *)exportPNG {
    if (!_paper) return @"";
    CGImageRef image = CGBitmapContextCreateImage(_paper);
    NSData *data = UIImagePNGRepresentation([UIImage imageWithCGImage:image scale:_pixelScale orientation:UIImageOrientationUp]);
    CGImageRelease(image);
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject;
    NSString *file = [directory stringByAppendingPathComponent:@"Tinta.png"];
    return [data writeToFile:file atomically:YES] ? file : @"";
}
- (void)beginCapture {
    _captureFrames=0; _captureSeconds=0; _captureMaxGap=0; _capturePaintMs=0;
    _captureSamples=[NSMutableArray array]; _capturing=YES;
}
- (void)finishCapture {
    _capturing=NO;
    NSDictionary *result=@{@"motionEngine":@"Jolt RC.11",@"frames":@(_captureFrames),@"seconds":@(_captureSeconds),@"uiCallbackHz":@(_captureFrames/_captureSeconds),@"maximumCallbackGapMs":@(_captureMaxGap),@"meanNativeCallbackMs":@(_capturePaintMs/_captureFrames),@"samples":_captureSamples,@"pixelWidth":@(CGBitmapContextGetWidth(_paper)),@"pixelHeight":@(CGBitmapContextGetHeight(_paper)),@"mode":@(_mode),@"pid":@(NSProcessInfo.processInfo.processIdentifier)};
    NSString *directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"benchmarks"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:[directory stringByAppendingPathComponent:@"canvas-cadence.json"] atomically:YES];
}
- (void)shutdown { [_clock invalidate]; _clock=nil; self.trackedView=nil; [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; if (_paper) CGContextRelease(_paper); if (_undoImage) CGImageRelease(_undoImage); }
@end
