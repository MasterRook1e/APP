// entry/src/main/ets/pages/FlightListPage.ets

import router from '@ohos.router';
import { ChatStore } from '../common/ChatStore';
import { BottomNav } from '../common/BottomNav';
import {
  COLOR_BG,
  COLOR_SURFACE,
  COLOR_PRIMARY,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../common/Theme';

// DatePicker 返回值结构：单独定义一个接口，避免内联类型报错
interface DatePickerValue {
  year: number;
  month: number;
  day: number;
}

@Entry
@Component
struct FlightListPage {
  // 姓名（允许中文）
  @State crewName: string = '';
  // 航班号（只允许大写字母 + 数字）
  @State flightNo: string = '';
  // 选中的日期对象
  @State selectedDate: Date = new Date();
  // 传给 ChatStore 的日期字符串，例如 20251128
  @State flightDate: string = '';
  // 简单错误提示
  @State warningText: string = '';

  aboutToAppear() {
    if (this.flightDate === '') {
      this.flightDate = this.formatDateForStore(this.selectedDate);
    }
  }

  // ChatStore 用：YYYYMMDD
  private formatDateForStore(d: Date): string {
    const year: number = d.getFullYear();
    const month: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const mm: string = month < 10 ? '0' + month.toString() : month.toString();
    const dd: string = day < 10 ? '0' + day.toString() : day.toString();
    return year.toString() + mm + dd;
  }

  // UI 展示用：YYYY-MM-DD
  private formatDateDisplay(d: Date): string {
    const year: number = d.getFullYear();
    const month: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const mm: string = month < 10 ? '0' + month.toString() : month.toString();
    const dd: string = day < 10 ? '0' + day.toString() : day.toString();
    return year.toString() + '-' + mm + '-' + dd;

  }

  // 构造航班号输入规范：只保留 A-Z 和 0-9，小写自动变大写，长度限制 6
  private normalizeFlightNo(value: string): string {
    const upper: string = value.toUpperCase();
    let filtered: string = '';
    for (let i = 0; i < upper.length; i++) {
      const ch: string = upper.charAt(i);
      const isLetter: boolean = (ch >= 'A' && ch <= 'Z');
      const isDigit: boolean = (ch >= '0' && ch <= '9');
      if (isLetter || isDigit) {
        filtered += ch;
      }
    }
    if (filtered.length > 6) {
      filtered = filtered.substring(0, 6); // CA888 / MU5123 够用
    }
    return filtered;
  }

  // 点击创建航班对话
  private onCreateThread(): void {
    const nameTrimmed: string = this.crewName.trim();
    const flightNoTrimmed: string = this.flightNo.trim();
    const dateStr: string = this.flightDate;

    if (nameTrimmed === '') {
      this.warningText = '请输入飞行员姓名';
      return;
    }
    if (flightNoTrimmed === '') {
      this.warningText = '请输入航班号';
      return;
    }
    if (dateStr === '') {
      this.warningText = '请选择日期';
      return;
    }

    this.warningText = '';

    // 创建会话
    const thread = ChatStore.createThread(nameTrimmed, flightNoTrimmed, dateStr);

    // 跳转到聊天页，传入 threadId
    try {
      router.pushUrl({
        url: 'pages/ChatPage',
        params: { threadId: thread.id }
      });
    } catch (err) {
      console.error('pushUrl to ChatPage error: ' + JSON.stringify(err));
    }
  }

  build() {
    Column() {
      // ===== 内容区 =====
      Column() {
        // 顶部标题栏
        Row() {
          Text('航班')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY);

          Blank();

          // 右上角 + 号占位（预留以后扩展）
          Text('+')
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_PRIMARY);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 8 })
        .backgroundColor(COLOR_SURFACE);

        // 表单卡片
        Column() {
          // 姓名
          Text('姓名')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 8, bottom: 4 });

          TextInput({
            text: this.crewName,
            placeholder: '请输入飞行员姓名，例如 张三'
          })
            .width('100%')
            .height(40)
            .borderRadius(8)
            .backgroundColor(0xFFF1F3F7)
            .padding({ left: 12, right: 12 })
            .fontSize(14)
            .fontColor(COLOR_TEXT_PRIMARY)
            .onChange((value: string) => {
              // 不做特殊处理，避免影响中文输入法
              this.crewName = value;
            });

          // 航班号
          Text('航班号')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 16, bottom: 4 });

          TextInput({
            text: this.flightNo,
            placeholder: '例如 CA888'
          })
            .width('100%')
            .height(40)
            .borderRadius(8)
            .backgroundColor(0xFFF1F3F7)
            .padding({ left: 12, right: 12 })
            .fontSize(14)
            .fontColor(COLOR_TEXT_PRIMARY)
            .onChange((value: string) => {
              this.flightNo = this.normalizeFlightNo(value);
            });

          // 日期标题
          Text('日期')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 16, bottom: 4 });

          // 当前选择的日期显示
          Text(this.formatDateDisplay(this.selectedDate))
            .fontSize(14)
            .fontColor(COLOR_TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ bottom: 8 });

          // 日期选择（滚轮式）
          DatePicker({
            start: new Date(2020, 0, 1),      // 2020-01-01
            end: new Date(2035, 11, 31),      // 2035-12-31
            selected: this.selectedDate
          })
            .width('100%')
            .height(120)
            .onChange((value: DatePickerValue) => {
              // HarmonyOS DatePicker 的 month 为 0~11。先求当前月最大天数（month+1, day=0 得到前一个月最后一天）。
              const maxDay: number = new Date(value.year, value.month + 1, 0).getDate();
              const safeDay: number = Math.min(value.day, maxDay);
              // 按 0~11 直接构造日期，不做 -1 偏移，避免月份回退 bug。
              const d: Date = new Date(value.year, value.month, safeDay);
              this.selectedDate = d;
              try {
                this.flightDate = this.formatDateForStore(d);
              } catch (err) {
                console.error('formatDateForStore error: ' + JSON.stringify(err));
              }
            });

          // 创建按钮
          Button('创建航班对话')
            .width('100%')
            .height(44)
            .margin({ top: 24 })
            .backgroundColor(COLOR_PRIMARY)
            .borderRadius(22)
            .fontSize(16)
            .fontColor(Color.White)
            .onClick(() => {
              this.onCreateThread();
            });

          // 提示文案 + 错误提示
          if (this.warningText !== '') {
            Text(this.warningText)
              .fontSize(12)
              .fontColor(0xFFD93025)
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 8 });
          } else {
            Text('创建后会直接跳转到「消息」页的对话窗口')
              .fontSize(12)
              .fontColor(COLOR_TEXT_SECONDARY)
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 8 });
          }
        }
        .padding({ left: 24, right: 24, top: 12, bottom: 24 })
        .width('100%')
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 12 });

        // 占位空白，防止内容太靠底
        Blank()
          .width('100%')
          .height(8);
      }
      .layoutWeight(1)
      .width('100%');

      // ===== 底部导航：当前是“航班”(1) =====
      BottomNav({ currentTab: 1 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG);
  }
}
