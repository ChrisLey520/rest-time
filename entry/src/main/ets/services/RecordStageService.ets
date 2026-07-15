import { SessionService } from './SessionService';
import { createRecordStageSnapshot, RecordStage, RecordStageSnapshot } from '../utils/recordStageCore';

export { RecordStage, RecordStageSnapshot };

export class RecordStageService {
  static async getSnapshot(): Promise<RecordStageSnapshot> {
    const sessions = await SessionService.listAll();
    return createRecordStageSnapshot(sessions, Date.now());
  }
}
