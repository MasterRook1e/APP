// entry/src/main/ets/pages/ProfilePage.ets

import router from '@ohos.router';
import { BottomNav } from '../common/BottomNav';
import {
  COLOR_BG,
  COLOR_SURFACE,
  COLOR_PRIMARY,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../common/Theme';

@Entry
@Component
struct ProfilePage {
  // 暂时写死用户名，后续可以从设置里读取
  @State userName: string = '白杨';

  private openSettings(): void {
    try {
      router.pushUrl({
        url: 'pages/SettingsPage'
      });
    } catch (err) {
      console.error('openSettings error: ' + JSON.stringify(err));
    }
  }

  private openAbout(): void {
    try {
      router.pushUrl({
        url: 'pages/AboutPage'
      });
    } catch (err) {
      console.error('openAbout error: ' + JSON.stringify(err));
    }
  }

  build() {
    Column() {
      // ===== 上方内容区 =====
      Column() {
        // 顶部标题
        Row() {
          Text('我的')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 8 })
        .backgroundColor(COLOR_SURFACE);

        // 个人信息卡片
        Column() {
          Row() {
            // 左侧头像
            Column() {
              Text(this.userName.length > 0 ? this.userName.charAt(0) : '我')
                .fontSize(22)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Medium);
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor(COLOR_PRIMARY)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .margin({ right: 16 });

            // 右侧文字
            Column() {
              Text(this.userName)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_TEXT_PRIMARY);

              Text('点击查看个人资料')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SECONDARY)
                .margin({ top: 4 });
            }

            Blank();
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 });
        }
        .width('100%')
        .backgroundColor(COLOR_SURFACE);

        // 分组：通用
        SectionHeader('通用');

        SettingRow('通用设置', '', () => {
          this.openSettings();
        });

        // 分组：关于
        SectionHeader('关于');

        SettingRow('关于我们', '', () => {
          this.openAbout();
        });

        // 占位，防止最后一行太贴底
        Blank()
          .width('100%')
          .height(12);
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(COLOR_BG);

      // ===== 底部导航：当前是“我的”(4) =====
      BottomNav({ currentTab: 4 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG);
  }
}

// ===== 分组标题 =====
@Builder
function SectionHeader(title: string) {
  Text(title)
    .fontSize(13)
    .fontColor(COLOR_TEXT_SECONDARY)
    .padding({ left: 16, right: 16, top: 16, bottom: 4 })
    .width('100%');
}

// ===== 设置行：左文字 + 右箭头 =====
@Builder
function SettingRow(title: string, subtitle: string, onClick: () => void) {
  Column() {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(COLOR_TEXT_PRIMARY);

        if (subtitle !== '') {
          Text(subtitle)
            .fontSize(12)
            .fontColor(COLOR_TEXT_SECONDARY)
            .margin({ top: 2 });
        }
      }

      Blank();

      Text('>')
        .fontSize(16)
        .fontColor(0xFFBBBBBB);
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 });

    // 底部分割线
    Row() { }
    .width('100%')
    .height(0.5)
    .backgroundColor(0x11000000);
  }
  .backgroundColor(COLOR_SURFACE)
  .onClick(() => {
    onClick();
  });
}
