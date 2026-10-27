#!/usr/bin/env python3
"""Build the isolated probe or restore the app without exposing signing values."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=['probe', 'terminal', 'app'], required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--code', type=int, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    evidence = root / 'build/acp-device-validation'
    evidence.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    signing = Path(env.get('VALHALLA_SIGN_DIR', '/home/dev/.local/share/valhalla-signing'))
    password = (signing / 'android-release.password').read_text().strip()
    if not password:
        raise RuntimeError('Empty signing credential')
    env.update(VALHALLA_ANDROID_KEYSTORE=str(signing / 'android-release.p12'),
               VALHALLA_ANDROID_STORE_PASSWORD=password,
               VALHALLA_ANDROID_KEY_PASSWORD=password,
               VALHALLA_ANDROID_KEY_ALIAS='valhalla')
    env.pop('VALHALLA_CI_UNSIGNED', None)
    gradle = evidence / 'gradle-home'
    gradle.mkdir(exist_ok=True)
    for name in ['caches', 'wrapper']:
        target = gradle / name
        if not target.exists():
            target.symlink_to(Path('/home/dev/.gradle') / name, target_is_directory=True)
    env['GRADLE_USER_HOME'] = str(gradle)
    target = {'probe': 'tool/acp_runtime_device_probe.dart',
              'terminal': 'tool/terminal_ime_probe.dart',
              'app': 'lib/main.dart'}[args.target]
    command = ['flutter', 'build', 'apk', '--release', '--target-platform', 'android-x64',
               '--target', target, '--build-name', args.version, '--build-number', str(args.code)]
    log = evidence / f'{args.target}-build.log'
    with log.open('w') as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'Build failed ({result.returncode}); inspect {log}')
    destination = evidence / f'{args.target}.apk'
    shutil.copy2(root / 'build/app/outputs/flutter-apk/app-release.apk', destination)
    print(f'Build succeeded: {destination}')


if __name__ == '__main__':
    main()
