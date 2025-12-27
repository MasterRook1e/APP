// entry/src/main/ets/common/BleGattReceiver.ets

/*
 * 蓝牙通信模块
 *
 * HarmonyOS ArkTS 对 BLE 接口的调用与 TypeScript 类似，但不支持结构化类型推断。为了避免
 * ArkTS 编译器报错，以下代码统一采用 class 定义数据模型，并在方法中显式捕获异常。此模块
 * 支持两种角色：
 *
 * 1. Central（客户端模式）：可以扫描周围蓝牙设备并发起连接。当前版本仅提供扫描和连接/断开，
 *    未实现主动写入特征的接口；如需主动发送数据，请在后续扩展 write 特征逻辑。
 * 2. Peripheral（外设模式）：创建自定义服务（UUID: 0000FFF0-0000-1000-8000-00805F9B34FB），
 *    提供一个可写特征 (FFF1) 供对端写入文本消息，以及一个可通知特征 (FFF2) 用于向订阅者
 *    推送文本消息。该模式通过 EasyBLE 或 iOS 系统蓝牙调试工具连接并订阅 Notify 特征即可实现
 *    收发聊天消息。
 *
 * 使用方式：
 *   - 引入本模块：`import { BleGattReceiver, BleDeviceInfo } from '../common/BleGattReceiver'`；
 *   - 扫描设备：调用 `BleGattReceiver.startScan(timeoutMs)` 并通过 `getScannedDevices()` 获取结果；
 *   - 连接设备：调用 `BleGattReceiver.connect(deviceId, name)`；
 *   - 启动外设模式：`BleGattReceiver.startPeripheral()`；停止：`BleGattReceiver.stopPeripheral()`；
 *   - 发送文本：`BleGattReceiver.sendText(content)`（仅在外设模式且对端订阅 Notify 时生效）。
 */

// HarmonyOS 蓝牙 BLE 模块应从 '@ohos.bluetooth.ble' 导入，使用冒号会导致找不到声明。
import ble from '@ohos.bluetooth.ble';
import { BusinessError } from '@ohos.base';
import { onIncomingText } from './IncomingBridge';

// 自定义服务和特征 UUID
export const BLE_SERVICE_UUID: string = '0000fff0-0000-1000-8000-00805f9b34fb';
export const BLE_WRITE_CHAR_UUID: string = '0000fff1-0000-1000-8000-00805f9b34fb';
export const BLE_NOTIFY_CHAR_UUID: string = '0000fff2-0000-1000-8000-00805f9b34fb';
// 保留兼容旧名称
export const BLE_CHAR_UUID: string = BLE_WRITE_CHAR_UUID;
// iOS 订阅 Notify 常用的描述符 UUID
const CCCD_UUID: string = '00002902-0000-1000-8000-00805f9b34fb';

/**
 * 扫描到的设备信息。名称有可能为空，调用方应根据实际情况显示。
 */
export class BleDeviceInfo {
  deviceId: string;
  name: string;

  constructor(deviceId: string, name: string) {
    this.deviceId = deviceId;
    this.name = name;
  }
}

// ======== 内部模型定义：避免 ArkTS 结构化类型校验 ========
class ScanResultModel {
  deviceId: string = '';
  deviceName: string = '';
  name: string = '';
}

class ConnStateModel {
  deviceId: string = '';
  state: number = 0;
  connected: boolean = false;
  deviceName: string = '';
  name: string = '';
}

class CharWriteReqModel {
  deviceId: string = '';
  transId: number = 0;
  offset: number = 0;
  needRsp: boolean = false;
  serviceUuid: string = '';
  characteristicUuid: string = '';
  value: ArrayBuffer = new ArrayBuffer(0);
}

class DescWriteReqModel {
  deviceId: string = '';
  transId: number = 0;
  offset: number = 0;
  needRsp: boolean = false;
  isPrep: boolean = false;
  serviceUuid: string = '';
  characteristicUuid: string = '';
  descriptorUuid: string = '';
  value: ArrayBuffer = new ArrayBuffer(0);
}

class DescReadReqModel {
  deviceId: string = '';
  transId: number = 0;
  offset: number = 0;
  serviceUuid: string = '';
  characteristicUuid: string = '';
  descriptorUuid: string = '';
}

