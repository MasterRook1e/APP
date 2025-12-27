// entry/src/main/ets/pages/ChatListPage.ets

import router from '@ohos.router';
import { ChatStore, ChatMessage, ChatThread } from '../common/ChatStore';
import { BottomNav } from '../common/BottomNav';
import {
  COLOR_BG,
  COLOR_SURFACE,
  COLOR_PRIMARY,
  COLOR_TEXT_PRIMARY,
  COLOR_TEXT_SECONDARY
} from '../common/Theme';

// 会话列表里用的简化结构
class ChatItem {
  id: number;
  name: string;      // 标题：张三-CA888-20251126
  lastText: string;  // 最后一条消息预览

  constructor(id: number, name: string, lastText: string) {
    this.id = id;
    this.name = name;
    this.lastText = lastText;
  }
}

@Entry
@Component
struct ChatListPage {
  @State searchText: string = '';
  @State allChats: ChatItem[] = [];

  // 轮询定时器：用于“即时刷新”
  private pollTimer: number = -1;

  aboutToAppear() {
    this.syncFromStore();
    this.startPolling();
  }

  aboutToDisappear() {
    this.stopPolling();
  }

  // 从 ChatStore 把会话同步到列表
  private syncFromStore(): void {
    const list: ChatItem[] = [];
    const threads: ChatThread[] = ChatStore.threads;

    for (let i = 0; i < threads.length; i++) {
      const t: ChatThread = threads[i];

      // 兼容：优先用 lastMessage（如果你的 ChatStore 有维护）
      let last: string = '';
      if (t.lastMessage && t.lastMessage.length > 0) {
        last = t.lastMessage;
      } else {
        const msgs: ChatMessage[] = t.messages;
        if (msgs.length > 0) {
          last = msgs[msgs.length - 1].text;
        } else {
          last = '暂无消息';
        }
      }

      list.push(new ChatItem(t.id, t.title, last));
    }

    this.allChats = list;
  }

  private startPolling(): void {
    if (this.pollTimer >= 0) {
      return;
    }
    try {
      // 500ms 刷一次：肉眼接近“即时”
      this.pollTimer = setInterval(() => {
        this.syncFromStore();
      }, 500);
    } catch (_) {
      this.pollTimer = -1;
    }
  }

  private stopPolling(): void {
    if (this.pollTimer < 0) {
      return;
    }
    try {
      clearInterval(this.pollTimer);
    } catch (_) {
      // ignore
    }
    this.pollTimer = -1;
  }

  // 根据搜索关键字过滤
  private getShowList(): ChatItem[] {
    const keyword: string = this.searchText.trim();
    if (keyword.length === 0) {
      return this.allChats;
    }
    const result: ChatItem[] = [];
    for (let i = 0; i < this.allChats.length; i++) {
      const item: ChatItem = this.allChats[i];
      if (item.name.indexOf(keyword) >= 0 || item.lastText.indexOf(keyword) >= 0) {
        result.push(item);
      }
    }
    return result;
  }

  build() {
    Column() {
      // ===== 顶部：标题 + 搜索栏 =====
      Column() {
        Row() {
          Text('消息')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT_PRIMARY);

          Blank();

          Text(' ')
            .fontSize(16);
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 4 });

        Row() {
          Text('🔍')
            .fontSize(18)
            .margin({ left: 12, right: 6 })
            .fontColor(COLOR_TEXT_SECONDARY);

          TextInput({
            text: this.searchText,
            placeholder: '搜索联系人或聊天内容'
          })
            .layoutWeight(1)
            .height(36)
            .borderRadius(18)
            .backgroundColor(0xFFF0F2F6)
            .padding({ left: 4, right: 12 })
            .fontSize(14)
            .fontColor(COLOR_TEXT_PRIMARY)
            .onChange((value: string) => {
              this.searchText = value;
            });
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 6, bottom: 10 });

        Row() { }
        .width('100%')
        .height(0.5)
        .backgroundColor(0x11000000);
      }
      .width('100%')
      .backgroundColor(COLOR_SURFACE);

      // ===== 列表 / 空状态 =====
      if (this.allChats.length === 0) {
        Column() {
          Column() {
            Text('✈')
              .fontSize(32)
              .fontColor(COLOR_PRIMARY);
          }
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor(0xFFE3F1FB)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ bottom: 12 });

          Text('暂无航班对话')
            .fontSize(16)
            .fontColor(COLOR_TEXT_PRIMARY)
            .margin({ bottom: 6 });

          Text('请前往下方「航班」页创建新的航班对话。')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SECONDARY)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(COLOR_BG);
      } else {
        List() {
          ForEach(this.getShowList(), (item: ChatItem) => {
            ListItem() {
              ChatListRow(item.name, item.lastText, () => {
                // 点击进入对话
                try {
                  router.pushUrl({
                    url: 'pages/ChatPage',
                    params: { threadId: item.id }
                  });
                } catch (err) {
                  console.error('pushUrl to ChatPage error: ' + JSON.stringify(err));
                }
              }, () => {
                // 点击删除
                ChatStore.deleteThread(item.id);
                // 立即刷新列表
                this.syncFromStore();
              });
            }
          }, (item: ChatItem) => item.id.toString());
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .backgroundColor(COLOR_BG);
      }

      BottomNav({ currentTab: 0 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG);
  }
}

@Builder
function ChatListRow(name: string, lastText: string, onClick: () => void, onDelete: () => void) {
  // 使用堆叠布局实现滑动删除：底层为删除区域，顶层为内容区域。
  // 由于 ArkTS 标准库未提供 SwipeAction，本示例简化为直接显示删除按钮。
  Row() {
    // 左侧圆形头像
    Column() {
      Text(name.length > 0 ? name.charAt(0) : '')
        .fontSize(20)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium);
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .backgroundColor(COLOR_PRIMARY)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .margin({ right: 12 });

    // 中间文本区域
    Column() {
      Text(name)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT_PRIMARY);

      Text(lastText)
        .fontSize(13)
        .fontColor(COLOR_TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 4 });
    }
    .layoutWeight(1);

    // 删除按钮
    Text('删除')
      .fontSize(14)
      .fontColor(Color.White)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(0xFFE74C3C) // 红色
      .borderRadius(4)
      .onClick(() => {
        onDelete();
      });
  }
  .width('100%')
  .height(68)
  .padding({ left: 16, right: 16 })
  .backgroundColor(Color.White)
  .onClick(() => {
    onClick();
  });

  Row() {}
  .width('100%')
  .height(0.5)
  .backgroundColor(0x11000000);
}
