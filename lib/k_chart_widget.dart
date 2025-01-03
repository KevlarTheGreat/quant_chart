import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:quant_chart/chart_translations.dart';
import 'package:quant_chart/extension/map_ext.dart';
import 'package:quant_chart/quant_chart.dart';

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn
  ];
}

class QuantChartWidget extends StatefulWidget {
  final List<KLineEntity>? data;
  final MainState mainState;
  final bool volHidden;
  final SecondaryState secondaryState;
  final bool isLine;
  final bool isTapShowInfoDialog; // Whether to enable tap to show detailed data
  final bool hideGrid;
  final bool showNowPrice;
  final bool showInfoDialog;
  final Map<String, ChartTranslations> translations;
  final List<String> timeFormat;

  /// Called when the screen scrolls to the end. True if scrolled to the
  /// right end, false if scrolled to the left end.
  final Function(bool)? onLoadMore;

  final List<int> maDayList;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartStyle style;
  final bool isTrendLine;
  final double xFrontPadding;
  final String Function(double value)? dataFormat;

  QuantChartWidget(
      {required this.data,
      required this.style,
      required this.isTrendLine,
      this.xFrontPadding = 100,
      // The type of indicator displayed in the main area
      this.mainState = MainState.MA,
      // The type of indicator displayed in the secondary area
      this.secondaryState = SecondaryState.MACD,
      this.volHidden = false,
      this.isLine = false,
      this.isTapShowInfoDialog = false,
      this.hideGrid = false,
      this.showNowPrice = true,
      this.showInfoDialog = true,
      this.translations = quantChartTranslations,
      this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
      this.onLoadMore,
      this.maDayList = const [5, 10, 20],
      this.flingTime = 600,
      this.flingRatio = 0.5,
      this.flingCurve = Curves.decelerate,
      this.isOnDrag,
      this.dataFormat});

  @override
  _QuantChartWidgetState createState() => _QuantChartWidgetState();
}

