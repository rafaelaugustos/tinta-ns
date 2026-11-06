#import "TintaCanvas.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>

@interface TintaCanvas () {
    CGContextRef _paper;
    CGImageRef _undoImage;
    CGSize _paperSize;
    CGFloat _pixelScale;
    CGPoint _point, _previous, _target, _velocity, _gravity;
    double _elapsed, _lastTimestamp;
    BOOL _touching, _foreground, _capturing;
    NSUInteger _captureFrames;
    double _captureSeconds, _captureMaxGap, _capturePaintMs;
    uint32_t _random;
}
@property(nonatomic, strong) CALayer *paperLayer;
@property(nonatomic, strong) CAGradientLayer *bead;
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
        _bead = [CAGradientLayer layer];
        _bead.bounds = CGRectMake(0, 0, 30, 30); _bead.cornerRadius = 15;
        _bead.startPoint = CGPointMake(.15, .05); _bead.endPoint = CGPointMake(.8, 1);
        _bead.shadowColor = UIColor.blackColor.CGColor; _bead.shadowOpacity = .2;
        _bead.shadowOffset = CGSizeMake(0, 5); _bead.shadowRadius = 5;
        [self.layer addSublayer:_bead];
        CALayer *shine = [CALayer layer]; shine.frame = CGRectMake(7, 5, 8, 4);
        shine.cornerRadius = 2; shine.backgroundColor = [UIColor colorWithWhite:1 alpha:.65].CGColor;
        shine.transform = CATransform3DMakeRotation(-.55, 0, 0, 1); [_bead addSublayer:shine];
        [self updateInk];
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
    _point = _previous = CGPointMake(size.width * .3, size.height * .5); _target = _point;
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _paperLayer.frame = self.bounds; _bead.position = _point; [CATransaction commit];
    [self presentPaper];
}
- (void)fillPaper {
    CGContextSetRGBFillColor(_paper, .976, .969, .945, 1); CGContextFillRect(_paper, self.bounds);
    // A faint dot grid keeps the blank sheet from feeling like an empty screen.
    CGContextSetRGBFillColor(_paper, .64, .61, .54, .12);
    for (CGFloat x = 18; x < _paperSize.width; x += 24)
        for (CGFloat y = 18; y < _paperSize.height; y += 24) CGContextFillEllipseInRect(_paper, CGRectMake(x, y, .8, .8));
}
- (void)setInkColor:(UIColor *)color { _inkColor = color; [self updateInk]; }
- (void)updateInk {
    CGFloat r=0,g=0,b=0,a=1; [_inkColor getRed:&r green:&g blue:&b alpha:&a];
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    _bead.colors = @[(id)[UIColor colorWithRed:MIN(1,r+.25) green:MIN(1,g+.25) blue:MIN(1,b+.15) alpha:1].CGColor, (id)_inkColor.CGColor, (id)[UIColor colorWithRed:r*.5 green:g*.5 blue:b*.6 alpha:1].CGColor];
    _bead.locations = @[@0, @.45, @1]; [CATransaction commit];
}
- (void)setMode:(NSInteger)mode { _mode = MAX(0,MIN(2,mode)); _velocity = CGPointZero; _lastTimestamp = 0; [self updateClock]; }
- (void)setRunning:(BOOL)running { _running = running; _lastTimestamp = 0; [self updateClock]; }
- (void)setGravityX:(double)x y:(double)y { _gravity = CGPointMake(x, y); }
- (void)suspend { _foreground = NO; [self updateClock]; }
- (void)resume { _foreground = YES; _lastTimestamp = 0; [self updateClock]; }
- (void)updateClock { _clock.paused = !_foreground || !_running || !self.window || (_mode == 1 && !_touching && hypot(_velocity.x,_velocity.y) < 1); }
- (CGFloat)randomUnit { _random = 1664525 * _random + 1013904223; return (CGFloat)(_random >> 8) / 16777216.; }
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
        _lastTimestamp = clock.timestamp; _elapsed += dt; _previous = _point;
        CGFloat w = _paperSize.width, h = _paperSize.height;
        if (_mode == 0) {
            double t = _elapsed * .63;
            CGPoint destination = CGPointMake(w * (.5 + .36*sin(t) + .035*sin(t*3)), h * (.5 + .31*sin(t*1.7+.4)));
            _point.x += (destination.x-_point.x) * MIN(1,dt*7);
            _point.y += (destination.y-_point.y) * MIN(1,dt*7);
        } else if (_touching) {
            _velocity = CGPointMake((_target.x-_point.x)*18, (_target.y-_point.y)*18);
            _point.x += _velocity.x*dt; _point.y += _velocity.y*dt;
        } else {
            if (_mode == 2) { _velocity.x += _gravity.x*110*dt; _velocity.y -= _gravity.y*110*dt; }
            double damping = exp(-dt*1.8); _velocity.x *= damping; _velocity.y *= damping;
            _point.x += _velocity.x*dt; _point.y += _velocity.y*dt;
        }
        if (_point.x<16 || _point.x>w-16) { _point.x=MAX(16,MIN(w-16,_point.x)); _velocity.x *= -.65; }
        if (_point.y<16 || _point.y>h-16) { _point.y=MAX(16,MIN(h-16,_point.y)); _velocity.y *= -.65; }
        double distance = hypot(_point.x-_previous.x,_point.y-_previous.y);
        if (distance > .08) {
            CGFloat speed = distance/dt, thickness = _brushWidth * (1.25-MIN(.65,speed/900));
            CGContextSetStrokeColorWithColor(_paper,_inkColor.CGColor); CGContextSetLineCap(_paper,kCGLineCapRound);
            CGContextSetLineWidth(_paper,thickness); CGContextMoveToPoint(_paper,_previous.x,_previous.y);
            CGContextAddLineToPoint(_paper,_point.x,_point.y); CGContextStrokePath(_paper);
            if (speed>70 && [self randomUnit]<.18) {
                CGFloat angle=[self randomUnit]*M_PI*2, spread=10+[self randomUnit]*20, radius=.55+[self randomUnit]*1.4;
                CGContextSetFillColorWithColor(_paper,[_inkColor colorWithAlphaComponent:.75].CGColor);
                CGContextFillEllipseInRect(_paper,CGRectMake(_point.x+cos(angle)*spread,_point.y+sin(angle)*spread,radius*2,radius*2));
            }
            [self presentPaper];
        }
        [CATransaction begin]; [CATransaction setDisableActions:YES]; _bead.position = _point; [CATransaction commit];
        if (_mode==1 && !_touching && hypot(_velocity.x,_velocity.y)<1) [self updateClock];
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
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_paper) return;
    [self saveUndo];
    if (_mode!=1) { self.mode=1; if (_modeChanged) _modeChanged(1); }
    _target = [touches.anyObject locationInView:self]; _touching = YES; self.running=YES;
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { _target = [touches.anyObject locationInView:self]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { _touching=NO; [self updateClock]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { _touching=NO; _velocity=CGPointZero; [self updateClock]; }
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
    NSDictionary *result=@{@"frames":@(_captureFrames),@"seconds":@(_captureSeconds),@"uiCallbackHz":@(_captureFrames/_captureSeconds),@"maximumCallbackGapMs":@(_captureMaxGap),@"meanNativeCallbackMs":@(_capturePaintMs/_captureFrames),@"samples":_captureSamples,@"pixelWidth":@(CGBitmapContextGetWidth(_paper)),@"pixelHeight":@(CGBitmapContextGetHeight(_paper)),@"mode":@(_mode),@"pid":@(NSProcessInfo.processInfo.processIdentifier)};
    NSString *directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"benchmarks"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:[directory stringByAppendingPathComponent:@"canvas-cadence.json"] atomically:YES];
}
- (void)shutdown { [_clock invalidate]; _clock=nil; _modeChanged=nil; [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; if (_paper) CGContextRelease(_paper); if (_undoImage) CGImageRelease(_undoImage); }
@end
