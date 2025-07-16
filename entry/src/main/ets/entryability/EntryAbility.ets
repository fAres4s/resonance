// 纠正：从导入列表中移除未使用的 AbilityConstant
import { UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';
import backgroundTaskManager from '@ohos.backgroundTaskManager';
import wantAgent from '@ohos.wantAgent';
import { ble } from '@kit.ConnectivityKit';
import util from '@ohos.util';

type HeartRateResponse = sensor.HeartRateResponse;
type WearDetectionResponse = sensor.WearDetectionResponse;
const DOMAIN = 0x0000;

// 修正：将 "export default" 修改为 "export"
export class EntryAbility extends UIAbility {
  private vibrationLoopTimerId: number | null = null;
  private lastVibrationRate: number = 0;
  private gattServer: ble.GattServer | null = null;
  private gattClient: ble.GattClientDevice | null = null;
  private textEncoder = new util.TextEncoder();
  private textDecoder = new util.TextDecoder('utf-8');

  private onHeartRateChange = (data: HeartRateResponse) => {
    const currentHeartRate = data.heartRate;
    if (data && typeof currentHeartRate === 'number' && currentHeartRate < 255) {
      AppStorage.set('heartRate', currentHeartRate);
      // 在双机模式下，发送心率数据给对方
      const isDualMode = AppStorage.get<boolean>('isDualMode') ?? false;
      if (isDualMode) {
        this.sendHeartRateToPeer();
      }
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
    // 在双机模式下，使用对方心率；单机模式下使用本机心率
    const isDualMode = AppStorage.get<boolean>('isDualMode') ?? false;
    const heartRate = isDualMode ? 
      (AppStorage.get<number>('peerHeartRate') ?? 0) : 
      (AppStorage.get<number>('heartRate') ?? 0);
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
    AppStorage.setOrCreate('peerHeartRate', 0);
    AppStorage.setOrCreate('isWorn', false);
    AppStorage.setOrCreate('isVibrationOn', true);
    AppStorage.setOrCreate('isDualMode', false);
    AppStorage.setOrCreate('peerDeviceId', '');
    AppStorage.setOrCreate('gattServer', null);
    AppStorage.setOrCreate('gattClient', null);
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

  // 双机模式：设置GATT服务器
  public setGattServer(gattServer: ble.GattServer | null): void {
    this.gattServer = gattServer;
    AppStorage.setOrCreate('gattServer', gattServer);
    if (gattServer) {
      this.setupGattServerCallbacks();
    }
  }

  // 双机模式：设置GATT客户端
  public setGattClient(gattClient: ble.GattClientDevice | null): void {
    this.gattClient = gattClient;
    AppStorage.setOrCreate('gattClient', gattClient);
    if (gattClient) {
      this.setupGattClientCallbacks();
    }
  }

  // 设置GATT服务器回调
  private setupGattServerCallbacks(): void {
    if (!this.gattServer) return;
    
    this.gattServer.on('characteristicRead', (characteristicReadRequest) => {
      hilog.info(DOMAIN, 'GattServer', 'Characteristic read request received');
      // 发送本机心率给对方
      const heartRate = AppStorage.get<number>('heartRate') ?? 0;
      const heartRateData = new ArrayBuffer(4);
      const view = new DataView(heartRateData);
      view.setUint32(0, heartRate, true);
      
      const response: ble.ServerResponse = {
        deviceId: characteristicReadRequest.deviceId,
        transId: characteristicReadRequest.transId,
        status: 0,
        offset: characteristicReadRequest.offset,
        value: heartRateData
      };
      this.gattServer?.sendResponse(response);
    });

    this.gattServer.on('characteristicWrite', (characteristicWriteRequest) => {
      hilog.info(DOMAIN, 'GattServer', 'Characteristic write request received');
      // 接收对方心率
      if (characteristicWriteRequest.value && characteristicWriteRequest.value.byteLength >= 4) {
        const view = new DataView(characteristicWriteRequest.value);
        const peerHeartRate = view.getUint32(0, true);
        hilog.info(DOMAIN, 'GattServer', `Received peer heart rate: ${peerHeartRate}`);
        AppStorage.set('peerHeartRate', peerHeartRate);
      }
    });
  }

  // 设置GATT客户端回调
  private setupGattClientCallbacks(): void {
    if (!this.gattClient) return;

    this.gattClient.on('BLECharacteristicChange', (characteristicChangeInfo) => {
      hilog.info(DOMAIN, 'GattClient', 'Characteristic changed');
      // 接收对方心率通知
      if (characteristicChangeInfo.characteristicValue && characteristicChangeInfo.characteristicValue.byteLength >= 4) {
        const view = new DataView(characteristicChangeInfo.characteristicValue);
        const peerHeartRate = view.getUint32(0, true);
        hilog.info(DOMAIN, 'GattClient', `Received peer heart rate notification: ${peerHeartRate}`);
        AppStorage.set('peerHeartRate', peerHeartRate);
      }
    });

    // 连接成功后启用特征值通知
    try {
      const serviceUUID = '0000FD01-0000-1000-8000-00805F9B34FB';
      const characteristicUUID = '0000FD02-0000-1000-8000-00805F9B34FB';
      
      const characteristic: ble.BLECharacteristic = {
        serviceUuid: serviceUUID,
        characteristicUuid: characteristicUUID,
        characteristicValue: new ArrayBuffer(0),
        descriptors: [],
        properties: { notify: true }
      };
      this.gattClient.setCharacteristicChangeNotification(characteristic, true);
      hilog.info(DOMAIN, 'GattClient', 'Enabled characteristic notifications');
    } catch (err) {
      hilog.error(DOMAIN, 'GattClient', `Failed to enable notifications: ${(err as BusinessError).message}`);
    }
  }

  // 发送本机心率给对方
  public sendHeartRateToPeer(): void {
    const heartRate = AppStorage.get<number>('heartRate') ?? 0;
    if (heartRate <= 0) return;

    const heartRateData = new ArrayBuffer(4);
    const view = new DataView(heartRateData);
    view.setUint32(0, heartRate, true);

    const serviceUUID = '0000FD01-0000-1000-8000-00805F9B34FB';
    const characteristicUUID = '0000FD02-0000-1000-8000-00805F9B34FB';

    if (this.gattClient) {
      // 客户端写入心率数据
      try {
        const characteristic: ble.BLECharacteristic = {
          serviceUuid: serviceUUID,
          characteristicUuid: characteristicUUID,
          characteristicValue: heartRateData,
          descriptors: [],
          properties: { write: true }
        };
        this.gattClient.writeCharacteristicValue(characteristic, ble.GattWriteType.WRITE);
        hilog.info(DOMAIN, 'GattClient', `Sent heart rate to peer: ${heartRate}`);
      } catch (err) {
        hilog.error(DOMAIN, 'GattClient', `Failed to write characteristic: ${(err as BusinessError).message}`);
      }
    }

    if (this.gattServer) {
      // 服务器发送通知
      try {
        const deviceId = AppStorage.get<string>('peerDeviceId') ?? '';
        if (deviceId) {
          const notifyCharacteristic: ble.NotifyCharacteristic = {
            serviceUuid: serviceUUID,
            characteristicUuid: characteristicUUID,
            characteristicValue: heartRateData,
            confirm: false
          };
          this.gattServer.notifyCharacteristicChanged(deviceId, notifyCharacteristic);
          hilog.info(DOMAIN, 'GattServer', `Sent heart rate notification to peer: ${heartRate}`);
        }
      } catch (err) {
        hilog.error(DOMAIN, 'GattServer', `Failed to notify characteristic: ${(err as BusinessError).message}`);
      }
    }
  }

  // 启用双机模式
  public enableDualMode(peerDeviceId: string): void {
    AppStorage.set('isDualMode', true);
    AppStorage.set('peerDeviceId', peerDeviceId);
    hilog.info(DOMAIN, 'DualMode', `Enabled dual mode with peer: ${peerDeviceId}`);
  }

  // 禁用双机模式
  public disableDualMode(): void {
    AppStorage.set('isDualMode', false);
    AppStorage.set('peerDeviceId', '');
    AppStorage.set('peerHeartRate', 0);
    this.gattServer = null;
    this.gattClient = null;
    AppStorage.set('gattServer', null);
    AppStorage.set('gattClient', null);
    hilog.info(DOMAIN, 'DualMode', 'Disabled dual mode');
  }
}
