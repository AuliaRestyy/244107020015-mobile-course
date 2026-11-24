void debugPrintIfDebug(Object? error) {
  assert(() {
    // ignore: avoid_print
    print('[sync] background refresh gagal (offline?): $error');
    return true;
  }());
}
