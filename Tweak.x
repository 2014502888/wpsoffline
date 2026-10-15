#import <UIKit/UIKit.h>

/* WPS 私有类声明（自绘 tab 体系） */
@interface KWPublicViewController : UIViewController @end
@interface KWMeViewController : KWPublicViewController @end
@interface KWTabBarController : UIViewController @end
@interface KWPhoneMainTabBarController : KWTabBarController @end

/* =========================================================
 * WPS Office 离线化 tweak v6
 * 1. VIP 解锁（合并自 wpsofficevip.dylib 逆向）
 * 2. 禁网：NSURLSessionTask 白名单外全拦（cancel 回调）
 * 3. 登录跳转拦截（scheme + 微信/QQ 域名）
 * 4. 视图树遍历彻底移除：稻壳儿 tab / "我的"页功能项（含箭头与空白）
 * 5. 首页右上角"证"按钮移除（精确匹配）
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

/* ---------- 通用：视图树遍历移除（cell 去箭头+隐藏；自绘项隐藏上层容器） ---------- */
static void kw_hide_text_views(UIView *root, NSArray *kws, BOOL exact) {
  if (!root) return;
  for (UIView *sub in root.subviews) {
    if ([sub isKindOfClass:[UILabel class]]) {
      NSString *t = ((UILabel *)sub).text;
      if (t.length > 0) {
        for (NSString *k in kws) {
          BOOL hit = exact ? [t isEqualToString:k] : [t containsString:k];
          if (hit) {
            // 向上找可交互祖先（cell/按钮）
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
              // UITableView cell：去箭头 + 隐藏整个 cell（含背景）
              UITableViewCell *cell = (UITableViewCell *)target;
              cell.accessoryType = UITableViewCellAccessoryNone;
              cell.accessoryView = nil;
              cell.hidden = YES;
              cell.userInteractionEnabled = NO;
              cell.contentView.hidden = YES;
            } else if ([target isKindOfClass:[UIControl class]]) {
              // 自绘按钮/控件
              UIView *parent = target.superview;
              if (parent && parent != root && parent.superview != root &&
                  parent.frame.size.height < 140) {
                // 列表内的项：连箭头/同行内容一起隐藏
                parent.hidden = YES;
                parent.userInteractionEnabled = NO;
              } else {
                // tab 栏/工具栏等根容器直接子视图：只隐藏按钮本身，避免整栏消失
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

/* ---------- 4. 视图树遍历移除 ---------- */
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
  %orig;
  // 全页面：稻壳儿 tab / 首页共享、星标 / 文档三点弹窗按钮
  kw_hide_text_views(self.view, @[@"稻壳", @"共享", @"星标"], NO);
  kw_hide_text_views(self.view, @[@"立即上传", @"分享给好友", @"上传至云文档",
                                  @"输出为长图片", @"超级PPT", @"更多应用"], NO);
  // "我的"页面移除云端/会员功能项
  NSString *cn = NSStringFromClass([self class]);
  if ([cn hasPrefix:@"KWMe"]) {
    kw_hide_text_views(self.view, @[@"登入", @"登录", @"享受更多", @"云服务",
                                    @"云文档", @"会员", @"找回文档", @"消息",
                                    @"钱包", @"已购", @"收藏", @"活动"], NO);
  }
  // 首页右上角"证"按钮（精确匹配单字）
  kw_hide_text_views(self.view, @[@"证"], YES);
}
%end
