import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';

type HeartRateResponse = sensor.HeartRateResponse;
type WearDetectionResponse = sensor.WearDetectionResponse;
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private vibrationLoopTimerId: number | null = null;

  private onHeartRateChange = (data: HeartRateResponse) => {
    const currentHeartRate = data.heartRate;
    if (data && typeof currentHeartRate === 'number' && currentHeartRate < 255) {
      AppStorage.set('heartRate', currentHeartRate);
    }
  };

  private onWearStatusChange = (data: WearDetectionResponse) => {
    const isWorn = data.value;
    AppStorage.set('isWorn', isWorn);
    if (isWorn) {
      this.startVibrationLoop();
      this.startGettingHeartRate();
    } else {
      this.stopVibrationLoop();
      this.stopGettingHeartRate();
      AppStorage.set('heartRate', 0);
    }
  };

  private vibrationLoop = () => {
    const isVibrationOn = AppStorage.get<boolean>('isVibrationOn');
    if (isVibrationOn !== true) { // 使用严格比较，确保只有在明确为 true 时才继续
      this.stopVibrationLoop();
      return;
    }

    // 关键修正点：在使用前，检查从AppStorage取出的值是否存在
    const heartRate = AppStorage.get<number>('heartRate');
    if (typeof heartRate === 'number' && heartRate > 0) {
      // 只有当heartRate是一个有效数字且大于0时，才执行振动和计算
      try {
        vibrator.startVibration({ type: 'time', duration: 80 }, { usage: 'unknown' })
          .catch((error: BusinessError) => {
            hilog.error(DOMAIN, 'Vibrator', `Vibration failed. Code: ${error.code}, message: ${error.message}`);
          });
      } catch (err) {
        const error = err as BusinessError;
        hilog.error(DOMAIN, 'Vibrator', `Vibration start threw an error. Code: ${error.code}, message: ${error.message}`);
      }

      const nextInterval = 60000 / heartRate;
      this.vibrationLoopTimerId = setTimeout(this.vibrationLoop, nextInterval);
    } else {
      // 如果heartRate是0, null, 或 undefined, 则等待1秒后重试
      this.vibrationLoopTimerId = setTimeout(this.vibrationLoop, 1000);
    }
  }

  private startVibrationLoop(): void {
    if (this.vibrationLoopTimerId !== null) { return; }
    hilog.info(DOMAIN, 'Vibrator', 'Starting vibration loop...');
    this.vibrationLoop();
  }

  private stopVibrationLoop(): void {
    if (this.vibrationLoopTimerId !== null) {
      clearTimeout(this.vibrationLoopTimerId);
      this.vibrationLoopTimerId = null;
      try {
        vibrator.stopVibration();
        hilog.info(DOMAIN, 'Vibrator', 'Vibration loop stopped.');
      } catch (err) {
        hilog.error(DOMAIN, 'Vibrator', 'Failed to stop vibration.');
      }
    }
  }

  // ... (其他所有方法保持不变)
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    this.stopMonitoring();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    AppStorage.setOrCreate('ability', this);
    AppStorage.setOrCreate('heartRate', 0);
    AppStorage.setOrCreate('isWorn', false);
    AppStorage.setOrCreate('isVibrationOn', true);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', `Failed to load the content. Cause: ${JSON.stringify(err)}`);
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
    this.stopVibrationLoop();
    this.stopGettingHeartRate();
    try {
      hilog.info(DOMAIN, 'WearDetection', 'Unsubscribing from wear detection sensor.');
      sensor.off(sensor.SensorId.WEAR_DETECTION);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'WearDetection', `Failed to unsubscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }

  public startGettingHeartRate(): void {
    try {
      hilog.info(DOMAIN, 'HeartRate', 'Subscribing to heart rate sensor...');
      sensor.on(sensor.SensorId.HEART_RATE, this.onHeartRateChange, { interval: 1000000000 });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'HeartRate', `Failed to subscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }

  public stopGettingHeartRate(): void {
    try {
      hilog.info(DOMAIN, 'HeartRate', 'Unsubscribing from heart rate sensor.');
      sensor.off(sensor.SensorId.HEART_RATE);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'HeartRate', `Failed to unsubscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }
}