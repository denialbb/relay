.pragma library

function formatItem(h, kCol, aCol) {
  var key = h.key;
  var label = (h.label || "").replace(/ /g, "\u00A0");
  return "<font color='" + kCol + "'>" + key + "</font>\u00A0<font color='" + aCol + "'>" + label + "</font>";
}

function formatSingleLine(hints, kCol, aCol) {
  var parts = [];
  for (var i = 0; i < hints.length; i++) {
    if (hints[i]) parts.push(formatItem(hints[i], kCol, aCol));
  }
  return parts.join(" <font color='" + kCol + "'>·</font> ");
}

function formatMultiLine(hints, kCol, aCol, perLine) {
  var limit = perLine || 4;
  var lines = [];
  var current = [];
  for (var i = 0; i < hints.length; i++) {
    if (!hints[i]) continue;
    current.push(formatItem(hints[i], kCol, aCol));
    if (current.length >= limit) {
      lines.push(current.join(" <font color='" + kCol + "'>·</font> "));
      current = [];
    }
  }
  if (current.length > 0) {
    lines.push(current.join(" <font color='" + kCol + "'>·</font> "));
  }
  return lines.join("<br>");
}

function formatHints(hints, expanded, kCol, aCol) {
  if (!hints || !hints.length) return "";
  if (!expanded) {
    return formatSingleLine(hints, kCol, aCol);
  }
  return formatMultiLine(hints, kCol, aCol, 4);
}
