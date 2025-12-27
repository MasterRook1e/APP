import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { BleGattReceiver, BleDeviceInfo } from '../common/BleGattReceiver';

@Entry
@Component
struct BleDebugPage {
  @State devices: BleDeviceInfo[] = [];
  @State statusText: string = '未连接';

  private refreshTimerId: number = -1;

  private connListener = (connected: boolean, name: string, deviceId: string): void => {
    if (connected) {
      this.statusText = '已连接：' + name + ' (' + deviceId + ')';
      try { promptAction.showToast({ message: 'BLE已连接：' + name }); } catch { }
    } else {
      this.statusText = '未连接';
    }
  }

  aboutToAppear() {
    BleGattReceiver.addListener(this.connListener);
    this.refreshList();
    if (BleGattReceiver.isConnected()) {
      this.statusText = '已连接：' + BleGattReceiver.getConnectedName() + ' (' + BleGattReceiver.getConnectedId() + ')';
    } else {
      this.statusText = '未连接';
    }
  }

  aboutToDisappear() {
    BleGattReceiver.removeListener(this.connListener);
    this.stopRefreshTimer();
  }

  private stopRefreshTimer(): void {
    if (this.refreshTimerId !== -1) {
      try { clearInterval(this.refreshTimerId); } catch { }
      this.refreshTimerId = -1;
    }
  }

  private refreshList(): void {
    const src: Array<BleDeviceInfo> = BleGattReceiver.getScannedDevices();
    const dst: Array<BleDeviceInfo> = [];
    for (let i = 0; i < src.length; i++) {
      dst.push(src[i]);
    }
    this.devices = dst;
  }

  private scanOnce(): void {
    // 1) 开始扫描
    BleGattReceiver.startScan(5000);
    try { promptAction.showToast({ message: '开始扫描(5秒)...' }); } catch { }

    // 2) 停掉旧的刷新计时器
    this.stopRefreshTimer();

    // 3) 每秒刷新列表，6次（≈6秒，覆盖5秒扫描）
    let count: number = 0;
    this.refreshTimerId = setInterval((): void => {
      this.refreshList();
      count += 1;

      if (count >= 6) {
        this.stopRefreshTimer();

        // ✅ 扫描结束后再提示一次
        try {
          promptAction.showToast({ message: '扫描完成，发现 ' + this.devices.length + ' 个设备' });
        } catch { }
      }
    }, 1000);
  }


  private connectTo(d: BleDeviceInfo): void {
    BleGattReceiver.connect(d.deviceId, d.name);
    try { promptAction.showToast({ message: '正在连接：' + d.name }); } catch { }
  }

  build() {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(16)
          .onClick(() => {
            router.back();
          });

        Text('BLE调试')
          .fontSize(16)
          .margin({ left: 12 });
      }
      .width('100%')
      .padding(16);

      Text(this.statusText)
        .fontSize(14)
        .margin({ left: 16, right: 16, bottom: 12 });

      Row() {
        Button('扫描5秒')
          .onClick(() => this.scanOnce())
          .margin({ right: 12 });

        Button('断开')
          .onClick(() => BleGattReceiver.disconnect());
      }
      .padding({ left: 16, right: 16, bottom: 12 });

      List() {
        ForEach(this.devices, (d: BleDeviceInfo) => {
          ListItem() {
            Column() {
              Text(d.name).fontSize(15);
              Text(d.deviceId).fontSize(11).opacity(0.6);
            }
            .padding(12)
            .onClick(() => this.connectTo(d));
          }
        }, (d: BleDeviceInfo) => d.deviceId);
      }
      .width('100%')
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%');
  }
}
