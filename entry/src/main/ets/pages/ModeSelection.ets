import router from '@ohos.router';
import { hilog } from '@kit.PerformanceAnalysisKit';
// 新增：导入 BusinessError 类型，用于明确指定错误对象的类型
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct ModeSelection {
  build() {
    Column({ space: 20 }) {
      Button('本机共鸣')
        .fontSize(16)
        .width('80%')
        .height(50)
        .type(ButtonType.Capsule)
        .backgroundColor('#007DFF')
        .onClick(() => {
          router.pushUrl({
            url: 'pages/Index'
          }).catch((err: BusinessError) => { // 纠正：为 err 参数明确指定 BusinessError 类型
            hilog.error(DOMAIN, 'Router', `Failed to navigate to Index page. Code: ${err.code}, message: ${err.message}`);
          });
        })

      Button('双机共鸣 (TBD)')
        .fontSize(16)
        .width('80%')
        .height(50)
        .type(ButtonType.Capsule)
        .backgroundColor('#555555')
        .onClick(() => {
          hilog.info(DOMAIN, 'Feature', 'Dual-device resonance feature is under development.');
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}