import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import '../../utils/app_theme.dart';
import '../../utils/flight_route_utils.dart';
import '../../widgets/common/app_text.dart';
import '../boarding/boarding_pass_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dimensions
// ─────────────────────────────────────────────────────────────────────────────

const _kSeatSz   = 44.0;
const _kSeatGap  = 6.0;
const _kAisleW   = 40.0;
const _kWallW    = 22.0;   // fuselage side wall (windows)
const _kFuselageMaxW = 400.0;

/// Width of the seat map (walls + 6 seats + aisle).
double get _kSeatMapWidth =>
    _kWallW * 2 +
    _kSeatSz * 6 +
    _kSeatGap * 4 +
    _kAisleW;
const _kBizGap   = 14.0;   // row gap in business
const _kEcoGap   =  8.0;   // row gap in economy

// ─────────────────────────────────────────────────────────────────────────────
// Cabin sections
// ─────────────────────────────────────────────────────────────────────────────

const _kBizRows      = [1, 2, 3, 4];
const _kEcoFront     = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
const _kOverwing     = [17, 18];
const _kEcoRear      = [19, 20, 21, 22, 23, 24, 25, 26, 27];
const _kCols         = ['A', 'B', 'C', 'D', 'E', 'F'];
const _kLeftCols     = ['A', 'B', 'C'];
const _kRightCols    = ['D', 'E', 'F'];

// ─────────────────────────────────────────────────────────────────────────────
// Seat model
// ─────────────────────────────────────────────────────────────────────────────

enum _SeatState { available, taken }

class _Seat {
  final int row;
  final String col;
  final _SeatState state;
  final bool isBiz;

  const _Seat({
    required this.row,
    required this.col,
    required this.state,
    required this.isBiz,
  });

  String get code => '${row.toString().padLeft(2, '0')}$col';

  bool get isWindow => col == 'A' || col == 'F';
  bool get isAisle  => col == 'C' || col == 'D';
  bool get isMiddle => col == 'B' || col == 'E';

  String get cabinLabel => isBiz ? 'Business' : 'Economy';

  String get positionLabel {
    if (isWindow) return 'Window';
    if (isAisle) return 'Aisle';
    return 'Middle';
  }

  String get typeLabel => '$positionLabel · $cabinLabel';

  String get typeDesc => 'Row $row';
}

// Deterministic "random" taken seats — same result every build
bool _isTaken(int row, String col, bool biz) {
  final s = (row * 17 + col.codeUnitAt(0) * 11) % 100;
  if (biz) {
    if (col == 'A' || col == 'F') return s < 20;
    return s < 50;
  }
  if (col == 'A' || col == 'F') return s < 28;
  if (col == 'C' || col == 'D') return s < 62;
  return s < 78;
}

List<_Seat> _buildSeats() {
  final all = [
    ..._kBizRows.map((r) => (r, true)),
    ..._kEcoFront.map((r) => (r, false)),
    ..._kOverwing.map((r) => (r, false)),
    ..._kEcoRear.map((r)  => (r, false)),
  ];
  return [
    for (final (row, biz) in all)
      for (final col in _kCols)
        _Seat(
          row:   row,
          col:   col,
          isBiz: biz,
          state: _isTaken(row, col, biz)
              ? _SeatState.taken
              : _SeatState.available,
        ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Fuselage silhouette + deck (aisle carpet, hull walls, wing band)
// ─────────────────────────────────────────────────────────────────────────────

class _FuselageClipper extends CustomClipper<Path> {
  const _FuselageClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const noseDepth = 128.0;
    const tailR = 28.0;

    return Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.94, 4, w, noseDepth * 0.42, w, noseDepth)
      ..lineTo(w, h - tailR)
      ..quadraticBezierTo(w, h, w - tailR, h)
      ..lineTo(tailR, h)
      ..quadraticBezierTo(0, h, 0, h - tailR)
      ..lineTo(0, noseDepth)
      ..cubicTo(0, noseDepth * 0.42, w * 0.06, 4, w * 0.5, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _FuselageClipper old) => false;
}

class _FuselageDeckPainter extends CustomPainter {
  _FuselageDeckPainter({required this.mapWidth});

  final double mapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mapLeft = (w - mapWidth) / 2;
    final aisleLeft = mapLeft + _kWallW + _kSeatSz * 3 + _kSeatGap * 2;
    final aisleRight = aisleLeft + _kAisleW;

    // Outer hull
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF181C24),
    );

    // Side walls (curved barrel look)
    final wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF353B48),
          Color(0xFF252A34),
          Color(0xFF252A34),
          Color(0xFF353B48),
        ],
        stops: const [0.0, 0.12, 0.88, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTRB(0, 0, mapLeft + _kWallW, h), wallPaint);
    canvas.drawRect(
      Rect.fromLTRB(mapLeft + mapWidth - _kWallW, 0, w, h),
      wallPaint,
    );

    // Center aisle carpet
    canvas.drawRect(
      Rect.fromLTRB(aisleLeft, 0, aisleRight, h),
      Paint()..color = const Color(0xFF2A303A),
    );

    // Aisle center line (subtle)
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final cx = (aisleLeft + aisleRight) / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, h), linePaint);

    // Seat deck panels (left / right blocks)
    final deckPaint = Paint()..color = const Color(0xFF1E232C);
    canvas.drawRect(
      Rect.fromLTRB(mapLeft + _kWallW, 0, aisleLeft, h),
      deckPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(aisleRight, 0, mapLeft + mapWidth - _kWallW, h),
      deckPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FuselageDeckPainter old) =>
      old.mapWidth != mapWidth;
}

