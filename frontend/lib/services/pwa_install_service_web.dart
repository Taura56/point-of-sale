import 'dart:js_interop';

@JS('businessManagerPwaInstall.isInstalled')
external JSBoolean get _isPwaInstalled;

@JS('businessManagerPwaInstall.promptInstall')
external JSPromise<JSString> _promptPwaInstall();

enum PwaInstallResult { accepted, dismissed, manual, alreadyInstalled }

class PwaInstallService {
  bool get isInstalled => _isPwaInstalled.toDart;

  Future<PwaInstallResult> promptInstall() async {
    final outcome = (await _promptPwaInstall().toDart).toDart;
    return switch (outcome) {
      'accepted' => PwaInstallResult.accepted,
      'dismissed' => PwaInstallResult.dismissed,
      'installed' => PwaInstallResult.alreadyInstalled,
      _ => PwaInstallResult.manual,
    };
  }
}
