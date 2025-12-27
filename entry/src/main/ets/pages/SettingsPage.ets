import router from '@ohos.router';
import { COLOR_PRIMARY } from '../common/Theme';
import { SettingsStore, AppLanguage, FontSizeLevel } from '../common/SettingsStore';

@Entry
@Component
struct SettingsPage {
  @State private isDark: boolean = false;
  @State private language: AppLanguage = AppLanguage.System;
  @State private fontSizeLevel: FontSizeLevel = FontSizeLevel.Normal;

  aboutToAppear() {
    this.isDark = SettingsStore.getDarkMode();
    this.language = SettingsStore.getLanguage();
    this.fontSizeLevel = SettingsStore.getFontSizeLevel();
  }

  // ===== 多语言工具 =====
  private getUiLang(): string {
    if (this.language === AppLanguage.En) {
      return 'en';
    }
    return 'zh';
  }

  private tr(zh: string, en: string): string {
    return this.getUiLang() === 'en' ? en : zh;
  }

  private getLanguageValueLabel(): string {
    if (this.language === AppLanguage.En) {
      return this.tr('英文', 'English');
    } else if (this.language === AppLanguage.Zh) {
      return this.tr('简体中文', 'Chinese');
    }
    return this.tr('跟随系统', 'Follow system');
  }

  private getFontSizeLabel(): string {
    if (this.fontSizeLevel === FontSizeLevel.Small) {
      return this.tr('小', 'Small');
    } else if (this.fontSizeLevel === FontSizeLevel.Large) {
      return this.tr('大', 'Large');
    }
    return this.tr('标准', 'Standard');
  }

  // ===== 颜色 getter（避免在 build 里写 const）=====
  private getBgColor(): number {
    return this.isDark ? 0xFF111111 : 0xFFF5F5F7;
  }

  private getSurfaceColor(): number {
    return this.isDark ? 0xFF222222 : 0xFFFFFFFF;
  }

  private getTextPrimaryColor(): number {
    return this.isDark ? 0xFFFFFFFF : 0xFF111111;
  }

  private getTextSecondaryColor(): number {
    return this.isDark ? 0xFFB0B0B0 : 0xFF888888;
  }

  private getDividerColor(): number {
    return this.isDark ? 0x33FFFFFF : 0x11000000;
  }

  // ===== 事件处理 =====
  private onLanguageClick(): void {
    let next: AppLanguage;
    if (this.language === AppLanguage.System) {
      next = AppLanguage.En;
    } else if (this.language === AppLanguage.En) {
      next = AppLanguage.Zh;
    } else {
      next = AppLanguage.System;
    }
    this.language = next;
    SettingsStore.setLanguage(next);
  }

  private onFontSizeClick(): void {
    let next: FontSizeLevel;
    if (this.fontSizeLevel === FontSizeLevel.Normal) {
      next = FontSizeLevel.Large;
    } else if (this.fontSizeLevel === FontSizeLevel.Large) {
      next = FontSizeLevel.Small;
    } else {
      next = FontSizeLevel.Normal;
    }
    this.fontSizeLevel = next;
    SettingsStore.setFontSizeLevel(next);
  }

  private onToggleDark(value: boolean): void {
    this.isDark = value;
    SettingsStore.setDarkMode(value);
  }

  private onBack(): void {
    try {
      router.back();
    } catch (err) {
      console.error('router.back error: ' + JSON.stringify(err));
    }
  }

  private onOpenChangelog(): void {
    try {
      router.pushUrl({ url: 'pages/ChangelogPage' });
    } catch (err) {
      console.error('open changelog error: ' + JSON.stringify(err));
    }
  }

  private onOpenAbout(): void {
    try {
      router.pushUrl({ url: 'pages/AboutPage' });
    } catch (err) {
      console.error('open about error: ' + JSON.stringify(err));
    }
  }

  // ===== UI 构建 =====
  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('< ' + (this.getUiLang() === 'en' ? 'Back' : '返回'))
          .fontSize(16)
          .fontColor(COLOR_PRIMARY)
          .onClick(() => {
            this.onBack();
          });

