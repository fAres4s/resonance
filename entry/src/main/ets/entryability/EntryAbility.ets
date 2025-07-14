import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
// 纠正：彻底移除对 AppStorage 的导入，它是一个全局内置对象
import { window } from '@kit.ArkUI';
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

type HeartRateResponse = sensor.HeartRateResponse;
type WearDetectionResponse = sensor.WearDetectionResponse;
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private onHeartRateChange = (data: HeartRateResponse) => {
    if (data && typeof data.heartRate === 'number' && data.heartRate < 255) {
      // 直接使用全局的 AppStorage 对象
      AppStorage.set('heartRate', data.heartRate);
      hilog.info(DOMAIN, 'HeartRate', `Heart rate updated in AppStorage: ${data.heartRate}`);
    }
  };

  private onWearStatusChange = (data: WearDetectionResponse) => {
    const isWorn = data.value;
    // 直接使用全局的 AppStorage 对象
    AppStorage.set('isWorn', isWorn);
    hilog.info(DOMAIN, 'WearDetection', `Wear status updated in AppStorage: ${isWorn}`);

    if (isWorn) {
      this.startGettingHeartRate();
    } else {
      this.stopGettingHeartRate();
      AppStorage.set('heartRate', 0);
    }
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    this.stopMonitoring();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    // 直接使用全局的 AppStorage 对象
    AppStorage.setOrCreate('ability', this);
    AppStorage.setOrCreate('heartRate', 0);
    AppStorage.setOrCreate('isWorn', false);
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

  onForeground(): void { }
  onBackground(): void { }

  public startMonitoring(): void {
    try {
      hilog.info(DOMAIN, 'WearDetection', 'Subscribing to wear detection sensor...');
      sensor.on(sensor.SensorId.WEAR_DETECTION, this.onWearStatusChange, { interval: 200000000 });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'WearDetection', `Failed to subscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }

  public stopMonitoring(): void {
    this.stopGettingHeartRate();
    try {
      hilog.info(DOMAIN, 'WearDetection', 'Unsubscribing from wear detection sensor.');
      sensor.off(sensor.SensorId.WEAR_DETECTION);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'WearDetection', `Failed to unsubscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }

  private startGettingHeartRate(): void {
    try {
      hilog.info(DOMAIN, 'HeartRate', 'Subscribing to heart rate sensor...');
      sensor.on(sensor.SensorId.HEART_RATE, this.onHeartRateChange, { interval: 1000000000 });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'HeartRate', `Failed to subscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }

  private stopGettingHeartRate(): void {
    try {
      hilog.info(DOMAIN, 'HeartRate', 'Unsubscribing from heart rate sensor.');
      sensor.off(sensor.SensorId.HEART_RATE);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'HeartRate', `Failed to unsubscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }
}