// ======== 扫描过滤器模型 ========
/**
 * HarmonyOS BLE 扫描过滤器模型。为了满足 ArkTS 类型检查要求，
 * 使用类来定义过滤器字段，而不是在数组中直接使用对象字面量。
 */
class BleScanFilterModel {
  serviceUuid: string = '';
  constructor(serviceUuid: string) {
    this.serviceUuid = serviceUuid;
  }
}

// ======== UTF‑8 编解码，支持 emoji ========
function utf8Encode(s: string): Uint8Array {
  const bytes: number[] = [];
  for (let i = 0; i < s.length; i++) {
    let code: number = s.charCodeAt(i);
    if (code < 0x80) {
      bytes.push(code);
      continue;
    }
    if (code < 0x800) {
      bytes.push(0xC0 | (code >> 6));
      bytes.push(0x80 | (code & 0x3F));
      continue;
    }
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < s.length) {
      const next: number = s.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        const cp: number = 0x10000 + (((code - 0xD800) << 10) | (next - 0xDC00));
        bytes.push(0xF0 | (cp >> 18));
        bytes.push(0x80 | ((cp >> 12) & 0x3F));
        bytes.push(0x80 | ((cp >> 6) & 0x3F));
        bytes.push(0x80 | (cp & 0x3F));
        i++;
        continue;
      }
    }
    bytes.push(0xE0 | (code >> 12));
    bytes.push(0x80 | ((code >> 6) & 0x3F));
    bytes.push(0x80 | (code & 0x3F));
  }
  return new Uint8Array(bytes);
}

function utf8Decode(buf: ArrayBuffer): string {
  const data: Uint8Array = new Uint8Array(buf);
  let out: string = '';
  let i: number = 0;
  while (i < data.length) {
    const b0: number = data[i];
    if (b0 < 0x80) {
      out += String.fromCharCode(b0);
      i++;
      continue;
    }
    if ((b0 & 0xE0) === 0xC0 && i + 1 < data.length) {
      const b1: number = data[i + 1];
      const cp: number = ((b0 & 0x1F) << 6) | (b1 & 0x3F);
      out += String.fromCharCode(cp);
      i += 2;
      continue;
    }
    if ((b0 & 0xF0) === 0xE0 && i + 2 < data.length) {
      const b1: number = data[i + 1];
      const b2: number = data[i + 2];
      const cp: number = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F);
      out += String.fromCharCode(cp);
      i += 3;
      continue;
    }
    if ((b0 & 0xF8) === 0xF0 && i + 3 < data.length) {
      const b1: number = data[i + 1];
      const b2: number = data[i + 2];
      const b3: number = data[i + 3];
      const cp4: number = ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F);
      const u: number = cp4 - 0x10000;
      const hi: number = 0xD800 + (u >> 10);
      const lo: number = 0xDC00 + (u & 0x3FF);
      out += String.fromCharCode(hi, lo);
      i += 4;
      continue;
    }
    // 跳过未知字节，避免死循环
    i++;
  }
  return out;
}

/**
 * 统一化 UUID 字符串，去掉空白并转换为小写
 */
function normUuid(u: string): string {
  return u.trim().toLowerCase();
}

// ======== BLE 数据模型，用于构造服务和特征 ========
class BleDescriptorModel implements ble.BLEDescriptor {
  serviceUuid: string;
  characteristicUuid: string;
  descriptorUuid: string;
  descriptorValue: ArrayBuffer;

  constructor(serviceUuid: string, characteristicUuid: string, descriptorUuid: string, descriptorValue: ArrayBuffer) {
    this.serviceUuid = serviceUuid;
    this.characteristicUuid = characteristicUuid;
    this.descriptorUuid = descriptorUuid;
    this.descriptorValue = descriptorValue;
  }
}

class BleCharacteristicModel implements ble.BLECharacteristic {
  serviceUuid: string;
  characteristicUuid: string;
  characteristicValue: ArrayBuffer;
  descriptors: Array<ble.BLEDescriptor>;

  constructor(serviceUuid: string, characteristicUuid: string, value: ArrayBuffer, descriptors: Array<ble.BLEDescriptor>) {
    this.serviceUuid = serviceUuid;
    this.characteristicUuid = characteristicUuid;
    this.characteristicValue = value;
    this.descriptors = descriptors;
  }
}

