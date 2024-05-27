import 'package:flutter/material.dart';
import 'package:flutter_k_chart/flutter_k_chart.dart';

class VolRenderer extends BaseChartRenderer<VolumeEntity> {
  late double mVolWidth;
  final ChartStyle style;
  final ChartColors colors;
  final String Function(double value)? dataFormat;

  VolRenderer({
    required Rect rect,
    required double maxValue,
    required double minValue,
    required double topPadding,
    required this.style,
    required this.colors,
    this.dataFormat
  }) : super(
    chartRect: rect,
    maxValue: maxValue,
    minValue: minValue,
    topPadding: topPadding,
    dataFormat: dataFormat,
    gridColor: colors.gridColor
  ) {
    mVolWidth = this.style.volWidth;
  }

  @override
  void drawChart(VolumeEntity lastPoint, VolumeEntity curPoint, double lastX,
      double curX, Size size, Canvas canvas) {
    double r = mVolWidth / 2;
    double top = getVolY(curPoint.vol);
    double bottom = chartRect.bottom;
    if (curPoint.vol != 0) {
      canvas.drawRect(
        Rect.fromLTRB(curX - r, top, curX + r, bottom),
        chartPaint..color = curPoint.close > curPoint.open ? this.colors.upColor : this.colors.dnColor
      );
    }

    if (lastPoint.MA5Volume != 0) {
      drawLine(lastPoint.MA5Volume, curPoint.MA5Volume, canvas, lastX, curX, this.colors.ma5Color);
    }

    if (lastPoint.MA10Volume != 0) {
      drawLine(lastPoint.MA10Volume, curPoint.MA10Volume, canvas, lastX, curX, this.colors.ma10Color);
    }
  }

  double getVolY(double value) => (maxValue - value) * (chartRect.height / maxValue) + chartRect.top;

  @override
  void drawText(Canvas canvas, VolumeEntity data, double x) {
    TextSpan span = TextSpan(
      children: [
        TextSpan(
            text: "VOL:${NumberUtil.format(data.vol)}    ",
            style: getTextStyle(this.colors.volColor)),
        if (data.MA5Volume.notNullOrZero)
          TextSpan(
              text: "MA5:${NumberUtil.format(data.MA5Volume!)}    ",
              style: getTextStyle(this.colors.ma5Color)),
        if (data.MA10Volume.notNullOrZero)
          TextSpan(
              text: "MA10:${NumberUtil.format(data.MA10Volume!)}    ",
              style: getTextStyle(this.colors.ma10Color)),
      ],
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawVerticalText(canvas, textStyle, int gridRows) {
    TextSpan span =
        TextSpan(text: "${NumberUtil.format(maxValue)}", style: textStyle);
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(
        canvas, Offset(chartRect.width - tp.width, chartRect.top - topPadding));
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    canvas.drawLine(Offset(0, chartRect.bottom),
        Offset(chartRect.width, chartRect.bottom), gridPaint);
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= columnSpace; i++) {
      //vol垂直线
      canvas.drawLine(Offset(columnSpace * i, chartRect.top - topPadding),
          Offset(columnSpace * i, chartRect.bottom), gridPaint);
    }
  }
}
