import 'package:flutter/material.dart';

export '../chart_style.dart';

abstract class BaseChartRenderer<T> {
  double maxValue;
  double minValue;
  late double scaleY;
  double topPadding;
  Rect chartRect;
  final String Function(double value)? dataFormat;

  Paint chartPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 1.0
    ..color = Colors.red;
  Paint gridPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..strokeWidth = 0.5
    ..color = Color(0xff4c5c74);

  BaseChartRenderer({
    required this.chartRect,
    required this.maxValue,
    required this.minValue,
    required this.topPadding,
    required Color gridColor,
    this.dataFormat
  }) {
    if (maxValue == minValue) {
      maxValue *= 1.5;
      minValue /= 2;
    }
    scaleY = chartRect.height / (maxValue - minValue);
    gridPaint.color = gridColor;
  }

  double getY(double y) => (maxValue - y) * scaleY + chartRect.top;

  String format(double? n) {
    if (n == null || n.isNaN) return '0.00';
    if (dataFormat != null) return dataFormat!(n);

    return n.toStringAsFixed(2);
  }

  void drawGrid(Canvas canvas, int gridRows, int gridColumns);

  void drawText(Canvas canvas, T data, double x);

  void drawVerticalText(canvas, textStyle, int gridRows);

  void drawChart(T lastPoint, T curPoint, double lastX, double curX, Size size, Canvas canvas);

  void drawLine(double? lastPrice, double? curPrice, Canvas canvas, double lastX, double curX, Color color) {
    if (lastPrice == null || curPrice == null) return;

    final lastY = getY(lastPrice);
    final curY = getY(curPrice);
    canvas.drawLine(Offset(lastX, lastY), Offset(curX, curY), chartPaint..color = color);
  }

  TextStyle getTextStyle(Color color) {
    return TextStyle(fontSize: 10.0, color: color);
  }
}
