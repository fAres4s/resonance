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
    if (isVibrationOn !== true) {
      this.stopVibrationLoop();
      return;
    }
    const heartRate = AppStorage.get<number>('heartRate');
    if (typeof heartRate === 'number' && heartRate > 0) {
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
      this.vibrationLoopTimerId = setTimeout(this.vibrationLoop, 1000);
    }
  }

  private startVibrationLoop(): void {
    if (this.vibrationLoopTimerId !== null) { return; }
    if (AppStorage.get<boolean>('isVibrationOn') === true) {
      hilog.info(DOMAIN, 'Vibrator', 'Starting vibration loop...');
      this.vibrationLoop();
    }
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

  // 纠正：新增一个公开方法，用于被UI调用
  public handleVibrationToggle(): void {
    const isVibrationOn = AppStorage.get<boolean>('isVibrationOn');
    const isWorn = AppStorage.get<boolean>('isWorn');
    hilog.info(DOMAIN, 'VibratorToggle', `Vibration toggled by UI. New state: ${isVibrationOn}`);

    if (isVibrationOn && isWorn) {
      this.startVibrationLoop();
    } else {
      this.stopVibrationLoop();
    }
  }

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

    // 纠正：将启动页面从 'pages/Index' 重新改回 'pages/ModeSelection'
    windowStage.loadContent('pages/ModeSelection', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', `Failed to load the content. Cause: ${JSON.stringify(err)}`);
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  // ... (其余方法保持不变，但修正了它们的可见性)
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
    // 停止心率监测时，不需要再停止振动循环，因为 onWearStatusChange 会处理
    try {
      hilog.info(DOMAIN, 'HeartRate', 'Unsubscribing from heart rate sensor.');
      sensor.off(sensor.SensorId.HEART_RATE);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'HeartRate', `Failed to unsubscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }
}