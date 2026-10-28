Pod::Spec.new do |s|
  s.name         = "IQCoreDataBrowser"
  s.version      = "1.3.1"
  s.summary      = "Fast visualization of CoreData context content"
  s.homepage     = "https://github.com/InQBarna/iq-core-data-browser"
  s.author       = { "David Romacho" => "david.romacho@inqbarna.com", "Sergi Hernanz" => "sergi.hernanz@inqbarna.com"  }
  s.license      = 'MIT'

  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '10.15'

  s.source       = { :git => "https://github.com/InQBarna/iq-core-data-browser.git", :tag => "v#{s.version}" }
  # The public header lives in include/ (the Swift Package layout), so the glob has to go into subfolders
  s.source_files = 'Sources/IQCoreDataBrowser/**/*.{h,m}'
  s.public_header_files = 'Sources/IQCoreDataBrowser/include/*.h'

  s.requires_arc = true
end
