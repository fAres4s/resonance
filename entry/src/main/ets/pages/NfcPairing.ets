import { hilog } from '@kit.PerformanceAnalysisKit';
import router from '@ohos.router';
import { BusinessError } from '@kit.BasicServicesKit';
// 引入 abilityAccessCtrl 用于权限请求
import { access, ble, constant } from '@kit.ConnectivityKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { EntryAbility } from '../entryability/EntryAbility';
import util from '@ohos.util';

const DOMAIN = 0x0000;
const RESONATE_SERVICE_UUID = '0000FD01-0000-1000-8000-00805F9B34FB';
const HEART_RATE_CHARACTERISTIC_UUID = '0000FD02-0000-1000-8000-00805F9B34FB';
const RSSI_THRESHOLD = -65;
const MANUFACTURER_ID = 0x00A9;

enum DeviceRole {
  IDLE,
  SERVER_WAITING,
  CLIENT_INPUTTING_ID,
  CLIENT_SCANNING
}

@Entry
@Component
struct NfcPairing {
  @State message: string = '请选择一个操作';
  @State currentRole: DeviceRole = DeviceRole.IDLE;
  @State isBusy: boolean = false;
  @State connectionId: string = '';
  @State inputId: string = '';
  @StorageLink('ability') ability: EntryAbility | undefined = undefined;

  private gattServer: ble.GattServer | null = null;
  private gattClient: ble.GattClientDevice | null = null;
  private bleScanner: ble.BleScanner | null = null;

  private advertisingId: number = -1;
  private textEncoder = new util.TextEncoder();

  onBackPress(): boolean {
    hilog.info(DOMAIN, 'NfcPairing', 'Back press event triggered.');
    if (this.currentRole !== DeviceRole.IDLE) {
      void this.handleCancel();
      return true;
    }
    return false;
  }

  async onPageShow() {
    hilog.info(DOMAIN, 'NfcPairing', 'Page onPageShow.');
    if (!this.ability) {
      setTimeout((): void => {
        void this.onPageShow();
      }, 50);
      return;
    }
    await this.resetState();
  }

  async onPageHide() {
    hilog.info(DOMAIN, 'NfcPairing', 'Page onPageHide.');
    await this.stopBleOperations();
    await this.resetState();
    hilog.info(DOMAIN, 'NfcPairing', 'Cleaned up all BLE resources.');
  }

  private async resetState() {
    this.isBusy = false;
    this.currentRole = DeviceRole.IDLE;
    this.message = '请选择一个操作';
    this.connectionId = '';
    this.inputId = '';
  }

  // --- 服务端逻辑 ---
  async handleCreateConnection() {
    if (this.isBusy) return;
    this.isBusy = true;
    this.message = '正在准备服务...';

    // 关键：先检查服务和权限
    if (!await this.checkAndEnableServices()) {
      // 如果失败（例如用户拒绝权限），则重置状态
      await this.resetState();
      return;
    }

    this.connectionId = (Math.floor(Math.random() * 90000) + 10000).toString();
    this.message = `您的连接ID是: ${this.connectionId}`;

    const success = await this.startGattServerAndAdvertising();
    if (success) {
      this.currentRole = DeviceRole.SERVER_WAITING;
    } else {
      this.message = '启动服务失败，请重试';
      setTimeout(async () => {
        await this.resetState();
      }, 2000);
    }
  }

