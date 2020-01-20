Pod::Spec.new do |s|
  s.name         = "IQCoreDataBrowser"
  s.version      = "1.1.0"
  s.summary      = "Fast visualization of CoreData context content"
  s.homepage     = "https://github.com/InQBarna/iq-core-data-browser"
  s.author       = { "David Romacho" => "david.romacho@inqbarna.com", "Sergi Hernanz" => "sergi.hernanz@inqbarna.com"  }
  s.license      = 'MIT'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.7'

  s.source       = { :git => "https://github.com/InQBarna/iq-core-data-browser/iq-core-data-browser.git", :tag => "1.1.0" }
  s.source_files = 'IQCoreDataBrowser/*.{h,m}'

  s.requires_arc = true
end
