#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface TintaCanvas : UIView
@property(nonatomic) NSInteger mode; // 0 flow, 1 touch, 2 tilt
@property(nonatomic) BOOL running;
@property(nonatomic) CGFloat brushWidth;
@property(nonatomic, readonly) double callbackFPS;
@property(nonatomic, readonly) double processRSSMiB;
@property(nonatomic, strong) UIColor *inkColor;
@property(nonatomic, weak, nullable) UIView *trackedView;
@property(nonatomic, readonly) CGPoint currentPoint;
- (void)resetTracking;
- (void)saveUndo;
- (void)clearPaper;
- (BOOL)undo;
- (NSString *)exportPNG;
- (void)beginCapture;
- (void)shutdown;
@end

@interface TintaContactObserver : UIGestureRecognizer
+ (instancetype)attachToView:(UIView *)view contact:(void (^)(double x, double y))contact;
- (void)dispose;
@end

@interface TintaRenderProbe : NSObject
+ (void)runInDirectory:(NSString *)directory progress:(void (^)(NSInteger frame, NSString *phase))progress completion:(void (^)(NSString *result))completion;
@end
NS_ASSUME_NONNULL_END
