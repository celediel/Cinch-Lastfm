Automode Plugin for Cinch
========================
Lastfm plugin for Cinch, featuring mulitple commands.
Display recently played tracks, search artists, display top
artists/albums/tracks from specified time period, search tags, display profile
information, etc.

Usage
-----

[![Gem Version](https://badge.fury.io/rb/cinch-lastfm-ng.svg)](https://badge.fury.io/rb/cinch-lastfm-ng)

install the gem with *gem install cinch-lastfm-ng*, and
add it to your bot like so:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ruby
require 'cinch'
require 'cinch/plugins/lastfm'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = 'your server'
    c.nick = 'your nick'
    c.realname = 'your realname'
    c.user = 'your user'
    c.channels = ['#yourchannel']
    c.plugins.plugins = [Cinch::Plugins::Lastfm]
  end
end

bot.start
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Contained Commands
------------------

TODO: this

License
-------

Licensed under The MIT License (MIT)

Please see LICENSE
