Pod::Spec.new do |s|
  s.name = 'valhalla_smb'
  s.version = '0.1.0'
  s.summary = 'Bounded SMB2/3 reads using pinned libsmb2.'
  s.description = s.summary
  s.homepage = 'https://github.com/sahlberg/libsmb2'
  s.license = { :type => 'LGPL-2.1-or-later', :file => '../NOTICE' }
  s.author = 'Valhalla contributors'
  s.source = { :path => '.' }
  s.source_files = 'Classes/*.c'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu11',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_CONFIG_H=1 _FILE_OFFSET_BITS=64 _U_=__attribute__((unused))',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../src/apple" "${PODS_TARGET_SRCROOT}/../vendor/libsmb2/include" "${PODS_TARGET_SRCROOT}/../vendor/libsmb2/include/smb2"',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
