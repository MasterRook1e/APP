// entry/src/main/ets/pages/ChatPage.ets

import { onIncomingText } from '../common/IncomingBridge';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { BleGattReceiver } from '../common/BleGattReceiver';
import { ChatStore, ChatMessage, ChatThread } from '../common/ChatStore';
import {
  COLOR_BG,
  COLOR_SURFACE,
  COLOR_PRIMARY,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../common/Theme';

function toStr(v: object | undefined): string {
  if (v === undefined) {
    return '';
  }
  try {
    return v.toString();
  } catch (_) {
    return '';
  }
}

function getParam(params: Record<string, object>, key: string): object | undefined {
  const v: object | undefined = params[key];
  return v;
}

function parsePositiveInt(s: string): number {
  const n: number = Number.parseInt(s, 10);
  if (Number.isNaN(n)) {
    return 0;
  }
  return n > 0 ? n : 0;
}

@Entry
@Component
struct ChatPage {
  @State threadId: number = 0;
  @State title: string = '';
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State showMoreMenu: boolean = false;

  private pollTimerId: number = -1;

  aboutToAppear() {
    this.resolveThreadFromRouter();
    this.refreshFromStore();
    this.startPolling();
  }

  aboutToDisappear() {
    this.stopPolling();
  }

  private resolveThreadFromRouter(): void {
    const paramsObj: Record<string, object> = router.getParams() as Record<string, object>;

    // 兼容 threadId / id / name
    const threadIdObj: object | undefined = getParam(paramsObj, 'threadId');
    const idObj: object | undefined = getParam(paramsObj, 'id');
    const nameObj: object | undefined = getParam(paramsObj, 'name');

    let idValue: number = 0;

    const tidStr: string = toStr(threadIdObj);
    if (tidStr.length > 0) {
      idValue = parsePositiveInt(tidStr);
    }

    if (idValue <= 0) {
      const idStr: string = toStr(idObj);
      if (idStr.length > 0) {
        idValue = parsePositiveInt(idStr);
      }
    }

    let thread: ChatThread | undefined = undefined;

    if (idValue > 0) {
      thread = ChatStore.getThreadById(idValue);
    }

    if (!thread) {
      const nameStr: string = toStr(nameObj);
      if (nameStr.length > 0) {
        // name 形如：张三-CA888-20251128
        let pilotName: string = nameStr;
        let flightNo: string = '';
        let flightDate: string = '';

        const parts: string[] = nameStr.split('-');
        if (parts.length >= 3) {
          pilotName = parts[0];
          flightNo = parts[1];
          flightDate = parts[2];
        }

        const newThread: ChatThread = ChatStore.createThread(pilotName, flightNo, flightDate);
        thread = newThread;
        idValue = newThread.id;
      }
    }

    if (thread) {
      this.threadId = idValue;
      this.title = thread.title;
      this.messages = [...thread.messages];
      ChatStore.setCurrentThread(this.threadId);
    }
  }

  private startPolling(): void {
    if (this.pollTimerId >= 0) {
      return;
    }
    this.pollTimerId = setInterval(() => {
      this.refreshFromStore();
    }, 200);
  }

  private stopPolling(): void {
    if (this.pollTimerId >= 0) {
      clearInterval(this.pollTimerId);
      this.pollTimerId = -1;
    }
  }

  private refreshFromStore(): void {
    if (this.threadId <= 0) {
      return;
    }
    const thread: ChatThread | undefined = ChatStore.getThreadById(this.threadId);
    if (!thread) {
      return;
    }

    // 更新标题（防止被创建时变化）
    this.title = thread.title;

    // 只要长度变化就刷新引用，触发 UI 更新
    if (this.messages.length !== thread.messages.length) {
      this.messages = [...thread.messages];
      return;
    }

    // 长度相同也可能内容变了：用最后一条 id 做轻量校验
    const len: number = thread.messages.length;
    if (len > 0) {
      const lastStoreId: number = thread.messages[len - 1].id;
      const lastUiId: number = this.messages[len - 1].id;
      if (lastStoreId !== lastUiId) {
        this.messages = [...thread.messages];
      }
    }
  }

  private sendMessage(): void {
    const content: string = this.inputText.trim();
    if (content.length === 0 || this.threadId <= 0) {
      return;
    }

    ChatStore.appendMessageToThread(this.threadId, content, true);
    this.inputText = '';

    // 同步把消息发到 BLE（如果已连接）。
    const ok: boolean = BleGattReceiver.sendText(content);
    if (!ok) {
      try {
        promptAction.showToast({ message: 'BLE未连接，消息未发到设备' });
      } catch {
        // ignore
      }
    }

    this.refreshFromStore();
  }

  build() {
    Column() {
      // ===== 顶部栏 =====
      Column() {
        Row() {
          Text('< 返回')
            .fontSize(16)
            .fontColor(COLOR_PRIMARY)
            .onClick(() => {
              try {
                router.back();
              } catch (e) {
                const eo: object = e as object;
                console.error('router.back error: ' + JSON.stringify(eo));
              }
            });

          Text(this.title.length > 0 ? this.title : '对话')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .margin({ left: 12, right: 12 });

          Text('···')
            .fontSize(20)
            .fontColor(COLOR_TEXT_SECONDARY)
            .onClick(() => {
              this.showMoreMenu = !this.showMoreMenu;
            });
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        .backgroundColor(COLOR_SURFACE);

        Row() { }
        .width('100%')
        .height(0.5)
        .backgroundColor(0x11000000);

        if (this.showMoreMenu) {
          Column() {
            Text('对话信息（暂未实现）')
              .fontSize(14)
              .fontColor(COLOR_TEXT_PRIMARY)
              .margin({ bottom: 8 });

            Text('清空消息（暂未实现）')
              .fontSize(14)
              .fontColor(COLOR_TEXT_SECONDARY);

            Text('模拟接收 HELLO')
              .fontSize(14)
              .fontColor(COLOR_PRIMARY)
              .margin({ top: 8 })
              .onClick(() => {
                onIncomingText('HELLO');
                this.showMoreMenu = false;
              });

            Text('收起')
              .fontSize(13)
              .fontColor(COLOR_PRIMARY)
              .margin({ top: 8 })
              .onClick(() => {
                this.showMoreMenu = false;
              });
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(COLOR_SURFACE);
        }
      }
      .width('100%');

      // ===== 消息区 =====
      Column() {
        List() {
          ForEach(this.messages, (msg: ChatMessage) => {
            ListItem() {
              MessageRow(msg.text, msg.fromMe);
            }
          }, (msg: ChatMessage) => msg.id.toString());
        }
        .width('100%')
        .height('100%');
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(COLOR_BG);

      Row() { }
      .width('100%')
      .height(0.5)
      .backgroundColor(0x11000000);

      // ===== 输入区 =====
      Row() {
        TextInput({ text: this.inputText, placeholder: '输入消息内容' })
          .layoutWeight(1)
          .height(40)
          .borderRadius(20)
          .backgroundColor(0xFFF1F3F7)
          .padding({ left: 12, right: 12 })
          .fontSize(14)
          .fontColor(COLOR_TEXT_PRIMARY)
          .onChange((value: string) => {
            this.inputText = value;
          });

        Button('发送')
          .width(76)
          .height(40)
          .margin({ left: 8, right: 12 })
          .borderRadius(20)
          .backgroundColor(COLOR_PRIMARY)
          .fontColor(Color.White)
          .fontSize(15)
          .onClick(() => {
            this.sendMessage();
          });
      }
      .width('100%')
      .height(60)
      .backgroundColor(COLOR_SURFACE);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG);
  }
}

@Builder
function MessageRow(text: string, fromMe: boolean) {
  Row() {
    if (fromMe) {
      Blank().layoutWeight(1);

      Column() {
        ChatBubble(text, true);
      }
      .margin({ left: 40 });
    } else {
      Column() {
        ChatBubble(text, false);
      }
      .margin({ right: 40 });

      Blank().layoutWeight(1);
    }
  }
  .width('100%')
  .padding({ left: 16, right: 16, top: 6, bottom: 6 });
}

@Builder
function ChatBubble(text: string, fromMe: boolean) {
  Text(text)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(fromMe ? COLOR_PRIMARY : 0xFFE5E5EA)
    .fontColor(fromMe ? Color.White : COLOR_TEXT_PRIMARY)
    .fontSize(14)
    .borderRadius(16);
}
