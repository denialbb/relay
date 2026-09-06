.pragma library

function stripHtml(s) {
  return (s || "").replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
}

function truncate(s, max) {
  if (s.length <= max) return s;
  return s.slice(0, max - 3).trimEnd() + "...";
}

function formatSnippet(chat) {
  if (!chat) return "";
  var preview = chat.preview;
  if (!preview) return "";
  if (preview.kind !== "text") return "Unsupported message";
  var text = stripHtml(preview.text);
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
