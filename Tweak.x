#import <UIKit/UIKit.h>

/* WPS 私有类声明（自绘 tab 体系：KWPhoneMainTabBarController -> KWTabBarController） */
@interface KWPublicViewController : UIViewController @end
@interface KWMeViewController : KWPublicViewController @end
@interface KWTabBarController : UIViewController @end
@interface KWPhoneMainTabBarController : KWTabBarController @end

/* =========================================================
 * WPS Office 离线化 tweak v5
 * 1. VIP 解锁（合并自 wpsofficevip.dylib 逆向）
 * 2. 禁网：NSURLSessionTask 白名单外全拦（cancel 回调）
 * 3. 登录跳转拦截（scheme + 微信/QQ 域名，含 wx.qq.com）
 * 4. 视图树遍历移除：稻壳儿 tab（自绘 tab 也能命中）+ "我的"页云端/会员功能项
 * 5. 启动验证弹窗（确认 dylib 已加载，测试后移除）
 * ========================================================= */

/* ---------- 通用：第三方登录跳转是否拦截 ---------- */
static BOOL kw_block_third_login(NSURL *url) {
  NSString *s = [url.scheme lowercaseString] ?: @"";
  NSString *h = [url.host lowercaseString] ?: @"";
  if ([s hasPrefix:@"weixin"] || [s hasPrefix:@"weixindicator"] ||
      [s hasPrefix:@"mqq"] || [s hasPrefix:@"tim"] ||
      [s hasPrefix:@"wtlogin"] || [s hasPrefix:@"alipay"]) {
    return YES;
  }
  if ([h hasSuffix:@"weixin.qq.com"] || [h hasSuffix:@"wx.qq.com"] ||
      [h containsString:@"open.weixin"] || [h hasSuffix:@"open.mobile.qq.com"] ||
      [h hasSuffix:@"graph.qq.com"] || [h hasSuffix:@"connect.qq.com"] ||
      [h hasSuffix:@"ssl.qq.com"]) {
    return YES;
  }
  return NO;
}

/* ---------- 通用：视图树遍历，移除文本命中关键词的 cell/按钮祖先 ---------- */
static void kw_hide_text_views(UIView *root, NSArray *kws) {
  if (!root) return;
  for (UIView *sub in root.subviews) {
    if ([sub isKindOfClass:[UILabel class]]) {
      NSString *t = ((UILabel *)sub).text;
      if (t.length > 0) {
        for (NSString *k in kws) {
          if ([t containsString:k]) {
            // 向上找可交互祖先（按钮/cell），整体隐藏
            UIView *v = sub;
            while (v && !([v isKindOfClass:[UIControl class]] ||
                          [v isKindOfClass:[UITableViewCell class]] ||
                          [v isKindOfClass:[UICollectionViewCell class]])) {
              v = v.superview;
            }
            if (v) {
              v.hidden = YES;
              v.userInteractionEnabled = NO;
            }
            break;
          }
        }
      }
    }
    kw_hide_text_views(sub, kws);
  }
}

/* ---------- 1. VIP 解锁 ---------- */
%hook KWUserDocerVip
- (BOOL)isBuy { return YES; }
- (BOOL)isDocerVip { return YES; }
%end

%hook KWUserNewVip
- (BOOL)isBuy { return YES; }
- (BOOL)isWpsVip { return YES; }
- (BOOL)isSuperVip { return YES; }
%end

%hook KWPDFConverWordModel
- (BOOL)isBuy { return YES; }
%end

/* ---------- 2. 禁网（白名单外全拦） ---------- */
%hook NSURLSessionTask
- (void)resume {
  NSString *u = self.originalRequest.URL.absoluteString;
  if (u.length > 0 &&
      ([u hasPrefix:@"http://127."] ||
       [u hasPrefix:@"https://127."] ||
       [u hasPrefix:@"http://localhost"] ||
       [u hasPrefix:@"https://localhost"] ||
       [u hasPrefix:@"http://[::1]"] ||
       [u hasPrefix:@"https://[::1]"])) {
    %orig;
    return;
  }
  [self cancel];
}
%end

/* ---------- 3. 拦截第三方登录跳转 ---------- */
%hook UIApplication
- (BOOL)openURL:(NSURL *)url {
  if (kw_block_third_login(url)) return NO;
  return %orig;
}
- (BOOL)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(id)completion {
  if (kw_block_third_login(url)) {
    if (completion) {
      void (^cb)(BOOL) = completion;
      cb(NO);
    }
    return NO;
  }
  return %orig;
}
%end

/* ---------- 4. 视图树遍历移除（覆盖自绘 tab + 我的页） ---------- */
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
  %orig;
  // 全页面移除含"稻壳"的 tab 按钮/cell
  kw_hide_text_views(self.view, @[@"稻壳"]);
  // "我的"页面移除云端/会员功能项
  NSString *cn = NSStringFromClass([self class]);
  if ([cn hasPrefix:@"KWMe"]) {
    kw_hide_text_views(self.view, @[@"登入", @"登录", @"享受更多", @"云服务",
                                    @"云文档", @"会员", @"找回文档", @"消息",
                                    @"钱包", @"已购", @"收藏", @"活动"]);
  }
}
%end

/* ---------- 5. 启动验证弹窗（确认 dylib 加载，测试后移除） ---------- */
%hook UIViewController
- (void)viewDidLoad {
  %orig;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
      UIWindow *w = [UIApplication sharedApplication].windows.firstObject;
      UIViewController *root = w.rootViewController;
      if (root) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"wpsoffline"
                                                                    message:@"tweak 已加载 v5"
                                                             preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:ac animated:YES completion:nil];
      }
    });
  });
}
%end
