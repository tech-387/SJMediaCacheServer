#
# Be sure to run `pod lib lint SJMediaCacheServer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SJMediaCacheServer'
  s.version          = '2.0.7'
  s.summary          = <<-DESC
SJMediaCacheServer is an efficient HTTP media caching framework.
  DESC

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'SJMediaCacheServer is an efficient HTTP media caching framework designed to proxy media data requests and prioritize serving cached data, thereby reducing network traffic and enhancing playback smoothness. The framework supports two types of remote resources: file-based media, such as common formats like MP3, AAC, WAV, FLAC, OGG, MP4, and MOV, as well as HLS (HTTP Live Streaming) streams. It automatically parses HLS playlists and proxies individual media segments.
The design of SJMediaCacheServer effectively reduces the number of network requests by serving cached content, thereby improving the playback experience for remote media resources whenever possible.'

  s.homepage         = 'https://github.com/changsanjiang/SJMediaCacheServer'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'changsanjiang' => 'changsanjiang@gmail.com' }
  s.source           = { :git => 'https://github.com/tech-387/SJMediaCacheServer.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'

  s.source_files = 'SJMediaCacheServer/*.{h,m}'
  s.subspec 'Core' do |ss|
    ss.source_files = 'SJMediaCacheServer/Core/**/*.{h,m}'
    ss.dependency 'SJMediaCacheServer/KTVCocoaHTTPServer'
  end
  
  s.subspec 'KTVCocoaHTTPServer' do |ss|
    ss.source_files = 'SJMediaCacheServer/KTVCocoaHTTPServer/**/*.{h,m}'
    ss.dependency 'CocoaAsyncSocket'
  end
  
  s.dependency 'SJUIKit/SQLite3'
  
  s.resource_bundles = {
   'SJMediaCacheServer' => ['SJMediaCacheServer/Assets/**/*']
  }
end
