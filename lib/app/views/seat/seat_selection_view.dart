import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dimensions
// ─────────────────────────────────────────────────────────────────────────────

const _kSeatSz   = 40.0;   // seat tile width & height
const _kSeatGap  = 5.0;    // gap between seats in same 3-group
const _kAisleW   = 34.0;   // aisle (holds row number)
const _kWallW    = 16.0;   // cabin wall strip (where porthole lives)
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

  String get typeLabel {
    if (isBiz) {
      if (isWindow) return 'Business · Window';
      if (isAisle)  return 'Business · Aisle';
      return 'Business · Middle';
    }
    if (isWindow) return 'Window seat · Deep Work';
    if (isAisle)  return 'Aisle seat · Flexible';
    return 'Middle seat';
  }

  String get typeDesc {
    if (isBiz)    return 'Premium cabin · Priority boarding · Focus Sprint';
    if (isWindow) return 'Distraction-free · notifications paused';
    if (isAisle)  return 'Easy access · full connectivity';
    return 'Standard experience';
  }

  String get focusLabel {
    if (isBiz)    return 'Sprint';
    if (isWindow) return 'Deep\nWork';
    if (isAisle)  return 'Flex';
    return 'Std';
  }
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
// Fuselage nose clipper
// ─────────────────────────────────────────────────────────────────────────────

class _NoseClipper extends CustomClipper<Path> {
  const _NoseClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const nH = 110.0; // nose taper height
    const r  = 24.0;  // bottom corner radius

