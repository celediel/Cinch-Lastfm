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

**[np (username)]**
Displays last played track from user's saved username, or specified username.

**[(plays|artist) (artistname)]**
Displays info, and user playcount if played, of specified artist.

**[top(artists|tracks|albums) (7d|1m|3m|6m|1y|overall)]**
Displays user's top artists/tracks/albums from specified period.

**[tag (tag)]**
Displays info about specified tag, if it exists.

**[profile (username)]**
Display user's or specified user's profile information.

**[fmset (username)]**
Store specified username in the database.

**[fmget]**
Displays stored username.

License
-------

Licensed under The MIT License (MIT)

Please see LICENSE
