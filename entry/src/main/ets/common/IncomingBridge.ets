// entry/src/main/ets/common/IncomingBridge.ets

import emitter from '@ohos.events.emitter';
import { CHAT_EVENT_ID } from './ChatEvents';
import { ChatStore, ChatThread } from './ChatStore';

/**
 * 统一把异常转成字符串（避免 any/unknown）
 */
function errToString(e: object): string {
  try {
    return JSON.stringify(e);
  } catch (_) {
    return String(e);
  }
}

/**
 * 通知 UI “有新消息了”
 * 注意：不要写 emitter.Event 类型（你 SDK 里没有这个导出，会报错）
 */
function notifyUi(threadId: number, text: string): void {
  try {
    emitter.emit(
      { eventId: CHAT_EVENT_ID },
      { data: { threadId: threadId, text: text } }
    );
  } catch (e) {
    const eo: object = e as object;
    console.error('[IncomingBridge] emitter.emit failed: ' + errToString(eo));
  }
}

/**
 * 拿到当前激活会话；如果没有，就创建一个默认“蓝牙设备”会话
 */
function ensureActiveThreadId(): number {
  let activeId: number = 0;

  try {
    activeId = ChatStore.getActiveThreadId();
  } catch (e) {
    // 如果你 ChatStore 没实现 getActiveThreadId，就会走这里
    // 但你当前 ChatStore 里已经有这个方法（是 setCurrentThread / getActiveThreadId 那套）
    activeId = 0;
  }

  if (activeId > 0) {
    const t: ChatThread | undefined = ChatStore.getThreadById(activeId);
    if (t) {
      return activeId;
    }
  }

  // 没有激活会话：创建一个默认会话
  const th: ChatThread = ChatStore.createThread('Device', 'BT', '00000000');
  try {
    ChatStore.setCurrentThread(th.id);
  } catch (_) {
    // setCurrentThread 如果不存在也不影响消息写入，只是“当前会话”概念会弱化
  }
  return th.id;
}

/**
 * 给你未来蓝牙接收回调调用：
 * 任何外部收到的纯文本，直接丢进来即可。
 *
 * 例：onIncomingText('HELLO')
 */
export function onIncomingText(text: string): void {
  // 规整：去掉首尾空白
  const clean: string = text.trim();
  if (clean.length === 0) {
    return;
  }

  const tid: number = ensureActiveThreadId();

  // 支持多行：每行作为一条消息（可选）
  const normalized: string = clean.replace(/\r/g, '\n');
  const lines: string[] = normalized.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line: string = lines[i].trim();
    if (line.length === 0) {
      continue;
    }

    try {
      // fromMe=false -> 左侧“对方”气泡
      ChatStore.appendMessage(tid, line, false);
      notifyUi(tid, line);
    } catch (e) {
      const eo: object = e as object;
      console.error('[IncomingBridge] append incoming failed: ' + errToString(eo));
    }
  }
}

/**
 * 如果你未来能明确知道要写入哪个 threadId（比如蓝牙设备绑定到某个航班会话）
 * 可以用这个。
 */
export function onIncomingTextToThread(threadId: number, text: string): void {
  const clean: string = text.trim();
  if (clean.length === 0) {
    return;
  }

  try {
    // 不存在会话就不写，避免写到错误位置
    const t: ChatThread | undefined = ChatStore.getThreadById(threadId);
    if (!t) {
      console.warn('[IncomingBridge] thread not found: ' + threadId);
      return;
    }

    ChatStore.appendMessage(threadId, clean, false);
    notifyUi(threadId, clean);
  } catch (e) {
    const eo: object = e as object;
    console.error('[IncomingBridge] append incoming to thread failed: ' + errToString(eo));
  }
}