    return Path()
      // Nose tip (top-center)
      ..moveTo(w / 2, 0)
      // Right nose curve to right side
      ..quadraticBezierTo(w, 0, w, nH)
      // Right side down
      ..lineTo(w, h - r)
      // Bottom-right corner
      ..quadraticBezierTo(w, h, w - r, h)
      // Bottom
      ..lineTo(r, h)
      // Bottom-left corner
      ..quadraticBezierTo(0, h, 0, h - r)
      // Left side up
      ..lineTo(0, nH)
      // Left nose curve back to tip
      ..quadraticBezierTo(0, 0, w / 2, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _NoseClipper old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// SeatSelectionView
// ─────────────────────────────────────────────────────────────────────────────

class SeatSelectionView extends StatefulWidget {
  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;

  const SeatSelectionView({
    super.key,
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mq     = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: colors.surf1,
      body: Stack(
        children: [
          // ── Fixed header + scrollable cabin ──────────────────────────────
          Column(
            children: [
              _SeatHeader(
                fromCode: widget.fromCode,
                fromCity: widget.fromCity,
                toCode:   widget.toCode,
                toCity:   widget.toCity,
                topPad:   mq.padding.top,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: mq.padding.bottom + 250),
                  child: _CabinBody(
                    find:      _find,
                    selected:  _selected,
                    onSeatTap: _selectSeat,
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
  final String fromCode;
  final String fromCity;
  final String toCode;
  final String toCity;
  final double topPad;

  const _SeatHeader({
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
    required this.topPad,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surf1, colors.surf1.withValues(alpha: 0.0)],
          stops: const [0.72, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button — rounded rect
          GestureDetector(
            onTap: Get.back,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        colors.surf2,
                borderRadius: BorderRadius.circular(13),
                border:       Border.all(color: colors.hair, width: 1),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset:     const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded, color: colors.tx2, size: 17),
            ),
          ),

          // Center route display
          Expanded(
            child: Column(
              children: [
                // Large IATA codes with flight arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppText(
                      fromCode,
                      fontSize:   28,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white,
                      poppins:    true,
                      letterSpacing: -0.5,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 5),
                        decoration: BoxDecoration(
                          color:        AppColors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border:       Border.all(
                              color: AppColors.amber.withValues(alpha: 0.30),
                              width: 1),
                        ),
                        child: const Icon(Icons.flight_rounded,
                            color: AppColors.amber, size: 14),
                      ),
                    ),
                    AppText(
                      toCode,
                      fontSize:   28,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white,
                      poppins:    true,
                      letterSpacing: -0.5,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // City names
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText(
                      fromCity,
                      fontSize:   11,
                      fontWeight: FontWeight.w500,
                      color:      Colors.white.withValues(alpha: 0.40),
                      poppins:    true,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 3, height: 3,
                        decoration: BoxDecoration(
                          color:  Colors.white.withValues(alpha: 0.25),
                          shape:  BoxShape.circle,
                        ),
                      ),
                    ),
                    AppText(
                      toCity,
                      fontSize:   11,
                      fontWeight: FontWeight.w500,
                      color:      Colors.white.withValues(alpha: 0.40),
                      poppins:    true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mirror back button width for symmetry
          const SizedBox(width: 40),
        ],
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
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipPath(
        clipper: const _NoseClipper(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1C1F28),
                colors.surf2,
                colors.surf2,
                const Color(0xFF181B22),
              ],
              stops: const [0.0, 0.10, 0.88, 1.0],
            ),
          ),
          child: Column(
            children: [
              // ── Cockpit nose decoration ─────────────────────────────────
              _CockpitDecor(),
              const SizedBox(height: 8),

              // ── Business class ──────────────────────────────────────────
              _SectionHeader(
                label:    'BUSINESS · FOCUS SPRINT',
                iconData: Icons.star_rounded,
              ),
              const SizedBox(height: 10),
              const _ColHeaderRow(),
              const SizedBox(height: 8),

              for (int i = 0; i < _kBizRows.length; i++) ...[
                _SeatRowWidget(
                  row:       _kBizRows[i],
                  isBiz:     true,
                  find:      find,
                  selected:  selected,
                  onSeatTap: onSeatTap,
                ),
                if (i < _kBizRows.length - 1)
                  const SizedBox(height: _kBizGap),
              ],
              const SizedBox(height: 24),

              // ── Galley / exit divider ───────────────────────────────────
              _GalleyDivider(),
              const SizedBox(height: 24),

              // ── Economy — front ─────────────────────────────────────────
              _SectionHeader(
                label:    'ECONOMY · DEEP WORK',
                iconData: Icons.laptop_rounded,
              ),
              const SizedBox(height: 10),
              const _ColHeaderRow(),
              const SizedBox(height: 8),

              for (int i = 0; i < _kEcoFront.length; i++) ...[
                _SeatRowWidget(
                  row:       _kEcoFront[i],
                  isBiz:     false,
                  find:      find,
                  selected:  selected,
                  onSeatTap: onSeatTap,
                ),
                if (i < _kEcoFront.length - 1)
                  const SizedBox(height: _kEcoGap),
              ],
              const SizedBox(height: 14),

              // ── Over-wing exit rows ─────────────────────────────────────
              _OverwingBanner(),
              const SizedBox(height: 6),

              for (int i = 0; i < _kOverwing.length; i++) ...[
                _SeatRowWidget(
                  row:       _kOverwing[i],
                  isBiz:     false,
                  isExit:    true,
                  find:      find,
                  selected:  selected,
                  onSeatTap: onSeatTap,
                ),
                if (i < _kOverwing.length - 1)
                  const SizedBox(height: _kEcoGap + 4),
              ],

              const SizedBox(height: 6),
              _OverwingBanner(),
              const SizedBox(height: 14),

              // ── Economy — rear ──────────────────────────────────────────
              for (int i = 0; i < _kEcoRear.length; i++) ...[
                _SeatRowWidget(
                  row:       _kEcoRear[i],
                  isBiz:     false,
                  find:      find,
                  selected:  selected,
                  onSeatTap: onSeatTap,
                ),
                if (i < _kEcoRear.length - 1)
                  const SizedBox(height: _kEcoGap),
              ],
              const SizedBox(height: 28),

              // ── Legend ──────────────────────────────────────────────────
              _LegendRow(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cockpit nose decoration
// ─────────────────────────────────────────────────────────────────────────────

class _CockpitDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        const SizedBox(height: 86), // empty space inside the nose arch

        // Handle / drag indicator
        Container(
          width: 32, height: 3,
          decoration: BoxDecoration(
            color:        colors.hair2,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Cockpit windows — two small rounded rects
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CockpitWindow(),
            const SizedBox(width: 14),
            _CockpitWindow(),
          ],
        ),
        const SizedBox(height: 8),

        // "COCKPIT" label
        AppText(
          'COCKPIT',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.amber.withValues(alpha: 0.65),
          letterSpacing: 2.5,
          poppins: true,
        ),
        const SizedBox(height: 18),

        // Nose divider — amber glow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.amber.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CockpitWindow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3510), Color(0xFF2A1E08)],
        ),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(
            color: AppColors.amber.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color:      AppColors.amber.withValues(alpha: 0.22),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData iconData;
  const _SectionHeader({required this.label, required this.iconData});

  @override
  Widget build(BuildContext context) {
    final colors   = context.colors;
    final isBiz    = label.contains('BUSINESS');
    final accent   = isBiz ? AppColors.amber : colors.tx3;
    final lineColor = isBiz
        ? AppColors.amber.withValues(alpha: 0.22)
        : colors.hair;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: lineColor),
          ),
          const SizedBox(width: 10),
          Icon(iconData, color: accent, size: 12),
          const SizedBox(width: 5),
          AppText(
            label,
            fontSize:    9,
            fontWeight:  FontWeight.w700,
            color:       accent,
            letterSpacing: 1.8,
            poppins:     true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: lineColor),
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
        child: AppText.label(cols[i], color: colors.tx3, textAlign: TextAlign.center),
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
    final colors = context.colors;

    // Porthole every even row
    final showPort = row.isEven;

    // Porthole amber if window seat is available
    final leftAvail  = find(row, 'A')?.state == _SeatState.available;
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
        // Left porthole wall
        SizedBox(
          width:  _kWallW,
          height: _kSeatSz,
          child: showPort
              ? Center(child: _Porthole(isAmber: leftAvail))
              : null,
        ),

        // Left seats A B C
        for (int i = 0; i < _kLeftCols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kSeatGap),
          tile(_kLeftCols[i]),
        ],

        // Aisle with row number
        SizedBox(
          width: _kAisleW,
          height: _kSeatSz,
          child: Center(
            child: AppText(
              '$row',
              fontSize:   11,
              fontWeight: FontWeight.w500,
              color:      isExit
                  ? AppColors.amber.withValues(alpha: 0.8)
                  : colors.tx3,
              poppins:    true,
            ),
          ),
        ),

        // Right seats D E F
        for (int i = 0; i < _kRightCols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kSeatGap),
          tile(_kRightCols[i]),
        ],

        // Right porthole wall
        SizedBox(
          width:  _kWallW,
          height: _kSeatSz,
          child: showPort
              ? Center(child: _Porthole(isAmber: rightAvail))
              : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Porthole window
// ─────────────────────────────────────────────────────────────────────────────

class _Porthole extends StatelessWidget {
  final bool isAmber;
  const _Porthole({required this.isAmber});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 9, height: 13,
      decoration: BoxDecoration(
        color:        isAmber ? AppColors.amberSoft : colors.surf3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAmber
              ? AppColors.amber.withValues(alpha: 0.5)
              : colors.hair2,
          width: 1,
        ),
        boxShadow: isAmber
            ? [BoxShadow(
                color:      AppColors.amber.withValues(alpha: 0.18),
                blurRadius: 8,
                spreadRadius: 1,
              )]
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
          color:        fill,
          borderRadius: BorderRadius.circular(11),
          border:       border,
          boxShadow:    shadows,
        ),
        child: Stack(
          children: [
            if (isSelected)
              Center(
                child: const Icon(Icons.flight,
                    color: Color(0xFF0A0B0D), size: 18),
              )
            else if (taken)
              Center(
                child: Icon(Icons.close_rounded,
                    size: 13,
                    color: colors.tx3.withValues(alpha: 0.40)),
              )
            else if (seat.isBiz)
              // Headrest bar at top for business
              Positioned(
                top: 5, left: 7, right: 7,
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Galley / exit divider between business & economy
// ─────────────────────────────────────────────────────────────────────────────

class _GalleyDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.amber.withValues(alpha: 0.04),
              AppColors.amber.withValues(alpha: 0.10),
              AppColors.amber.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.amber.withValues(alpha: 0.20), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.door_sliding_outlined,
                color: AppColors.amber.withValues(alpha: 0.60), size: 13),
            const SizedBox(width: 8),
            AppText(
              'GALLEY · EMERGENCY EXIT',
              fontSize:    9,
              fontWeight:  FontWeight.w700,
              color:       AppColors.amber.withValues(alpha: 0.70),
              letterSpacing: 1.5,
              poppins:     true,
            ),
            const SizedBox(width: 8),
            Icon(Icons.door_sliding_outlined,
                color: AppColors.amber.withValues(alpha: 0.60), size: 13),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Over-wing exit banner
// ─────────────────────────────────────────────────────────────────────────────

class _OverwingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _ExitChip(),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              painter: _DashPainter(AppColors.amber.withValues(alpha: 0.35)),
              child: const SizedBox(height: 1),
            ),
          ),
          const SizedBox(width: 8),
          AppText.label('OVER-WING EXIT', color: AppColors.amber.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              painter: _DashPainter(AppColors.amber.withValues(alpha: 0.35)),
              child: const SizedBox(height: 1),
            ),
          ),
          const SizedBox(width: 8),
          _ExitChip(),
        ],
      ),
    );
  }
}

class _ExitChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color:        AppColors.amberSoft,
        borderRadius: BorderRadius.circular(5),
        border:       Border.all(
            color: AppColors.amber.withValues(alpha: 0.4), width: 1),
      ),
      child: const Icon(Icons.exit_to_app_rounded, color: AppColors.amber, size: 11),
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

    return Wrap(
      alignment:   WrapAlignment.center,
      spacing:     16,
      runSpacing:  8,
      children: [
        _LegendItem(
          fill:   AppColors.amberSoft,
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.55), width: 1.5),
          label:  'Window · Deep work',
        ),
        _LegendItem(
          fill:   colors.surf3,
          border: null,
          label:  'Aisle · Flexible',
        ),
        _LegendItem(
          fill:   colors.surf1,
          border: Border.all(color: colors.hair, width: 1),
          label:  'Taken',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color fill;
  final Border? border;
  final String label;

  const _LegendItem({required this.fill, required this.border, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color:        fill,
            borderRadius: BorderRadius.circular(4),
            border:       border,
          ),
        ),
        const SizedBox(width: 5),
        AppText.caption(label, color: context.colors.tx3),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed line painter
// ─────────────────────────────────────────────────────────────────────────────

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom panel — seat info card + continue button
// ─────────────────────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final _Seat? selected;
  final Animation<Offset> slideAnim;
  final double bottomPad;

  const _BottomPanel({
    required this.selected,
    required this.slideAnim,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final has    = selected != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.surf1.withValues(alpha: 0.0),
            colors.surf1.withValues(alpha: 0.92),
            colors.surf1,
          ],
          stops: const [0.0, 0.18, 0.45],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seat info card — slides up when a seat is tapped
          if (has)
            SlideTransition(
              position: slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _SeatInfoCard(seat: selected!),
              ),
            ),

          const SizedBox(height: 12),

          // Continue button — amber gradient
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
            child: GestureDetector(
              onTap: has ? () => HapticFeedback.mediumImpact() : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 19),
                decoration: BoxDecoration(
                  gradient: has
                      ? const LinearGradient(
                          colors: [Color(0xFFFFC267), Color(0xFFF6A93B),
                                   Color(0xFFE48F1A)],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        )
                      : null,
                  color:        has ? null : colors.surf3,
                  borderRadius: BorderRadius.circular(30),
                  border: has
                      ? null
                      : Border.all(color: colors.hair, width: 1),
                  boxShadow: has
                      ? [
                          BoxShadow(
                            color:      AppColors.amber.withValues(alpha: 0.42),
                            blurRadius: 28,
                            spreadRadius: 0,
                            offset:     const Offset(0, 10),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppText(
                      has ? 'Continue to boarding pass' : 'Select a seat',
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      has ? const Color(0xFF0A0B0D) : colors.tx3,
                      poppins:    true,
                      letterSpacing: 0.1,
                    ),
                    if (has) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Color(0xFF0A0B0D)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final borderColor = seat.isBiz
        ? AppColors.amber.withValues(alpha: 0.35)
        : colors.hair;
    final glowShadow = seat.isBiz
        ? [BoxShadow(
            color:      AppColors.amber.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          )]
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        colors.surf2,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: borderColor, width: 1),
        boxShadow:    glowShadow,
      ),
      child: Row(
        children: [
          // Seat code badge
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: [Color(0xFFFFC267), Color(0xFFE48F1A)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color:      AppColors.amber.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: AppText(
              seat.code,
              fontSize:   14,
              fontWeight: FontWeight.w800,
              color:      const Color(0xFF0A0B0D),
              poppins:    true,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  seat.typeLabel,
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                  color:      colors.tx1,
                  poppins:    true,
                ),
                const SizedBox(height: 4),
                AppText(
                  seat.typeDesc,
                  fontSize: 11,
                  color:    colors.tx3,
                  poppins:  true,
                ),
              ],
            ),
          ),

          // Focus mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:        AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(
                  color: AppColors.amber.withValues(alpha: 0.28), width: 1),
            ),
            child: Column(
              children: [
                AppText(
                  'FOCUS',
                  fontSize:    8,
                  fontWeight:  FontWeight.w700,
                  color:       AppColors.amber.withValues(alpha: 0.65),
                  letterSpacing: 1.5,
                  poppins:     true,
                ),
                const SizedBox(height: 3),
                AppText(
                  seat.focusLabel,
                  fontSize:   14,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.amber,
                  poppins:    true,
                  textAlign:  TextAlign.center,
                  height:     1.1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
