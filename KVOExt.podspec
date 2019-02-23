Pod::Spec.new do |s|
  s.name             = "KVOExt"
  s.version          = "0.3.0"
  s.summary          = "Simplify work with KVO."
  s.homepage         = "https://github.com/alerstov/KVOExt"
  s.license          = 'MIT'
  s.author           = { "Alexander Stepanov" => "alerstov@gmail.com" }
  s.source           = { :git => "https://github.com/alerstov/KVOExt.git", :tag => s.version.to_s }
  s.platform         = :ios, '7.0'
  s.requires_arc     = true
  s.source_files     = 'KVOExt/KVOExt.{h,m}'
end
