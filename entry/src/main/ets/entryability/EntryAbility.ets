// 纠正：从导入列表中移除未使用的 AbilityConstant
import { UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';
import backgroundTaskManager from '@ohos.backgroundTaskManager';
import wantAgent from '@ohos.wantAgent';

type HeartRateResponse = sensor.HeartRateResponse;
type WearDetectionResponse = sensor.WearDetectionResponse;
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private vibrationLoopTimerId: number | null = null;
  private lastVibrationRate: number = 0;

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
        let vibrationEffect: vibrator.VibrateEffect = {
          type: 'time',
          duration: 80
        };
        vibrator.startVibration(vibrationEffect, { usage: 'unknown' })
          .catch((error: BusinessError) => {
            hilog.error(DOMAIN, 'Vibrator', `Vibration failed. Code: ${error.code}, message: ${error.message}`);
          });
      } catch (err) {
        const error = err as BusinessError;
        hilog.error(DOMAIN, 'Vibrator', `Vibration start threw an error. Code: ${error.code}, message: ${error.message}`);
      }
      const nextInterval = 60000 / (AppStorage.get<number>('heartRate') ?? heartRate);
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

  private startContinuousTask(): void {
    hilog.info(DOMAIN, 'ContinuousTask', 'Attempting to start continuous task...');
    const wants: Want[] = [{
      bundleName: this.context.abilityInfo.bundleName,
      abilityName: this.context.abilityInfo.name
    }];
    try {
      wantAgent.getWantAgent({
        wants: wants,
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      }).then((wantAgentObj) => {
        try {
          backgroundTaskManager.startBackgroundRunning(this.context, backgroundTaskManager.BackgroundMode.DATA_TRANSFER, wantAgentObj)
            .then(() => {
              hilog.info(DOMAIN, 'ContinuousTask', 'Succeeded in starting background running.');
            }).catch((err: BusinessError) => {
            hilog.error(DOMAIN, 'ContinuousTask', `Failed to start background running. Code: ${err.code}, message: ${err.message}`);
          });
        } catch (error) {
          const e = error as BusinessError;
          hilog.error(DOMAIN, 'ContinuousTask', `startBackgroundRunning threw an error. Code: ${e.code}, message: ${e.message}`);
        }
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'ContinuousTask', `getWantAgent failed. Code: ${err.code}, message: ${err.message}`);
      });
    } catch (error) {
      const e = error as BusinessError;
      hilog.error(DOMAIN, 'ContinuousTask', `getWantAgent threw an error. Code: ${e.code}, message: ${e.message}`);
    }
  }

  private stopContinuousTask(): void {
    hilog.info(DOMAIN, 'ContinuousTask', 'Attempting to stop continuous task...');
    try {
      backgroundTaskManager.stopBackgroundRunning(this.context)
        .then(() => {
          hilog.info(DOMAIN, 'ContinuousTask', 'Succeeded in stopping background running.');
        }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'ContinuousTask', `Failed to stop background running. Code: ${err.code}, message: ${err.message}`);
      });
    } catch (error) {
      const e = error as BusinessError;
      hilog.error(DOMAIN, 'ContinuousTask', `stopBackgroundRunning threw an error. Code: ${e.code}, message: ${e.message}`);
    }
  }

  onCreate(want: Want): void {
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
    windowStage.loadContent('pages/ModeSelection', (err) => {
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
    this.startContinuousTask();
    try {
      hilog.info(DOMAIN, 'WearDetection', 'Subscribing to wear detection sensor...');
      sensor.on(sensor.SensorId.WEAR_DETECTION, this.onWearStatusChange, { interval: 200000000 });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'WearDetection', `Failed to subscribe. Code: ${error.code}, message: ${error.message}`);
    }
  }

  public stopMonitoring(): void {
    this.stopContinuousTask();
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