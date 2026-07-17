import { DT } from '../utils/designTokens';
import { defaultSurface, SurfaceStyle } from '../utils/themePalette';

// 页面级卡片：双层柔影（外层 ambient + 内层 contact）+ 极淡渐变，无描边。
// surface 可传主题表面（深色主题自动去影换受光渐变）；
// 颜色与阴影都挂了过渡动画，主题切换时平滑渐变。
@Component
export struct AppCard {
  @Prop surface: SurfaceStyle = defaultSurface();
  @Prop cardPadding: number = 20;
  @Prop cardRadius: number = DT.radiusXL;
  @BuilderParam content: () => void;

  build() {
    Column() {
      Column() {
        this.content()
      }
      .width('100%')
      .padding(this.cardPadding)
      .linearGradient({
        angle: 168,
        colors: [[this.surface.cardTop, 0], [this.surface.cardBottom, 1]]
      })
      .animation({ duration: DT.durSlow, curve: Curve.EaseInOut })
      .borderRadius(this.cardRadius)
      .shadow(this.surface.shadowContact)
    }
    .width('100%')
    .borderRadius(this.cardRadius)
    .shadow(this.surface.shadowAmbient)
  }
}