class GattServiceModel implements ble.GattService {
  serviceUuid: string;
  isPrimary: boolean;
  characteristics: Array<ble.BLECharacteristic>;
  includeServices: Array<ble.GattService>;

  constructor(serviceUuid: string, isPrimary: boolean, characteristics: Array<ble.BLECharacteristic>) {
    this.serviceUuid = serviceUuid;
    this.isPrimary = isPrimary;
    this.characteristics = characteristics;
    this.includeServices = [];
  }
}

class AdvertiseSettingModel implements ble.AdvertiseSetting {
  interval: number;
  txPower: number;
  connectable: boolean;

  constructor(interval: number, txPower: number, connectable: boolean) {
    this.interval = interval;
    this.txPower = txPower;
    this.connectable = connectable;
  }
}

class AdvertiseDataModel implements ble.AdvertiseData {
  serviceUuids: Array<string>;
  manufactureData: Array<ble.ManufactureData>;
  serviceData: Array<ble.ServiceData>;
  includeDeviceName?: boolean;
  // 注意：不要声明 includeTxPowerLevel 字段，该字段在某些系统版本上会导致 napi 校验失败

  constructor(serviceUuids: Array<string>) {
    this.serviceUuids = serviceUuids;
    this.manufactureData = [];
    this.serviceData = [];
  }
}

class ServerResponseModel implements ble.ServerResponse {
  deviceId: string;
  transId: number;
  status: number;
  offset: number;
  value: ArrayBuffer;

  constructor(deviceId: string, transId: number, status: number, offset: number, value: ArrayBuffer) {
    this.deviceId = deviceId;
    this.transId = transId;
    this.status = status;
    this.offset = offset;
    this.value = value;
  }
}

class NotifyCharacteristicModel implements ble.NotifyCharacteristic {
  serviceUuid: string;
  characteristicUuid: string;
  characteristicValue: ArrayBuffer;
  confirm: boolean;

  constructor(serviceUuid: string, characteristicUuid: string, value: ArrayBuffer, confirm: boolean) {
    this.serviceUuid = serviceUuid;
    this.characteristicUuid = characteristicUuid;
    this.characteristicValue = value;
    this.confirm = confirm;
  }
}

/**
 * 连接状态监听器类型。
 * connected: 是否已连接；name/deviceId: 当前连接的设备名称和地址。
 */
export type BleConnListener = (connected: boolean, name: string, deviceId: string) => void;

// ======== 主实现类 ========
class BleGattReceiverImpl {
  // --- Central（客户端模式）状态 ---
  private connected: boolean = false;
  private connectedName: string = '';
  private connectedId: string = '';
  private scanning: boolean = false;
  private scanTimer: number = -1;
  private devices: Array<BleDeviceInfo> = [];
  private listeners: Array<BleConnListener> = [];
  private client: ble.GattClientDevice | null = null;

  // --- Peripheral（外设模式）状态 ---
  private periphOn: boolean = false;
  private periphConnected: boolean = false;
  private periphNotifyEnabled: boolean = false;
  private periphCccdValue: ArrayBuffer = new ArrayBuffer(2);
  private periphDeviceId: string = '';
  private periphPeerName: string = '';
  private gattServer: ble.GattServer | null = null;
  private advertising: boolean = false;

  /**
   * 添加连接状态监听器。监听器将会在连接状态变化时被调用。
   */
  public addListener(listener: BleConnListener): void {
    this.listeners.push(listener);
  }

  /**
   * 移除连接状态监听器。
   */
  public removeListener(listener: BleConnListener): void {
    const next: Array<BleConnListener> = [];
    for (let i = 0; i < this.listeners.length; i++) {
      if (this.listeners[i] !== listener) {
        next.push(this.listeners[i]);
      }
    }
    this.listeners = next;
  }

  /**
   * 内部调用：通知所有监听器连接状态。
   */
  private notify(): void {
    const name: string = this.getConnectedName();
    const id: string = this.getConnectedId();
    const ok: boolean = this.isConnected();
    for (let i = 0; i < this.listeners.length; i++) {
      try {
        this.listeners[i](ok, name, id);
      } catch {
        // 忽略监听器内部异常
      }
    }
  }

