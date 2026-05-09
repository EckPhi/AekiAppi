import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scooter_state.dart';
import '../services/scooter_service.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScooterService>(
      builder: (context, service, _) {
        final state = service.scooterState;
        final device = service.connectedDevice;

        return Scaffold(
          appBar: AppBar(
            title: Text(device?.platformName ?? 'Äike Scooter'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.bluetooth_disabled),
                tooltip: 'Disconnect',
                onPressed: () async {
                  await service.disconnect();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ScanScreen()),
                    );
                  }
                },
              ),
            ],
          ),
          body: service.isConnecting
              ? const Center(child: CircularProgressIndicator())
              : !service.isConnected
                  ? _DisconnectedView(service: service)
                  : _ConnectedView(state: state, service: service),
        );
      },
    );
  }
}

// ── Disconnected placeholder ──────────────────────────────────────────────────

class _DisconnectedView extends StatelessWidget {
  const _DisconnectedView({required this.service});

  final ScooterService service;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 64),
          const SizedBox(height: 16),
          const Text('Scooter disconnected'),
          if (service.error != null) ...[
            const SizedBox(height: 8),
            Text(
              service.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ScanScreen()),
            ),
            icon: const Icon(Icons.search),
            label: const Text('Back to Scan'),
          ),
        ],
      ),
    );
  }
}

// ── Connected control panel ───────────────────────────────────────────────────

class _ConnectedView extends StatelessWidget {
  const _ConnectedView({required this.state, required this.service});

  final ScooterState state;
  final ScooterService service;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusCard(state: state),
        const SizedBox(height: 16),
        const _SectionHeader('Controls'),
        _LockUnlockRow(state: state, service: service),
        const SizedBox(height: 12),
        _CommandButton(
          icon: Icons.battery_unknown,
          label: 'Open Battery Tray',
          onTap: service.openBatteryTray,
        ),
        const SizedBox(height: 16),
        const _SectionHeader('Settings'),
        _ToggleTile(
          icon: Icons.eco,
          label: 'Eco Mode',
          value: state.ecoMode,
          onChanged: (v) => service.setEcoMode(enable: v),
        ),
        _ToggleTile(
          icon: Icons.speed,
          label: 'Auto-brake',
          value: state.autoBrakeEnabled,
          onChanged: (v) => service.setAutoBrake(enable: v),
        ),
        _ToggleTile(
          icon: Icons.local_shipping,
          label: 'Transport Mode',
          value: state.transportMode,
          onChanged: (v) => service.setTransportMode(enable: v),
        ),
        _AutoLockTile(state: state, service: service),
        if (state.firmwareVersion != null) ...[
          const SizedBox(height: 16),
          const _SectionHeader('Device Info'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Firmware'),
            trailing: Text(state.firmwareVersion!),
          ),
        ],
      ],
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final ScooterState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batteryText =
        state.batteryLevel != null ? '${state.batteryLevel}%' : '—';
    final voltageText = state.batteryVoltageMillivolts != null
        ? '${(state.batteryVoltageMillivolts! / 1000).toStringAsFixed(1)} V'
        : '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: state.isLocked ? Icons.lock : Icons.lock_open,
              label: state.isLocked ? 'Locked' : 'Unlocked',
              color: state.isLocked
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            _StatItem(
              icon: Icons.battery_std,
              label: batteryText,
              color: _batteryColor(state.batteryLevel, theme),
            ),
            _StatItem(
              icon: Icons.electrical_services,
              label: voltageText,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  Color _batteryColor(int? level, ThemeData theme) {
    if (level == null) return theme.colorScheme.onSurface;
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

// ── Lock / unlock row ─────────────────────────────────────────────────────────

class _LockUnlockRow extends StatelessWidget {
  const _LockUnlockRow({required this.state, required this.service});

  final ScooterState state;
  final ScooterService service;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: state.isLocked ? service.unlock : null,
            icon: const Icon(Icons.lock_open),
            label: const Text('Unlock'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: state.isLocked ? null : service.lock,
            icon: const Icon(Icons.lock),
            label: const Text('Lock'),
          ),
        ),
      ],
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _AutoLockTile extends StatelessWidget {
  const _AutoLockTile({required this.state, required this.service});

  final ScooterState state;
  final ScooterService service;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timer),
      title: const Text('Auto-lock Timer'),
      subtitle: Text(
        state.autoLockMinutes == 0
            ? 'Disabled'
            : '${state.autoLockMinutes} min',
      ),
      trailing: DropdownButton<int>(
        value: state.autoLockMinutes.clamp(0, 60),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Off')),
          DropdownMenuItem(value: 5, child: Text('5 min')),
          DropdownMenuItem(value: 10, child: Text('10 min')),
          DropdownMenuItem(value: 15, child: Text('15 min')),
          DropdownMenuItem(value: 30, child: Text('30 min')),
          DropdownMenuItem(value: 60, child: Text('60 min')),
        ],
        onChanged: (v) {
          if (v != null) service.setAutoLockTimer(v);
        },
      ),
    );
  }
}
