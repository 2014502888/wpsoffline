#import <UIKit/UIKit.h>

/* WPS 私有类声明：告诉编译器 KWPhoneMainTabBarController 是 UITabBarController 子类 */
@interface KWPhoneMainTabBarController : UITabBarController @end

/* =========================================================
 * WPS Office 离线化 tweak v3
 * 1. VIP 解锁（合并自 wpsofficevip.dylib 逆向：稻壳儿 VIP / 新 VIP / PDF转Word）
 * 2. 禁网：NSURLSessionTask 白名单外全拦（cancel 触发回调，不卡 loading）
 * 3. 移除"稻壳儿"tab（广覆盖：任意 UITabBarController 的 viewDidLoad/viewDidAppear/setViewControllers:）
 * 4. 拦截第三方登录跳转（微信/QQ/TIM/支付宝 openURL）
 * ========================================================= */

/* ---------- 通用：移除含"稻壳"的 tab ---------- */
static void kw_remove_docer_tab(UIViewController *tabVC) {
  if (![tabVC respondsToSelector:@selector(viewControllers)]) return;
  NSArray *vcs = [(UITabBarController *)tabVC viewControllers];
  if (vcs.count == 0) return;
  NSMutableArray *keep = [NSMutableArray array];
  for (UIViewController *vc in vcs) {
    NSString *t = vc.title ?: @"";
    if (t.length == 0 && [vc respondsToSelector:@selector(tabBarItem)]) {
      t = vc.tabBarItem.title ?: @"";
    }
    if ([t containsString:@"稻壳"]) {
      continue;   // 跳过稻壳儿 tab
    }
    [keep addObject:vc];
  }
  if (keep.count > 0 && keep.count != vcs.count) {
    [(UITabBarController *)tabVC setViewControllers:keep animated:NO];
  }
}

/* ---------- 通用：第三方登录跳转是否拦截 ---------- */
static BOOL kw_block_third_login(NSURL *url) {
  NSString *s = [url.scheme lowercaseString] ?: @"";
  if ([s hasPrefix:@"weixin"] || [s hasPrefix:@"weixindicator"] ||
      [s hasPrefix:@"mqq"] || [s hasPrefix:@"tim"] ||
      [s hasPrefix:@"wtlogin"] || [s hasPrefix:@"alipay"]) {
    return YES;
  }
  return NO;
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
    %orig;   // 本地地址放行
    return;
  }
  // 其余网络请求：不发包，直接 cancel（触发完成回调，避免 UI 无限转圈）
  [self cancel];
}
%end

/* ---------- 3. 移除"稻壳儿"tab（广覆盖 UITabBarController） ---------- */
%hook UITabBarController
- (void)viewDidLoad {
  %orig;
  kw_remove_docer_tab(self);
}
- (void)viewDidAppear:(BOOL)animated {
  %orig;
  kw_remove_docer_tab(self);
}
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated {
  %orig;
  kw_remove_docer_tab(self);
}
%end

/* ---------- 4. 拦截第三方登录跳转（微信/QQ/TIM/支付宝） ---------- */
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
