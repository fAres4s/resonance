import EntryAbility from '../entryability/EntryAbility';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct HeartRateDisplay {
  @StorageLink('ability') ability: EntryAbility | undefined = undefined;
  @StorageLink('heartRate') heartRate: number = 0;
  @StorageLink('isWorn') isWorn: boolean = false;
  // 新增：绑定振动开关的状态
  @StorageLink('isVibrationOn') isVibrationOn: boolean = true;

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

  aboutToAppear() {
    this.requestPermissionAndStart();
  }

  aboutToDisappear() {
    if (this.ability) {
      this.ability.stopMonitoring();
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

      // 新增：振动开关按钮
      Button(this.isVibrationOn ? '振动已开' : '振动已关')
        .type(ButtonType.Capsule) // 胶囊样式
        .margin({ top: 40 })
        .backgroundColor(this.isVibrationOn ? '#007DFF' : '#555555') // 根据状态改变颜色
        .onClick(() => {
          // 点击时，直接改变绑定的状态变量
          // @StorageLink会自动将这个改变同步回AppStorage
          this.isVibrationOn = !this.isVibrationOn;
          if (!this.isVibrationOn) {
            // 如果是关闭振动，立即停止当前所有振动
            if (this.ability) {
              this.ability.stopGettingHeartRate();
              this.ability.startGettingHeartRate(); // 重启心率但不振动
            }
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