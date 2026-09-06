export function calculateCropGeometry(monitors, barWidgets, options = {}) {
  if (!Array.isArray(monitors) || monitors.length === 0) return null;
  if (!Array.isArray(barWidgets)) return null;

  const widgetId = options.widgetId || 'denial.beeper-relay';
  const widget = barWidgets.find(w => w && w.id === widgetId);
  if (!widget) return null;

  const monitor = monitors.find(m => m && m.focused) || monitors[0];
  const cardWidth = options.cardWidth || 400;
  const cardHeight = options.cardHeight || 310;
  const margin = options.margin || 5;
  const paddingX = options.paddingX || 20;
  const paddingY = options.paddingY || 30;

  const anchorCenterX = widget.x + widget.width / 2;
  let cardX = anchorCenterX - cardWidth / 2;

  cardX = Math.max(margin, Math.min(cardX, monitor.width - cardWidth - margin));

  const captureX = Math.max(0, Math.floor(cardX - paddingX));
  const captureY = Math.max(0, widget.y);
  const captureW = Math.min(monitor.width - captureX, Math.ceil(cardWidth + paddingX * 2));
  const captureH = Math.min(monitor.height - captureY, Math.ceil(cardHeight + (widget.height || 26) + paddingY));

  const globalX = monitor.x + captureX;
  const globalY = monitor.y + captureY;

  return {
    monitor,
    widget,
    x: globalX,
    y: globalY,
    width: captureW,
    height: captureH,
    geomString: `${globalX},${globalY} ${captureW}x${captureH}`
  };
}
