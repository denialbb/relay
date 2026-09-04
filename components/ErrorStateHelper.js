.pragma library

var ERROR_MESSAGES = {
  "beeper-unavailable": "Beeper Desktop is unreachable. Make sure Beeper is running.",
  "unauthorized": "Connection unauthorized. Please check your Beeper credentials.",
  "rate-limited": "Too many requests. Please wait a moment before retrying.",
  "server-error": "Beeper local server encountered an error.",
  "invalid-response": "Received an invalid response from Beeper.",
  "unknown": "An unexpected error occurred."
};

function humanErrorMessage(err) {
  if (!err) return "An unexpected error occurred.";
  var msg = ERROR_MESSAGES[err];
  if (msg) return msg;
  return "Error: " + err;
}
