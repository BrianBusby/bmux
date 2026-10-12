# Stage 2 visual evidence

Open `comparison.html` for the supplied reference alongside native material
previews and same-size isolated app captures. This stage adds drawing primitives;
it does not yet change app views. All stage 1 baseline deviations still apply.

The `*-surfaces.png` images are actual SwiftUI ImageRenderer output at 1092 × 593
points, scale 2. The app baselines are nominal-resolution debug window captures.
Texture is off. The gallery uses diagnostic labels and layouts, not final product
content, typography, or interaction. Selection marks, card movement, accessibility
traits and control hit targets belong to the upcoming component integration.

To regenerate the gallery from the repository root on macOS:

```sh
swiftc -parse-as-library Packages/macOS/BmuxAppKitSupportUI/Sources/BmuxAppKitSupportUI/Matte/*.swift docs/design/matte-skin/verification-stage2/render-surfaces.swift -o /tmp/bmux-matte-stage2-render
/tmp/bmux-matte-stage2-render /tmp
```

Native adaptation: outer shadow radius is CSS blur / 2; negative spread contracts
the caster. Raised edges use a 1pt diagonal gradient stroke. Recessed shadows use
concentric fading strokes sized from the inset tokens. These approximate native
versus CSS shadow kernels without live blur views or rendering loops. Exact
browser raster parity is not claimed. Colors, radii, contact/ambient ingredients,
focus geometry and state precedence use the authoritative tokens.
