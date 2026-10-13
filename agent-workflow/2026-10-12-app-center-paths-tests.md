# Path regression verification — OpenCode

No subagents. No product/UI/ARB edits, build, ADB input, push or release.
Use only explicit free main/small model. Preserve all existing tests. Do not
rewrite application_compose_test.dart: the prior failing writer was reverted
to its exact pre-run snapshot, all 22 original tests preserved.

Write NEW test/core/application_paths_test.dart only, apply_patch, small tests.
User's failing app is Nginx Proxy Manager. Fixture should use real long-form
bind mounts /DATA/AppData/$AppID/data -> /data and
/DATA/AppData/$AppID/etc/letsencrypt -> /etc/letsencrypt, ports 80/443/81,
image jc21/nginx-proxy-manager:2.13.5, variables AppID (use raw strings!).
Use real ApplicationComposeService.defaults, changeVariables with changed TZ,
and build, valid environment.home /root, instance 32 hex. Assert actual JSON
source/target/read_only and variables, not merely non-empty volumes. Baseline
normal paths should pass. Test separately dataRoot trailing slash plus rebased
sources, manual mount source trailing slash, template target/source trailing
slash in both short and long syntax. Current validation rejects these benign
directory paths; first record actual failing stack, do NOT fix product.
Keep root, slash-only, traversal, relative, control-character and forbidden
mount rejection assertions. Distinguish empty variable versus path error.

Also optional READ-ONLY diagnosis of device: adb devices -l, check foreground
com.antigravity.valhalla.valhalla; only if already foreground, uiautomator dump
to unique /sdcard/valhalla-path-diagnosis.xml and pull into scratch. Print ONLY
nodes whose text starts with / (directory paths) or APP_CENTER_PATH_INVALID,
never password fields, other UI text or whole XML. No taps/launches/navigation,
no production SSH or writes. Current serial was127.0.0.1:14251, do not assume.

Run focused test with complete output and exit status to
/tmp/valhalla-app-paths.HS4wpP/paths-before.log. On assertion failure report
truthfully, do not weaken tests. No global formatting.
