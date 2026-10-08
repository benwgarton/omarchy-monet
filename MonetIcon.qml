import QtQuick
import QtQuick.Shapes
import qs.Commons

// Monet's mark for the bar and the panel: a serif M in one color, so it takes
// the bar's text color like every other bar icon. An optional dot in the top
// corner says something is waiting.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool dotVisible: false
  property color dotColor: color

  readonly property real stroke: Math.max(1.4, iconSize * 0.15)
  readonly property real serif: Math.max(1, iconSize * 0.11)

  width: Math.round(iconSize * 1.2)
  height: Math.round(iconSize)
  implicitWidth: width
  implicitHeight: height

  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    // The two stems and the V between them.
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.stroke
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: root.width * 0.17
      startY: root.height * 0.9
      PathLine { x: root.width * 0.17; y: root.height * 0.12 }
      PathLine { x: root.width * 0.5; y: root.height * 0.7 }
      PathLine { x: root.width * 0.83; y: root.height * 0.12 }
      PathLine { x: root.width * 0.83; y: root.height * 0.9 }
    }

    // Feet and head serifs.
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.serif
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap
      startX: root.width * 0.02
      startY: root.height * 0.9 - root.serif / 2
      PathLine { x: root.width * 0.32; y: root.height * 0.9 - root.serif / 2 }
      PathMove { x: root.width * 0.68; y: root.height * 0.9 - root.serif / 2 }
      PathLine { x: root.width * 0.98; y: root.height * 0.9 - root.serif / 2 }
      PathMove { x: root.width * 0.02; y: root.height * 0.12 + root.serif / 2 }
      PathLine { x: root.width * 0.2; y: root.height * 0.12 + root.serif / 2 }
      PathMove { x: root.width * 0.8; y: root.height * 0.12 + root.serif / 2 }
      PathLine { x: root.width * 0.98; y: root.height * 0.12 + root.serif / 2 }
    }
  }

  Rectangle {
    visible: root.dotVisible
    width: Math.max(4, Math.round(root.iconSize * 0.38))
    height: width
    radius: width / 2
    color: root.dotColor
    x: root.width - width * 0.55
    y: -height * 0.3
  }
}