  /**
   * 当前是否与某设备连接（Central 或 Peripheral）。
   */
  public isConnected(): boolean {
    return this.periphConnected || this.connected;
  }

  /**
   * 返回当前连接设备名称，如果没有则返回空字符串。
   */
  public getConnectedName(): string {
    if (this.periphConnected) {
      return this.periphPeerName.length > 0 ? this.periphPeerName : this.periphDeviceId;
    }
    return this.connectedName;
  }

  /**
   * 返回当前连接设备 ID，如果没有则返回空字符串。
   */
  public getConnectedId(): string {
    if (this.periphConnected) {
      return this.periphDeviceId;
    }
    return this.connectedId;
  }

  /**
   * 返回显示在 UI 上的设备标签。这里与 getConnectedName 相同，可以根据需要调整。
   */
  public getPeerLabel(): string {
    return this.getConnectedName();
  }

  // ======== Central 扫描功能 ========

  /**
   * 获取最近扫描到的设备列表。该列表会在调用 startScan() 后更新。
   */
  public getScannedDevices(): Array<BleDeviceInfo> {
    return this.devices;
  }

  /**
   * 清除扫描计时器。
   */
  private clearScanTimer(): void {
    if (this.scanTimer !== -1) {
      try {
        clearTimeout(this.scanTimer);
      } catch {
        // ignore
      }
      this.scanTimer = -1;
    }
  }

  /**
   * 扫描结果回调：更新设备列表并去重。
   */
  private onDeviceFind = (devices: Array<object>): void => {
    for (let i = 0; i < devices.length; i++) {
      const item: ScanResultModel = devices[i] as ScanResultModel;
      const id: string = item.deviceId;
      if (id.length <= 0) {
        continue;
      }
      let name: string = item.deviceName;
      if (name.length <= 0) {
        name = item.name;
      }
      if (name.length <= 0) {
        name = id;
      }
      // 去重：如果已存在则跳过
      let existed: boolean = false;
      for (let j = 0; j < this.devices.length; j++) {
        if (this.devices[j].deviceId === id) {
          existed = true;
          break;
        }
      }
      if (!existed) {
        this.devices.push(new BleDeviceInfo(id, name));
      }
    }
  };

  /**
   * 开始扫描周围蓝牙设备。timeoutMs 为扫描超时时间，单位毫秒。超时后自动停止扫描。
   */
  public startScan(timeoutMs: number): void {
    if (this.periphOn) {
      // 外设模式下不执行扫描
      return;
    }
    if (this.scanning) {
      return;
    }
    this.scanning = true;
    this.devices = [];
    this.clearScanTimer();
    try {
      // 注册扫描回调
      ble.on('BLEDeviceFind', this.onDeviceFind);
    } catch {
      // ignore
    }
    try {
      // 构造过滤器数组：使用类实例而非对象字面量，以便 ArkTS 能正确推断类型。
      const filters: Array<BleScanFilterModel> = [
        new BleScanFilterModel(BLE_SERVICE_UUID),
      ];
      ble.startBLEScan(filters);
    } catch {
      // ignore
    }
    if (timeoutMs > 0) {
      this.scanTimer = setTimeout(() => {
        this.stopScan();
      }, timeoutMs) as number;
    }
  }

  /**
   * 停止扫描。
   */
  public stopScan(): void {
    if (!this.scanning) {
      return;
    }
    this.scanning = false;
    this.clearScanTimer();
    try {
      ble.stopBLEScan();
    } catch {
      // ignore
    }
  }

  /**
   * 引用未使用的方法，避免 ArkTS 编译器提示某些成员“声明但从未读取”。
   * 这个方法不会在运行时被调用。
   */
  private _suppressUnusedWarnings(): void {
    // 将成员方法和字段引用一次，避免编译器报“未使用”告警。
    void this.startScan;
    void this.stopScan;
    void this.connected;
  }

  // ======== Central 连接功能 ========

