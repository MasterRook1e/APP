// entry/src/main/ets/common/SettingsStore.ets

import { initTheme } from './Theme';

// 应用语言：跟随系统 / 中文 / 英文
export enum AppLanguage {
  System = 0,
  Zh = 1,
  En = 2
}

// 字体大小级别：小 / 标准 / 大
export enum FontSizeLevel {
  Small = 0,
  Normal = 1,
  Large = 2
}

export class SettingsStoreImpl {
  private darkMode: boolean = false;
  private language: AppLanguage = AppLanguage.System;
  private fontSizeLevel: FontSizeLevel = FontSizeLevel.Normal;
  private fontScale: number = 1.0;

  // ===== 深色模式 =====
  getDarkMode(): boolean {
    return this.darkMode;
  }

  setDarkMode(value: boolean): void {
    this.darkMode = value;
    // 切换全局主题颜色
    initTheme(this.darkMode);
  }

  // ===== 语言 =====
  getLanguage(): AppLanguage {
    return this.language;
  }

  setLanguage(lang: AppLanguage): void {
    this.language = lang;
  }

  // ===== 字体大小 =====
  getFontSizeLevel(): FontSizeLevel {
    return this.fontSizeLevel;
  }

  setFontSizeLevel(level: FontSizeLevel): void {
    this.fontSizeLevel = level;

    // 预留给 UI 使用的缩放因子（目前其他页面还没用到）
    if (level === FontSizeLevel.Small) {
      this.fontScale = 0.9;
    } else if (level === FontSizeLevel.Large) {
      this.fontScale = 1.1;
    } else {
      this.fontScale = 1.0;
    }
  }

  getFontScale(): number {
    return this.fontScale;
  }
}

export const SettingsStore = new SettingsStoreImpl();
