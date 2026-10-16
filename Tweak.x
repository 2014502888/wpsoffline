#import <UIKit/UIKit.h>

/* WPS 私有类声明 */
@interface KWPublicViewController : UIViewController @end
@interface KWMeViewController : KWPublicViewController @end
@interface KWTabBarController : UIViewController @end
@interface KWPhoneMainTabBarController : KWTabBarController @end

/* WPS Office 离线化 tweak v13
 * 视图隐藏全面改"宽度法"：只隐藏宽度 < 屏幕 80% 的独立单元（tab 项/按钮/菜单项），
 * 绝不隐藏全宽容器（修复"我"页黑屏 = 登入 banner 被整块隐藏）
 * tab 稻壳儿：在 KWPhoneMainTabBarController 的 tab 栏视图上专门遍历（只藏那一项）
 */

/* ---------- 第三方登录跳转拦截 ---------- */
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

/* ---------- 宽度法：隐藏叶子独立单元（不隐藏全宽容器） ---------- */
static void kw_hide_leaf_unit(UIView *leaf, UIView *root) {
  CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
  UIView *cur = leaf;
  UIView *hide = leaf;
  while (cur && cur != root && cur.superview) {
    if (cur.frame.size.width < screenW * 0.8) {
      hide = cur;          // 记住最靠近但仍是窄单元的容器（往上找 tab 项/独立项）
    } else {
      break;               // 遇到全宽容器（页面/整栏）停止
    }
    cur = cur.superview;
  }
  hide.hidden = YES;
  hide.userInteractionEnabled = NO;
}

/* ---------- 视图树遍历移除（宽度法） ---------- */
static void kw_hide_text_views(UIView *root, NSArray *kws, BOOL exact) {
  if (!root) return;
  for (UIView *sub in root.subviews) {
    if ([sub isKindOfClass:[UIControl class]] || [sub isKindOfClass:[UIImageView class]]) {
      NSString *al = sub.accessibilityLabel;
      if (al.length > 0) {
        for (NSString *k in kws) {
          BOOL hit = exact ? [al isEqualToString:k] : [al containsString:k];
          if (hit) {
            sub.hidden = YES;
            sub.userInteractionEnabled = NO;
            break;
          }
        }
      }
    }
    if ([sub isKindOfClass:[UILabel class]]) {
      NSString *t = ((UILabel *)sub).text;
      if (t.length > 0) {
        for (NSString *k in kws) {
          BOOL hit = exact ? [t isEqualToString:k] : [t containsString:k];
          if (hit) {
            /* 先找 cell（列表行整体隐藏） */
            UIView *v = sub;
            UIView *cell = nil;
            while (v && v != root) {
              if ([v isKindOfClass:[UITableViewCell class]] ||
                  [v isKindOfClass:[UICollectionViewCell class]]) {
                cell = v;
                break;
              }
              v = v.superview;
            }
            if (cell) {
              if ([cell isKindOfClass:[UITableViewCell class]]) {
                UITableViewCell *c = (UITableViewCell *)cell;
                c.accessoryType = UITableViewCellAccessoryNone;
                c.accessoryView = nil;
                c.hidden = YES;
                c.userInteractionEnabled = NO;
                c.contentView.hidden = YES;
              } else {
                cell.hidden = YES;
                cell.userInteractionEnabled = NO;
              }
            } else {
              /* 非 cell：宽度法隐藏独立单元（不隐藏全宽容器） */
              kw_hide_leaf_unit(sub, root);
            }
            break;
          }
        }
      }
    }
    kw_hide_text_views(sub, kws, exact);
  }
}

/* ---------- 清理：页面 + 导航栏 + navigationItem ---------- */
static void kw_cleanup_vc(UIViewController *vc) {
  kw_hide_text_views(vc.view, @[@"立即上传", @"分享给好友", @"上传至云文档",
                                @"输出为长图片", @"超级PPT", @"更多应用"], NO);
  NSString *cn = NSStringFromClass([vc class]);
  if ([cn hasPrefix:@"KWMe"]) {
    kw_hide_text_views(vc.view, @[@"登入", @"登录", @"享受更多", @"云服务",
                                  @"云文档", @"会员", @"找回文档", @"消息",
                                  @"钱包", @"已购", @"收藏", @"活动"], NO);
  }
  kw_hide_text_views(vc.view, @[@"证"], YES);
  UINavigationBar *nb = vc.navigationController.navigationBar;
  if (nb) {
    kw_hide_text_views(nb, @[@"证"], YES);
  }
  UINavigationItem *ni = vc.navigationItem;
  if (ni.rightBarButtonItem) {
    if ([ni.rightBarButtonItem.title isEqualToString:@"证"]) {
      ni.rightBarButtonItem = nil;
    } else if (ni.rightBarButtonItem.customView) {
      kw_hide_text_views(ni.rightBarButtonItem.customView, @[@"证"], YES);
    }
  }
}

