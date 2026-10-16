#import <UIKit/UIKit.h>

/* WPS 私有类声明 */
@interface KWPublicViewController : UIViewController @end
@interface KWMeViewController : KWPublicViewController @end
@interface KWTabBarController : UIViewController @end
@interface KWPhoneMainTabBarController : KWTabBarController @end

/* WPS Office 离线化 tweak v11
 * 基于反编译结果精确 hook：
 * 1. VIP 解锁
 * 2. 禁网
 * 3. 登录跳转拦截
 * 4. tab 栏：KWPhoneMainTabBarController setBottomTags: + KWCustomTabbarView setTabbarButtonArray: 数据源过滤稻壳儿
 * 5. "证"按钮：KSOComponentTopBar showSafeDocIcon:/docSecurityMarkView + KWHomeNavBanner 跳转
 * 6. 三点弹窗：KWMenuView layoutSubviews 清理
 * 7. 我的页/视图兜底清理保留
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

/* ---------- 视图树遍历移除（兜底） ---------- */
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
              int ctrlCount = 0;
              for (UIView *sv in target.subviews) {
                if ([sv isKindOfClass:[UIControl class]]) ctrlCount++;
              }
              if (ctrlCount >= 2) {
                UIView *cur = sub.superview;
                UIView *unit = sub;
                while (cur && cur != target) {
                  BOOL hasCtrl = NO;
                  for (UIView *sv in cur.subviews) {
                    if ([sv isKindOfClass:[UIControl class]]) { hasCtrl = YES; break; }
                  }
                  if (!hasCtrl) { unit = cur; break; }
                  cur = cur.superview;
                }
                if (unit == sub) unit = sub.superview ?: sub;
                unit.hidden = YES;
                unit.userInteractionEnabled = NO;
              } else {
                UIView *parent = target.superview;
                BOOL isBottomBar = NO;
                if (parent) {
                  CGRect pf = [parent convertRect:parent.bounds toView:root];
                  isBottomBar = (CGRectGetMaxY(pf) > [UIScreen mainScreen].bounds.size.height - 130);
                }
                if (parent && !isBottomBar && parent != root &&
                    parent.frame.size.height < 140) {
                  parent.hidden = YES;
                  parent.userInteractionEnabled = NO;
                } else {
                  target.hidden = YES;
                  target.userInteractionEnabled = NO;
                }
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

/* ---------- 清理：页面 + 导航栏 + navigationItem ---------- */
static void kw_cleanup_vc(UIViewController *vc) {
  /* 注意：不再视图遍历 tab 关键词（稻壳/共享/星标）——WPS tab 栏容器是 UIControl，
     视图遍历会把整个 tab 栏容器当"按钮"隐藏导致整栏按钮全灭。tab 移除走数据源
     (setBottomTags:/setTabbarButtonArray:) hook。 */
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

/* ---------- 6. "证"按钮（安全文档标记） ---------- */
%hook KSOComponentTopBar
- (void)showSafeDocIcon:(BOOL)show {
  %orig(NO);
}
- (void)setDocSecurityMarkView:(UIView *)v {
  %orig(nil);
}
%end

/* ---------- 7. 首页导航横幅（证/跳转兜底） ---------- */
%hook KWHomeNavBanner
- (void)setJumpUrl:(NSString *)url {
  %orig(nil);
}
- (void)setIsDisplayIcon:(BOOL)flag {
  %orig(NO);
}
%end

/* ---------- 8. 三点弹窗菜单清理 ---------- */
%hook KWMenuView
- (void)layoutSubviews {
  %orig;
  kw_hide_text_views(self, @[@"立即上传", @"分享给好友", @"上传至云文档",
                             @"输出为长图片", @"超级PPT", @"更多应用"], NO);
}
%end

/* ---------- 9. 页面视图兜底清理 ---------- */
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

/* ---------- 10. 动态视图兜底清理 ---------- */
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
