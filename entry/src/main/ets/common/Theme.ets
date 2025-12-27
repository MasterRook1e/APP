// entry/src/main/ets/common/Theme.ets
// 全局主题颜色 & 深色/浅色主题切换

// 主色：深蓝色 #00579B
export let COLOR_PRIMARY: number = 0xFF00579B;

// 当前生效的颜色（其它文件都用这些）
export let COLOR_BG: number = 0xFFF5F5F7;
export let COLOR_SURFACE: number = 0xFFFFFFFF;
export let COLOR_TEXT_PRIMARY: number = 0xFF111111;
export let COLOR_TEXT_SECONDARY: number = 0xFF888888;
export let COLOR_NAV_BG: number = 0xFFFFFFFF;
export let COLOR_TAB_INACTIVE: number = 0xFF999999;

// ===== 内部：浅色主题调色板 =====
const LIGHT_BG: number = 0xFFF5F5F7;
const LIGHT_SURFACE: number = 0xFFFFFFFF;
const LIGHT_TEXT_PRIMARY: number = 0xFF111111;
const LIGHT_TEXT_SECONDARY: number = 0xFF888888;
const LIGHT_NAV_BG: number = 0xFFFFFFFF;
const LIGHT_TAB_INACTIVE: number = 0xFF999999;

// ===== 内部：深色主题调色板 =====
const DARK_BG: number = 0xFF121212;
const DARK_SURFACE: number = 0xFF1E1E1E;
const DARK_TEXT_PRIMARY: number = 0xFFF5F5F5;
const DARK_TEXT_SECONDARY: number = 0xFFAAAAAA;
const DARK_NAV_BG: number = 0xFF1E1E1E;
const DARK_TAB_INACTIVE: number = 0xFF777777;

// 应用浅色主题
export function applyLightTheme(): void {
  COLOR_BG = LIGHT_BG;
  COLOR_SURFACE = LIGHT_SURFACE;
  COLOR_TEXT_PRIMARY = LIGHT_TEXT_PRIMARY;
  COLOR_TEXT_SECONDARY = LIGHT_TEXT_SECONDARY;
  COLOR_NAV_BG = LIGHT_NAV_BG;
  COLOR_TAB_INACTIVE = LIGHT_TAB_INACTIVE;
}

// 应用深色主题
export function applyDarkTheme(): void {
  COLOR_BG = DARK_BG;
  COLOR_SURFACE = DARK_SURFACE;
  COLOR_TEXT_PRIMARY = DARK_TEXT_PRIMARY;
  COLOR_TEXT_SECONDARY = DARK_TEXT_SECONDARY;
  COLOR_NAV_BG = DARK_NAV_BG;
  COLOR_TAB_INACTIVE = DARK_TAB_INACTIVE;
}

// 根据标志应用主题
export function initTheme(isDark: boolean): void {
  if (isDark) {
    applyDarkTheme();
  } else {
    applyLightTheme();
  }
}

// 默认启动时使用浅色主题
applyLightTheme();
