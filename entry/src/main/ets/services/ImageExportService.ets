import componentSnapshot from '@ohos.arkui.componentSnapshot';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import { ErrorLogService } from './ErrorLogService';

export interface ImageExportResult {
  saved: boolean;
  message: string;
}

export class ImageExportService {
  /**
   * 截取指定组件 id 的渲染快照，打包为 PNG 并通过系统文件选择器保存。
   * 组件必须在当前窗口内可见（componentSnapshot.get 的系统约束）。
   */
  static async saveComponentAsPng(componentId: string, fileName: string): Promise<ImageExportResult> {
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      pixelMap = await componentSnapshot.get(componentId);
    } catch (error) {
      await ErrorLogService.record('export', `组件截图失败：${error instanceof Error ? error.message : error}`);
      return { saved: false, message: '生成图片失败，请回到页面顶部后重试' };
    }

    let packedBuffer: ArrayBuffer;
    const imagePacker = image.createImagePacker();
    try {
      packedBuffer = await imagePacker.packing(pixelMap, {
        format: 'image/png',
        quality: 100
      });
    } catch (error) {
      await ErrorLogService.record('export', `图片打包失败：${error instanceof Error ? error.message : error}`);
      return { saved: false, message: '生成图片失败，可稍后再试' };
    } finally {
      await imagePacker.release();
      await pixelMap.release();
    }

    const saveOptions = new picker.PhotoSaveOptions();
    saveOptions.newFileNames = [fileName];

    let uris: string[] = [];
    try {
      const photoPicker = new picker.PhotoViewPicker();
      uris = await photoPicker.save(saveOptions);
    } catch (error) {
      await ErrorLogService.record('export', `图片保存选择器打开失败：${error instanceof Error ? error.message : error}`);
      return { saved: false, message: '未完成保存，可稍后再试' };
    }

    if (uris.length === 0) {
      return { saved: false, message: '已取消保存' };
    }

    try {
      const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, packedBuffer);
      fs.closeSync(file);
    } catch (error) {
      await ErrorLogService.record('export', `图片写入失败：${error instanceof Error ? error.message : error}`);
      return { saved: false, message: '保存失败，请检查存储空间' };
    }

    return { saved: true, message: '报告长图已保存到相册' };
  }
}
