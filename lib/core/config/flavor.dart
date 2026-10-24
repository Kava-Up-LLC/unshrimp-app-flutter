/// Build flavor, from `--dart-define=FLAVOR=dev|prod`. It drives only the DEV
/// launcher badge and the DEV label on Home — never the App Key. An absent or
/// unknown value reads as prod, so a build with no define never shows the badge
/// or the label.
const appFlavor = String.fromEnvironment('FLAVOR');

/// Whether this is the dev flavor (the only one that shows the DEV badge/label).
bool isDevFlavor([String flavor = appFlavor]) => flavor == 'dev';
