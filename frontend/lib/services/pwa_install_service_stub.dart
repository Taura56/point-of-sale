enum PwaInstallResult { accepted, dismissed, manual, alreadyInstalled }

class PwaInstallService {
  bool get isInstalled => false;

  Future<PwaInstallResult> promptInstall() async {
    return PwaInstallResult.manual;
  }
}
