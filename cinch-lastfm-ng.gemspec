
# -*- encoding: utf-8 -*-
$LOAD_PATH.push('lib')
require 'cinch/plugins/lastfm/version.rb'

Gem::Specification.new do |s|
  s.name     = 'cinch-lastfm-ng'
  s.version  = Cinch::Lastfm::VERSION.dup
  s.licenses = ['MIT']
  s.date     = '2016-05-22'
  s.summary  = 'Lastfm plugin for Cinch'
  s.email    = 'lilian.jonsdottir@gmail.com'
  s.homepage = 'https://github.com/lilyseki/Cinch-Lastfm'
  s.authors  = ['Lily Jónsdóttir']

  s.description = <<-EOF
Lastfm plugin for Cinch, featuring mulitple commands.
Display recently played tracks, search artists, display top
artists/albums/tracks from specified time period, search tags, display profile
information, etc.
EOF

  dependencies = [
    [:runtime, 'sequel', '~> 4.34'],
    [:runtime, 'nokogiri', '~> 1.6'],
    [:runtime, 'time_diff', '~> 0.3'],
    [:runtime, 'addressable', '~> 2.4']
  ]

  s.files         = Dir['**/*']
  s.test_files    = Dir['test/**/*'] + Dir['spec/**/*']
  s.executables   = Dir['bin/*'].map { |f| File.basename(f) }
  s.require_paths = ['lib']

  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = '2.5.1'
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.specification_version = 3 if s.respond_to? :specification_version

  dependencies.each do |type, name, version|
    if s.respond_to?("add_#{type}_dependency")
      s.send("add_#{type}_dependency", name, version)
    else
      s.add_dependency(name, version)
    end
  end
end

# vim:tabstop=2 softtabstop=2 expandtab shiftwidth=2 smarttab foldmethod=syntax:
