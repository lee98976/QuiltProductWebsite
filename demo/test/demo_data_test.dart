import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:quilt/Service/firebase_service.dart';
import 'package:quilt/Models/user.dart';

class UnusedStorage extends Fake implements FirebaseStorage {}

void main() {
  final student = UserProfile(
    email: 'demo@quilt.example',
    displayName: 'Some Guy',
    realName: 'Some Guy',
    schoolID: 'troy_high_school',
    UID: 'demo_some_guy',
  );
  test(
    'repeated club and event navigation resolves without Firebase initialization',
    () async {
      final service = FirebaseService(storage: UnusedStorage());
      for (var visit = 0; visit < 5; visit++) {
        final clubs = await service
            .getClubs(student.schoolID)
            .first
            .timeout(const Duration(seconds: 1));
        expect(clubs.map((club) => club.title), contains('Robotics Team'));
        final joined = await service
            .getMembershipClubIds(
              student.schoolID,
              student.UID,
              clubs.map((club) => club.id),
            )
            .timeout(const Duration(seconds: 1));
        expect(joined, contains('robotics_team'));
        final events = await service
            .getCalendarEventsOnce(
              student.schoolID,
              joined,
              startAt: DateTime.now(),
            )
            .timeout(const Duration(seconds: 1));
        expect(events.length, 3);
        expect(
          events.map((event) => event.title),
          contains('Robotics drive practice'),
        );
        final mine = await service
            .getEventSubmissions(student.schoolID, student.UID)
            .first
            .timeout(const Duration(seconds: 1));
        expect(mine.map((event) => event.title), contains('Fall club fair'));
      }
    },
  );
  test(
    'club detail, unseeded queries, and home upcoming events finish locally',
    () async {
      final service = FirebaseService(storage: UnusedStorage());
      expect(
        await service
            .getMembers(student.schoolID, 'robotics_team')
            .first
            .timeout(const Duration(seconds: 1)),
        isNotEmpty,
      );
      expect(
        await service
            .getLeaderMembers(student.schoolID, 'robotics_team')
            .first
            .timeout(const Duration(seconds: 1)),
        isNotEmpty,
      );
      expect(
        await service
            .getPendingClubJoinRequestIds(
              schoolID: student.schoolID,
              userID: student.UID,
              clubIDs: ['robotics_team'],
            )
            .timeout(const Duration(seconds: 1)),
        isEmpty,
      );
      expect(
        await service
            .watchNotifications(student.UID)
            .first
            .timeout(const Duration(seconds: 1)),
        isEmpty,
      );
      expect(
        await service
            .getSignedUpEventsForStudent(student, upcomingOnly: true)
            .timeout(const Duration(seconds: 1)),
        isNotEmpty,
      );
    },
  );
}