class _WingBandPainter extends CustomPainter {
  const _WingBandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wingPaint = Paint()..color = const Color(0xFF3D4554).withValues(alpha: 0.55);

    // Wing shadow trapezoids on both sides
    final leftWing = Path()
      ..moveTo(0, h * 0.15)
      ..lineTo(w * 0.22, h * 0.35)
      ..lineTo(w * 0.22, h * 0.65)
      ..lineTo(0, h * 0.85)
      ..close();
    final rightWing = Path()
      ..moveTo(w, h * 0.15)
      ..lineTo(w * 0.78, h * 0.35)
      ..lineTo(w * 0.78, h * 0.65)
      ..lineTo(w, h * 0.85)
      ..close();
    canvas.drawPath(leftWing, wingPaint);
    canvas.drawPath(rightWing, wingPaint);

    // Wing box across fuselage
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.84, h * 0.24),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF4A5568).withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Full-screen airplane photo + dark scrim for legible UI on top
class _SeatPlaneBackground extends StatelessWidget {
  const _SeatPlaneBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          kSeatAirplaneBgAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF080A0D)),
        ),
        // Light scrim — keeps seats readable without hiding the photo
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF080A0D).withValues(alpha: 0.28),
                const Color(0xFF080A0D).withValues(alpha: 0.48),
                const Color(0xFF080A0D).withValues(alpha: 0.62),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeatSelectionView
// ─────────────────────────────────────────────────────────────────────────────

