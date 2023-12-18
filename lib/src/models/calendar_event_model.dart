import 'package:flutter/material.dart';

final class CalendarEventModel {
  CalendarEventModel({
    required this.name,
    required this.begin,
    required this.end,
    required this.keyId,
    this.eventColor = Colors.green,
  });

  String name;
  DateTime begin;
  DateTime end;
  Color eventColor;
  String keyId;
}
