import EntryAbility from '../entryability/EntryAbility';
// 导入 StorageLinkV2 装饰器
import { LocalStorageLink } from '@kit.ArkUI';

@Entry
@Component
struct HeartRateDisplay {
  @StorageLink('ability') ability: EntryAbility | undefined = undefined;

  @State heartRate: number = 0;

  private timer: number | undefined = undefined;

  aboutToAppear() {
    this.timer = setInterval(() => {
      if (this.ability) {
        this.heartRate = this.ability.heartRate;
      }
    }, 1000);
  }

  aboutToDisappear() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
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
      }
      .width('100%');
    }
    .width('100%')
    .height('100%');
  }
}