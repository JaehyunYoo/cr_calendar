import 'dart:convert';

import 'package:cr_calendar/src/contract.dart';
import 'package:cr_calendar/src/cr_calendar.dart';
import 'package:cr_calendar/src/extensions/datetime_ext.dart';
import 'package:cr_calendar/src/extensions/jiffy_ext.dart';
import 'package:cr_calendar/src/models/calendar_event_model.dart';
import 'package:cr_calendar/src/models/drawers.dart';
import 'package:cr_calendar/src/models/event_count_keeper.dart';
import 'package:jiffy/jiffy.dart';

///Returns list of events for [date]
List<CalendarEventModel> calculateAvailableEventsForDate(
    List<CalendarEventModel> events, Jiffy date) {
  final eventsHappen = <CalendarEventModel>[];
  for (final event in events) {
    final eventStartUtc =
        DateTime.utc(event.begin.year, event.begin.month, event.begin.day);
    final eventEndUtc =
        DateTime.utc(event.end.year, event.end.month, event.end.day);
    if (date.isInRange(eventStartUtc.toJiffy(), eventEndUtc.toJiffy())) {
      eventsHappen.add(event);
    }
  }

  return eventsHappen;
}

List<CalendarEventModel> calculateAvailableEventsForRange(
    List<CalendarEventModel> events, Jiffy? start, Jiffy? end) {
  final eventsHappen = <CalendarEventModel>[];

  for (final event in events) {
    final eventStartUtc =
        DateTime.utc(event.begin.year, event.begin.month, event.begin.day);
    final eventEndUtc =
        DateTime.utc(event.end.year, event.end.month, event.end.day);
    if (eventStartUtc.toJiffy().isInRange(start, end) ||
        eventEndUtc.toJiffy().isInRange(start, end) ||
        (start?.isInRange(eventStartUtc, eventEndUtc) ?? false) ||
        (end?.isInRange(eventStartUtc, eventEndUtc) ?? false)) {
      eventsHappen.add(event);
    }
  }

  return eventsHappen;
}

/// Returns drawers for [week]
List<EventProperties> resolveEventDrawersForWeek(
    int week, Jiffy monthStart, List<CalendarEventModel> events) {
  final drawers = <EventProperties>[];

  final beginDate = Jiffy.parseFromJiffy(monthStart).add(weeks: week);
  final endDate =
      Jiffy.parseFromJiffy(beginDate).add(days: Contract.kWeekDaysCount - 1);

  for (final e in events) {
    final simpleEvent = _mapSimpleEventToDrawerOrNull(e, beginDate, endDate);
    if (simpleEvent != null) {
      drawers.add(simpleEvent);
    }
  }

  return drawers;
}

/// This method maps CalendarEventItem to EventDrawer and calculates drawer begin and end
EventProperties? _mapSimpleEventToDrawerOrNull(
    CalendarEventModel event, Jiffy begin, Jiffy end) {
  final jBegin = DateTime.utc(
    event.begin.year,
    event.begin.month,
    event.begin.day,
    event.begin.hour,
    event.begin.minute,
  ).toJiffy();
  final jEnd = DateTime.utc(
    event.end.year,
    event.end.month,
    event.end.day,
    event.end.hour,
    event.end.minute,
  ).toJiffy();

  if (jEnd.isBefore(begin, unit: Unit.day) ||
      jBegin.isAfter(end, unit: Unit.day)) {
    return null;
  }

  var beginDay = 1;
  if (jBegin.isSameOrAfter(begin)) {
    beginDay = (begin.dayOfWeek - jBegin.dayOfWeek < 1)
        ? 1 - (begin.dayOfWeek - jBegin.dayOfWeek)
        : 1 - (begin.dayOfWeek - jBegin.dayOfWeek) + WeekDay.values.length;
  }

  var endDay = Contract.kWeekDaysCount;
  if (jEnd.isSameOrBefore(end)) {
    endDay = (begin.dayOfWeek - jEnd.dayOfWeek < 1)
        ? 1 - (begin.dayOfWeek - jEnd.dayOfWeek)
        : 1 - (begin.dayOfWeek - jEnd.dayOfWeek) + WeekDay.values.length;
  }

  return EventProperties(
    begin: beginDay,
    end: endDay,
    name: event.name,
    backgroundColor: event.eventColor,
    keyId: event.keyId,
  );
}

