import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { CsvExportFile } from '../utils/csvExportCore';
import { ErrorLogService } from './ErrorLogService';

export interface FileExportResult {
  savedCount: number;
  message: string;
}

// CSV 带 BOM，避免在表格软件中打开出现中文乱码。
const UTF8_BOM = '﻿';

export class FileExportService {
  static async saveCsvFiles(files: CsvExportFile[]): Promise<FileExportResult> {
    if (files.length === 0) {
      return { savedCount: 0, message: '没有可导出的内容' };
    }

    const saveOptions = new picker.DocumentSaveOptions();
    saveOptions.newFileNames = files.map((file: CsvExportFile) => file.fileName);

    let uris: string[] = [];
    try {
      const documentPicker = new picker.DocumentViewPicker();
      uris = await documentPicker.save(saveOptions);
    } catch (error) {
      await ErrorLogService.record('export', `文档选择器打开失败：${error instanceof Error ? error.message : error}`);
      return { savedCount: 0, message: '未完成保存，可稍后再试' };
    }

    if (uris.length === 0) {
      return { savedCount: 0, message: '已取消保存' };
    }

    let savedCount = 0;
    for (let index = 0; index < uris.length && index < files.length; index += 1) {
      try {
        const file = fs.openSync(uris[index], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        fs.writeSync(file.fd, `${UTF8_BOM}${files[index].content}`);
        fs.closeSync(file);
        savedCount += 1;
      } catch (error) {
        // 单个文件失败不阻塞其余文件，最终以 savedCount 反馈结果。
        await ErrorLogService.record('export', `CSV 写入失败：${files[index].fileName}`);
      }
    }

    if (savedCount === 0) {
      return { savedCount, message: '保存失败，请检查存储权限或剩余空间' };
    }

    if (savedCount < files.length) {
      return { savedCount, message: `已保存 ${savedCount}/${files.length} 个文件，部分失败` };
    }

    return { savedCount, message: `已保存 ${savedCount} 个 CSV 文件` };
  }
}
