#import <UIKit/UIKit.h>

/* WPS 私有类声明 */
@interface KWPublicViewController : UIViewController @end
@interface KWMeViewController : KWPublicViewController @end
@interface KWTabBarController : UIViewController @end
@interface KWPhoneMainTabBarController : KWTabBarController @end

/* =========================================================
 * WPS Office 离线化 tweak v8
 * 1. VIP 解锁
 * 2. 禁网：NSURLSessionTask 白名单外全拦
 * 3. 登录跳转拦截（scheme + 域名）
 * 4. 视图树遍历移除（tab 容器按类名识别，不误杀整栏）
 * 5. 右上角"证"按钮（遍历 navigationBar）
 * 6. 弹窗按钮（延迟 0.6s 遍历 keyWindow 覆盖弹窗层）
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

/* ---------- 通用：视图树遍历移除 ---------- */
static void kw_hide_text_views(UIView *root, NSArray *kws, BOOL exact) {
  if (!root) return;
  for (UIView *sub in root.subviews) {
    if ([sub isKindOfClass:[UILabel class]]) {
      NSString *t = ((UILabel *)sub).text;
      if (t.length > 0) {
        for (NSString *k in kws) {
          BOOL hit = exact ? [t isEqualToString:k] : [t containsString:k];
          if (hit) {
            UIView *v = sub;
            UIView *last = sub;
            while (v && !([v isKindOfClass:[UIControl class]] ||
                          [v isKindOfClass:[UITableViewCell class]] ||
                          [v isKindOfClass:[UICollectionViewCell class]])) {
              last = v;
              v = v.superview;
            }
            UIView *target = v ?: last;
            if ([target isKindOfClass:[UITableViewCell class]]) {
              UITableViewCell *cell = (UITableViewCell *)target;
              cell.accessoryType = UITableViewCellAccessoryNone;
              cell.accessoryView = nil;
              cell.hidden = YES;
              cell.userInteractionEnabled = NO;
              cell.contentView.hidden = YES;
            } else if ([target isKindOfClass:[UIControl class]]) {
              UIView *parent = target.superview;
              NSString *pcn = parent ? NSStringFromClass([parent class]) : @"";
              // tab 栏/工具容器按类名识别，只隐藏按钮本身，不误杀整栏
              BOOL isTabContainer = [pcn containsString:@"Tabbar"] ||
                                    [pcn containsString:@"TabBar"] ||
                                    [pcn containsString:@"TabView"];
              if (parent && !isTabContainer && parent != root &&
                  parent.superview != root && parent.frame.size.height < 140) {
                parent.hidden = YES;
                parent.userInteractionEnabled = NO;
              } else {
                target.hidden = YES;
                target.userInteractionEnabled = NO;
              }
            } else {
              target.hidden = YES;
              target.userInteractionEnabled = NO;
            }
            break;
          }
        }
      }
    }
    kw_hide_text_views(sub, kws, exact);
  }
}

/* ---------- 执行清理：页面 + 导航栏 ---------- */
static void kw_cleanup_vc(UIViewController *vc) {
  kw_hide_text_views(vc.view, @[@"稻壳", @"共享", @"星标"], NO);
  kw_hide_text_views(vc.view, @[@"立即上传", @"分享给好友", @"上传至云文档",
                                @"输出为长图片", @"超级PPT", @"更多应用"], NO);
  NSString *cn = NSStringFromClass([vc class]);
  if ([cn hasPrefix:@"KWMe"]) {
    kw_hide_text_views(vc.view, @[@"登入", @"登录", @"享受更多", @"云服务",
                                  @"云文档", @"会员", @"找回文档", @"消息",
                                  @"钱包", @"已购", @"收藏", @"活动"], NO);
  }
  // 右上角"证"（在导航栏，不在 view 子树）
  kw_hide_text_views(vc.view, @[@"证"], YES);
  UINavigationBar *nb = vc.navigationController.navigationBar;
  if (nb) {
    kw_hide_text_views(nb, @[@"证"], YES);
  }
}

/* ---------- 执行清理：整个窗口（覆盖弹窗层） ---------- */
static void kw_cleanup_window(void) {
  UIWindow *w = [UIApplication sharedApplication].windows.firstObject;
  if (!w) return;
  kw_hide_text_views(w, @[@"稻壳"], NO);
  kw_hide_text_views(w, @[@"立即上传", @"分享给好友", @"上传至云文档",
                          @"输出为长图片", @"超级PPT", @"更多应用"], NO);
  kw_hide_text_views(w, @[@"证"], YES);
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

/* ---------- 4. 视图清理 ---------- */
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
  %orig;
  kw_cleanup_vc(self);
  // 弹窗是独立层且晚出现：延迟再清一次全窗口
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.6 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    kw_cleanup_window();
  });
}
%end
