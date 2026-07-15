import { StarterPlan, createStarterPlan } from '../utils/starterCore';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';

export { StarterPlan };

export class StarterPlanService {
  static async getPlan(): Promise<StarterPlan> {
    const sessions = await SessionService.listAll();
    const config = await StorageService.getConfig();
    return createStarterPlan(sessions, config.focusMinutes);
  }
}
