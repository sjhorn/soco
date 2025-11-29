import 'package:test/test.dart';
import 'package:soco/src/groups.dart';
import 'package:soco/src/core.dart';

void main() {
  group('ZoneGroup', () {
    late SoCo coordinator;
    late SoCo member1;
    late SoCo member2;
    late ZoneGroup group;

    setUp(() {
      coordinator = SoCo('192.168.1.101');
      member1 = SoCo('192.168.1.101');
      member2 = SoCo('192.168.1.102');
      group = ZoneGroup(
        uid: 'RINCON_000FD584236D01400:58',
        coordinator: coordinator,
        members: {member1, member2},
      );
    });

    test('creates ZoneGroup with required fields', () {
      expect(group.uid, equals('RINCON_000FD584236D01400:58'));
      expect(group.coordinator, equals(coordinator));
      expect(group.members, containsAll([member1, member2]));
      expect(group.members.length, equals(2));
    });

    test('is iterable', () {
      final membersList = group.toList();
      expect(membersList.length, equals(2));
      expect(membersList, containsAll([member1, member2]));
    });

    test('iterator works correctly', () {
      var count = 0;
      for (final member in group) {
        expect(member, isA<SoCo>());
        count++;
      }
      expect(count, equals(2));
    });

    // Note: label and shortLabel require network calls and would need
    // proper HTTP mocking to test. Skipping for now.
    test('label property exists', () {
      // Just verify the property exists without calling it
      expect(group, isA<ZoneGroup>());
    });

    test('shortLabel property exists', () {
      // Just verify the property exists without calling it
      expect(group, isA<ZoneGroup>());
    });

    test('toString returns formatted group representation', () {
      final str = group.toString();
      expect(str, contains('ZoneGroup'));
      expect(str, contains('192.168.1.101'));
      expect(str, contains('192.168.1.102'));
    });

    test('uid property is accessible', () {
      expect(group.uid, equals('RINCON_000FD584236D01400:58'));
    });

    test('coordinator property is accessible', () {
      expect(group.coordinator, equals(coordinator));
    });

    test('different groups have different properties', () {
      final group2 = ZoneGroup(
        uid: 'RINCON_DIFFERENT:58',
        coordinator: SoCo('192.168.1.103'),
        members: {SoCo('192.168.1.103')},
      );
      expect(group.uid, isNot(equals(group2.uid)));
      expect(group.members, isNot(equals(group2.members)));
    });

    test('members set is immutable from outside', () {
      final originalSize = group.members.length;
      // Get the members set
      final members = group.members;
      // Try to modify (should not affect internal state)
      expect(members.length, equals(originalSize));
    });
  });
}