  async startGattServerAndAdvertising(): Promise<boolean> {
    try {
      this.gattServer = ble.createGattServer();
      this.gattServer.on('connectionStateChange', (state) => this.onConnectionStateChange(state, 'Server'));

      const heartRateCharacteristic: ble.BLECharacteristic = {
        serviceUuid: RESONATE_SERVICE_UUID, characteristicUuid: HEART_RATE_CHARACTERISTIC_UUID,
        characteristicValue: new ArrayBuffer(4), descriptors: [],
        properties: { read: true, write: true, notify: true }
      };
      const gattService: ble.GattService = {
        serviceUuid: RESONATE_SERVICE_UUID, isPrimary: true, characteristics: [heartRateCharacteristic]
      };
      this.gattServer.addService(gattService);

      const manufactureValue: Uint8Array = this.textEncoder.encode(this.connectionId);
      const manufactureData: ble.ManufactureData = {
        manufactureId: MANUFACTURER_ID,
        manufactureValue: manufactureValue.buffer
      };

      const advertisingSettings: ble.AdvertiseSetting = { connectable: true, interval: 160, txPower: -6 };
      const advertisingData: ble.AdvertiseData = {
        serviceUuids: [RESONATE_SERVICE_UUID],
        manufactureData: [manufactureData],
        includeDeviceName: false,
        serviceData: []
      };

      await new Promise<void>(resolve => setTimeout(resolve, 200));

      this.advertisingId = await ble.startAdvertising({ advertisingSettings, advertisingData });
      hilog.info(DOMAIN, 'NfcPairing', `Started advertising with ID: ${this.advertisingId} and ConnectionID: ${this.connectionId}`);
      this.message = `等待加入，连接ID: ${this.connectionId}`;
      return true;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, 'NfcPairing', `Server setup failed. Code: ${error.code}, Message: ${error.message}`);
      return false;
    }
  }

  // --- 客户端逻辑 ---
  async handleJoinConnection() {
    if (this.isBusy) return;
    this.isBusy = true;

    // 关键：先检查服务和权限
    if (!await this.checkAndEnableServices()) {
      await this.resetState();
      return;
    }

    this.currentRole = DeviceRole.CLIENT_INPUTTING_ID;
    this.message = '请输入对方的连接ID';
  }

  async handleConfirmJoin() {
    if (this.inputId.length !== 5) {
      this.message = '请输入一个5位数的ID';
      return;
    }
    this.currentRole = DeviceRole.CLIENT_SCANNING;
    this.message = `正在寻找ID为 ${this.inputId} 的连接...`;
    await this.startBleScan();
  }

  async startBleScan() {
    try {
      this.bleScanner = ble.createBleScanner();
      this.bleScanner.on('BLEDeviceFind', (report: ble.ScanReport) => this.onDeviceFound(report));
      const scanFilter: ble.ScanFilter = { serviceUuid: RESONATE_SERVICE_UUID };
      await this.bleScanner.startScan([scanFilter]);
      hilog.info(DOMAIN, 'NfcPairing', 'Started BLE scanning.');
    } catch (err) {
      hilog.error(DOMAIN, 'NfcPairing', `Failed to start scan: ${(err as BusinessError).message}`);
      this.message = '启动扫描失败，请重试';
      await this.resetState();
    }
  }

  private parseConnectionIdFromAdvData(data: ArrayBuffer): string | null {
    const view = new Uint8Array(data);
    let i = 0;
    while (i < view.length) {
      const length = view[i];
      if (length === 0 || i + length >= view.length) {
        break;
      }
      const type = view[i + 1];
      if (type === 0xFF) {
        if (length >= 3) {
          const manufacturerId = view[i + 2] + (view[i + 3] << 8);
          if (manufacturerId === MANUFACTURER_ID) {
            const connectionIdData = data.slice(i + 4, i + 1 + length);
            const textDecoder = new util.TextDecoder('utf-8');
            return textDecoder.decode(new Uint8Array(connectionIdData));
          }
        }
      }
      i += (length + 1);
    }
    return null;
  }

  private async onDeviceFound(report: ble.ScanReport) {
    if (this.currentRole !== DeviceRole.CLIENT_SCANNING) return;

    for (const result of report.scanResult) {
      const receivedId = this.parseConnectionIdFromAdvData(result.data);
      if (receivedId && receivedId === this.inputId) {
        this.message = `发现目标 (${result.rssi}dBm)，请靠近...`;
        if (result.rssi > RSSI_THRESHOLD) {
          await this.stopBleScan();
          this.message = '信号已锁定，正在连接...';
          await this.connectToPeer(result.deviceId);
          break;
        }
      }
    }
  }

  // --- 公共逻辑 ---
  async handleCancel() {
    this.message = "正在取消...";
    await this.stopBleOperations();
    await this.resetState();
  }

  // 修正：集成了权限请求的函数
  async checkAndEnableServices(): Promise<boolean> {
    // 1. 检查蓝牙是否开启
    try {
      if (access.getState() !== access.BluetoothState.STATE_ON) {
        this.message = '正在打开蓝牙...';
        access.enableBluetooth();
        await new Promise<void>(resolve => {
          const stateChangeCallback = (state: access.BluetoothState) => {
            if (state === access.BluetoothState.STATE_ON) {
              access.off('stateChange', stateChangeCallback);
              setTimeout(() => resolve(), 200);
            }
          };
          access.on('stateChange', stateChangeCallback);
        });
      }
    } catch (err) {
      hilog.error(DOMAIN, 'NfcPairing', `Bluetooth state check failed: ${(err as BusinessError).message}`);
      this.message = '蓝牙服务检查失败';
      return false;
    }

    // 2. 检查并请求蓝牙权限
    if (!this.ability) return false;
    let atManager = abilityAccessCtrl.createAtManager();
    try {
      // 直接请求权限，如果已授权则直接返回成功
      const result = await atManager.requestPermissionsFromUser(this.ability.context, ['ohos.permission.ACCESS_BLUETOOTH']);
      if (result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        hilog.info(DOMAIN, 'Permission', 'Bluetooth permission granted successfully.');
        return true;
      } else {
        hilog.warn(DOMAIN, 'Permission', 'Bluetooth permission was denied.');
        this.message = '您拒绝了蓝牙权限';
        return false;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'Permission', `Failed to request permission: ${(err as BusinessError).message}`);
      this.message = '权限请求失败';
      return false;
    }
  }

  async stopBleOperations() {
    await this.stopBleScan();
    await this.stopAdvertising();
  }

  async stopBleScan() {
    if (this.bleScanner) {
      try {
        this.bleScanner.off('BLEDeviceFind');
        await this.bleScanner.stopScan();
      } catch (e) { /* ... */ }
      this.bleScanner = null;
    }
  }

  async stopAdvertising() {
    if (this.advertisingId !== -1) {
      try {
        await ble.stopAdvertising(this.advertisingId);
      } catch (err) { /* ... */ }
      this.advertisingId = -1;
    }
  }

  async connectToPeer(deviceId: string) {
    try {
      this.gattClient = ble.createGattClientDevice(deviceId);
      this.gattClient.on('BLEConnectionStateChange', (state) => this.onConnectionStateChange(state, 'Client'));
      this.gattClient.connect();
    } catch (err) {
      hilog.error(DOMAIN, 'NfcPairing', `Failed to connect to peer: ${(err as BusinessError).message}`);
      this.message = '连接失败';
      await this.resetState();
    }
  }

  onConnectionStateChange(state: ble.BLEConnectionChangeState, role: 'Server' | 'Client') {
    hilog.info(DOMAIN, 'NfcPairing', `${role} Connection State Changed: ${JSON.stringify(state)}`);
    if (state.state === constant.ProfileConnectionState.STATE_CONNECTED) {
      this.message = '已连接！';
      // 设置EntryAbility的GATT对象和双机模式
      if (this.ability) {
        if (role === 'Server' && this.gattServer) {
          this.ability.setGattServer(this.gattServer);
        } else if (role === 'Client' && this.gattClient) {
          this.ability.setGattClient(this.gattClient);
        }
        this.ability.enableDualMode(state.deviceId);
      }
      this.navigateToDualModePage(state.deviceId);
    } else if (state.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
      this.message = '连接已断开';
      // 禁用双机模式
      if (this.ability) {
        this.ability.disableDualMode();
      }
      void this.resetState();
    }
  }

  navigateToDualModePage(peerDeviceId: string) {
    router.replaceUrl({
      url: 'pages/Index',
      params: { mode: 'dual', peerDevice: peerDeviceId }
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'Router', `Failed to navigate. Code: ${err.code}, message: ${err.message}`);
    });
  }

  build() {
    Column({ space: 15 }) {
      if (this.currentRole === DeviceRole.IDLE) {
        Button('创建连接')
          .type(ButtonType.Capsule)
          .fontSize(18).width('80%').height(50)
          .enabled(!this.isBusy)
          .onClick(() => this.handleCreateConnection())

        Button('加入连接')
          .type(ButtonType.Capsule)
          .fontSize(18).width('80%').height(50)
          .margin({ top: 15 })
          .enabled(!this.isBusy)
          .onClick(() => this.handleJoinConnection())
      } else if (this.currentRole === DeviceRole.CLIENT_INPUTTING_ID) {
        Text(this.message).fontSize(16).textAlign(TextAlign.Center).margin({ bottom: 20 })
        TextInput({ placeholder: '输入5位ID' })
          .type(InputType.Number)
          .maxLength(5)
          .fontSize(22)
          .width('60%')
          .height(45)
          .margin({ bottom: 20 })
          .onChange((value: string) => {
            this.inputId = value;
          })
        Button('确认加入')
          .type(ButtonType.Capsule)
          .fontSize(16).width('75%').height(45)
          .onClick(() => this.handleConfirmJoin())
        Button('返回')
          .type(ButtonType.Capsule)
          .fontSize(14).width('65%').height(40)
          .backgroundColor(Color.Gray)
          .margin({ top: 10 })
          .onClick(() => this.resetState())
      } else {
        Column() {
          LoadingProgress().width(50).height(50)
          Text(this.message)
            .fontSize(18)
            .textAlign(TextAlign.Center)
            .margin({ top: 15 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Button('取消')
          .type(ButtonType.Capsule)
          .fontSize(16).width('70%').height(45)
          .backgroundColor(Color.Gray)
          .onClick(() => this.handleCancel())
          .margin({ bottom: 15 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Black)
    .padding({ left: 20, right: 20, top: 30, bottom: 20 })
  }
}
