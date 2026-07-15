import {
  findPlanTemplate,
  PlanTemplate,
  PlanTemplateId,
  PlanTemplateTaskDraft,
  planTemplates
} from '../utils/planTemplateCore';
import { TaskService } from './TaskService';

export { PlanTemplate, PlanTemplateId, PlanTemplateTaskDraft, planTemplates };

export interface ApplyPlanTemplateResult {
  templateTitle: string;
  createdCount: number;
}

export class PlanTemplateService {
  static listTemplates(): PlanTemplate[] {
    return planTemplates;
  }

  static async applyTemplate(templateId: PlanTemplateId): Promise<ApplyPlanTemplateResult> {
    const template = findPlanTemplate(templateId);
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
}