  /**
   * 与指定设备建立连接。deviceId 为扫描或系统蓝牙列表中的设备 ID，name 为显示名称。
   */
  public connect(deviceId: string, name: string): void {
    if (this.periphOn) {
      // 外设模式下不能作为 Central 连接其他设备
      return;
    }
    if (deviceId.length <= 0) {
      return;
    }
    // 断开现有连接
    this.disconnect();
    this.connectedId = deviceId;
    this.connectedName = name;
    try {
      this.client = ble.createGattClientDevice(deviceId);
    } catch {
      this.client = null;
      this.connected = false;
      this.connectedId = '';
      this.connectedName = '';
      this.notify();
      return;
    }
    try {
      this.client.on('BLEConnectionStateChange', this.onConnStateChange);
    } catch {
      // ignore
    }
    try {
      // 发起连接
      this.client.connect();
    } catch {
      // ignore
    }
  }

  /**
   * 连接状态变化回调。
   */
  private onConnStateChange = (state: object): void => {
    const s: ConnStateModel = state as ConnStateModel;
    let nextConnected: boolean = this.connected;
    if (s.connected === true) {
      nextConnected = true;
    } else if (s.connected === false) {
      nextConnected = false;
    } else {
      // 部分机型只返回 state: 2 表示已连接，state: 0 表示未连接
      if (s.state === 2) {
        nextConnected = true;
      } else if (s.state === 0) {
        nextConnected = false;
      }
    }
    if (nextConnected !== this.connected) {
      this.connected = nextConnected;
      if (!this.connected) {
        this.connectedId = '';
        this.connectedName = '';
      }
      this.notify();
    }
  };

  /**
   * 断开当前连接。
   */
  public disconnect(): void {
    if (this.client !== null) {
      try {
        this.client.disconnect();
      } catch {
        // ignore
      }
      this.client = null;
    }
    if (this.connected) {
      this.connected = false;
      this.connectedId = '';
      this.connectedName = '';
      this.notify();
    }
  }

  // ======== Peripheral 外设模式 ========

  /**
   * 外设模式是否已开启。
   */
  public isPeripheralOn(): boolean {
    return this.periphOn;
  }

  /**
   * 开启外设模式：创建 GATT 服务、启动广播。成功返回 true。若已开启直接返回 true。
   */
  public startPeripheral(): boolean {
    if (this.periphOn) {
      return true;
    }
    // 外设模式启动前停止扫描和客户端连接
    this.stopScan();
    this.disconnect();
    // 创建 GATT 服务器
    let server: ble.GattServer;
    try {
      server = ble.createGattServer();
      // 日志：创建 GattServer 成功
      console.info('[BleGattReceiver] createGattServer OK');
    } catch (e) {
      console.error('[BleGattReceiver] createGattServer failed: ' + String(e));
      return false;
    }
    this.gattServer = server;
    // 注册服务器回调
    try {
      server.on('connectionStateChange', this.onServerConnChange);
      console.info('[BleGattReceiver] registered connectionStateChange');
    } catch (e) {
      console.error('[BleGattReceiver] register connectionStateChange failed: ' + String(e));
    }
    try {
      server.on('characteristicWrite', this.onServerCharWrite);
      console.info('[BleGattReceiver] registered characteristicWrite');
    } catch (e) {
      console.error('[BleGattReceiver] register characteristicWrite failed: ' + String(e));
    }
    try {
      server.on('descriptorRead', this.onServerDescRead);
      console.info('[BleGattReceiver] registered descriptorRead');
    } catch (e) {
      console.error('[BleGattReceiver] register descriptorRead failed: ' + String(e));
    }
    try {
      server.on('descriptorWrite', this.onServerDescWrite);
      console.info('[BleGattReceiver] registered descriptorWrite');
    } catch (e) {
      console.error('[BleGattReceiver] register descriptorWrite failed: ' + String(e));
    }
    // 添加自定义聊天服务；若失败则关闭服务器
    try {
      this.addChatService(server);
      console.info('[BleGattReceiver] addChatService OK');
    } catch (e) {
      console.error('[BleGattReceiver] addChatService failed: ' + String(e));
      try { server.close(); } catch {}
      this.gattServer = null;
      return false;
    }
    // 尝试启动广播；若失败则关闭服务并返回 false
    const advOk: boolean = this.startAdvertising();
    console.info('[BleGattReceiver] startAdvertising return ' + String(advOk));
    if (!advOk) {
      try { server.close(); } catch {}
      this.gattServer = null;
      return false;
    }
    this.periphOn = true;
    this.notify();
    return true;
  }