/* ---------- 清理：整个窗口 ---------- */
static void kw_cleanup_window(void) {
  UIWindow *w = [UIApplication sharedApplication].windows.firstObject;
  if (!w) return;
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

/* ---------- 2. 禁网 ---------- */
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

/* ---------- 3. 登录跳转拦截 ---------- */
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

/* ---------- 4. tab 数据源过滤稻壳儿 ---------- */
%hook KWPhoneMainTabBarController
- (void)setBottomTags:(NSArray *)tags {
  if (tags) {
    NSMutableArray *m = [NSMutableArray array];
    for (id tag in tags) {
      BOOL bad = NO;
      NSString *d = [tag description];
      if (d && [d containsString:@"稻壳"]) bad = YES;
      if (!bad) {
        for (NSString *key in @[@"title", @"name", @"text", @"desc", @"label"]) {
          id v = nil;
          @try { v = [tag valueForKey:key]; } @catch (NSException *e) {}
          if ([v isKindOfClass:[NSString class]] && [(NSString *)v containsString:@"稻壳"]) {
            bad = YES;
            break;
          }
        }
      }
      if (!bad) [m addObject:tag];
    }
    %orig(m);
  } else {
    %orig;
  }
}
%end

/* ---------- 5. tab 按钮数组过滤 ---------- */
%hook KWCustomTabbarView
- (void)setTabbarButtonArray:(NSArray *)arr {
  if (arr) {
    NSMutableArray *m = [NSMutableArray array];
    for (UIView *b in arr) {
      NSString *t = @"";
      if ([b isKindOfClass:[UIButton class]]) {
        t = [t stringByAppendingString:((UIButton *)b).titleLabel.text ?: @""];
      }
      for (UIView *sv in b.subviews) {
        if ([sv isKindOfClass:[UILabel class]]) {
          t = [t stringByAppendingString:((UILabel *)sv).text ?: @""];
        }
      }
      if ([t containsString:@"稻壳"]) continue;
      [m addObject:b];
    }
    %orig(m);
  } else {
    %orig;
  }
}
%end

/* ---------- 6. tab 栏视图兜底：只隐藏稻壳儿那一项（宽度法） ---------- */
%hook KWPhoneMainTabBarController
- (void)viewDidLoad {
  %orig;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.6 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    UIView *tb = nil;
    @try { tb = [self valueForKey:@"phoneMainTabBarView"]; } @catch (NSException *e) {}
    if (tb) {
      kw_hide_text_views(tb, @[@"稻壳"], NO);
    }
  });
}
- (void)viewDidAppear:(BOOL)animated {
  %orig;
  UIView *tb = nil;
  @try { tb = [self valueForKey:@"phoneMainTabBarView"]; } @catch (NSException *e) {}
  if (tb) {
    kw_hide_text_views(tb, @[@"稻壳"], NO);
  }
}
%end

/* ---------- 7. "证"按钮（安全文档标记） ---------- */
%hook KSOComponentTopBar
- (void)showSafeDocIcon:(BOOL)show {
  %orig(NO);
}
- (void)setDocSecurityMarkView:(UIView *)v {
  %orig(nil);
}
%end

/* ---------- 8. 首页导航横幅（证/跳转兜底） ---------- */
%hook KWHomeNavBanner
- (void)setJumpUrl:(NSString *)url {
  %orig(nil);
}
- (void)setIsDisplayIcon:(BOOL)flag {
  %orig(NO);
}
%end

/* ---------- 9. 三点弹窗菜单清理 ---------- */
%hook KWMenuView
- (void)layoutSubviews {
  %orig;
  kw_hide_text_views(self, @[@"立即上传", @"分享给好友", @"上传至云文档",
                             @"输出为长图片", @"超级PPT", @"更多应用"], NO);
}
%end

/* ---------- 10. 页面视图兜底清理 ---------- */
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
  %orig;
  kw_cleanup_vc(self);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.6 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    kw_cleanup_window();
  });
}
%end

/* ---------- 11. 动态视图兜底清理 ---------- */
%hook UIWindow
- (void)addSubview:(UIView *)view {
  %orig;
  __weak UIView *wv = view;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    if (wv) {
      kw_hide_text_views(wv, @[@"立即上传", @"分享给好友", @"上传至云文档",
                               @"输出为长图片", @"超级PPT", @"更多应用"], NO);
      kw_hide_text_views(wv, @[@"证"], YES);
    }
  });
}
%end
