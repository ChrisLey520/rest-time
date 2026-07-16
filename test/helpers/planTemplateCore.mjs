export const planTemplates = [
  {
    id: 'deep_work',
    title: '深度工作日',
    subtitle: '适合推进一个重要产出，留出复盘和收尾',
    projectName: '工作',
    estimatedFocusCount: 6,
    tasks: [
      {
        title: '推进今天最重要的产出',
        estimatedFocusCount: 3,
        priority: 'high',
        plannedFor: 'today',
        projectName: '工作'
      },
      {
        title: '整理关键资料和决策',
        estimatedFocusCount: 2,
        priority: 'normal',
        plannedFor: 'today',
        projectName: '工作'
      },
      {
        title: '复盘结果并写下明天第一步',
        estimatedFocusCount: 1,
        priority: 'normal',
        plannedFor: 'today',
        projectName: '工作'
      }
    ]
  },
  {
    id: 'study_sprint',
    title: '学习冲刺',
    subtitle: '适合备考、读文档、课程推进',
    projectName: '学习',
    estimatedFocusCount: 5,
    tasks: [
      {
        title: '学习一个核心章节',
        estimatedFocusCount: 2,
        priority: 'high',
        plannedFor: 'today',
        projectName: '学习'
      },
      {
        title: '做一组练习或案例',
        estimatedFocusCount: 2,
        priority: 'normal',
        plannedFor: 'today',
        projectName: '学习'
      },
      {
        title: '整理错题和下一步问题',
        estimatedFocusCount: 1,
        priority: 'normal',
        plannedFor: 'today',
        projectName: '学习'
      }
    ]
  },
  {
    id: 'maintenance',
    title: '维护收尾',
    subtitle: '适合处理积压小事，降低心理噪音',
    projectName: '维护',
    estimatedFocusCount: 4,
    tasks: [
      {
        title: '清理最影响状态的积压事项',
        estimatedFocusCount: 1,
        priority: 'high',
        plannedFor: 'today',
        projectName: '维护'
      },
      {
        title: '处理一组低成本事务',
        estimatedFocusCount: 2,
        priority: 'normal',
        plannedFor: 'today',
        projectName: '维护'
      },
      {
        title: '归档资料并更新任务列表',
        estimatedFocusCount: 1,
        priority: 'low',
        plannedFor: 'today',
        projectName: '维护'
      }
    ]
  },
  {
    id: 'restart',
    title: '轻量重启',
    subtitle: '适合状态不稳时重新进入节奏',
    projectName: '个人',
    estimatedFocusCount: 3,
    tasks: [
      {
        title: '完成一个 25 分钟的小任务',
        estimatedFocusCount: 1,
        priority: 'high',
        plannedFor: 'today',
        projectName: '个人'
      },
      {
        title: '整理桌面和待办入口',
        estimatedFocusCount: 1,
        priority: 'normal',
        plannedFor: 'today',
        projectName: '个人'
      },
      {
        title: '写下今天剩余的唯一重点',
        estimatedFocusCount: 1,
        priority: 'normal',
        plannedFor: 'today',
        projectName: '个人'
      }
    ]
  }
];

export const CUSTOM_TEMPLATE_LIMIT = 6;
export const CUSTOM_TEMPLATE_TASK_LIMIT = 6;

export function findPlanTemplate(templateId, customTemplates = []) {
  const custom = customTemplates.find((template) => template.id === templateId);
  if (custom) {
    return custom;
  }

  return planTemplates.find((template) => template.id === templateId);
}

export function templateTaskCount(template) {
  return template.tasks.length;
}

export function mergeTemplates(customTemplates) {
  const merged = [];
  customTemplates.forEach((template) => {
    merged.push(template);
  });
  planTemplates.forEach((template) => {
    merged.push(template);
  });

  return merged;
}

function templateProjectName(tasks) {
  const counts = new Map();
  tasks.forEach((task) => {
    if (!task.projectName) {
      return;
    }

    const current = counts.get(task.projectName);
    counts.set(task.projectName, current ? current + 1 : 1);
  });

  let topName = '';
  let topCount = 0;
  counts.forEach((count, name) => {
    if (count > topCount) {
      topName = name;
      topCount = count;
    }
  });

  return topName ? topName : '个人';
}

export function createCustomTemplate(title, activeTasks, createdAt) {
  const trimmedTitle = title.trim();
  if (!trimmedTitle) {
    return undefined;
  }

  const drafts = [];
  activeTasks.forEach((task) => {
    if (drafts.length >= CUSTOM_TEMPLATE_TASK_LIMIT || task.status !== 'active') {
      return;
    }

    const remaining = Math.max(1, task.estimatedFocusCount - task.completedFocusCount);
    drafts.push({
      title: task.title,
      estimatedFocusCount: remaining,
      priority: task.priority === 'low' || task.priority === 'high' ? task.priority : 'normal',
      plannedFor: task.plannedFor === 'today' || task.plannedFor === 'tomorrow' || task.plannedFor === 'later'
        ? task.plannedFor
        : 'today',
      projectName: task.projectName && task.projectName.trim() ? task.projectName.trim() : ''
    });
  });

  if (drafts.length === 0) {
    return undefined;
  }

  let estimatedFocusCount = 0;
  drafts.forEach((draft) => {
    estimatedFocusCount += draft.estimatedFocusCount;
  });

  return {
    id: `custom_${createdAt}`,
    title: trimmedTitle.slice(0, 20),
    subtitle: `从当前任务保存 · ${drafts.length} 个任务`,
    projectName: templateProjectName(drafts),
    estimatedFocusCount,
    custom: true,
    tasks: drafts
  };
}

export function addCustomTemplate(customTemplates, template, limit = CUSTOM_TEMPLATE_LIMIT) {
  const next = customTemplates.filter((item) => item.title !== template.title);
  next.unshift(template);
  return next.slice(0, Math.max(1, Math.floor(limit)));
}

export function removeCustomTemplate(customTemplates, templateId) {
  return customTemplates.filter((template) => template.id !== templateId);
}