class _QuantChartWidgetState extends State<QuantChartWidget>
    with TickerProviderStateMixin {
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

  ChartStyle get _style => widget.style;

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
        style: _style,
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
        dataFormat: widget.dataFormat);

    return LayoutBuilder(builder: (context, constraints) {
      mHeight = constraints.maxHeight;
      mWidth = constraints.maxWidth;

      return Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            // Adjust the scale factor based on scroll delta
            double zoomAmount = pointerSignal.scrollDelta.dy * 0.001;
            mScaleX = (mScaleX + zoomAmount).clamp(0.5, 2.2);
            notifyChanged();
          }
        },
        child: GestureDetector(
            onTapUp: (details) {
              _stopAnimation();
              if (isLongPress || (isOnTap && widget.isTapShowInfoDialog)) {
                isOnTap = false;
                isLongPress = false;
                notifyChanged();
                return;
              }

              if (!widget.isTrendLine &&
                  _painter.isInMainRect(details.localPosition)) {
                isOnTap = true;
                if (mSelectX != details.localPosition.dx &&
                    widget.isTapShowInfoDialog) {
                  mSelectX = details.localPosition.dx;
                  notifyChanged();
                }
              }
              if (widget.isTrendLine && !isLongPress && enableCordRecord) {
                enableCordRecord = false;
                Offset p1 = Offset(trendLineX, mSelectY);
                if (!waitingForOtherPairOfCords)
                  lines.add(TrendLine(
                      p1, Offset(-1, -1), trendLineMax!, trendLineScale!));

                if (waitingForOtherPairOfCords) {
                  lines.removeLast();
                  lines.add(TrendLine(
                      lines.last.p1, p1, trendLineMax!, trendLineScale!));
                  waitingForOtherPairOfCords = false;
                } else {
                  waitingForOtherPairOfCords = true;
                }
                notifyChanged();
              }
            },
            onScaleStart: (details) {
              isOnTap = false;
            },
            onScaleUpdate: (details) {
              if (isLongPress) return;
              mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
              mScrollX = (details.focalPointDelta.dx / mScaleX + mScrollX)
                  .clamp(0.0, ChartPainter.maxScrollX + widget.xFrontPadding)
                  .toDouble();
              notifyChanged();
            },
            onScaleEnd: (details) {
              _lastScale = mScaleX;
              var velocity = details.velocity.pixelsPerSecond.dx;
              _onFling(velocity);
            },
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: (details) {
              if ((mSelectX != details.localPosition.dx ||
                      mSelectY != details.globalPosition.dy) &&
                  !widget.isTrendLine) {
                mSelectX = details.localPosition.dx;
                mSelectY = details.localPosition.dy;
                notifyChanged();
              }
              if (widget.isTrendLine) {
                mSelectX =
                    mSelectX + (details.localPosition.dx - changeInXPosition!);
                changeInXPosition = details.localPosition.dx;
                mSelectY =
                    mSelectY + (details.globalPosition.dy - changeInYPosition!);
                changeInYPosition = details.globalPosition.dy;
                notifyChanged();
              }
            },
            onLongPressEnd: (details) {
              if (widget.isTapShowInfoDialog) return;

              isLongPress = false;
              enableCordRecord = true;
              mInfoWindowStream?.sink.add(null);
              notifyChanged();
            },
            child: Stack(children: [
              CustomPaint(
                  size: Size(double.infinity, double.infinity),
                  painter: _painter),
              if (widget.showInfoDialog) _buildInfoDialog()
            ])),
      );
    });
  }

  void notifyChanged() => setState(() {});

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
        stream: mInfoWindowStream?.stream,
        builder: (_, snapshot) {
          if ((!isOnTap && !isLongPress) || widget.isLine)
            return SizedBox.shrink();
          if (!snapshot.hasData || snapshot.data?.kLineEntity == null)
            return SizedBox.shrink();
          if (snapshot.data!.isShow && !isLongPress) return SizedBox.shrink();

          final entity = snapshot.data!.kLineEntity;
          final upDown = entity.change ?? entity.close - entity.open;
          final upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
          final entityAmount = entity.amount;

          final infos = [
            getDate(entity.time),
            format(entity.open),
            format(entity.high),
            format(entity.low),
            format(entity.close),
            '${upDown > 0 ? '+' : ''}${format(upDown)}',
            '${upDownPercent > 0 ? '+' : ''}${upDownPercent.toStringAsFixed(2)}%',
            if (entityAmount != null) entityAmount.toInt().toString()
          ];
          final edge = _style.select.margin.left;
          final width = _style.select.width ?? mWidth / 3;

          snapshot.data!.show();
          return Container(
              margin: EdgeInsets.only(
                  left: snapshot.data!.isLeft ? edge : mWidth - width - edge,
                  top: _style.select.margin.top),
              padding: _style.select.padding,
              width: width,
              decoration: BoxDecoration(
                  color: _style.select.colors.fill,
                  border: Border.all(
                      color: _style.select.colors.border, width: 0.5),
                  borderRadius: _style.select.radius),
              child: ListView.builder(
                  itemCount: infos.length,
                  itemExtent: 14.0,
                  shrinkWrap: true,
                  itemBuilder: (c, i) => _buildItem(
                      infos[i], widget.translations.of(c).byIndex(i))));
        });
  }

  Widget _buildItem(String info, String infoName) {
    return Material(
        color: Colors.transparent,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                  child: Text(infoName,
                      style: TextStyle(
                          color: _style.select.colors.text,
                          fontSize: _style.select.fontSize))),
              Text(info,
                  style: TextStyle(
                      color: _getItemColor(info),
                      fontSize: _style.select.fontSize))
            ]));
  }

  Color _getItemColor(String info) {
    if (info.startsWith('+')) return _style.select.colors.upText;
    if (info.startsWith('-')) return _style.select.colors.downText;
    return _style.select.colors.text;
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
      widget.timeFormat);

  String format(double value) {
    if (widget.dataFormat != null) return widget.dataFormat!(value);
    return value.toStringAsFixed(_length);
  }

  int get _length {
    if (widget.data?.isEmpty ?? true) return 2;

    final t = widget.data!.first;
    return NumberUtil.getMaxDecimalLength(t.open, t.close, t.high, t.low);
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: 1000), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(CurvedAnimation(
            parent: _controller!.view, curve: widget.flingCurve));
    aniX!.addListener(() {
      mScrollX = aniX!.value;

      if (mScrollX <= 0) {
        mScrollX = 0;
        _onLoadMore(true);
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX - widget.xFrontPadding) {
        _onLoadMore(false);
        if (mScrollX >= ChartPainter.maxScrollX + widget.xFrontPadding) {
          mScrollX = ChartPainter.maxScrollX;
          _stopAnimation();
        }
      }

      notifyChanged();
    });

    _controller!.forward();
  }

  void _onLoadMore(bool status) {
    if (widget.onLoadMore == null) return;
    widget.onLoadMore!(status);
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      if (needNotify) notifyChanged();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
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
  }
}

enum MainState { MA, BOLL, NONE }

enum SecondaryState { MACD, KDJ, RSI, WR, CCI, NONE }
