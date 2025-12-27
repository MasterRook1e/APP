// entry/src/main/ets/common/ChatStore.ets

import common from '@ohos.app.ability.common';
import relationalStore from '@ohos.data.relationalStore';

// ===== 类型定义 =====
export interface ChatMessage {
  id: number;
  threadId: number;
  text: string;
  fromMe: boolean;
  timestamp: number;
}

export interface ChatThread {
  id: number;
  title: string;

  pilotName: string;
  flightNo: string;
  flightDate: string;

  lastMessage: string;
  timestamp: number;

  messages: ChatMessage[];
}

// ===== DB 写入对象：必须是“明确声明的 interface”，不要用索引签名 =====
interface ThreadRow {
  id: number;
  displayName: string;
  pilotName: string;
  flightNo: string;
  flightDate: string;
}

interface MessageRow {
  id: number;
  threadId: number;
  text: string;
  fromMe: number; // 0/1
  timestamp: number;
}

// ===== RDB 最小可用方法签名（避免你 SDK 类型缺失导致的报错）=====
interface ResultSetLike {
  goToNextRow(): boolean;
  getLong(columnIndex: number): number;
  getString(columnIndex: number): string;
  close(): void;
}

interface RdbStoreLike {
  executeSql(sql: string, bindArgs?: (string | number | boolean | null)[]): Promise<void>;
  querySql(sql: string, bindArgs?: (string | number | boolean | null)[]): Promise<ResultSetLike>;
  insert(table: string, values: object): Promise<number>;
}

interface RdbConfig {
  name: string;
  securityLevel: number;
}

function errToString(e: object): string {
  try {
    return JSON.stringify(e);
  } catch (_) {
    return '[stringify error]';
  }
}

class ChatStoreImpl {
  private threadsInner: ChatThread[] = [];

  private nextThreadId: number = 1;
  private nextMessageId: number = 1;

  private store: RdbStoreLike | null = null;
  private initialized: boolean = false;

  // 当前正在打开的会话（ChatPage aboutToAppear 里 setCurrentThread）
  private currentThreadId: number = 0;

  get threads(): ChatThread[] {
    return this.threadsInner;
  }

  async init(context: common.Context): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      const cfg: RdbConfig = {
        name: 'piva_chat.db',
        securityLevel: relationalStore.SecurityLevel.S1
      };

      const raw: object = (await relationalStore.getRdbStore(context, cfg)) as object;
      this.store = raw as RdbStoreLike;

      await this.ensureTables();
      await this.loadFromDb();

