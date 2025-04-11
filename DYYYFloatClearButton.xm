/* 
 * Tweak Name: 1KeyHideDYUI
 * Target App: com.ss.iphone.ugc.Aweme
 * Dev: @c00kiec00k 曲奇的坏品味🍻
 * iOS Version: 16.5
 */
#import "AwemeHeaders.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <signal.h>
// 递归查找指定类型的视图的函数
static void findViewsOfClassHelper(UIView *view, Class viewClass, NSMutableArray *result) {
    if ([view isKindOfClass:viewClass]) {
        // 如果是AWEElementStackView，检查accessibilityLabel是否为"#EJAT= left"
        if ([viewClass isEqual:NSClassFromString(@"AWEElementStackView")]) {
            if ([[(UIView *)view valueForKey:@"accessibilityLabel"] isEqual:@"#EJAT= left"]) {
                [result addObject:view];
                
                // 同时添加它的所有子视图（特别是AWEBaseElementView）
                for (UIView *subview in view.subviews) {
                    if ([subview isKindOfClass:NSClassFromString(@"AWEBaseElementView")]) {
                        [result addObject:subview];
                    }
                }
            }
        } else {
            [result addObject:view];
        }
    }
    
    for (UIView *subview in view.subviews) {
        findViewsOfClassHelper(subview, viewClass, result);
    }
}
// 定义悬浮按钮类
@interface HideUIButton : UIButton
@property (nonatomic, assign) BOOL isElementsHidden;
@property (nonatomic, strong) NSMutableArray *hiddenViewsList;
@property (nonatomic, assign) BOOL isPersistentMode; // 是否为全局生效模式
@end
// 全局变量
static HideUIButton *hideButton;
static BOOL isAppInTransition = NO;
static BOOL isGlobalHidden = NO; // 全局隐藏状态标志
static NSString *const kLastPositionXKey = @"lastHideButtonPositionX";
static NSString *const kLastPositionYKey = @"lastHideButtonPositionY";
static NSString *const kPersistentModeKey = @"hideButtonPersistentMode";
static NSString *const kIsGlobalHiddenKey = @"isGlobalHidden";
// 获取keyWindow的辅助方法
static UIWindow* getKeyWindow() {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    return keyWindow;
}
// 恢复所有元素到原始状态的方法 - 重置方法
static void forceResetAllUIElements() {
    UIWindow *window = getKeyWindow();
    if (!window) return;
    
    NSArray *viewClassStrings = @[
        @"AWEHPTopBarCTAContainer",
        @"AWEHPDiscoverFeedEntranceView",
        @"AWELeftSideBarEntranceView",
        @"DUXBadge",
        @"AWEBaseElementView",
        @"AWEElementStackView",
        @"AWEPlayInteractionDescriptionLabel",
        @"AWEUserNameLabel",
        @"AWEStoryProgressSlideView",
        @"AWEStoryProgressContainerView",
        @"ACCEditTagStickerView",
        @"AWEFeedTemplateAnchorView",
        @"AWESearchFeedTagView",
        @"AWEPlayInteractionSearchAnchorView",
        @"AFDRecommendToFriendTagView",
        @"AWELandscapeFeedEntryView",
        @"AWEFeedAnchorContainerView",
        @"AFDAIbumFolioView"
    ];
    
    // 查找所有匹配的视图并设置Alpha为1
    for (NSString *className in viewClassStrings) {
        Class viewClass = NSClassFromString(className);
        if (!viewClass) continue;
        
        // 使用辅助函数查找视图
        NSMutableArray *views = [NSMutableArray array];
        findViewsOfClassHelper(window, viewClass, views);
        
        for (UIView *view in views) {
            dispatch_async(dispatch_get_main_queue(), ^{
                view.alpha = 1.0;
            });
        }
    }
    
    // 更新全局状态
    isGlobalHidden = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kIsGlobalHiddenKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
// 获取抖音应用的Documents目录
static NSString* getAppDocumentsPath() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}
// 检查自定义图标是否存在
static UIImage* getCustomImage(NSString *imageName) {
    NSString *documentsPath = getAppDocumentsPath();
    NSString *imagePath = [documentsPath stringByAppendingPathComponent:imageName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return [UIImage imageWithContentsOfFile:imagePath];
    }
    return nil;
}
// HideUIButton 实现
@implementation HideUIButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // 基本设置 - 完全透明背景，只显示图标
        self.backgroundColor = [UIColor clearColor];
        
        // 初始化属性
        _hiddenViewsList = [NSMutableArray array];
        
        // 从用户默认设置中加载持久化模式设置
        _isPersistentMode = [[NSUserDefaults standardUserDefaults] boolForKey:kPersistentModeKey];
        _isElementsHidden = [[NSUserDefaults standardUserDefaults] boolForKey:kIsGlobalHiddenKey];
        isGlobalHidden = _isElementsHidden;
        
        // 设置初始图标或文字
        [self setupButtonAppearance];
        
        // 添加拖动手势
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGesture];
        
        // 使用单击事件（原生按钮点击）
        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加长按手势
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPressGesture.minimumPressDuration = 0.5; // 0.5秒长按
        [self addGestureRecognizer:longPressGesture];
    }
    return self;
}
- (void)setupButtonAppearance {
    // 尝试加载自定义图标
    UIImage *customShowIcon = getCustomImage(@"Qingping.png");
    
    if (customShowIcon) {
        [self setImage:customShowIcon forState:UIControlStateNormal];
    } else {
        // 如果没有自定义图标，则使用文字
        [self setTitle:self.isElementsHidden ? @"显示" : @"隐藏" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    }
}
- (void)updateButtonAppearance {
    // 更新按钮外观，根据当前状态
    UIImage *customShowIcon = getCustomImage(@"Qingping.png");
    
    if (customShowIcon) {
        [self setImage:customShowIcon forState:UIControlStateNormal];
    } else {
        [self setTitle:self.isElementsHidden ? @"显示" : @"隐藏" forState:UIControlStateNormal];
    }
}
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    
    // 确保按钮不会超出屏幕边界
    newCenter.x = MAX(self.frame.size.width / 2, MIN(newCenter.x, self.superview.frame.size.width - self.frame.size.width / 2));
    newCenter.y = MAX(self.frame.size.height / 2, MIN(newCenter.y, self.superview.frame.size.height - self.frame.size.height / 2));
    
    self.center = newCenter;
    [gesture setTranslation:CGPointZero inView:self.superview];
    
    // 保存位置到NSUserDefaults
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setFloat:self.center.x forKey:kLastPositionXKey];
        [[NSUserDefaults standardUserDefaults] setFloat:self.center.y forKey:kLastPositionYKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self showOptionsMenu];
    }
}
- (void)showOptionsMenu {
    // 创建一个UIAlertController作为菜单
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"设置"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 添加"全局生效"选项
    NSString *persistentTitle = self.isPersistentMode ? @"✓ 全局生效" : @"全局生效";
    UIAlertAction *persistentAction = [UIAlertAction actionWithTitle:persistentTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
        self.isPersistentMode = !self.isPersistentMode;
        [[NSUserDefaults standardUserDefaults] setBool:self.isPersistentMode forKey:kPersistentModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    [alertController addAction:persistentAction];
    
    // 添加"单个视频生效"选项
    NSString *singleVideoTitle = !self.isPersistentMode ? @"✓ 单个视频生效" : @"单个视频生效";
    UIAlertAction *singleVideoAction = [UIAlertAction actionWithTitle:singleVideoTitle
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        self.isPersistentMode = !self.isPersistentMode;
        [[NSUserDefaults standardUserDefaults] setBool:self.isPersistentMode forKey:kPersistentModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    [alertController addAction:singleVideoAction];
    
    // 添加取消选项
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    // 在iPad上，我们需要设置弹出位置
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alertController.popoverPresentationController.sourceView = self;
        alertController.popoverPresentationController.sourceRect = self.bounds;
    }
    
    // 显示菜单
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
}
- (void)handleTap {
    if (isAppInTransition) {
        return;
    }
    
    if (!self.isElementsHidden) {
        // 隐藏UI元素
        [self hideUIElements];
        
        // 更新全局状态
        isGlobalHidden = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kIsGlobalHiddenKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        // 直接强制恢复所有UI元素
        forceResetAllUIElements();
        self.isElementsHidden = NO;
        [self.hiddenViewsList removeAllObjects];
        
        // 更新全局状态
        isGlobalHidden = NO;
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kIsGlobalHiddenKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    [self updateButtonAppearance];
}
- (void)hideUIElements {
    NSArray *viewClassStrings = @[
        @"AWEHPTopBarCTAContainer",
        @"AWEHPDiscoverFeedEntranceView",
        @"AWELeftSideBarEntranceView",
        @"DUXBadge",
        @"AWEBaseElementView",
        @"AWEElementStackView",
        @"AWEPlayInteractionDescriptionLabel",
        @"AWEUserNameLabel",
        @"AWEStoryProgressSlideView",
        @"AWEStoryProgressContainerView",
        @"ACCEditTagStickerView",
        @"AWEFeedTemplateAnchorView",
        @"AWESearchFeedTagView",
        @"AWEPlayInteractionSearchAnchorView",
        @"AFDRecommendToFriendTagView",
        @"AWELandscapeFeedEntryView",
        @"AWEFeedAnchorContainerView",
        @"AFDAIbumFolioView"
    ];
    
    // 隐藏元素
    [self.hiddenViewsList removeAllObjects]; // 清空隐藏列表
    [self findAndHideViews:viewClassStrings];
    self.isElementsHidden = YES;
}
- (void)findAndHideViews:(NSArray *)classNames {
    // 遍历所有窗口
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        for (NSString *className in classNames) {
            Class viewClass = NSClassFromString(className);
            if (!viewClass) continue;
            
            NSMutableArray *views = [NSMutableArray array];
            findViewsOfClassHelper(window, viewClass, views);
            
            for (UIView *view in views) {
                if ([view isKindOfClass:[UIView class]]) {
                    // 添加到隐藏视图列表
                    [self.hiddenViewsList addObject:view];
                    
                    // 设置新的alpha值
                    view.alpha = 0.0;
                }
            }
        }
    }
}
- (void)safeResetState {
    // 强制恢复所有UI元素
    forceResetAllUIElements();
    
    // 重置状态
    self.isElementsHidden = NO;
    [self.hiddenViewsList removeAllObjects];
    
    [self updateButtonAppearance];
}
@end
// 对新添加的视图进行处理 - 这是关键部分，防止闪烁
%hook UIView
- (void)didMoveToWindow {
    %orig;
    
    // 如果全局隐藏模式开启，则立即隐藏新添加的视图
    if (isGlobalHidden && self.window != nil) {
        // 检查是否是我们需要隐藏的类型
        NSArray *classNames = @[
            @"AWEHPTopBarCTAContainer",
            @"AWEHPDiscoverFeedEntranceView",
            @"AWELeftSideBarEntranceView",
            @"DUXBadge",
            @"AWEBaseElementView",
            @"AWEElementStackView",
            @"AWEPlayInteractionDescriptionLabel",
            @"AWEUserNameLabel",
            @"AWEStoryProgressSlideView",
            @"AWEStoryProgressContainerView",
            @"ACCEditTagStickerView",
            @"AWEFeedTemplateAnchorView",
            @"AWESearchFeedTagView",
            @"AWEPlayInteractionSearchAnchorView",
            @"AFDRecommendToFriendTagView",
            @"AWELandscapeFeedEntryView",
            @"AWEFeedAnchorContainerView",
            @"AFDAIbumFolioView"
        ];
        
        for (NSString *className in classNames) {
            Class viewClass = NSClassFromString(className);
            if (!viewClass) continue;
            
            if ([self isKindOfClass:viewClass]) {
                // 特殊处理AWEElementStackView
                if ([viewClass isEqual:NSClassFromString(@"AWEElementStackView")]) {
                    if ([[(UIView *)self valueForKey:@"accessibilityLabel"] isEqual:@"#EJAT= left"]) {
                        self.alpha = 0.0;
                        
                        // 处理子视图
                        for (UIView *subview in self.subviews) {
                            if ([subview isKindOfClass:NSClassFromString(@"AWEBaseElementView")]) {
                                subview.alpha = 0.0;
                            }
                        }
                    }
                } else {
                    // 其他类型直接隐藏
                    self.alpha = 0.0;
                }
                
                // 如果找到了匹配的类，就不需要继续检查了
                break;
            }
        }
    }
}
%end
// 监控视图转换状态
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    isAppInTransition = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        isAppInTransition = NO;
    });
}
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    isAppInTransition = YES;
    
    if (hideButton && hideButton.isElementsHidden && !hideButton.isPersistentMode) {
        // 如果视图即将消失且不是全局模式，直接重置状态
        dispatch_async(dispatch_get_main_queue(), ^{
            [hideButton safeResetState];
        });
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        isAppInTransition = NO;
    });
}
%end
// 监控视频内容变化
%hook AWEFeedCellViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // 如果是单视频模式且元素被隐藏，则在视频切换时恢复元素
    if (hideButton && hideButton.isElementsHidden && !hideButton.isPersistentMode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [hideButton safeResetState];
        });
    }
}
%end
// Hook AppDelegate 来初始化按钮
%hook AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    // 尝试从NSUserDefaults加载全局隐藏状态
    isGlobalHidden = [[NSUserDefaults standardUserDefaults] boolForKey:kIsGlobalHiddenKey];
    
    // 立即创建按钮，不使用延迟
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    hideButton = [[HideUIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    
    // 从NSUserDefaults获取上次位置，如果没有则放在左侧中间
    CGFloat lastX = [[NSUserDefaults standardUserDefaults] floatForKey:kLastPositionXKey];
    CGFloat lastY = [[NSUserDefaults standardUserDefaults] floatForKey:kLastPositionYKey];
    
    if (lastX > 0 && lastY > 0) {
        // 使用保存的位置
        hideButton.center = CGPointMake(lastX, lastY);
    } else {
        // 默认位置：左侧中间
        hideButton.center = CGPointMake(30, screenHeight / 2);
    }
    
    // 我们需要确保有一个有效的窗口来添加按钮
    // 使用一个小延迟确保窗口已经创建
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = getKeyWindow();
        if (window) {
            [window addSubview:hideButton];
        } else {
            // 如果还没有窗口，再尝试一次
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [getKeyWindow() addSubview:hideButton];
            });
        }
    });
    
    return result;
}
// 确保在应用变为活跃状态时按钮也能正确显示
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    
    // 确保按钮已添加到窗口
    if (hideButton && !hideButton.superview) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [getKeyWindow() addSubview:hideButton];
        });
    }
}
%end
%ctor {
    // 注册信号处理
    signal(SIGSEGV, SIG_IGN);
}