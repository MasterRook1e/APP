// entry/src/main/ets/common/BottomNav.ets

import router from '@ohos.router';
import {
  COLOR_NAV_BG,
  COLOR_PRIMARY,
  COLOR_TAB_INACTIVE
} from './Theme';

@Component
export struct BottomNav {
  // 0: 消息, 1: 航班, 2: 首页, 3: 地图, 4: 我的
  @Prop currentTab: number;

  build() {
    Column() {
      // 导航栏主体
      Row() {
        // 消息
        TabItem('消息', this.currentTab === 0, () => {
          if (this.currentTab !== 0) {
            try {
              router.replaceUrl({ url: 'pages/ChatListPage' });
            } catch (err) {
              // ignore
            }
          }
        });

        // 航班
        TabItem('航班', this.currentTab === 1, () => {
          if (this.currentTab !== 1) {
            try {
              router.replaceUrl({ url: 'pages/FlightListPage' });
            } catch (err) {
              // ignore
            }
          }
        });

        // 中间大圆：首页
        CenterTab(this.currentTab === 2, () => {
          if (this.currentTab !== 2) {
            try {
              router.replaceUrl({ url: 'pages/Index' });
            } catch (err) {
              // ignore
            }
          }
        });

        // 地图（暂不实现功能，占位）
        TabItem('地图', this.currentTab === 3, () => {
          // 以后有 MapPage 再路由，目前占位不跳转
        });

        // 我的
        TabItem('我的', this.currentTab === 4, () => {
          if (this.currentTab !== 4) {
            try {
              router.replaceUrl({ url: 'pages/ProfilePage' });
            } catch (err) {
              // ignore
            }
          }
        });
      }
      .width('100%')
      .height(64)
      .justifyContent(FlexAlign.SpaceAround)
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .backgroundColor(COLOR_NAV_BG);
  }
}

// ===== 左右四个小圆点 Tab =====
@Builder
function TabItem(label: string, selected: boolean, onClick: () => void) {
  Column() {
    // 上方小圆点
    Column() {
    }
    .width(8)
    .height(8)
    .borderRadius(4)
    .backgroundColor(selected ? COLOR_PRIMARY : COLOR_TAB_INACTIVE)
    .margin({ bottom: 4 });

    // 文本
    Text(label)
      .fontSize(11)
      .fontColor(selected ? COLOR_PRIMARY : COLOR_TAB_INACTIVE);
  }
  .width('20%')
  .height(56)
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
  .onClick(() => {
    onClick();
  });
}

// ===== 中间蓝色圆形首页 Tab =====
@Builder
function CenterTab(selected: boolean, onClick: () => void) {
  Column() {
    Column() {
      Text('首页')
        .fontSize(12)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium);
    }
    .width(54)
    .height(54)
    .borderRadius(27)
    .backgroundColor(COLOR_PRIMARY)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
  .width('20%')
  .height(64)
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
  .onClick(() => {
    onClick();
  });
}
