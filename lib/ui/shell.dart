import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../data/day_record.dart';
import '../data/exporter.dart';
import '../data/health_repository.dart';
import '../l10n.dart';
import '../metrics/engine.dart';
import '../theme.dart';
import 'coverage_screen.dart';
import 'screens.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _repo = HealthRepository();
  int _tab = 0;
  bool _loading = true;
  String? _errorKey;
  String? _errorDetail;
  List<DayRecord> _days = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _errorDetail = null;
    });
    try {
      await _repo.configure();
      final status = await _repo.sdkStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailable) {
        setState(() {
          _loading = false;
          _errorKey = 'state.noSdk';
        });
        return;
      }
      if (status ==
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        await _repo.installHealthConnect();
        setState(() {
          _loading = false;
          _errorKey = 'state.updateSdk';
        });
        return;
      }

      var ok = await _repo.hasPermissions();
      if (!ok) ok = await _repo.requestPermissions();
      if (!ok) {
        setState(() {
          _loading = false;
          _errorKey = 'state.noPermission';
        });
        return;
      }

      final days = await _repo.load();
      MetricsEngine.run(days);
      final withData = days.where((d) => d.hasSleep || d.rhr != null).toList();
      final thin = withData.length < 3;
      setState(() {
        _days = withData.isEmpty ? days : withData;
        _loading = false;
        // Veri henuz azken skor ekranlarini acmak yaniltici olur;
        // once Health Connect'ten ne geldigini goster.
        if (thin) _tab = 4;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorKey = 'state.readError';
        _errorDetail = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget body;

    if (_loading) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: K.ink3)),
            const SizedBox(height: 18),
            Text(s.t('state.reading'), style: K.caption),
          ]),
        ),
      );
    } else if (_errorKey != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.t(_errorKey!), style: K.caption, textAlign: TextAlign.center),
            if (_errorDetail != null) ...[
              const SizedBox(height: 8),
              Text(_errorDetail!,
                  style: const TextStyle(fontSize: 12, color: K.ink3),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: K.ink,
                  side: const BorderSide(color: K.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _boot,
              child: Text(s.t('common.retry')),
            ),
          ]),
        ),
      );
    } else if (_days.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.t('state.noRecords'),
                style: K.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton(onPressed: _boot, child: Text(s.t('common.retry'))),
          ]),
        ),
      );
    } else {
      body = IndexedStack(index: _tab, children: [
        TodayScreen(_days),
        SleepScreen(_days),
        LoadScreen(_days),
        HeartScreen(_days),
        CoverageScreen(repo: _repo, days: _days, onReload: _boot),
      ]);
    }

    return Scaffold(
      backgroundColor: K.bg,
      body: SafeArea(child: body),
      floatingActionButton: _days.isEmpty
          ? null
          : FloatingActionButton.small(
              backgroundColor: K.ink,
              foregroundColor: Colors.white,
              elevation: 2,
              tooltip: s.t('data.export'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final failed = s.t('data.exportFailed');
                try {
                  await Exporter.share(_days, subject: s.t('data.exportSubject'));
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('$failed: $e')));
                }
              },
              child: const Icon(Icons.ios_share, size: 18),
            ),
      bottomNavigationBar: Container(
        decoration:
            const BoxDecoration(border: Border(top: BorderSide(color: K.line2))),
        child: NavigationBar(
          height: 68,
          backgroundColor: K.bg,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            _dest(Icons.circle_outlined, s.t('tab.today')),
            _dest(Icons.nightlight_outlined, s.t('tab.sleep')),
            _dest(Icons.show_chart, s.t('tab.load')),
            _dest(Icons.favorite_outline, s.t('tab.heart')),
            _dest(Icons.storage_outlined, s.t('tab.data')),
          ],
        ),
      ),
    );
  }

  NavigationDestination _dest(IconData icon, String label) =>
      NavigationDestination(
        icon: Icon(icon, color: K.ink3, size: 22),
        selectedIcon: Icon(icon, color: K.ink, size: 22),
        label: label,
      );
}
