#import <UIKit/UIKit.h>

/* =========================================================
 * WPS Office 离线化 tweak
 * 1. VIP 解锁（合并自 wpsofficevip.dylib 逆向：稻壳儿 VIP / 新 VIP / PDF转Word）
 * 2. 禁网：NSURLSessionTask 白名单外全部拦截（首页广告/稻壳儿列表/登录/云同步断网，
 *    本地打开 xlsx 完全不受影响）
 * ========================================================= */

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

/* ---------- 3. 移除主界面"稻壳儿"tab ---------- */
%hook KWPhoneMainTabBarController
- (void)viewDidLoad {
  %orig;
  if ([self respondsToSelector:@selector(viewControllers)]) {
    NSArray *vcs = [self viewControllers];
    if (vcs.count > 0) {
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
        self.viewControllers = keep;
      }
    }
  }
}
%end
