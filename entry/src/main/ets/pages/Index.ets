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

      Button(this.isVibrationOn ? '振动已开' : '振动已关')
        .type(ButtonType.Capsule)
        .margin({ top: 40 })
        .backgroundColor(this.isVibrationOn ? '#007DFF' : '#555555')
        .onClick(() => {
          // 1. 改变状态
          this.isVibrationOn = !this.isVibrationOn;
          // 2. 明确调用Ability中的方法来处理这个状态变化
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