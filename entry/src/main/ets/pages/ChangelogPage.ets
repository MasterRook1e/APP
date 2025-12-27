import router from '@ohos.router';
import {
  COLOR_BG,
  COLOR_SURFACE,
  COLOR_TEXT_SECONDARY,
  COLOR_PRIMARY,
  COLOR_TEXT_PRIMARY
} from '../common/Theme';

class LogItem {
  version: string;
  date: string;
  title: string;
  lines: string[];
  isCurrent: boolean;

  constructor(version: string, date: string, title: string, lines: string[], isCurrent: boolean = false) {
    this.version = version;
    this.date = date;
    this.title = title;
    this.lines = lines;
    this.isCurrent = isCurrent;
  }
}

// 更新日志数据（按时间倒序，最新在最上）
const CHANGELOG: LogItem[] = [
  new LogItem(
    'v0.5.0',
    '2025-11-28',
    '飞行员体验版 · UI 全面优化',
    [
      '首页重新设计为「北斗地面软件 · 飞行员模式」，统一深蓝 + 浅色的视觉风格。',
      '新增飞行辅助功能卡片样式，按钮与图标布局调整，更符合单手操作习惯。',
      '航班创建页增加日期滚轮选择器，支持 YYYY-MM-DD 格式展示，避免手工输入错误。',
      '聊天页重构为左灰右蓝气泡样式，顶部增加航班标题与更多菜单，整体风格更接近主流 IM 应用。',
      '本次更新还对多个细节交互进行打磨，例如按钮点击反馈、间距与字号统一等。'
    ],
    true  // 当前版本
  ),
  new LogItem(
    'v0.4.2',
    '2025-11-27',
    '航班对话细节优化',
    [
      '优化消息列表空状态效果，当尚未创建任何航班时提供清晰的引导文案。',
      '修复部分场景下再次进入对话页时，历史消息未即时刷新显示的问题。',
      '对路由参数解析进行增强，避免异常参数导致页面白屏或崩溃。',
      '合并若干 UI 微调（列表行高、分割线透明度、底部输入栏高度等），不再单独拆分版本。'
    ]
  ),
  new LogItem(
    'v0.4.0',
    '2025-11-27',
    '按航班分组的聊天体验',
    [
      '新增：「航班」页支持通过飞行员姓名 + 航班号 + 日期创建独立航班对话。',
      '新增：ChatStore 中引入 ChatThread 概念，实现按航班维度管理消息记录。',
      '优化消息列表展示，条目标题统一为「姓名-航班号-日期」，便于飞行员快速辨识。',
      '新增消息搜索能力，可按航班信息或最后一条消息内容进行模糊匹配。'
    ]
  ),
  new LogItem(
    'v0.3.1',
    '2025-11-26',
    '品牌对齐与关于信息完善',
    [
      '应用名称由「北斗空中软件」正式更名为「北斗地面软件」，更贴合产品定位。',
      '新增：「关于我们」页面，展示应用名称、版本信息与简要介绍。',
      '在「我的」与「设置」页中增加统一的「关于我们」入口，方便飞行员查看应用信息。'
    ]
  ),
  new LogItem(
    'v0.3.0',
    '2025-11-26',
    '界面统一 & 主题抽取',
    [
      '新增：全局主题配置 Theme.ets，统一主色、背景色、文本颜色与分割线样式。',
      '新增：公共底部导航 BottomNav，支持「消息 / 航班 / 首页 / 地图 / 我的」快速切换。',
      '新增：「设置」页通用分组，包含语言、字体大小与深色模式开关等选项。',
      '新增：「更新日志」页面，并在设置中加入入口，支持查看历史版本变化。',
      '修复多处 ArkTS 规范相关问题（根容器结构、@Builder 返回值等），提高工程稳定性。'
    ]
  ),
  new LogItem(
    'v0.2.1',
    '2025-11-25',
    '聊天体验小幅优化',
    [
      '微调聊天气泡内边距与圆角，让文本显示更舒适。',
      '优化输入框占位提示文案，提示飞行员当前输入的是航班内对话内容。',
      '修复极少数场景下发送按钮无响应的逻辑问题。'
    ]
  ),
  new LogItem(
    'v0.2.0',
    '2025-11-25',
    '基础聊天功能打通',
    [
      '新增：消息列表页，支持查看最近会话并进入对应聊天窗口。',
      '新增：聊天页，支持发送文本消息，并以气泡形式展示对话内容。',
      '新增：全局消息存储 ChatStore，切换页面或返回列表后聊天记录不会丢失。',
      '新增：示例会话数据，方便在无真实航班接入时快速体验流程。'
    ]
  ),
  new LogItem(
    'v0.1.0',
    '2025-11-25',
    '项目创建与首页原型',
    [
      '完成「北斗地面软件」 HarmonyOS NEXT 工程初始化与基础目录搭建。',
      '新增：首页原型布局，包括设备连接状态大圆与飞行相关功能入口。'
    ]
  )
];

@Entry
@Component
struct ChangelogPage {
  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('< 返回')
          .fontSize(16)
          .fontColor(COLOR_PRIMARY)
          .onClick(() => {
            try {
              router.back();
            } catch (err) { }
          });

        Text('更新日志')
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

      // 日志列表
      List() {
        ForEach(CHANGELOG, (item: LogItem) => {
          ListItem() {
            LogCard(item);
          }
        }, (item: LogItem) => item.version);
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLOR_BG);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG);
  }
}

// 单个版本日志卡片
@Builder
function LogCard(item: LogItem) {
  Column() {
    // 版本号 + 日期 + 当前版本标签
    Row() {
      Text(item.version)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT_PRIMARY);

      if (item.isCurrent) {
        Text('当前版本')
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor(COLOR_PRIMARY)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .margin({ left: 8 });
      }

      Blank();

      Text(item.date)
        .fontSize(12)
        .fontColor(COLOR_TEXT_SECONDARY);
    }
    .width('100%');

    // 标题
    Text(item.title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(COLOR_TEXT_PRIMARY)
      .margin({ top: 4, bottom: 4 });

    // 具体条目
    ForEach(item.lines, (line: string) => {
      Text('• ' + line)
        .fontSize(13)
        .fontColor(COLOR_TEXT_SECONDARY)
        .margin({ top: 2 });
    }, (line: string) => line);
  }
  .width('100%')
  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  .margin({ top: 8, left: 12, right: 12 })
  .backgroundColor(COLOR_SURFACE)
  .borderRadius(10);
}
