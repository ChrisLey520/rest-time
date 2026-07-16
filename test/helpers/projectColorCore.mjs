export const PROJECT_COLOR_PALETTE = [
  '#5F9E8A',
  '#4D7EA8',
  '#B08954',
  '#8A7FB4',
  '#C96F5D',
  '#5E9CA8',
  '#A8815E',
  '#7FA05F'
];

export const DEFAULT_PROJECT_COLOR = '#9AA6A3';

function hashProjectName(projectName) {
  let hash = 0;
  for (let index = 0; index < projectName.length; index += 1) {
    hash = (hash * 31 + projectName.charCodeAt(index)) >>> 0;
  }

  return hash;
}

export function projectColor(projectName) {
  const trimmedProjectName = projectName ? projectName.trim() : '';
  if (!trimmedProjectName || trimmedProjectName === '未归类') {
    return DEFAULT_PROJECT_COLOR;
  }

  return PROJECT_COLOR_PALETTE[hashProjectName(trimmedProjectName) % PROJECT_COLOR_PALETTE.length];
}
