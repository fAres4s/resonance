import EntryAbility from '../entryability/EntryAbility';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

@Entry
@Component
struct HeartRateDisplay {
  @StorageLink('ability') ability: EntryAbility | undefined = undefined;
  @StorageLink('heartRate') heartRate: number = 0;
  @StorageLink('isWorn') isWorn: boolean = false;
  @StorageLink('isVibrationOn') isVibrationOn: boolean = true;
  private windowClass: window.Window | undefined = undefined;


  async requestPermissionAndStart() {
    if (!this.ability) {
      setTimeout((): void => { this.requestPermissionAndStart(); }, 50);
      return;
    }
    let context = this.ability.context;
    let atManager = abilityAccessCtrl.createAtManager();
    try {
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.READ_HEALTH_DATA']);
      let grants = result.authResults;
      if (grants.length > 0 && grants[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        hilog.info(DOMAIN, 'Permission', 'Heart rate permission granted.');
        this.ability.startMonitoring();
      } else {
        hilog.warn(DOMAIN, 'Permission', 'Heart rate permission denied.');
      }
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'Permission', `Failed to request permission. Code: ${error.code}, message: ${error.message}`);
    }
  }

  // aboutToAppear 现在使用 async/await 来处理异步操作
  async aboutToAppear() {
    this.requestPermissionAndStart();

    // 规范重写：使用 async/await 语法，并加上完整的 try/catch 错误处理
    try {
      const windowClass = await window.getLastWindow(getContext(this));
      this.windowClass = windowClass;
      await this.windowClass.setWindowKeepScreenOn(true);
      hilog.info(DOMAIN, 'ScreenOn', 'Succeeded in setting the screen to be always on.');
    } catch (exception) {
      // exception可能是BusinessError或其他类型，使用 as 进行类型断言
      const error = exception as BusinessError;
      hilog.error(DOMAIN, 'ScreenOn', `Failed to set screen on. Code: ${error.code}, message: ${error.message}`);
    }
  }

  async aboutToDisappear() {
    if (this.ability) {
      this.ability.stopMonitoring();
    }

    // 规范重写：同样使用 async/await 语法
    if (this.windowClass) {
      try {
        await this.windowClass.setWindowKeepScreenOn(false);
        hilog.info(DOMAIN, 'ScreenOn', 'Succeeded in setting the screen to be off.');
      } catch (exception) {
        const error = exception as BusinessError;
        hilog.error(DOMAIN, 'ScreenOn', `Failed to set screen off. Code: ${error.code}, message: ${error.message}`);
      }
    }
  }

  @Builder HeartRateView() {
    Column() {
      Text('当前心率')
        .fontSize(20)
        .textAlign(TextAlign.Center);
      Text(this.heartRate > 0 ? this.heartRate.toString() : '--')
        .fontSize(40)
        .fontColor(Color.Red)
        .textAlign(TextAlign.Center);
      Text('BPM')
        .fontSize(16)
        .textAlign(TextAlign.Center);

      Button(this.isVibrationOn ? '振动已开' : '振动已关')
        .type(ButtonType.Capsule)
        .margin({ top: 40 })
        .backgroundColor(this.isVibrationOn ? '#007DFF' : '#555555')
        .onClick(() => {
          this.isVibrationOn = !this.isVibrationOn;
          if (this.ability) {
            this.ability.handleVibrationToggle();
          }
        })
    }
    .width('100%');
  }

  @Builder WearPromptView() {
    Text('请正确佩戴手表')
      .fontSize(24)
      .fontColor(Color.Gray)
      .textAlign(TextAlign.Center);
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      if (this.isWorn) {
        this.HeartRateView();
      } else {
        this.WearPromptView();
      }
    }
    .width('100%')
    .height('100%');
  }
}