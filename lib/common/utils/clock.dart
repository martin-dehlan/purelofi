/// m:ss — hours would be dishonest for a three-minute track.
String clockOf(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
