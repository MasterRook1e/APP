import common from '@ohos.app.ability.common';
import {
  AbilityConstant,
  ConfigurationConstant,
  UIAbility,
  Want
} from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ChatStore } from '../common/ChatStore';

// 导入权限管理和后台任务管理 API
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import { Permissions } from '@kit.AbilityKit';

// 定义 DelaySuspendInfo，以匹配 requestSuspendDelay 同步返回的对象结构
interface DelaySuspendInfo {
  requestId: number;
  actualDelayTime: number;
}

// 日志域
const DOMAIN: number = 0x0000;

// 将错误对象转为字符串，避免 any/unknown
function errToString(e: Error | object): string {
  try {
    return JSON.stringify(e);
  } catch (_) {
    return '[stringify error]';
  }
}

export default class EntryAbility extends UIAbility {
  /**
   * 当前后台延迟任务的请求 ID；默认为 -1 表示未申请
   */
  private delaySuspendId: number = -1;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置颜色模式可能会抛出异常，捕获并记录日志
    try {
      this.context
        .getApplicationContext()
        .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (e) {
      hilog.error(
        DOMAIN,
        'EntryAbility',
        'Failed to set colorMode. Cause: %{public}s',
        errToString(e as object)
      );
    }

    hilog.info(
      DOMAIN,
      'EntryAbility',
      'onCreate want=%{public}s launchParam=%{public}s',
      JSON.stringify(want),
      JSON.stringify(launchParam)
    );
  }

  /**
   * 动态请求蓝牙及位置权限。在 HarmonyOS 中，调用蓝牙扫描或连接前需要获用户授权。
   */
  private async requestBlePermissions(): Promise<void> {
    // 构造需要请求的权限列表，并显式断言类型为 Permissions
    const reqPerms: Permissions[] = [
      'ohos.permission.ACCESS_BLUETOOTH' as Permissions,
      'ohos.permission.DISCOVER_BLUETOOTH' as Permissions,
      'ohos.permission.USE_BLUETOOTH' as Permissions,
      'ohos.permission.APPROXIMATELY_LOCATION' as Permissions
    ];
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      // 请求权限，返回 Promise；忽略返回值即可
      await atManager.requestPermissionsFromUser(this.context, reqPerms);
    } catch (e) {
      // 若授权过程中抛异常，不终止程序
      hilog.error(
        DOMAIN,
        'EntryAbility',
        'requestBlePermissions error: %{public}s',
        errToString(e as object)
      );
    }
  }

  /**
   * 申请后台短时任务。该任务在应用切到后台后延迟挂起，以保持 BLE 通信持续一段时间。
   */
  private requestBleKeepAlive(): void {
    // 已存在任务则不重复申请
    if (this.delaySuspendId !== -1) {
      return;
    }
    try {
      // requestSuspendDelay 为同步调用，返回 DelaySuspendInfo；回调在延迟即将结束时执行
      const info = backgroundTaskManager.requestSuspendDelay(
        'Maintain BLE connection',
        () => {
          try {
            if (this.delaySuspendId !== -1) {
              backgroundTaskManager.cancelSuspendDelay(this.delaySuspendId);
              this.delaySuspendId = -1;
            }
          } catch {
            // 忽略取消异常
          }
        }
      ) as DelaySuspendInfo;
      this.delaySuspendId = info.requestId;
    } catch (e) {
      // 申请失败则重置 ID
      this.delaySuspendId = -1;
      hilog.error(
        DOMAIN,
        'EntryAbility',
        'requestBleKeepAlive failed: %{public}s',
        errToString(e as object)
      );
    }
  }

  /**
   * 取消已申请的后台延迟任务
   */
  private cancelBleKeepAlive(): void {
    if (this.delaySuspendId === -1) {
      return;
    }
    try {
      backgroundTaskManager.cancelSuspendDelay(this.delaySuspendId);
    } catch (e) {
      hilog.error(
        DOMAIN,
        'EntryAbility',
        'cancelBleKeepAlive error: %{public}s',
        errToString(e as object)
      );
    } finally {
      this.delaySuspendId = -1;
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onWindowStageCreate');

    // 定义加载主页的回调
    const loadIndex = (): void => {
      try {
        windowStage.loadContent('pages/Index');
      } catch (e) {
        hilog.error(
          DOMAIN,
          'EntryAbility',
          'loadContent throw: %{public}s',
          errToString(e as object)
        );
      }
    };

    // 异步初始化数据和权限，然后加载主页
    void (async () => {
      await this.requestBlePermissions();
      try {
        await ChatStore.init(this.context as common.Context);
      } catch (e) {
        hilog.error(
          DOMAIN,
          'EntryAbility',
          'ChatStore.init failed: %{public}s',
          errToString(e as object)
        );
      }
      loadIndex();
    })();
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onForeground');
    // 申请后台保持任务
    this.requestBleKeepAlive();
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onBackground');
    // 取消后台保持任务
    this.cancelBleKeepAlive();
  }
}
