void debugPrintIfDebug(Object? error) {
  assert(() {
    print('[sync] background refresh gagal (offline?): $error');
    return true;
  }());
}