  /**
   * 关闭外设模式：停止广播、关闭 GATT 服务器并重置状态。
   */
  public stopPeripheral(): void {
    if (!this.periphOn) {
      return;
    }
    this.stopAdvertising();
    if (this.gattServer !== null) {
      try {
        this.gattServer.off('connectionStateChange');
      } catch {
        // ignore
      }
      try {
        this.gattServer.off('characteristicWrite');
      } catch {
        // ignore
      }
      try {
        this.gattServer.off('descriptorRead');
      } catch {
        // ignore
      }
      try {
        this.gattServer.off('descriptorWrite');
      } catch {
        // ignore
      }
      try {
        this.gattServer.close();
      } catch {
        // ignore
      }
    }
    this.gattServer = null;
    this.periphConnected = false;
    this.periphNotifyEnabled = false;
    this.periphCccdValue = new ArrayBuffer(2);
    this.periphDeviceId = '';
    this.periphPeerName = '';
    this.periphOn = false;
    this.notify();
  }

  /**
   * 服务器连接状态变化回调。
   */
  private onServerConnChange = (stateObj: object): void => {
    const s: ConnStateModel = stateObj as ConnStateModel;
    let nextConnected: boolean = this.periphConnected;
    if (s.connected === true) {
      nextConnected = true;
    } else if (s.connected === false) {
      nextConnected = false;
    } else {
      // HarmonyOS 的 GATT 连接状态回调中，state 值含义可能因系统版本而异。
      // 在 Nova14 上观察到 state=1 和 state=3 会频繁交替出现，导致连接状态闪烁。
      // 这里将除了 0 以外的任意 state 都视为连接状态，只在 state=0 时断开连接。
      if (s.state === 0) {
        nextConnected = false;
      } else {
        nextConnected = true;
      }
    }
    if (nextConnected !== this.periphConnected) {
      this.periphConnected = nextConnected;
      if (this.periphConnected) {
        this.periphDeviceId = s.deviceId;
        // 某些系统版本下，deviceName 或 name 可能为 undefined。使用空字符串兜底，避免 TypeError
        const devName: string = (s.deviceName && typeof s.deviceName === 'string') ? s.deviceName : '';
        const altName: string = (s.name && typeof s.name === 'string') ? s.name : '';
        if (devName.length > 0) {
          this.periphPeerName = devName;
        } else if (altName.length > 0) {
          this.periphPeerName = altName;
        } else {
          this.periphPeerName = s.deviceId;
        }
      } else {
        this.periphDeviceId = '';
        this.periphPeerName = '';
        this.periphNotifyEnabled = false;
      }
      this.notify();
    }
  };

  /**
   * 接收写入特征的回调：收到对端发来的数据，将文本解码并转交给聊天逻辑。
   */
  private onServerCharWrite = (reqObj: object): void => {
    const req: CharWriteReqModel = reqObj as CharWriteReqModel;
    if (normUuid(req.serviceUuid) !== normUuid(BLE_SERVICE_UUID)) {
      return;
    }
    if (normUuid(req.characteristicUuid) !== normUuid(BLE_WRITE_CHAR_UUID)) {
      return;
    }
    const text: string = utf8Decode(req.value);
    if (text.trim().length > 0) {
      // 转发到聊天逻辑
      try {
        onIncomingText(text);
      } catch {
        // ignore
      }
    }
    // 如果需要响应，回复空值
    if (req.needRsp && this.gattServer !== null) {
      const resp: ServerResponseModel = new ServerResponseModel(req.deviceId, req.transId, 0, req.offset, new ArrayBuffer(0));
      try {
        this.gattServer.sendResponse(resp);
      } catch {
        // ignore
      }
    }
  };

