import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
// 纠正：使用 AppStorage 而不是 AppStorageV2
import { AppStorageV2, window } from '@kit.ArkUI';
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

type HeartRateResponse = sensor.HeartRateResponse;

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  public heartRate: number = 0;

  // 定义回调函数，以便在订阅时使用
  private onHeartRateChange = (data: HeartRateResponse) => {
    if (data && typeof data.heartRate === 'number') {
      this.heartRate = data.heartRate;
      hilog.info(DOMAIN, 'HeartRate', `Heart rate updated: ${this.heartRate}`);
    }
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    this.stopGettingHeartRate();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 纠正：使用 AppStorage.set() 或 setOrCreate()。因为是首次设置，用setOrCreate更保险。
    AppStorage.setOrCreate('ability', this);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    this.startGettingHeartRate();
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    this.stopGettingHeartRate();
  }

  private startGettingHeartRate(): void {
    try {
      hilog.info(DOMAIN, 'HeartRate', 'Subscribing to heart rate sensor...');
      // 正确：直接在 sensor 对象上调用 on
      sensor.on(sensor.SensorId.HEART_RATE, this.onHeartRateChange, { interval: 1000000000 });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'HeartRate', `Failed to subscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }

  private stopGettingHeartRate(): void {
    try {
      hilog.info(DOMAIN, 'HeartRate', 'Unsubscribing from heart rate sensor.');

      // 纠正：根据您的文档，不传递回调函数可以取消该类型所有订阅，更简洁。
      sensor.off(sensor.SensorId.HEART_RATE);

    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'HeartRate', `Failed to unsubscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }
}