mixin CandleEntity {
  late double open;
  late double high;
  late double low;
  late double close;

  List<double>? maValueList;

  /// Upper track line
  double? up;

  /// Middle track line
  double? mb;

  /// Lower track line
  double? dn;

  double? BOLLMA;
}
