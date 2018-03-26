require 'json'
version = JSON.parse(File.read('package.json'))["version"]

Pod::Spec.new do |s|

  s.name           = "RNMultiPeer"
  s.version        = version
  s.summary        = ""
  s.homepage       = ""
  s.license        = "MIT"
  s.author         = { "Joel Arvidsson" => "joel@oblador.se" }
  s.platform       = :ios, "7.0"
  s.source         = { :git => "https://github.com/atvenu/react-native-multipeer.git", :tag => "v#{s.version}" }
  s.source_files   = '*.{h,m}'
  s.preserve_paths = "**/*.js"
  s.dependency 'React'

end
