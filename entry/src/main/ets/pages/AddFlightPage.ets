// entry/src/main/ets/pages/AddFlightPage.ets  （或 FlightListPage.ets）

import router from '@ohos.router';
import { BottomNav } from '../common/BottomNav';
import { ChatStore, ChatThread } from '../common/ChatStore';

@Entry
@Component
struct AddFlightPage {
  // 飞行员姓名
  @State pilotName: string = '';
  // 航班号
  @State flightNo: string = '';
  // 日期（例如 20251126）
  @State flightDate: string = '';

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('< 首页')
          .fontSize(16)
          .onClick(() => {
            try {
              router.pushUrl({ url: 'pages/Index' });
            } catch (err) {}
          });

        Text('航班')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 });
      }
      .height(50)
      .width('100%')
      .padding({ left: 12, right: 12 })
      .backgroundColor(0xFFF7F7F7)
      .alignItems(VerticalAlign.Center);

      // 表单区
      Column() {
        // 飞行员
        Text('飞行员')
          .fontSize(14)
          .fontColor(0xFF666666)
          .margin({ left: 16, top: 16, bottom: 4 });

        TextInput({ text: this.pilotName, placeholder: '请输入飞行员姓名，例如 张三' })
          .width('100%')
          .height(40)
          .margin({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(0xFFF5F5F5)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => {
            this.pilotName = v;
          });

        // 航班号
        Text('航班号')
          .fontSize(14)
          .fontColor(0xFF666666)
          .margin({ left: 16, top: 16, bottom: 4 });

        TextInput({ text: this.flightNo, placeholder: '例如 CA888' })
          .width('100%')
          .height(40)
          .margin({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(0xFFF5F5F5)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => {
            this.flightNo = v;
          });

        // 日期
        Text('日期')
          .fontSize(14)
          .fontColor(0xFF666666)
          .margin({ left: 16, top: 16, bottom: 4 });

        TextInput({ text: this.flightDate, placeholder: '例如 20251126' })
          .width('100%')
          .height(40)
          .margin({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(0xFFF5F5F5)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => {
            this.flightDate = v;
          });

        // 创建按钮
        Button('创建航班对话')
          .width('100%')
          .height(44)
          .margin({ left: 16, right: 16, top: 24 })
          .borderRadius(22)
          .backgroundColor(0xFF1E90FF)
          .fontColor(0xFFFFFFFF)
          .onClick(() => {
            const name = this.pilotName.trim();
            const no = this.flightNo.trim();
            const date = this.flightDate.trim();

            if (name.length === 0 || no.length === 0 || date.length === 0) {
              // 现在简单处理：有空字段就不创建
              return;
            }

            const thread: ChatThread = ChatStore.createThread(name, no, date);

            // 创建完成后直接跳到对应对话
            try {
              router.pushUrl({
                url: 'pages/ChatPage',
                params: {
                  id: thread.id
                }
              });
            } catch (err) {}
          });

        Text('创建后会直接跳到【消息】页的对话窗口。')
          .fontSize(12)
          .fontColor(0xFF999999)
          .margin({ left: 16, right: 16, top: 8 });
      }
      .layoutWeight(1)
      .width('100%');

      // 底部导航：航班 Tab 在索引 1
      BottomNav({ currentTab: 1 });
    }
    .height('100%')
    .width('100%')
    .backgroundColor(0xFFFFFFFF);
  }
}