        Text(this.getUiLang() === 'en' ? 'Settings' : '设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getTextPrimaryColor())
          .margin({ left: 12 });

        Blank();
      }
      .height(48)
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(this.getSurfaceColor())
      .alignItems(VerticalAlign.Center);

      // 内容区域
      Column() {
        // ===== General =====
        Text(this.getUiLang() === 'en' ? 'General' : '通用')
          .fontSize(13)
          .fontColor(this.getTextSecondaryColor())
          .padding({ left: 16, right: 16, top: 12, bottom: 4 })
          .width('100%');

        SettingsRowInternal(
          this.getUiLang() === 'en' ? 'Language' : '语言',
          this.getLanguageValueLabel(),
          this.getTextPrimaryColor(),
          this.getTextSecondaryColor(),
          this.getSurfaceColor(),
          this.getDividerColor(),
          () => {
            this.onLanguageClick();
          }
        );

        SettingsRowInternal(
          this.getUiLang() === 'en' ? 'Font size' : '字体大小',
          this.getFontSizeLabel(),
          this.getTextPrimaryColor(),
          this.getTextSecondaryColor(),
          this.getSurfaceColor(),
          this.getDividerColor(),
          () => {
            this.onFontSizeClick();
          }
        );

        // ===== Display =====
        Text(this.getUiLang() === 'en' ? 'Display' : '显示')
          .fontSize(13)
          .fontColor(this.getTextSecondaryColor())
          .padding({ left: 16, right: 16, top: 16, bottom: 4 })
          .width('100%');

        DarkModeRowInternal(
          this.getUiLang() === 'en' ? 'Dark mode' : '深色模式',
          this.isDark,
          this.getTextPrimaryColor(),
          this.getSurfaceColor(),
          this.getDividerColor(),
          (value: boolean) => {
            this.onToggleDark(value);
          }
        );

        // ===== About =====
        Text(this.getUiLang() === 'en' ? 'About' : '关于')
          .fontSize(13)
          .fontColor(this.getTextSecondaryColor())
          .padding({ left: 16, right: 16, top: 16, bottom: 4 })
          .width('100%');

        SettingsRowInternal(
          this.getUiLang() === 'en' ? 'Changelog' : '更新日志',
          '',
          this.getTextPrimaryColor(),
          this.getTextSecondaryColor(),
          this.getSurfaceColor(),
          this.getDividerColor(),
          () => {
            this.onOpenChangelog();
          }
        );

        SettingsRowInternal(
          this.getUiLang() === 'en' ? 'About us' : '关于我们',
          '',
          this.getTextPrimaryColor(),
          this.getTextSecondaryColor(),
          this.getSurfaceColor(),
          this.getDividerColor(),
          () => {
            this.onOpenAbout();
          }
        );

        Blank()
          .width('100%')
          .height(16);
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.getBgColor());
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getBgColor());
  }
}

// ===== 共用设置行 =====
@Builder
function SettingsRowInternal(
  title: string,
  value: string,
  textPrimary: number,
  textSecondary: number,
  surfaceColor: number,
  dividerColor: number,
  onClick: () => void
) {
  Column() {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(textPrimary);

        if (value !== '') {
          Text(value)
            .fontSize(12)
            .fontColor(textSecondary)
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

    Row() { }
    .width('100%')
    .height(0.5)
    .backgroundColor(dividerColor);
  }
  .backgroundColor(surfaceColor)
  .onClick(() => {
    onClick();
  });
}

// ===== 深色模式行 =====
@Builder
function DarkModeRowInternal(
  title: string,
  isOn: boolean,
  textPrimary: number,
  surfaceColor: number,
  dividerColor: number,
  onChanged: (value: boolean) => void
) {
  Column() {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor(textPrimary);

      Blank();

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .width(50)
        .height(30)
        .onChange((value: boolean) => {
          onChanged(value);
        });
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 });

    Row() { }
    .width('100%')
    .height(0.5)
    .backgroundColor(dividerColor);
  }
  .backgroundColor(surfaceColor);
}
