/**
 * 项目颜色：把项目名稳定映射到一组柔和色板。
 * 同名项目在任务、记录、账单、月报各处始终同色，不需要用户手动配置。
 */
export const PROJECT_COLOR_PALETTE: string[] = [
  '#5F9E8A', // 苔绿
  '#4D7EA8', // 湖蓝
  '#B08954', // 陶土
  '#8A7FB4', // 雾紫
  '#C96F5D', // 赤陶
  '#5E9CA8', // 青碧
  '#A8815E', // 木棕
  '#7FA05F'  // 芽绿
];

export const DEFAULT_PROJECT_COLOR = '#9AA6A3';

function hashProjectName(projectName: string): number {
  let hash = 0;
  for (let index = 0; index < projectName.length; index += 1) {
    hash = (hash * 31 + projectName.charCodeAt(index)) >>> 0;
  }

  return hash;
}

export function projectColor(projectName?: string): string {
  const trimmedProjectName = projectName ? projectName.trim() : '';
  if (!trimmedProjectName || trimmedProjectName === '未归类') {
    return DEFAULT_PROJECT_COLOR;
  }

  return PROJECT_COLOR_PALETTE[hashProjectName(trimmedProjectName) % PROJECT_COLOR_PALETTE.length];
}
