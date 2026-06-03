import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../models/airport_model.dart';
import '../../../../services/api/airport_api_service.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_theme.dart';
import '../../../../widgets/common/app_text.dart';

class AirportPickerSheet extends StatefulWidget {
  final Airport? selected;
  final Airport? exclude;

  const AirportPickerSheet({
    super.key,
    required this.selected,
    required this.exclude,
  });

  @override
  State<AirportPickerSheet> createState() => _AirportPickerSheetState();
}

class _AirportPickerSheetState extends State<AirportPickerSheet> {
  final _ctrl = TextEditingController();
  final _api = Get.find<AirportApiService>();

  List<Airport> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  static const _debounceMs = 400;
  static const _minChars = 2;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onQueryChanged);
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    try {
      final list = await _api.popularAirports();
      if (!mounted) return;
      setState(() {
        _results = list.where((a) => a != widget.exclude).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
      () => _runSearch(_ctrl.text),
    );
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.length < _minChars) {
      await _loadSuggestions();
      return;
    }

    // Clear stale results immediately while a new query is in flight.
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final list = await _api.search(q);
      if (!mounted) return;
      if (_ctrl.text.trim() != q) return;
      setState(() {
        _results = list.where((a) => a != widget.exclude).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.78,
      decoration: BoxDecoration(
        color: colors.surf2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.hair2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText.title('Select Airport', color: colors.tx1),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surf3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.hair, width: 1),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: TextStyle(color: colors.tx1, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'City, airport or code (min 2 chars)',
                  hintStyle: TextStyle(color: colors.tx3, fontSize: 15),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.tx3,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(colors)),
          SizedBox(height: mq.padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildBody(AppTheme colors) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppText.body(_error!, color: colors.tx3, textAlign: TextAlign.center),
        ),
      );
    }
    if (_ctrl.text.trim().length < _minChars) {
      if (_results.isEmpty && !_loading) {
        return Center(
          child: AppText.body('Loading airports…', color: colors.tx3),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: AppText.caption('Popular airports', color: colors.tx3),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _results.length,
              itemBuilder: (_, i) => _row(_results[i], colors),
            ),
          ),
        ],
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: AppText.body('No airports found', color: colors.tx3),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _results.length,
      itemBuilder: (_, i) => _row(_results[i], colors),
    );
  }

  Widget _row(Airport a, AppTheme colors) {
    final active = a == widget.selected;

    return GestureDetector(
      onTap: () => Navigator.pop(context, a),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.amberSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.amberSoft : colors.surf3,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: AppText(
                a.code,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.amber : colors.tx2,
                poppins: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    a.city,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.amber : colors.tx1,
                    poppins: true,
                  ),
                  AppText.caption(
                    '${a.flagEmoji} ${a.name} · ${a.timezone}',
                    color: colors.tx3,
                  ),
                ],
              ),
            ),
            if (active)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.amber,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