      this.initialized = true;
      console.info('[ChatStore] init ok. threads=' + this.threadsInner.length);
    } catch (e) {
      const eo: object = e as object;
      console.error('[ChatStore] init failed: ' + errToString(eo));
      this.store = null;
      this.initialized = false;
    }
  }

  private async ensureTables(): Promise<void> {
    if (!this.store) {
      return;
    }
    try {
      await this.store.executeSql(
        'CREATE TABLE IF NOT EXISTS threads(' +
          'id INTEGER PRIMARY KEY,' +
          'displayName TEXT NOT NULL,' +
          'pilotName TEXT NOT NULL,' +
          'flightNo TEXT NOT NULL,' +
          'flightDate TEXT NOT NULL' +
          ');'
      );

      await this.store.executeSql(
        'CREATE TABLE IF NOT EXISTS messages(' +
          'id INTEGER PRIMARY KEY,' +
          'threadId INTEGER NOT NULL,' +
          'text TEXT NOT NULL,' +
          'fromMe INTEGER NOT NULL,' +
          'timestamp INTEGER NOT NULL' +
          ');'
      );
    } catch (e) {
      const eo: object = e as object;
      console.error('[ChatStore] ensureTables failed: ' + errToString(eo));
    }
  }

  // ===== 创建会话 =====
  createThread(pilotName: string, flightNo: string, flightDate: string): ChatThread {
    const id: number = this.nextThreadId++;
    const title: string = `${pilotName}-${flightNo}-${flightDate}`;

    const thread: ChatThread = {
      id,
      title,
      pilotName,
      flightNo,
      flightDate,
      lastMessage: '',
      timestamp: Date.now(),
      messages: []
    };

    this.threadsInner.push(thread);
    void this.insertThreadToDb(thread);

    return thread;
  }

  // ===== 追加消息（我方/对方都用这个）=====
  appendMessage(threadId: number, text: string, fromMe: boolean): void {
    const thread: ChatThread | undefined = this.getThreadById(threadId);
    if (!thread) {
      console.warn('[ChatStore] appendMessage: thread not found: ' + threadId);
      return;
    }

    const msgId: number = this.nextMessageId++;
    const now: number = Date.now();

    const msg: ChatMessage = {
      id: msgId,
      threadId,
      text,
      fromMe,
      timestamp: now
    };

    thread.messages.push(msg);
    thread.lastMessage = text;
    thread.timestamp = now;

    void this.insertMessageToDb(msg);
  }

  // ===== 给页面/桥接文件用的“兼容 & 别名” =====
  setCurrentThread(threadId: number): void {
    this.currentThreadId = threadId;
  }

  /**
   * 删除指定会话及其消息记录。
   * @param threadId 会话 id
   */
  deleteThread(threadId: number): void {
    // 从内存列表中删除
    const idx: number = this.threadsInner.findIndex((t) => t.id === threadId);
    if (idx >= 0) {
      this.threadsInner.splice(idx, 1);
    }
    // 清除当前激活会话
    if (this.currentThreadId === threadId) {
      this.currentThreadId = 0;
    }
    // 从数据库删除会话和其消息
    if (this.store) {
      const threadSql: string = 'DELETE FROM threads WHERE id = ?';
      const msgSql: string = 'DELETE FROM messages WHERE threadId = ?';
      void this.store.executeSql(threadSql, [threadId]);
      void this.store.executeSql(msgSql, [threadId]);
    }
  }

  // IncomingBridge 用：当前激活会话 id
  getActiveThreadId(): number {
    return this.currentThreadId;
  }

  getCurrentThread(): ChatThread | undefined {
    return this.getThreadById(this.currentThreadId);
  }

  // 兼容你 ChatPage 里旧调用名
  appendMessageToThread(threadId: number, text: string, fromMe: boolean): void {
    this.appendMessage(threadId, text, fromMe);
  }

  // ===== 查询 =====
  getThreadById(id: number): ChatThread | undefined {
    for (let i = 0; i < this.threadsInner.length; i++) {
      if (this.threadsInner[i].id === id) {
        return this.threadsInner[i];
      }
    }
    return undefined;
  }

  getLastMessageText(threadId: number): string {
    const thread: ChatThread | undefined = this.getThreadById(threadId);
    if (!thread || thread.messages.length === 0) {
      return '暂无消息';
    }
    return thread.messages[thread.messages.length - 1].text;
  }

  // ===== DB 写入 =====
  private async insertThreadToDb(thread: ChatThread): Promise<void> {
    if (!this.store) {
      return;
    }
    try {
      const row: ThreadRow = {
        id: thread.id,
        displayName: thread.title,
        pilotName: thread.pilotName,
        flightNo: thread.flightNo,
        flightDate: thread.flightDate
      };
      await this.store.insert('threads', row as object);
    } catch (e) {
      const eo: object = e as object;
      console.error('[ChatStore] insert thread failed: ' + errToString(eo));
    }
  }

  private async insertMessageToDb(msg: ChatMessage): Promise<void> {
    if (!this.store) {
      return;
    }
    try {
      const row: MessageRow = {
        id: msg.id,
        threadId: msg.threadId,
        text: msg.text,
        fromMe: msg.fromMe ? 1 : 0,
        timestamp: msg.timestamp
      };
      await this.store.insert('messages', row as object);
    } catch (e) {
      const eo: object = e as object;
      console.error('[ChatStore] insert message failed: ' + errToString(eo));
    }
  }

  // ===== DB 读取 =====
  private async loadFromDb(): Promise<void> {
    if (!this.store) {
      return;
    }

    this.threadsInner = [];
    const threadsMap: Map<number, ChatThread> = new Map<number, ChatThread>();

    let maxThreadId: number = 0;
    let maxMsgId: number = 0;

    // --- threads ---
    let trs: ResultSetLike | null = null;
    try {
      trs = await this.store.querySql(
        'SELECT id, displayName, pilotName, flightNo, flightDate FROM threads ORDER BY id ASC;',
        []
      );

      while (trs.goToNextRow()) {
        const id: number = trs.getLong(0);
        const displayName: string = trs.getString(1);
        const pilotName: string = trs.getString(2);
        const flightNo: string = trs.getString(3);
        const flightDate: string = trs.getString(4);

        const thread: ChatThread = {
          id,
          title: displayName,
          pilotName,
          flightNo,
          flightDate,
          lastMessage: '',
          timestamp: 0,
          messages: []
        };

        threadsMap.set(id, thread);
        this.threadsInner.push(thread);

        if (id > maxThreadId) {
          maxThreadId = id;
        }
      }
    } catch (e) {
      const eo: object = e as object;
      console.error('[ChatStore] load threads failed: ' + errToString(eo));
    } finally {
      if (trs) {
        try {
          trs.close();
        } catch (_) {}
      }
    }

    // --- messages ---
    let mrs: ResultSetLike | null = null;
    try {
      mrs = await this.store.querySql(
        'SELECT id, threadId, text, fromMe, timestamp FROM messages ORDER BY id ASC;',
        []
      );

      while (mrs.goToNextRow()) {
        const id: number = mrs.getLong(0);
        const threadId: number = mrs.getLong(1);
        const text: string = mrs.getString(2);
        const fromMeVal: number = mrs.getLong(3);
        const ts: number = mrs.getLong(4);

        const thread: ChatThread | undefined = threadsMap.get(threadId);
        if (!thread) {
          continue;
        }

        const msg: ChatMessage = {
          id,
          threadId,
          text,
          fromMe: fromMeVal === 1,
          timestamp: ts
        };

        thread.messages.push(msg);
        thread.lastMessage = text;
        thread.timestamp = ts;

        if (id > maxMsgId) {
          maxMsgId = id;
        }
      }
    } catch (e) {
      const eo: object = e as object;
      console.error('[ChatStore] load messages failed: ' + errToString(eo));
    } finally {
      if (mrs) {
        try {
          mrs.close();
        } catch (_) {}
      }
    }

    this.nextThreadId = maxThreadId + 1;
    this.nextMessageId = maxMsgId + 1;
  }
}

export const ChatStore: ChatStoreImpl = new ChatStoreImpl();
