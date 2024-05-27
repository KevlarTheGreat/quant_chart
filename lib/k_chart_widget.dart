import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_k_chart/chart_translations.dart';
import 'package:flutter_k_chart/extension/map_ext.dart';
import 'package:flutter_k_chart/flutter_k_chart.dart';

enum MainState {
  MA,
  BOLL,
  NONE
}

enum SecondaryState {
  MACD,
  KDJ,
  RSI,
  WR,
  CCI,
  NONE
}

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn];
}

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? data;
  final MainState mainState;
  final bool volHidden;
  final SecondaryState secondaryState;
  final Function()? onSecondaryTap;
  final bool isLine;
  final bool isTapShowInfoDialog; //是否开启单击显示详情数据
  final bool hideGrid;
  final bool showNowPrice;
  final bool showInfoDialog;
  final bool materialInfoDialog; // Material风格的信息弹窗
  final Map<String, ChartTranslations> translations;
  final List<String> timeFormat;

  //当屏幕滚动到尽头会调用，真为拉到屏幕右侧尽头，假为拉到屏幕左侧尽头
  final Function(bool)? onLoadMore;

  final List<int> maDayList;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartColors chartColors;
  final ChartStyle chartStyle;
  final VerticalTextAlignment verticalTextAlignment;
  final bool isTrendLine;
  final double xFrontPadding;
  final String Function(double value)? dataFormat;

  KChartWidget(
    this.data,
    this.chartStyle,
    this.chartColors,
    {
      required this.isTrendLine,
      this.xFrontPadding = 100,
      this.mainState = MainState.MA,
      this.secondaryState = SecondaryState.MACD,
      this.onSecondaryTap,
      this.volHidden = false,
      this.isLine = false,
      this.isTapShowInfoDialog = false,
      this.hideGrid = false,
      this.showNowPrice = true,
      this.showInfoDialog = true,
      this.materialInfoDialog = true,
      this.translations = kChartTranslations,
      this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
      this.onLoadMore,
      this.maDayList = const [5, 10, 20],
      this.flingTime = 600,
      this.flingRatio = 0.5,
      this.flingCurve = Curves.decelerate,
      this.isOnDrag,
      this.verticalTextAlignment = VerticalTextAlignment.left,
      this.dataFormat
    }
  );

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget> with TickerProviderStateMixin {
  double mScaleX = 1.0;
  double mScrollX = 0.0;
  double mSelectX = 0.0;
  StreamController<InfoWindowEntity?>? mInfoWindowStream;
  double mHeight = 0, mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;

  //For TrendLine
  List<TrendLine> lines = [];
  double? changeInXPosition;
  double? changeInYPosition;
  double mSelectY = 0.0;
  bool waitingForOtherPairOfCords = false;
  bool enableCordRecord = false;

  double getMinScrollX() => mScaleX;

  double _lastScale = 1.0;
  bool isLongPress = false;
  bool isOnTap = false;

  @override
  void initState() {
    super.initState();
    mInfoWindowStream = StreamController<InfoWindowEntity?>();
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data != null && widget.data!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }

    final _painter = ChartPainter(
      style: widget.chartStyle,
      colors: widget.chartColors,
      lines: lines, //For TrendLine
      xFrontPadding: widget.xFrontPadding,
      isTrendLine: widget.isTrendLine, //For TrendLine
      selectY: mSelectY, //For TrendLine
      data: widget.data,
      scaleX: mScaleX,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      isOnTap: isOnTap,
      isTapShowInfoDialog: widget.isTapShowInfoDialog,
      mainState: widget.mainState,
      volHidden: widget.volHidden,
      secondaryState: widget.secondaryState,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      sink: mInfoWindowStream?.sink,
      maDayList: widget.maDayList,
      verticalTextAlignment: widget.verticalTextAlignment,
      dataFormat: widget.dataFormat
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

        return GestureDetector(
          onTapUp: (details) {
            if (!widget.isTrendLine && widget.onSecondaryTap != null && _painter.isInSecondaryRect(details.localPosition)) {
              widget.onSecondaryTap!();
            }

            if (!widget.isTrendLine && _painter.isInMainRect(details.localPosition)) {
              isOnTap = true;
              if (mSelectX != details.localPosition.dx &&  widget.isTapShowInfoDialog) {
                mSelectX = details.localPosition.dx;
                notifyChanged();
              }
            }
            if (widget.isTrendLine && !isLongPress && enableCordRecord) {
              enableCordRecord = false;
              Offset p1 = Offset(getTrendLineX(), mSelectY);
              if (!waitingForOtherPairOfCords) lines.add(TrendLine(p1, Offset(-1, -1), trendLineMax!, trendLineScale!));

              if (waitingForOtherPairOfCords) {
                lines.removeLast();
                lines.add(TrendLine(lines.last.p1, p1, trendLineMax!, trendLineScale!));
                waitingForOtherPairOfCords = false;
              } else {
                waitingForOtherPairOfCords = true;
              }
              notifyChanged();
            }
          },
          onScaleUpdate: (details) {
            if (isLongPress) return;
            mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
            mScrollX = (details.focalPointDelta.dx / mScaleX + mScrollX).clamp(0.0, ChartPainter.maxScrollX).toDouble();
            notifyChanged();
          },
          onScaleEnd: (_) {
            _lastScale = mScaleX;
          },
          onLongPressStart: (details) {
            isOnTap = false;
            isLongPress = true;
            if ((mSelectX != details.localPosition.dx ||
                    mSelectY != details.globalPosition.dy) &&
                !widget.isTrendLine) {
              mSelectX = details.localPosition.dx;
              notifyChanged();
            }
            //For TrendLine
            if (widget.isTrendLine && changeInXPosition == null) {
              mSelectX = changeInXPosition = details.localPosition.dx;
              mSelectY = changeInYPosition = details.globalPosition.dy;
              notifyChanged();
            }
            //For TrendLine
            if (widget.isTrendLine && changeInXPosition != null) {
              changeInXPosition = details.localPosition.dx;
              changeInYPosition = details.globalPosition.dy;
              notifyChanged();
            }
          },
          onLongPressMoveUpdate: (details) {
            if ((mSelectX != details.localPosition.dx || mSelectY != details.globalPosition.dy) && !widget.isTrendLine) {
              mSelectX = details.localPosition.dx;
              mSelectY = details.localPosition.dy;
              notifyChanged();
            }
            if (widget.isTrendLine) {
              mSelectX = mSelectX + (details.localPosition.dx - changeInXPosition!);
              changeInXPosition = details.localPosition.dx;
              mSelectY = mSelectY + (details.globalPosition.dy - changeInYPosition!);
              changeInYPosition = details.globalPosition.dy;
              notifyChanged();
            }
          },
          onLongPressEnd: (details) {
            isLongPress = false;
            enableCordRecord = true;
            mInfoWindowStream?.sink.add(null);
            notifyChanged();
          },
          child: Stack(
            children: [
              CustomPaint(size: Size(double.infinity, double.infinity), painter: _painter),
              if (widget.showInfoDialog) _buildInfoDialog()
            ]
          )
        );
      }
    );
  }

  void notifyChanged() => setState(() {});

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
      stream: mInfoWindowStream?.stream,
      builder: (context, snapshot) {
        if ((!isLongPress && !isOnTap) || widget.isLine == true || !snapshot.hasData || snapshot.data?.kLineEntity == null) return Container();

        final entity = snapshot.data!.kLineEntity;
        final upDown = entity.change ?? entity.close - entity.open;
        final upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
        final entityAmount = entity.amount;

        infos = [
          getDate(entity.time),
          format(entity.open),
          format(entity.high),
          format(entity.low),
          format(entity.close),
          '${upDown > 0 ? '+' : ''}${format(upDown)}',
          '${upDownPercent > 0 ? '+' : ''}${upDownPercent.toStringAsFixed(2)}%',
          if (entityAmount != null) entityAmount.toInt().toString()
        ];
        final dialogPadding = 4.0;
        final dialogWidth = mWidth / 3;
        return Container(
          margin: EdgeInsets.only(left: snapshot.data!.isLeft ? dialogPadding : mWidth - dialogWidth - dialogPadding, top: 25),
          width: dialogWidth,
          decoration: BoxDecoration(
            color: widget.chartColors.selectFillColor,
            border: Border.all(color: widget.chartColors.selectBorderColor, width: 0.5)
          ),
          child: ListView.builder(
            padding: EdgeInsets.all(dialogPadding),
            itemCount: infos.length,
            itemExtent: 14.0,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final translations = widget.translations.of(context);
              return _buildItem(infos[index], translations.byIndex(index));
            }
          )
        );
      }
    );
  }

  Widget _buildItem(String info, String infoName) {
    final infoWidget = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(infoName, style: TextStyle(color: widget.chartColors.infoWindowTitleColor, fontSize: 10.0))),
        Text(info, style: TextStyle(color: _getItemColor(info), fontSize: 10.0))
      ]
    );

    return widget.materialInfoDialog ? Material(color: Colors.transparent, child: infoWidget) : infoWidget;
  }

  Color _getItemColor(String info) {
    if (info.startsWith('+')) return widget.chartColors.infoWindowUpColor;
    if (info.startsWith('-')) return widget.chartColors.infoWindowDnColor;
    return widget.chartColors.infoWindowNormalColor;
  }

  String getDate(int? date) => dateFormat(DateTime.fromMillisecondsSinceEpoch(date ?? DateTime.now().millisecondsSinceEpoch), widget.timeFormat);

  String format(double value) {
    if (widget.dataFormat != null) return widget.dataFormat!(value);
    return value.toStringAsFixed(_length);
  }

  int get _length {
    if (widget.data?.isEmpty ?? true) return 2;

    final t = widget.data!.first;
    return NumberUtil.getMaxDecimalLength(t.open, t.close, t.high, t.low);
  }
}
