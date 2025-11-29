/// Example demonstrating alarm management with the Dart SoCo library.
///
/// This example shows how to:
/// - List all configured alarms
/// - Create new alarms with different recurrence patterns
/// - Modify existing alarms
/// - Delete alarms
library;

import 'package:soco/soco.dart';

Future<void> main() async {
  print('=== Sonos Alarm Management Example ===\n');

  // Discover a Sonos device
  print('Discovering Sonos devices...');
  final device = await anySoco();

  if (device == null) {
    print('No Sonos devices found!');
    return;
  }

  print('Connected to: ${await device.playerName}\n');

  // Get all alarms
  print('--- Current Alarms ---');
  final alarms = await getAlarms(device);

  if (alarms.isEmpty) {
    print('No alarms configured.');
  } else {
    for (final alarm in alarms) {
      print('Alarm ${alarm.alarmId}:');
      print('  Start Time: ${alarm.startTime}');
      print('  Enabled: ${alarm.enabled}');
      print('  Recurrence: ${alarm.recurrence}');
      print('  Program URI: ${alarm.programUri}');
      if (alarm.includeLinkedZones) {
        print('  Include Linked Zones: Yes');
      }
      print('');
    }
  }

  // Example: Create a new alarm (disabled by default)
  print('\n--- Creating New Alarm ---');
  try {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 7, 0, 0);
    final duration = DateTime(now.year, now.month, now.day, 2, 0, 0);

    final newAlarm = Alarm(
      device,
      startTime: startTime,
      duration: duration,
      recurrence: 'DAILY',
      enabled: false, // Start disabled for safety
      programUri: 'x-rincon-buzzer:0',
      programMetadata: '',
      playMode: 'SHUFFLE',
      volume: 20,
      includeLinkedZones: false,
    );

    await newAlarm.save();
    print('Created alarm ${newAlarm.alarmId}');
    print('  Start: ${newAlarm.startTime}');
    print('  Recurrence: ${newAlarm.recurrence}');
    print('  Volume: ${newAlarm.volume}');
  } catch (e) {
    print('Error creating alarm: $e');
  }

  // Example: Modify an existing alarm
  if (alarms.isNotEmpty) {
    print('\n--- Modifying First Alarm ---');
    final alarm = alarms.first;
    print('Original volume: ${alarm.volume}');

    // Change volume
    alarm.volume = 15;
    await alarm.save();
    print('Updated volume to: 15');

    // You can also enable/disable
    // alarm.enabled = false;
    // await alarm.save();
  }

  // Example: Different recurrence patterns
  print('\n--- Recurrence Pattern Examples ---');
  print('DAILY: Every day');
  print('ONCE: One time only');
  print('WEEKDAYS: Monday through Friday');
  print('WEEKENDS: Saturday and Sunday');
  print('ON_MONWEDNESFRI: Monday, Wednesday, Friday');
  print('ON_TUEUTHURA: Tuesday, Thursday, Saturday');

  // Example: Delete an alarm (commented out for safety)
  /*
  if (alarms.isNotEmpty) {
    print('\n--- Deleting Alarm ---');
    final alarmToDelete = alarms.last;
    print('Deleting alarm ${alarmToDelete.alarmId}...');
    await removeAlarmById(device, alarmToDelete.alarmId);
    print('Alarm deleted.');
  }
  */

  // Get alarms again to see changes
  print('\n--- Updated Alarms List ---');
  final updatedAlarms = await getAlarms(device);
  print('Total alarms: ${updatedAlarms.length}');

  print('\n=== Example Complete ===');
}
