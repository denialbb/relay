// Stub: explicit error state. input: error. output: retry(). Never renders failure as empty.
import QtQuick

Item {
    property string error: ""
    signal retry()
}
