// entry/src/main/ets/pages/Index.ets
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import preferences from '@ohos.data.preferences';

import { BleGattReceiver } from '../common/BleGattReceiver';
import { BottomNav } from '../common/BottomNav';
import {
  COLOR_BG,
  COLOR_SURFACE,
  COLOR_PRIMARY,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../common/Theme';

// 用一个“显式接口”来避免 ArkTS 对 object literal 的校验报错
interface AbilityWantLike {
  bundleName: string;
  abilityName: string;
  uri?: string;
  parameters?: Record<string, string>;
}

@Entry
@Component
struct Index {
  @State isConnected: boolean = false;
  @State bleDeviceLabel: string = '';
  @State showMoreMenu: boolean = false;

  // ===== ✅ 只用于右上角菜单：外设模式开关 + 持久化 =====
  @State peripheralEnabled: boolean = false;
  private prefLoaded: boolean = false;
  private static readonly PREF_NAME: string = 'app2_ble';
  private static readonly PREF_KEY: string = 'peripheral_enabled';
  // ====================================================

  private blePollTimer: number = -1;

  onPageShow(): void {
    this.startBleWatcher();
    // ✅ 自动恢复外设模式（只执行一次）
    this.restorePeripheralSettingOnce().catch(() => { });
  }

  onPageHide(): void {
    this.stopBleWatcher();
    this.showMoreMenu = false;
  }

  private showToast(msg: string): void {
    try {
      promptAction.showToast({ message: msg });
    } catch {
      // ignore
    }
  }

  private startBleWatcher(): void {
    this.stopBleWatcher();
    this.syncBleState();

    // 避免 unknown/any：直接断言为 number
    this.blePollTimer = setInterval(() => {
      this.syncBleState();
    }, 800) as number;
  }

  private stopBleWatcher(): void {
    if (this.blePollTimer !== -1) {
      try {
        clearInterval(this.blePollTimer);
      } catch {
        // ignore
      }
      this.blePollTimer = -1;
    }
  }

  private syncBleState(): void {
    let connectedNow: boolean = false;
    let nameNow: string = '';

    // 只依赖你稳定存在的两个方法
    try {
      connectedNow = BleGattReceiver.isConnected();
      nameNow = BleGattReceiver.getConnectedName();
    } catch {
      connectedNow = false;
      nameNow = '';
    }

    if (connectedNow !== this.isConnected) {
      this.isConnected = connectedNow;
    }
    if (nameNow !== this.bleDeviceLabel) {
      this.bleDeviceLabel = nameNow;
    }

    // ✅ 同步外设模式状态（不影响主流程）
    try {
      this.peripheralEnabled = BleGattReceiver.isPeripheralOn();
    } catch {
      // ignore
    }
  }

  // ===== ✅ Preferences：恢复外设模式（修复你截图的 Promise->boolean 报错） =====
  private async restorePeripheralSettingOnce(): Promise<void> {
    if (this.prefLoaded) return;
    this.prefLoaded = true;

    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const pref: preferences.Preferences = await preferences.getPreferences(ctx, Index.PREF_NAME);

      // ✅ 关键修复：pref.get 在你环境里是 Promise<ValueType>，必须 await
      const v = await pref.get(Index.PREF_KEY, false);
      const enabled: boolean = (v === true);

      if (enabled) {
        try {
          const ok: boolean = BleGattReceiver.startPeripheral();
          this.peripheralEnabled = ok;
          if (!ok) this.showToast('外设模式自动开启失败');
        } catch {
          this.peripheralEnabled = false;
          this.showToast('外设模式自动开启失败');
        }
      }
    } catch {
      // ignore
    }
  }

  private async persistPeripheral(enabled: boolean): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const pref: preferences.Preferences = await preferences.getPreferences(ctx, Index.PREF_NAME);
      await pref.put(Index.PREF_KEY, enabled);
      await pref.flush();
    } catch {
      // ignore
    }
  }

  private togglePeripheral(): void {
    const next: boolean = !this.peripheralEnabled;

    if (next) {
      try {
        const ok: boolean = BleGattReceiver.startPeripheral();
        this.peripheralEnabled = ok;
        if (ok) {
          this.showToast('已开启外设模式：请用 iPhone EasyBLE 连接并订阅 Notify');
        } else {
          this.showToast('外设模式开启失败');
        }
      } catch {
        this.peripheralEnabled = false;
        this.showToast('外设模式开启失败');
      }
    } else {
      try {
        BleGattReceiver.stopPeripheral();
      } catch {
        // ignore
      }
      this.peripheralEnabled = false;
      this.showToast('已关闭外设模式');
    }

    this.persistPeripheral(this.peripheralEnabled).catch(() => { });
  }
  // ==================================================================

  // 打开系统蓝牙页（nova14 / HarmonyOS 6 你已验证可用）
  private async openSystemBluetoothSettings(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;

    const wantHuaweiBluetooth: AbilityWantLike = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'bluetooth_entry'
    };

    try {
      await ctx.startAbility(wantHuaweiBluetooth);
    } catch {
      this.showToast('无法直接打开蓝牙页，请手动：设置 > 蓝牙');
    }
  }

  private onClickConnect(): void {
    this.showToast('已打开系统蓝牙设置，请连接设备后返回本应用');
    // 不要 await，避免 UI/生命周期抖动
    this.openSystemBluetoothSettings();
  }

  private onClickDisconnect(): void {
    // 如果你 BleGattReceiver 里有 disconnect() 就放开这一行
    // BleGattReceiver.disconnect();
    this.showToast('如需断开，请在系统蓝牙页断开（后续再做应用内断连）');
  }

  build() {
    Column() {
      Column() {
        // 顶部标题栏
        Row() {
          Column() {
            Text('北斗地面软件')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_TEXT_PRIMARY);

            Text('飞行员模式')
              .fontSize(12)
              .fontColor(COLOR_TEXT_SECONDARY)
              .margin({ top: 4 });
          }

          Blank();

          Text('···')
            .fontSize(20)
            .fontColor(COLOR_TEXT_SECONDARY)
            .onClick(() => {
              this.showMoreMenu = !this.showMoreMenu;
            });
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })
        .width('100%');

        // ✅ 只改这里：右上角菜单内容（其余布局不动）
        if (this.showMoreMenu) {
          Column() {
            Text(this.peripheralEnabled ? '关闭外设模式（Peripheral）' : '开启外设模式（Peripheral）')
              .fontSize(14)
              .fontColor(COLOR_PRIMARY)
              .onClick(() => {
                this.showMoreMenu = false;
                this.togglePeripheral();
              });

            Text('BLE调试')
              .fontSize(14)
              .fontColor(COLOR_PRIMARY)
              .margin({ top: 10 })
              .onClick(() => {
                this.showMoreMenu = false;
                router.pushUrl({ url: 'pages/BleDebugPage' });
              });

            Text('关闭')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SECONDARY)
              .margin({ top: 10 })
              .onClick(() => {
                this.showMoreMenu = false;
              });
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(COLOR_SURFACE);
        }

        // 状态卡片：大圆 + 按钮
        Column() {
          // 大圆状态区
          Column() {
            Column() {
              Text(this.isConnected ? '✓' : '!')
                .fontSize(40)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isConnected ? COLOR_PRIMARY : 0xFFFFA000)
                .margin({ bottom: 6 });

              Text(this.isConnected ? '设备已连接' : '设备未连接')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_TEXT_PRIMARY)
                .margin({ bottom: 4 });

              Text(this.isConnected ? '连接正常，可随时开始任务' : '请连接设备以开始任务')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SECONDARY);

              if (this.isConnected && this.bleDeviceLabel.length > 0) {
                Text(this.bleDeviceLabel)
                  .fontSize(12)
                  .fontColor(COLOR_TEXT_SECONDARY)
                  .margin({ top: 8 });
              }
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center);
          }
          .width(220)
          .height(220)
          .borderRadius(110)
          .border({ width: 3, color: COLOR_PRIMARY })
          .backgroundColor(Color.White)
          .margin({ top: 8, bottom: 16 })
          .alignSelf(ItemAlign.Center);

          Row() {
            Button(this.isConnected ? '重新连接' : '一键连接')
              .width('48%')
              .height(44)
              .borderRadius(22)
              .backgroundColor(COLOR_PRIMARY)
              .fontColor(Color.White)
              .fontSize(16)
              .onClick(() => {
                this.onClickConnect();
              });

            Button('断开连接')
              .width('48%')
              .height(44)
              .borderRadius(22)
              .backgroundColor(Color.White)
              .fontColor(COLOR_PRIMARY)
              .fontSize(16)
              .border({ width: 1, color: COLOR_PRIMARY })
              .onClick(() => {
                this.onClickDisconnect();
              });
          }
          .justifyContent(FlexAlign.SpaceBetween)
          .width('100%')
          .margin({ top: 4 });
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
        .width('100%')
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 8, bottom: 16 });

        // 功能入口区域（2×2）
        Column({ space: 16 }) {
          Text('飞行辅助功能')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY)
            .margin({ left: 4, bottom: 4 });

          Column({ space: 16 }) {
            Row({ space: 16 }) {
              FeatureItem('电量', '设备剩余电量');
              FeatureItem('信号强度', '连接质量');
            }
            .justifyContent(FlexAlign.SpaceBetween)
            .width('100%');

            Row({ space: 16 }) {
              FeatureItem('目标配置', '航线与任务参数');
              FeatureItem('报文模板', '常用报文与口令');
            }
            .justifyContent(FlexAlign.SpaceBetween)
            .width('100%');
          }
        }
        .padding({ left: 16, right: 16, bottom: 12 })
        .width('100%');

        Blank()
          .height(8)
          .width('100%');
      }
      .layoutWeight(1)
      .width('100%');

      BottomNav({ currentTab: 2 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG);
  }
}

@Builder
function FeatureItem(title: string, subtitle: string) {
  Column() {
    Column() {
      Text(title.charAt(0))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White);
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor(COLOR_PRIMARY)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 8 });

    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(COLOR_TEXT_PRIMARY)
      .margin({ bottom: 2 });

    Text(subtitle)
      .fontSize(12)
      .fontColor(COLOR_TEXT_SECONDARY)
      .maxLines(2);
  }
  .padding({ top: 12, bottom: 12, left: 12, right: 12 })
  .width('48%')
  .backgroundColor(Color.White)
  .borderRadius(12)
  .shadow({
    radius: 8,
    color: 0x1A000000,
    offsetX: 0,
    offsetY: 4
  });
}
