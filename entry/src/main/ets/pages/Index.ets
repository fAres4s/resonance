import EntryAbility from '../entryability/EntryAbility';
// 纠正：移除所有关于 StorageLink 的 import 语句

@Entry
@Component
struct HeartRateDisplay {
  // 正确：直接使用内置的 @StorageLink 装饰器
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