  /**
   * 描述符读取回调：当对端读取 CCCD 时返回当前值。
   */
  private onServerDescRead = (reqObj: object): void => {
    const req: DescReadReqModel = reqObj as DescReadReqModel;
    if (normUuid(req.serviceUuid) !== normUuid(BLE_SERVICE_UUID)) {
      return;
    }
    if (normUuid(req.characteristicUuid) !== normUuid(BLE_NOTIFY_CHAR_UUID)) {
      return;
    }
    if (normUuid(req.descriptorUuid) !== normUuid(CCCD_UUID)) {
      return;
    }
    if (this.gattServer === null) {
      return;
    }
    const resp: ServerResponseModel = new ServerResponseModel(req.deviceId, req.transId, 0, req.offset, this.periphCccdValue);
    try {
      this.gattServer.sendResponse(resp);
    } catch {
      // ignore
    }
  };

  /**
   * 描述符写入回调：用于处理对端订阅/取消订阅 Notify 特征。
   */
  private onServerDescWrite = (reqObj: object): void => {
    const req: DescWriteReqModel = reqObj as DescWriteReqModel;
    if (normUuid(req.serviceUuid) !== normUuid(BLE_SERVICE_UUID)) {
      return;
    }
    if (normUuid(req.characteristicUuid) !== normUuid(BLE_NOTIFY_CHAR_UUID)) {
      return;
    }
    if (normUuid(req.descriptorUuid) !== normUuid(CCCD_UUID)) {
      return;
    }
    // 订阅值一般为 0x0001；取消订阅为 0x0000
    this.periphCccdValue = req.value;
    this.periphNotifyEnabled = false;
    const val: Uint8Array = new Uint8Array(req.value);
    if (val.length >= 2) {
      const enabled: number = val[0] | (val[1] << 8);
      this.periphNotifyEnabled = (enabled !== 0);
    }
    // 响应
    if (this.gattServer !== null) {
      const resp: ServerResponseModel = new ServerResponseModel(req.deviceId, req.transId, 0, req.offset, new ArrayBuffer(0));
      try {
        this.gattServer.sendResponse(resp);
      } catch {
        // ignore
      }
    }
  };

  /**
   * 将文本消息发送给已连接并订阅 Notify 的对端。仅在外设模式有效。
   * 返回 true 表示已尝试发送，false 表示当前无法发送（如未连接或未订阅）。
   */
  public sendText(text: string): boolean {
    const t: string = text.trim();
    if (t.length <= 0) {
      return true;
    }
    // 如果当前处于外设模式，向订阅者发送通知
    if (this.periphOn) {
      // 必须处于连接且订阅通知
      if (!this.periphConnected || !this.periphNotifyEnabled || this.gattServer === null || this.periphDeviceId.length <= 0) {
        return false;
      }
      this.sendTextAsPeripheral(t);
      return true;
    }
    // 如果当前作为中央已连接，则主动写入远端特征
    if (this.connected && this.client !== null) {
      return this.sendTextAsClient(t);
    }
    return false;
  }

