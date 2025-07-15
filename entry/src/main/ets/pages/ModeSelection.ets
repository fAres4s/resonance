import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct ModeSelection {
  // 引入状态锁，防止重复导航
  @State isNavigating: boolean = false;

  // 页面每次显示时，都重置导航状态
  onPageShow() {
    this.isNavigating = false;
    hilog.info(DOMAIN, 'ModeSelection', 'Page is shown, navigation lock released.');
  }

  build() {
    Column({ space: 20 }) {
      Button('本机共鸣')
        .type(ButtonType.Capsule)
        .fontSize(16)
        .width('80%')
        .height(50)
        .backgroundColor('#007DFF')
        .onClick(() => {
          // 在执行导航前检查状态锁
          if (this.isNavigating) {
            hilog.warn(DOMAIN, 'ModeSelection', 'Navigation is already in progress, ignoring click.');
            return;
          }
          // 立即上锁
          this.isNavigating = true;
          hilog.info(DOMAIN, 'ModeSelection', 'Navigating to Index page...');

          router.pushUrl({
            url: 'pages/Index'
          }).catch((err: BusinessError) => {
            hilog.error(DOMAIN, 'Router', `Failed to navigate to Index page. Code: ${err.code}, message: ${err.message}`);
            // 如果导航失败，也需要解锁
            this.isNavigating = false;
          });
        })

      Button('双机共鸣')
        .type(ButtonType.Capsule)
        .fontSize(16)
        .width('80%')
        .height(50)
        .backgroundColor('#007DFF')
        .onClick(() => {
          // 同样为第二个按钮添加状态锁
          if (this.isNavigating) {
            hilog.warn(DOMAIN, 'ModeSelection', 'Navigation is already in progress, ignoring click.');
            return;
          }
          this.isNavigating = true;
          hilog.info(DOMAIN, 'ModeSelection', 'Navigating to Pairing page...');

          router.pushUrl({
            url: 'pages/NfcPairing' // 确保您已将配对页面的文件名改回 NfcPairing.ets
          }).catch((err: BusinessError) => {
            hilog.error(DOMAIN, 'Router', `Failed to navigate to Pairing page. Code: ${err.code}, message: ${err.message}`);
            this.isNavigating = false;
          });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
