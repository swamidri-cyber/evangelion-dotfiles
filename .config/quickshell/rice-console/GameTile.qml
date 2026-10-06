// Tarjeta de un juego: portada (o tarjeta con el título si no hay imagen),
// tienda arriba a la derecha, sistema donde está instalado abajo a la izquierda.
import QtQuick
import QtQuick.Effects

Item {
    id: tile
    required property var game
    property bool   selected: false
    property var    theme                     // colores y fuente (root.theme)
    property bool   compact: false            // biblioteca: badges más chicos

    readonly property string art: game.art?.cover ?? game.art?.header ?? ""
    readonly property bool   portrait: !!game.art?.cover

    // Glifos (Nerd Font) o etiquetas de texto para cada tienda
    readonly property var stores: ({
        steam:   { glyph: "", label: "" },
        xbox:    { glyph: "\u{f05b9}", label: "" },
        epic:    { glyph: "", label: "EPIC" },
        gog:     { glyph: "", label: "GOG" },
        ea:      { glyph: "", label: "EA" },
        ubisoft: { glyph: "", label: "UBI" },
        riot:    { glyph: "", label: "RIOT" },
        roblox:  { glyph: "", label: "RBX" },
        local:   { glyph: "", label: "PC" }
    })
    readonly property var store: stores[game.store] ?? { glyph: "", label: "?" }

    scale: selected ? 1.12 : 1.0
    z: selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // Brillo verde alrededor de la seleccionada
    Rectangle {
        anchors.fill: frame
        anchors.margins: -3
        radius: 7
        color: "transparent"
        border.width: 2
        border.color: tile.theme.hi
        opacity: tile.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        layer.enabled: tile.selected
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: tile.theme.glow; shadowBlur: 1.0; blurMax: 32; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 5
        color: tile.theme.deep
        border.width: 1
        border.color: tile.selected ? tile.theme.hi : tile.theme.line
        clip: true

        // Portada vertical: llena la tarjeta. Imagen horizontal (cabecera):
        // entera, arriba del centro, con el título abajo.
        Image {
            id: img
            anchors.fill: tile.portrait ? parent : undefined
            anchors.margins: tile.portrait ? 1 : 0
            width: parent.width - 2
            height: tile.portrait ? parent.height - 2 : width * 0.47
            x: 1
            y: tile.portrait ? 1 : parent.height * 0.36 - height / 2
            source: tile.art
            fillMode: tile.portrait ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            sourceSize.width: 400
            opacity: status === Image.Ready ? (tile.game.installed ? 1 : 0.42) : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }

        Text {
            visible: !tile.portrait && img.status === Image.Ready
            anchors { left: parent.left; right: parent.right; margins: 10 }
            y: img.y + img.height + (tile.compact ? 10 : 16)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: tile.game.title.toUpperCase()
            font.family: tile.theme.font
            font.pixelSize: tile.compact ? 12 : 15
            color: tile.theme.fg
        }

        // Sin imagen: tarjeta de texto
        Column {
            visible: img.status !== Image.Ready
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 10
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.game.store === "xbox" && tile.game.title.startsWith("Minecraft") ? "\u{f0373}" : "\u{f05ba}"
                font.family: tile.theme.font
                font.pixelSize: tile.compact ? 30 : 44
                color: tile.theme.dim
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: tile.game.title.toUpperCase()
                font.family: tile.theme.font
                font.pixelSize: tile.compact ? 13 : 17
                color: tile.theme.fg
            }
        }

        // Rayado de "no instalado"
        Rectangle {
            visible: !tile.game.installed
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: tile.compact ? 18 : 22
            color: Qt.rgba(0, 0, 0, 0.7)
            Text {
                anchors.centerIn: parent
                text: "NO INSTALADO"
                font.family: tile.theme.font
                font.pixelSize: tile.compact ? 10 : 12
                color: tile.theme.dim
            }
        }
    }

    // Tienda: arriba a la derecha, en chiquito
    Rectangle {
        anchors.top: frame.top; anchors.right: frame.right
        anchors.margins: tile.compact ? 4 : 6
        width: badge.implicitWidth + (tile.compact ? 8 : 10)
        height: tile.compact ? 18 : 22
        radius: 3
        color: Qt.rgba(0.01, 0.05, 0.025, 0.82)
        border.width: 1
        border.color: tile.theme.line
        Text {
            id: badge
            anchors.centerIn: parent
            text: tile.store.glyph || tile.store.label
            font.family: tile.theme.font
            font.pixelSize: tile.store.glyph ? (tile.compact ? 13 : 16) : (tile.compact ? 10 : 12)
            color: tile.theme.fg
        }
    }

    // Sistema donde se juega: abajo a la izquierda
    Text {
        visible: tile.game.installed
        anchors.left: frame.left; anchors.bottom: frame.bottom
        anchors.margins: tile.compact ? 5 : 7
        text: (tile.game.installedOn ?? []).includes("linux") ? "" : ""
        font.family: tile.theme.font
        font.pixelSize: tile.compact ? 13 : 16
        color: tile.theme.hi
        style: Text.Outline
        styleColor: "#000"
    }
}