/// Map EventDrawers to EventsLineDrawer and sort them by duration on current week
// List<EventsLineDrawer> placeEventsToLines(
//     List<EventProperties> events, int maxLines) {
//   final copy = <EventProperties>[...events]
//     ..sort((a, b) => b.size().compareTo(a.size()));
//
//   final lines = List.generate(maxLines, (index) {
//     final lineDrawer = EventsLineDrawer();
//     for (var day = 1; day <= Contract.kWeekDaysCount; day++) {
//       final candidates = <EventProperties>[];
//       copy.forEach((e) {
//         if (day == e.begin) {
//           print(e.begin);
//           candidates.add(e);
//         }
//       });
//       candidates.sort((a, b) => b.size().compareTo(a.size()));
//       if (candidates.isNotEmpty) {
//         lineDrawer.events.add(candidates.first);
//         copy.remove(candidates.first);
//         day += candidates.first.size() - 1;
//       }
//     }
//     return lineDrawer;
//   });
//   return lines;
// }
// List<EventsLineDrawer> placeEventsToLines(
//     List<EventProperties> events, int maxLines) {
//   final copy = <EventProperties>[...events];
//
//   // 라인 생성
//   final lines = List.generate(maxLines, (index) {
//     final lineDrawer = EventsLineDrawer();
//     for (var day = 1; day <= Contract.kWeekDaysCount; day++) {
//       // 같은 날짜에 시작하는 이벤트 후보들을 찾음
//
//       final candidates = <EventProperties>[];
//       copy.forEach((e) {
//         if (day == e.begin) {
//           candidates.add(e);
//         }
//       });
//
//       candidates.sort((a, b) {
//         return _keyIdPriority(a.keyId).compareTo(_keyIdPriority(b.keyId));
//       });
//
//       // 후보 중 첫 번째 이벤트를 선택하여 라인에 추가
//       if (candidates.isNotEmpty) {
//         lineDrawer.events.add(candidates.first);
//         copy.remove(candidates.first);
//
//         day += candidates.first.size() - 1;
//       }
//     }
//     return lineDrawer;
//   });
//
//   return lines;
// }
List<EventsLineDrawer> placeEventsToLines(
    List<EventProperties> events, int maxLines) {
  final copy = <EventProperties>[...events];

  // 라인 생성
  final lines = List.generate(maxLines, (index) {
    final lineDrawer = EventsLineDrawer();
    int currentDay = 1; // 시작 날짜를 1로 초기화

    while (currentDay <= Contract.kWeekDaysCount) {
      // 같은 날짜에 시작하는 이벤트 후보들을 찾음
      final candidates = <EventProperties>[];
      copy.forEach((e) {
        if (currentDay == e.begin) {
          candidates.add(e);
        }
      });

      candidates.sort((a, b) {
        return _keyIdPriority(a.keyId).compareTo(_keyIdPriority(b.keyId));
      });

      // 현재 라인에 이미 그려진 이벤트 중에서 마지막 이벤트의 end 값
      int lastEventEnd = lineDrawer.events.isEmpty
          ? 0 // 현재 라인에 아무 이벤트도 없는 경우 0으로 초기화
          : lineDrawer.events.last.end;

      // 후보가 있다면 순차적으로 라인에 그림
      bool addedEvent = false; // 이벤트가 추가되었는지 여부를 추적
      for (var candidate in candidates) {
        if (candidate.begin > lastEventEnd) {
          // 현재 이벤트의 begin이 이미 그려진 이벤트의 end보다 큰 경우에만 그림
          lineDrawer.events.add(candidate);
          copy.remove(candidate);
          addedEvent = true; // 이벤트 추가됨
          lastEventEnd = candidate.end; // 현재 이벤트의 end 값을 업데이트
        }
      }

      // 이벤트가 추가되지 않았으면 다음 날짜로 이동
      if (!addedEvent) {
        currentDay++;
      }
    }

    return lineDrawer;
  });

  return lines;
}

int _keyIdPriority(String keyId) {
  switch (keyId) {
    case '우리':
      return 1; // 가장 높은 우선순위
    case '나':
      return 2;
    case '상대방':
      return 3; // 가장 낮은 우선순위
    default:
      return 4; // 예상치 못한 값에 대한 처리
  }
}

///Return list of not fitted events
List<NotFittedWeekEventCount> calculateOverflowedEvents(
    List<List<EventProperties>> monthEvents, int maxLines) {
  final weeks = <NotFittedWeekEventCount>[];
  for (final week in monthEvents) {
    var countList = List.filled(WeekDay.values.length, 0);

    for (final event in week) {
      for (var i = event.begin - 1; i < event.end; i++) {
        countList[i]++;
      }
    }
    countList = countList.map((count) {
      final notFitCount = count - maxLines;
      return notFitCount <= 0 ? 0 : notFitCount;
    }).toList();
    weeks.add(NotFittedWeekEventCount(countList));
  }
  return weeks;
}
