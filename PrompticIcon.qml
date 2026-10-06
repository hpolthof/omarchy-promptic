import QtQuick
import QtQuick.Shapes

// Promptic's mark: a speech bubble holding a command prompt (> _) with a
// spark of AI in the corner. Strokes on a 24-unit grid so it follows the
// theme colour and stays crisp at any size. Source artwork: assets/promptic.svg.
Item {
  id: root

  property real size: 16
  property color color: "white"
  property real strokeWidth: 1.5

  implicitWidth: size
  implicitHeight: size

  Shape {
    width: 24
    height: 24
    scale: root.size / 24
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      // Bubble with its tail.
      PathSvg { path: "M5.5 8 H14.5 A3 3 0 0 1 17.5 11 V15 A3 3 0 0 1 14.5 18 H10.5 L6 21.5 V18 H5.5 A3 3 0 0 1 2.5 15 V11 A3 3 0 0 1 5.5 8 Z" }
    }
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      // The prompt: chevron and cursor.
      PathSvg { path: "M6.5 11.2 L9.3 13 L6.5 14.8 M11 14.8 H13.8" }
    }
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      // The spark.
      PathSvg { path: "M19 1.2 Q19.4 4.1 22.3 4.5 Q19.4 4.9 19 7.8 Q18.6 4.9 15.7 4.5 Q18.6 4.1 19 1.2 Z" }
    }
  }
}
