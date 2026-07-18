#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint thefaithapp_auth.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'thefaithapp_auth'
  s.version          = '0.1.0'
  s.summary          = 'Hosted member authentication for TheFaithApp Flutter apps.'
  s.description      = <<-DESC
Opens TheFaithApp hosted sign-in, completes PKCE, and securely stores member sessions.
                       DESC
  s.homepage         = 'https://thefaithapp.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'TheFaithApp' => 'support@thefaithapp.com' }
  s.source           = { :path => '.' }
  s.source_files = 'thefaithapp_auth/Sources/thefaithapp_auth/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'thefaithapp_auth_privacy' => ['thefaithapp_auth/Sources/thefaithapp_auth/PrivacyInfo.xcprivacy']
  }
end
