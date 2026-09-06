.pragma library

function stripHtml(s) {
  return (s || "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, " ");
}

function extractFirstLine(s) {
  var stripped = stripHtml(s);
  var lines = stripped.split("\n");
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/\s+/g, " ").trim();
    if (line.length > 0) return line;
  }
  return "";
}

function truncate(s, max) {
  if (s.length <= max) return s;
  return s.slice(0, max - 3).replace(/\s+$/, "") + "...";
}

function formatSnippet(chat) {
  if (!chat) return "";
  var preview = chat.preview;
  if (!preview) return "";
  if (preview.kind !== "text") return "Unsupported message";
  var text = extractFirstLine(preview.text);
  if (chat.type === "group" && preview.senderName) {
    return truncate(preview.senderName + ": " + text, 90);
  }
  return truncate(text, 90);
}

function formatTimestamp(isoStr) {
  if (!isoStr) return "";
  var d = new Date(isoStr);
  if (isNaN(d.getTime())) return "";
  var now = new Date();
  if (d.toDateString() === now.toDateString()) {
    return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }
  return d.toLocaleDateString([], { month: "short", day: "numeric" });
}

function getInitials(title) {
  if (!title) return "?";
  var trimmed = title.trim();
  if (trimmed.length === 0) return "?";
  return trimmed.charAt(0).toUpperCase();
}
