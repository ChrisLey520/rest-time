import {
  addCustomTemplate,
  createCustomTemplate,
  findPlanTemplate,
  mergeTemplates,
  PlanTemplate,
  PlanTemplateId,
  PlanTemplateTaskDraft,
  planTemplates,
  removeCustomTemplate
} from '../utils/planTemplateCore';
import { StorageService } from './StorageService';
import { TaskService } from './TaskService';

export { PlanTemplate, PlanTemplateId, PlanTemplateTaskDraft, planTemplates };

export interface ApplyPlanTemplateResult {
  templateTitle: string;
  createdCount: number;
}

export class PlanTemplateService {
  static async listTemplates(): Promise<PlanTemplate[]> {
    const customTemplates = await StorageService.getCustomTemplates();
    return mergeTemplates(customTemplates);
  }

  static async applyTemplate(templateId: PlanTemplateId): Promise<ApplyPlanTemplateResult> {
    const customTemplates = await StorageService.getCustomTemplates();
    const template = findPlanTemplate(templateId, customTemplates);
    if (!template) {
      return {
        templateTitle: '',
        createdCount: 0
      };
    }

    let createdCount = 0;
    for (let index = template.tasks.length - 1; index >= 0; index -= 1) {
      const task = template.tasks[index];
      const createdTask = await TaskService.add(
        task.title,
        task.estimatedFocusCount,
        task.priority,
        task.plannedFor,
        task.projectName
      );
      if (createdTask) {
        createdCount += 1;
      }
    }

    return {
      templateTitle: template.title,
      createdCount
    };
  }

  static async saveCurrentTasksAsTemplate(title: string): Promise<PlanTemplate | undefined> {
    const activeTasks = await TaskService.listActive();
    const template = createCustomTemplate(title, activeTasks, Date.now());
    if (!template) {
      return undefined;
    }

    const customTemplates = await StorageService.getCustomTemplates();
    await StorageService.saveCustomTemplates(addCustomTemplate(customTemplates, template));
    return template;
  }

  static async deleteCustomTemplate(templateId: PlanTemplateId): Promise<void> {
    const customTemplates = await StorageService.getCustomTemplates();
    await StorageService.saveCustomTemplates(removeCustomTemplate(customTemplates, templateId));
  }
}