  /**
   * 内部方法：作为外设时将文本拆包发送到 Notify 特征。
   */
  private sendTextAsPeripheral(t: string): void {
    // UTF-8 编码
    const bytes: Uint8Array = utf8Encode(t);
    const max: number = 180;
    const chunks: Array<ArrayBuffer> = [];
    let off: number = 0;
    while (off < bytes.length) {
      const end: number = (off + max <= bytes.length) ? (off + max) : bytes.length;
      const len: number = end - off;
      const ab: ArrayBuffer = new ArrayBuffer(len);
      const view: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < len; i++) {
        view[i] = bytes[off + i];
      }
      chunks.push(ab);
      off = end;
    }
    this.notifyChunks(chunks, 0);
  }

  /**
   * 内部方法：作为中央角色向远端设备写入文本。
   * 返回 true 表示已排队写入，false 表示当前无法发送。
   */
  private sendTextAsClient(t: string): boolean {
    if (this.client === null) {
      return false;
    }
    const bytes: Uint8Array = utf8Encode(t);
    // 最大单次写入长度按照 180 字节拆分
    const max: number = 180;
    const chunks: Array<ArrayBuffer> = [];
    let off: number = 0;
    while (off < bytes.length) {
      const end: number = (off + max <= bytes.length) ? (off + max) : bytes.length;
      const len: number = end - off;
      const ab: ArrayBuffer = new ArrayBuffer(len);
      const view: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < len; i++) {
        view[i] = bytes[off + i];
      }
      chunks.push(ab);
      off = end;
    }
    this.writeChunks(chunks, 0);
    return true;
  }

  /**
   * 递归地写入分片数据到远端设备的写特征。
   */
  private writeChunks(chunks: Array<ArrayBuffer>, idx: number): void {
    if (this.client === null) {
      return;
    }
    if (idx >= chunks.length) {
      return;
    }
    const buffer: ArrayBuffer = chunks[idx];
    const characteristic: ble.BLECharacteristic = {
      serviceUuid: BLE_SERVICE_UUID,
      characteristicUuid: BLE_WRITE_CHAR_UUID,
      characteristicValue: buffer,
      descriptors: []
    } as ble.BLECharacteristic;
    try {
      // 尝试写入，采用带响应的写入方式确保可靠
      this.client.writeCharacteristicValue(
        characteristic,
        ble.GattWriteType.WRITE,
        (error: BusinessError) => {
          // 将 error 标记为已使用，避免编译器警告变量未使用
          void error;
          // 忽略错误，只尝试发送下一片
          if (idx + 1 < chunks.length) {
            setTimeout(() => {
              this.writeChunks(chunks, idx + 1);
            }, 30);
          }
        }
      );
    } catch {
      // ignore
    }
  }

  /**
   * 递归发送分片通知。发送完一片再等待短暂时间发送下一片。
   */
  private notifyChunks(chunks: Array<ArrayBuffer>, idx: number): void {
    if (this.gattServer === null) {
      return;
    }
    if (!this.periphConnected || this.periphDeviceId.length <= 0) {
      return;
    }
    if (idx >= chunks.length) {
      return;
    }
    const notifyChar: NotifyCharacteristicModel = new NotifyCharacteristicModel(BLE_SERVICE_UUID, BLE_NOTIFY_CHAR_UUID, chunks[idx], false);
    try {
      this.gattServer.notifyCharacteristicChanged(this.periphDeviceId, notifyChar);
    } catch {
      // ignore
    }
    if (idx + 1 < chunks.length) {
      // 递归发送下一片，间隔 30ms
      setTimeout(() => {
        this.notifyChunks(chunks, idx + 1);
      }, 30);
    }
  }

  /**
   * 构建聊天服务并添加到 GATT 服务器中。
   */
  private addChatService(server: ble.GattServer): void {
    const cccd: BleDescriptorModel = new BleDescriptorModel(BLE_SERVICE_UUID, BLE_NOTIFY_CHAR_UUID, CCCD_UUID, new ArrayBuffer(2));
    const writeCh: BleCharacteristicModel = new BleCharacteristicModel(BLE_SERVICE_UUID, BLE_WRITE_CHAR_UUID, new ArrayBuffer(0), []);
    const notifyCh: BleCharacteristicModel = new BleCharacteristicModel(BLE_SERVICE_UUID, BLE_NOTIFY_CHAR_UUID, new ArrayBuffer(0), [cccd]);
    const svc: GattServiceModel = new GattServiceModel(BLE_SERVICE_UUID, true, [writeCh, notifyCh]);
    try {
      server.addService(svc);
    } catch {
      // ignore
    }
  }

  /**
   * 开启蓝牙广播，使手机作为外设可被扫描到。重复调用会忽略。
   */
  /**
   * 启动蓝牙广播，返回是否启动成功。
   */
  private startAdvertising(): boolean {
    if (this.advertising) {
      return true;
    }
    const setting: AdvertiseSettingModel = new AdvertiseSettingModel(150, 0, true);
    // 使用对象字面量构建 AdvertiseData，只包含 serviceUuids/manufactureData/serviceData
    const data: ble.AdvertiseData = {
      serviceUuids: [BLE_SERVICE_UUID],
      manufactureData: [],
      serviceData: []
    } as ble.AdvertiseData;
    try {
      ble.startAdvertising(setting, data);
      this.advertising = true;
    } catch {
      this.advertising = false;
    }
    return this.advertising;
  }

  /**
   * 停止蓝牙广播。
   */
  private stopAdvertising(): void {
    if (!this.advertising) {
      return;
    }
    try {
      ble.stopAdvertising();
    } catch {
      // ignore
    }
    this.advertising = false;
  }
}

/**
 * 单例对象，供外部直接使用。
 */
export const BleGattReceiver: BleGattReceiverImpl = new BleGattReceiverImpl();