class SeatSelectionView extends StatefulWidget {
  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;
  final double? distanceKm;
  final Duration? flightDuration;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  const SeatSelectionView({
    super.key,
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
    this.distanceKm,
    this.flightDuration,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  @override
  State<SeatSelectionView> createState() => _SeatSelectionViewState();
}

class _SeatSelectionViewState extends State<SeatSelectionView>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;

  late final AnimationController _entranceCtrl;
  late final Animation<double>   _entranceAnim;

  late final List<_Seat> _seats;
  _Seat? _selected;

  @override
  void initState() {
    super.initState();
    _seats = _buildSeats();

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    // Entrance: amber overlay fades out, content scales up
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _entranceAnim = CurvedAnimation(
        parent: _entranceCtrl, curve: Curves.easeOutCubic);
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  _Seat? _find(int row, String col) {
    try {
      return _seats.firstWhere((s) => s.row == row && s.col == col);
    } catch (_) {
      return null;
    }
  }

  void _selectSeat(_Seat seat) {
    if (seat.state == _SeatState.taken) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = seat);
    _slideCtrl.forward(from: 0);
  }

  void _onContinue() {
    final seat = _selected;
    if (seat == null) return;
    Get.to(() => BoardingPassView(
          fromCode: widget.fromCode,
          fromCity: widget.fromCity,
          toCode: widget.toCode,
          toCity: widget.toCity,
          seatCode: seat.code,
          distanceKm: widget.distanceKm ?? 0,
          flightDuration: widget.flightDuration ?? Duration.zero,
          fromLat: widget.fromLat,
          fromLng: widget.fromLng,
          toLat: widget.toLat,
          toLng: widget.toLng,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080A0D),
      body: Stack(
        children: [
          const Positioned.fill(child: _SeatPlaneBackground()),

          // ── Fixed header + scrollable cabin ──────────────────────────────
          Column(
            children: [
              _SeatHeader(
                fromCode: widget.fromCode,
                fromCity: widget.fromCity,
                toCode: widget.toCode,
                toCity: widget.toCity,
                distanceKm: widget.distanceKm,
                flightDuration: widget.flightDuration,
                topPad: mq.padding.top,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.only(
                    left: 8,
                    right: 8,
                    bottom: mq.padding.bottom + 250,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _CabinBody(
                      find: _find,
                      selected: _selected,
                      onSeatTap: _selectSeat,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Fixed bottom panel ────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              selected:  _selected,
              slideAnim: _slideAnim,
              bottomPad: mq.padding.bottom,
              onContinue: _onContinue,
            ),
          ),

          // ── Amber entrance reveal ─────────────────────────────────────────
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _entranceAnim,
              builder: (context2, child2) {
                final t = _entranceAnim.value; // 0→1 as animation progresses
                if (t >= 1.0) return const SizedBox.shrink();
                return Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: const ColoredBox(
                    color: Color(0xFFF6A93B),
                    child: SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed header
// ─────────────────────────────────────────────────────────────────────────────

class _SeatHeader extends StatelessWidget {
  const _SeatHeader({
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
    required this.topPad,
    this.distanceKm,
    this.flightDuration,
  });

  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;
  final double topPad;
  final double? distanceKm;
  final Duration? flightDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasMeta = distanceKm != null && flightDuration != null;
    final metaLabel = hasMeta
        ? '${FlightRouteUtils.formatDistance(distanceKm!)} · '
            '${FlightRouteUtils.formatDurationCompact(flightDuration!)}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12).withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: colors.hair)),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SeatHeaderBackButton(colors: colors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'seat_selection_title'.tr,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.tx3,
                  letterSpacing: 0.6,
                  poppins: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SeatHeaderCode(code: fromCode),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: colors.tx3.withValues(alpha: 0.55),
                      ),
                    ),
                    _SeatHeaderCode(code: toCode),
                    if (metaLabel != null) ...[
                      const Spacer(),
                      _SeatHeaderMetaChip(label: metaLabel),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  '$fromCity → $toCity',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.tx2,
                  poppins: true,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatHeaderBackButton extends StatelessWidget {
  const _SeatHeaderBackButton({required this.colors});

  final AppTheme colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: Get.back,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surf2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.hair),
          ),
          child: Icon(Icons.arrow_back_rounded, color: colors.tx2, size: 20),
        ),
      ),
    );
  }
}

class _SeatHeaderCode extends StatelessWidget {
  const _SeatHeaderCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AppText(
      code,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      poppins: true,
      letterSpacing: -0.5,
    );
  }
}

class _SeatHeaderMetaChip extends StatelessWidget {
  const _SeatHeaderMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: AppText(
        label,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.65),
        poppins: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabin body — the full scrollable airplane
// ─────────────────────────────────────────────────────────────────────────────

class _CabinBody extends StatelessWidget {
  final _Seat? Function(int row, String col) find;
  final _Seat? selected;
  final ValueChanged<_Seat> onSeatTap;

  const _CabinBody({
    required this.find,
    required this.selected,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fuselageW = constraints.maxWidth.clamp(0.0, _kFuselageMaxW);

        return SizedBox(
          width: fuselageW,
          child: ClipPath(
            clipper: const _FuselageClipper(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF4A5260).withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FuselageDeckPainter(mapWidth: _kSeatMapWidth),
                    ),
                  ),
                  Column(
                    children: [
                      const _CockpitDecor(),
                      const SizedBox(height: 6),
                      const _SectionHeader(label: 'Business class'),
                      const SizedBox(height: 8),
                      const _ColHeaderRow(),
                      const SizedBox(height: 6),
                      for (int i = 0; i < _kBizRows.length; i++) ...[
                        _SeatRowWidget(
                          row: _kBizRows[i],
                          isBiz: true,
                          find: find,
                          selected: selected,
                          onSeatTap: onSeatTap,
                        ),
                        if (i < _kBizRows.length - 1)
                          const SizedBox(height: _kBizGap),
                      ],
                      const SizedBox(height: 16),
                      const _GalleyDivider(),
                      const SizedBox(height: 16),
                      const _SectionHeader(label: 'Economy class'),
                      const SizedBox(height: 8),
                      const _ColHeaderRow(),
                      const SizedBox(height: 6),
                      for (int i = 0; i < _kEcoFront.length; i++) ...[
                        _SeatRowWidget(
                          row: _kEcoFront[i],
                          isBiz: false,
                          find: find,
                          selected: selected,
                          onSeatTap: onSeatTap,
                        ),
                        if (i < _kEcoFront.length - 1)
                          const SizedBox(height: _kEcoGap),
                      ],
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          const Positioned.fill(
                            child: CustomPaint(
                              painter: _WingBandPainter(),
                            ),
                          ),
                          Column(
                            children: [
                              const _OverwingBanner(),
                              const SizedBox(height: 4),
                              for (int i = 0; i < _kOverwing.length; i++) ...[
                                _SeatRowWidget(
                                  row: _kOverwing[i],
                                  isBiz: false,
                                  isExit: true,
                                  find: find,
                                  selected: selected,
                                  onSeatTap: onSeatTap,
                                ),
                                if (i < _kOverwing.length - 1)
                                  const SizedBox(height: _kEcoGap + 2),
                              ],
                              const SizedBox(height: 4),
                              const _OverwingBanner(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (int i = 0; i < _kEcoRear.length; i++) ...[
                        _SeatRowWidget(
                          row: _kEcoRear[i],
                          isBiz: false,
                          find: find,
                          selected: selected,
                          onSeatTap: onSeatTap,
                        ),
                        if (i < _kEcoRear.length - 1)
                          const SizedBox(height: _kEcoGap),
                      ],
                      const SizedBox(height: 20),
                      const _FuselageTail(),
                      const SizedBox(height: 12),
                      _LegendRow(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FuselageTail extends StatelessWidget {
  const _FuselageTail();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 14),
          Icon(
            Icons.airplanemode_active_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 6),
          AppText(
            'Aft cabin',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.28),
            letterSpacing: 1.2,
            poppins: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cockpit nose decoration
// ─────────────────────────────────────────────────────────────────────────────

class _CockpitDecor extends StatelessWidget {
  const _CockpitDecor();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 8,
            left: 24,
            right: 24,
            height: 72,
            child: CustomPaint(
              painter: _CockpitGlassPainter(),
            ),
          ),
          Positioned(
            bottom: 10,
            child: AppText(
              'Flight deck',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 1.4,
              poppins: true,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 32,
            right: 32,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _CockpitGlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final glass = Path()
      ..moveTo(w * 0.18, h)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w * 0.82, h)
      ..lineTo(w * 0.72, h * 0.55)
      ..quadraticBezierTo(w * 0.5, h * 0.38, w * 0.28, h * 0.55)
      ..close();

    canvas.drawPath(
      glass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A8FA8), Color(0xFF3D4A5C)],
        ).createShader(Offset.zero & size),
    );

    final frame = Paint()
      ..color = const Color(0xFF5C6678)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(glass, frame);

    // Center windshield divider
    canvas.drawLine(
      Offset(w * 0.5, h * 0.12),
      Offset(w * 0.5, h * 0.92),
      Paint()
        ..color = const Color(0xFF2A3140)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isBiz = label.contains('Business');
    final accent = isBiz
        ? AppColors.amber.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          AppText(
            label,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: accent,
            poppins: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Column headers row (A B C  [aisle]  D E F)
// ─────────────────────────────────────────────────────────────────────────────

class _ColHeaderRow extends StatelessWidget {
  const _ColHeaderRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: _kWallW),
        ..._buildLabels(_kLeftCols, colors),
        SizedBox(width: _kAisleW),
        ..._buildLabels(_kRightCols, colors),
        SizedBox(width: _kWallW),
      ],
    );
  }

  List<Widget> _buildLabels(List<String> cols, AppTheme colors) {
    final widgets = <Widget>[];
    for (int i = 0; i < cols.length; i++) {
      if (i > 0) widgets.add(const SizedBox(width: _kSeatGap));
      widgets.add(SizedBox(
        width: _kSeatSz,
        child: AppText.label(
          cols[i],
          color: Colors.white.withValues(alpha: 0.7),
          textAlign: TextAlign.center,
        ),
      ));
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single seat row with portholes
// ─────────────────────────────────────────────────────────────────────────────

class _SeatRowWidget extends StatelessWidget {
  final int row;
  final bool isBiz;
  final bool isExit;
  final _Seat? Function(int row, String col) find;
  final _Seat? selected;
  final ValueChanged<_Seat> onSeatTap;

  const _SeatRowWidget({
    required this.row,
    required this.isBiz,
    this.isExit = false,
    required this.find,
    required this.selected,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final leftAvail = find(row, 'A')?.state == _SeatState.available;
    final rightAvail = find(row, 'F')?.state == _SeatState.available;

    Widget tile(String col) {
      final seat = find(row, col);
      if (seat == null) return SizedBox(width: _kSeatSz, height: _kSeatSz);
      return _SeatTile(
        seat:       seat,
        isSelected: selected?.code == seat.code,
        onTap:      () => onSeatTap(seat),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FuselageWallCell(
          isWindowSide: true,
          lit: leftAvail,
        ),

        // Left seats A B C
        for (int i = 0; i < _kLeftCols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kSeatGap),
          tile(_kLeftCols[i]),
        ],

        SizedBox(
          width: _kAisleW,
          height: _kSeatSz,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Center(
              child: AppText(
                '$row',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isExit
                    ? AppColors.amber.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.4),
                poppins: true,
              ),
            ),
          ),
        ),

        // Right seats D E F
        for (int i = 0; i < _kRightCols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kSeatGap),
          tile(_kRightCols[i]),
        ],

        _FuselageWallCell(
          isWindowSide: true,
          lit: rightAvail,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Porthole window
// ─────────────────────────────────────────────────────────────────────────────

class _FuselageWallCell extends StatelessWidget {
  const _FuselageWallCell({required this.isWindowSide, required this.lit});

  final bool isWindowSide;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kWallW,
      height: _kSeatSz,
      child: Center(
        child: isWindowSide
            ? _AirplaneWindow(lit: lit)
            : Container(
                width: 2,
                height: _kSeatSz * 0.6,
                color: Colors.white.withValues(alpha: 0.04),
              ),
      ),
    );
  }
}

class _AirplaneWindow extends StatelessWidget {
  const _AirplaneWindow({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: lit
            ? const Color(0xFF8BA4C4).withValues(alpha: 0.55)
            : const Color(0xFF2E3542),
        border: Border.all(
          color: lit
              ? const Color(0xFFB8CCE0).withValues(alpha: 0.5)
              : const Color(0xFF4A5568),
          width: 1.2,
        ),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: const Color(0xFF9BB8E8).withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seat tile
// ─────────────────────────────────────────────────────────────────────────────

class _SeatTile extends StatelessWidget {
  final _Seat seat;
  final bool isSelected;
  final VoidCallback onTap;

  const _SeatTile({
    required this.seat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final taken  = seat.state == _SeatState.taken;

    Color fill;
    BoxBorder? border;
    List<BoxShadow>? shadows;

    if (isSelected) {
      fill    = AppColors.amber;
      shadows = [
        BoxShadow(
          color:      AppColors.amber.withValues(alpha: 0.45),
          blurRadius: 14,
          offset:     const Offset(0, 4),
        ),
      ];
    } else if (taken) {
      fill   = colors.surf1;
      border = Border.all(color: colors.hair, width: 1);
    } else if (seat.isWindow) {
      fill   = AppColors.amberSoft;
      border = Border.all(
          color: AppColors.amber.withValues(alpha: 0.55), width: 1.5);
    } else if (seat.isBiz) {
      fill   = colors.surf3;
      border = Border.all(color: colors.hair2, width: 1);
    } else {
      fill = colors.surf3;
    }

    return GestureDetector(
      onTap: taken ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:  _kSeatSz,
        height: _kSeatSz,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(5),
          ),
          border: border,
          boxShadow: shadows,
        ),
        child: Stack(
          children: [
            if (isSelected)
              Center(
                child: const Icon(Icons.flight,
                    color: Color(0xFF0A0B0D), size: 20),
              )
            else if (taken)
              Center(
                child: Icon(Icons.close_rounded,
                    size: 15,
                    color: colors.tx3.withValues(alpha: 0.45)),
              )
            else ...[
              Center(
                child: AppText(
                  seat.col,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: seat.isWindow
                      ? AppColors.amber.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.72),
                  poppins: true,
                ),
              ),
              if (seat.isBiz)
                Positioned(
                  top: 5, left: 8, right: 8,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: seat.isWindow
                          ? AppColors.amber.withValues(alpha: 0.55)
                          : colors.hair2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Galley / exit divider between business & economy
// ─────────────────────────────────────────────────────────────────────────────

class _GalleyDivider extends StatelessWidget {
  const _GalleyDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.door_sliding_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                AppText(
                  'Galley',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.45),
                  poppins: true,
                ),
              ],
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Over-wing exit banner
// ─────────────────────────────────────────────────────────────────────────────

class _OverwingBanner extends StatelessWidget {
  const _OverwingBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.emergency_rounded,
            size: 13,
            color: AppColors.amber.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 6),
          AppText(
            'Over-wing · emergency exit',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.amber.withValues(alpha: 0.7),
            poppins: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surf2.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.hair.withValues(alpha: 0.8)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          _LegendItem(
            fill: AppColors.amberSoft,
            border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.55), width: 1.5),
            label: 'Window',
          ),
          _LegendItem(
            fill: colors.surf3,
            border: Border.all(color: colors.hair2, width: 1),
            label: 'Aisle / Middle',
          ),
          _LegendItem(
            fill: AppColors.amber,
            border: null,
            label: 'Selected',
            icon: Icons.flight,
          ),
          _LegendItem(
            fill: colors.surf1,
            border: Border.all(color: colors.hair, width: 1),
            label: 'Taken',
            icon: Icons.close_rounded,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color fill;
  final Border? border;
  final String label;
  final IconData? icon;

  const _LegendItem({
    required this.fill,
    required this.border,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5),
            border: border,
          ),
          child: icon != null
              ? Icon(icon, size: 11, color: const Color(0xFF0A0B0D))
              : null,
        ),
        const SizedBox(width: 6),
        AppText.caption(
          label,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom panel — seat info card + continue button
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final _Seat? selected;
  final Animation<Offset> slideAnim;
  final double bottomPad;
  final VoidCallback? onContinue;

  const _BottomPanel({
    required this.selected,
    required this.slideAnim,
    required this.bottomPad,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final has = selected != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F12),
        border: Border(top: BorderSide(color: colors.hair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (has)
            SlideTransition(
              position: slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _SeatInfoCard(seat: selected!),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.airline_seat_recline_normal_rounded,
                    size: 18,
                    color: colors.tx3.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      'Tap an available seat',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.tx3,
                      poppins: true,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 16),
            child: _SeatContinueButton(
              enabled: has,
              onTap: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatContinueButton extends StatelessWidget {
  const _SeatContinueButton({required this.enabled, this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: enabled ? AppColors.amber : colors.surf3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? AppColors.amber : colors.hair,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 20,
                color: enabled
                    ? const Color(0xFF0A0B0D)
                    : colors.tx3.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 10),
              AppText(
                enabled ? 'seat_boarding_pass'.tr : 'seat_choose'.tr,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? const Color(0xFF0A0B0D)
                    : colors.tx3.withValues(alpha: 0.45),
                poppins: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seat info card
// ─────────────────────────────────────────────────────────────────────────────

class _SeatInfoCard extends StatelessWidget {
  final _Seat seat;
  const _SeatInfoCard({required this.seat});

  IconData get _positionIcon {
    if (seat.isWindow) return Icons.window_rounded;
    if (seat.isAisle) return Icons.meeting_room_outlined;
    return Icons.airline_seat_recline_normal_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surf2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.hair),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'SEAT',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.tx3,
                letterSpacing: 1.2,
                poppins: true,
              ),
              const SizedBox(height: 2),
              AppText(
                seat.code,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.tx1,
                poppins: true,
                letterSpacing: 0.5,
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: colors.hair,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  seat.typeLabel,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.tx1,
                  poppins: true,
                ),
                const SizedBox(height: 2),
                AppText(
                  seat.typeDesc,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.tx3,
                  poppins: true,
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.hair),
            ),
            child: Icon(
              _positionIcon,
              size: 20,
              color: seat.isBiz
                  ? AppColors.amber.withValues(alpha: 0.85)
                  : colors.tx2,
            ),
          ),
        ],
      ),
    );
  }
}
