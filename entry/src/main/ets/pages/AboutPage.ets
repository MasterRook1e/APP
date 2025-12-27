import router from '@ohos.router';
import {
  COLOR_BG,
  COLOR_SURFACE,
  COLOR_TEXT_SECONDARY,
  COLOR_PRIMARY,
  COLOR_TEXT_PRIMARY
} from '../common/Theme';

@Entry
@Component
struct AboutPage {
  build() {
    Column() {
      // 顶部返回 + 标题
      Row() {
        Text('< 返回')
          .fontSize(16)
          .fontColor(COLOR_PRIMARY)
          .onClick(() => {
            try {
              router.back();
            } catch (err) {
              console.error('router.back error: ' + JSON.stringify(err));
            }
          });

        Text('关于我们')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT_PRIMARY)
          .margin({ left: 12 });

        Blank();
      }
      .height(48)
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(COLOR_SURFACE)
      .alignItems(VerticalAlign.Center);

      // 主体卡片
      Column() {
        // App 名称 + 版本
        Text('北斗地面软件')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT_PRIMARY)
          .margin({ top: 8, bottom: 4 });

        Text('版本 0.1.0（测试版）')
          .fontSize(13)
          .fontColor(COLOR_TEXT_SECONDARY)
          .margin({ bottom: 16 });

        // 简短介绍
        Text(
          '北斗地面软件是一款面向飞行员 / 机组的地面沟通与辅助工具，' +
            '用于集中展示飞行相关状态，并按航班维度管理对话与记录。'
        )
          .fontSize(14)
          .fontColor(COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.Start)
          .margin({ bottom: 12 });

        Text(
          '当前版本主要用于展示整体 UI 风格与基础交互流程，' +
            '后续将逐步接入真实设备数据与更多飞行场景能力。'
        )
          .fontSize(14)
          .fontColor(COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.Start)
          .margin({ bottom: 16 });

        // 底部版权信息
        Text('© 2025 Beidou Ground Software')
          .fontSize(12)
          .fontColor(COLOR_TEXT_SECONDARY)
          .textAlign(TextAlign.Start);
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .backgroundColor(COLOR_SURFACE)
      .margin({ top: 16 });

      Blank();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG);
  }
}
