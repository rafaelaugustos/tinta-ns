#import "TintaCanvas.h"

@interface TintaContactObserver () <UIGestureRecognizerDelegate>
@property(nonatomic, copy) void (^contact)(double, double);
@end

@implementation TintaContactObserver
+ (instancetype)attachToView:(UIView *)view contact:(void (^)(double, double))contact {
    TintaContactObserver *observer = [[self alloc] initWithTarget:nil action:nil];
    observer.contact = contact;
    observer.delegate = observer;
    observer.cancelsTouchesInView = NO;
    observer.delaysTouchesBegan = NO;
    observer.delaysTouchesEnded = NO;
    [view addGestureRecognizer:observer];
    return observer;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.contact) return;
    CGPoint point = [touches.anyObject locationInView:self.view];
    self.contact(point.x, point.y);
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { self.state = UIGestureRecognizerStateFailed; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { self.state = UIGestureRecognizerStateCancelled; }
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)other { return NO; }
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)other { return NO; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
- (void)dispose { self.enabled = NO; self.contact = nil; [self.view removeGestureRecognizer:self]; }
@end
