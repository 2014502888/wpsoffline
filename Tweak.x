#import <UIKit/UIKit.h>

/* WPS 私有类声明 */
@interface KWPhoneMainTabBarController : UITabBarController @end
@interface KWMeViewController : UIViewController @end

/* =========================================================
 * WPS Office 离线化 tweak v4
 * 1. VIP 解锁（合并自 wpsofficevip.dylib 逆向：稻壳儿 VIP / 新 VIP / PDF转Word）
 * 2. 禁网：NSURLSessionTask 白名单外全拦（cancel 触发回调，不卡 loading）
 * 3. 移除"稻壳儿"tab（广覆盖 UITabBarController）
 * 4. 拦截第三方登录跳转（微信/QQ/TIM/支付宝：scheme + Universal Link 域名）
 * 5. "我的"页面移除云端/会员功能项 + 左上角活动入口
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
      continue;
    }
    [keep addObject:vc];
  }
  if (keep.count > 0 && keep.count != vcs.count) {
    [(UITabBarController *)tabVC setViewControllers:keep animated:NO];
  }
}

/* ---------- 通用：第三方登录跳转是否拦截（scheme + Universal Link 域名） ---------- */
static BOOL kw_block_third_login(NSURL *url) {
  NSString *s = [url.scheme lowercaseString] ?: @"";
  NSString *h = [url.host lowercaseString] ?: @"";
  if ([s hasPrefix:@"weixin"] || [s hasPrefix:@"weixindicator"] ||
      [s hasPrefix:@"mqq"] || [s hasPrefix:@"tim"] ||
      [s hasPrefix:@"wtlogin"] || [s hasPrefix:@"alipay"]) {
    return YES;
  }
  if ([h containsString:@"weixin.qq.com"] || [h containsString:@"open.mobile.qq.com"] ||
      [h containsString:@"graph.qq.com"] || [h containsString:@"connect.qq.com"] ||
      [h containsString:@"ssl.qq.com"]) {
    return YES;
  }
  return NO;
}

/* ---------- 通用："我的"页面功能项文本匹配 ---------- */
static BOOL kw_is_docer_cell_text(NSString *t) {
  if (t.length == 0) return NO;
  NSArray *kws = @[@"登入", @"登录", @"享受更多", @"云服务", @"云文档", @"会员",
                   @"稻壳", @"找回文档", @"消息", @"钱包", @"已购", @"收藏", @"活动"];
  for (NSString *k in kws) {
    if ([t containsString:k]) return YES;
  }
  return NO;
}

/* 递归收集 view 内所有 UILabel 文本 */
static NSString *kw_all_text(UIView *v) {
  NSMutableString *s = [NSMutableString string];
  if ([v isKindOfClass:[UILabel class]]) {
    NSString *t = ((UILabel *)v).text;
    if (t.length) [s appendString:t];
  }
  for (UIView *sub in v.subviews) {
    [s appendString:kw_all_text(sub)];
  }
  return s;
}

/* 判断 tableView 是否属于"我的"页面（delegate/dataSource 类名 KWMe 前缀） */
static BOOL kw_is_me_table(UITableView *tv) {
  id d = tv.delegate ?: tv.dataSource;
  if (!d) return NO;
  NSString *cn = NSStringFromClass([d class]);
  return [cn hasPrefix:@"KWMe"] || [cn hasPrefix:@"KWMine"] || [cn hasPrefix:@"KWProfile"];
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

/* ---------- 4. 拦截第三方登录跳转 ---------- */
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

/* ---------- 5. "我的"页面：隐藏云端/会员功能 cell + 左上角活动 ---------- */
%hook UITableView
- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *c = %orig;
  if (c && kw_is_me_table(self)) {
    NSString *t = kw_all_text(c);
    if (kw_is_docer_cell_text(t)) {
      c.hidden = YES;
      c.userInteractionEnabled = NO;
    }
  }
  return c;
}
%end

%hook KWMeViewController
- (void)viewDidLoad {
  %orig;
  self.navigationItem.leftBarButtonItems = nil;
  self.navigationItem.leftBarButtonItem = nil;
}
%end
