#!/usr/bin/env ruby
# encoding=utf-8
require 'sequel' # SQLite 3 database
require 'nokogiri' # Decoding XML/HTML from lastfm api
require 'cgi' # Escaping/Unescaping HTML entities
require 'time_diff' # Calculating difference in times
require 'httparty' # Better HTTP Opening
require 'addressable/uri'
require 'webrick/httputils' # Fix for unicode URLs

module Cinch
  module Plugins
    # Last.fm plugin
    class Lastfm
      include Cinch::Plugin

      def initialize(*args)
        super
        @base_url = 'http://ws.audioscrobbler.com/2.0/?api_key='
        @api_key = config[:api_key]
        @api_url = "#{@base_url}#{@api_key}&method="
        # @db = Sequel.sqlite('riria.db')
        filename = "#{@bot.nick.downcase}.db"
        @db = Sequel.sqlite(filename)
      end

      private

      def get_user(nick)
        return nil if @db[:lastfm].where(nick: nick).empty?
        usernick = @db[:lastfm].where(nick: nick).first[:username]
        usernick
      end

      # Remove stupid pointless tags
      def stupid_tags(tagarray)
        tagarray.delete('seen live') # Worst tag on all of last.fm
        tagarray.delete('indie')

        tagarray
      end

      # Debug shit
      def header(title)
        puts '=' * 10 + " #{title} " + '=' * 10
      end

      public

      # And now onto the commands
      match(/np(?: (.+))?/, method: :np)
      def np(m, query = nil)
        method = 'user.getRecentTracks'

        user = query.nil? ? get_user(m.user.nick) : get_user(query.strip)
        user = query.nil? ? m.user.nick : query.strip unless user

        ac = '&autocorrect=1'
        request = "#{@api_url}#{method}&user=#{user}"

        # Last tracks
        begin
          page = HTTParty.get(Addressable::URI.parse(request))
          doc = Nokogiri::XML(page.body)
          # puts "Fetching #{request}"

          if doc.xpath('//lfm')[0]['status'] == 'failed'
            puts request
            puts doc
            m.reply "Error: #{doc.xpath('//error')[0].text}"
            return
          end
          nowplaying = doc.xpath('//track')[0]['nowplaying']

          whenplayed = doc.xpath('//track//date')[0]['uts'].to_i unless nowplaying

          artist = doc.xpath('//track//artist')[0].text
          title = doc.xpath('//track//name')[0].text
        rescue NoMethodError
          m.reply('No tracks found or username doesn\'t exist!')
          return
        end

        begin
          album = doc.xpath('//track//album')[0].text
          puts "album = #{album}"
        rescue NoMethodError
          album = nil
        end

        album = nil if album == ''

        # Track info
        begin
          header 'TRACK INFO'
          doop = WEBrick::HTTPUtils.escape_form(artist)
          pood = WEBrick::HTTPUtils.escape_form(title)
          # puts doop
          trackreq = "#{@api_url}track.getInfo&artist=#{doop}&track=#{pood}&user=#{user}#{ac}"
          puts "trackreq: #{trackreq}"
          query = trackreq.force_encoding('binary')
          puts "query: #{query}"
          page = HTTParty.get(Addressable::URI.parse(query))
          trackdoc = Nokogiri::XML(page.body)

          if trackdoc.xpath('//lfm')[0]['status'] == 'failed'
            begin
              m.reply error_code(trackdoc.xpath('//error')['code'].to_i)
              return
            rescue TypeError
              puts 'derp'
            end
          end
          header 'trackdoc'
          puts trackdoc
          header 'end trackdoc'
          # listeners = trackdoc.xpath('//track//listeners').text
          # playcount = trackdoc.xpath('//track//playcount').text
          userpc = trackdoc.xpath('//track//userplaycount').text
          loved = trackdoc.xpath('//track//userloved').text.to_i
          # trackinfo = true
          userplayed = true
          puts userpc
          header 'END TRACK INFO'
        # rescue OpenURI::HTTPError
          # trackinfo = false
        rescue NoMethodError
          userplayed = false
        end

        # Artist info
        begin
          doop = WEBrick::HTTPUtils.escape_form(artist)
          # puts doop
          artistreq = "#{@api_url}artist.getInfo#{ac}&artist=#{doop}&user=#{user}"
          query = artistreq.force_encoding('binary')
          page = HTTParty.get(Addressable::URI.parse(query))
          artistdoc = Nokogiri::XML(page.body)
          # puts "Fetching #{query}"
          if artistdoc.xpath('//lfm')[0]['status'] == 'failed'
            m.reply error_code(artistdoc.xpath('//error')[0]['code'].to_i)
            return
          end
          artistinfo = false
          toptags = artistdoc.xpath('//tags//tag//name')
          tags = []
          toptags.each { |i| tags << i.text }
          tags = stupid_tags(tags)
          artistinfo = true unless tags.empty?

        rescue NoMethodError
          artistinfo = false
        end

        unless nowplaying
          future = if whenplayed > Time.now.to_i
                     true
                   else
                     false
                   end
        end

        output = nowplaying ? '♫' : '♪'
        output << " #{artist} :: #{title}"
        output << " [#{album}]" if album
        output << ' ♥' unless loved.zero?
        unless nowplaying
          output << ' :: in ' + Time.diff(Time.at(whenplayed), Time.now)[:diff].to_s if future
          output << ' :: ' + Time.diff(Time.at(whenplayed), Time.now)[:diff].to_s + ' ago' unless future
        end
        # output << ' ::' if nowplaying
        output << " :: #{userpc} plays" if userplayed && !userpc.empty?
        # output << " #{playcount} by #{listeners} others." if trackinfo
        if artistinfo
          len = tags.length >= 3 ? 3 : tags.length
          output << ' :: '
          tags.first(len).each_with_index do |i, j|
            output.concat j == len - 1 ? i.to_s : "#{i}, "
          end
          output << ' ::'
        else
          output << ' :: no tags ::'
        end
        m.reply output
      end

      match(/artist(?: (.+))?/, method: :artist_search)
      match(/plays(?: (.+))?/, method: :artist_search)
      def artist_search(m, query)
        method = 'artist.getInfo'
        specific_user = false

        list = query.split
        if list.include?('-user')
          specific_user = true
          user_index = list.index('-user')
          band = if user_index.zero?
                   list[user_index + 2..-1]
                 else
                   list[0..user_index - 1] + list[user_index + 2..-1]
                 end
          query = band.join ' '
          puts query
          user = list[user_index + 1]
          user = get_user(user) unless get_user(user).nil?
        else
          user = get_user(m.user.nick)
          user = m.user.nick if user.nil? || user.empty?
        end

        artist = query.force_encoding('binary')
        artist = WEBrick::HTTPUtils.escape_form(artist)
        ac = '&autocorrect=1'

        artistreq = "#{@api_url}#{method}#{ac}&artist=#{artist}&user=#{user}"
        page = HTTParty.get(Addressable::URI.parse(artistreq))
        doc = Nokogiri::XML(page.body)
        puts "Fetching #{artistreq}"

        begin
          a = doc.xpath('//artist//name')[0].text
          toptags = doc.xpath('//tags//tag//name')
          listeners = doc.xpath('//stats//listeners').text
          playcount = doc.xpath('//stats//playcount').text
        rescue NoMethodError
          m.reply('Artist not found!')
          return
        end
        begin
          userpc = doc.xpath('//stats//userplaycount').text
          userpc = nil if userpc == ''
        rescue NoMethodError
          userpc = nil
        end

        tags = []
        toptags.each { |i| tags << i.text }
        tags = stupid_tags(tags)

        len = tags.length >= 3 ? 3 : tags.length
        notags = tags.empty? ? true : false

        output = a.to_s
        if notags
          output << ' :: no tags'
        else
          output << ' :: '
          tags.first(len).each_with_index do |i, j|
            output.concat j == len - 1 ? i.to_s : "#{i}, "
          end
        end
        output.concat userpc ? " :: #{userpc} plays" : ' :: '
        output << " by #{user} :: " if specific_user && userpc
        output << ' :: ' if userpc && !specific_user
        output << "#{playcount} by #{listeners} others ::"
        m.reply output
      end

      # Currently broken per Last.fm
      match(/compare(?: (.+))?/, method: :compare)
      def compare(m, user1, user2 = nil)
        method = 'tasteometer.compare'
        user2 = get_user(m.user.nick) unless user2

        creq = "#{@api_url}#{method}&type1=user&type2=user&value1=#{user1}&value2=&#{user2}"
        puts creq
        page = HTTParty.get(Addressable::URI.parse(creq))
        doc = Nokogiri::XML(page.body)
        if doc.xpath('//lfm')[0]['status'] == 'failed'
          m.reply("#{doc.xpath('//error')[0]['code']}: #{doc.xpath('//error').text}")
          # return
        end
        puts doc
      end

      # My probably lousy attempt at not reusing code
      match(/topartists(:? (.+))?/, method: :top_artists)
      def top_artists(m, p)
        tops(m, 'user.getTopArtists', p, 'artists')
      end

      match(/toptracks(:? (.+))?/, method: :top_tracks)
      def top_tracks(m, p)
        tops(m, 'user.getTopTracks', p, 'tracks')
      end

      match(/topalbums(:? (.+))?/, method: :top_albums)
      def top_albums(m, p)
        tops(m, 'user.getTopAlbums', p, 'albums')
      end

      def tops(m, meth, period, type)
        # method = 'user.getTopArtists'
        method = meth
        period = 'overall' if period.nil?

        period.strip!
        list = period.split
        if list.include?('-user')
          user_index = list.index('-user')
          per = if user_index.zero?
                  list[user_index + 2..-1]
                else
                  list[0..user_index - 1] + list[user_index + 2..-1]
                end
          period = per.join ' '
          user = list[user_index + 1]
        else
          user = get_user(m.user.nick)
          user = m.user.nick if user.nil? || user.empty?
        end

        case period
        when '7d', '7day'
          period = '7day'
          str = '7 days'
        when '1m', '1month'
          period = '1month'
          str = '1 month'
        when '3m', '3month'
          period = '3month'
          str = '3 months'
        when '6m', 'month'
          period = '6month'
          str = '6 months'
        when '1y', '1year', '12m', '12month'
          period = '12month'
          str = '1 year'
        else
          period = 'overall'
          str = period
        end

        urlget = "#{@api_url}#{method}&period=#{period}&user=#{user}&limit=10"
        puts urlget
        page = HTTParty.get(Addressable::URI.parse(urlget))
        doc = Nokogiri::XML(page.body)
        # puts "doc: #{doc.text}"

        # This will only ever be true for 'overall'
        output = if str == period
                   "#{str.capitalize} top #{type} "
                 else
                   "Top #{type} of the past #{str} "
                 end

        # process the doc differently depending on query type (artists, tracks,
        # albums, tags, etc.) There's probably a less shitty way to do this but
        # oh well, I tried to not be redundant a bunch
        if method == 'user.getTopArtists'
          artists = []
          plays_in_period = []
          doc.xpath('//topartists//name').each { |i| artists << i.text }
          doc.xpath('//topartists//playcount').each { |i| plays_in_period << i.text }

          # Combine the two arrays into a single hash.
          artplays = Hash[artists.zip(plays_in_period)]
          puts "Artists: #{artists}: #{artists.class}"
          puts "Artplays: #{artplays}: #{artplays.class}"

          len = artplays.length >= 5 ? 5 : artplays.length
          artplays.first(len).each_with_index do |(name, plays), i|
            puts "name: #{name} :: plays: #{plays}, i: #{i}"
            output << ":: #{name} (#{plays})"
            output.concat i == len - 1 ? ' ::' : ' '
          end
        elsif method == 'user.getTopTracks'
          artists = []
          tracks = []
          track_plays = []
          doc.xpath('//artist//name').each { |i| artists << i.text }
          doc.xpath('/lfm/toptracks/track/name').each { |i| tracks << i.text }
          doc.xpath('//track//playcount').each { |i| track_plays << i.text }

          puts "Artists: #{artists.length}, #{artists}"
          puts "Tracks: #{tracks.length}, #{tracks}"
          puts "Playcount: #{track_plays.length}, #{track_plays}"

          unless artists.length == tracks.length && track_plays.length == tracks.length
            # Something went horribly wrong, abort!
            m.reply('Fission mailed!')
            return
          end
          len = tracks.length >= 5 ? 5 : tracks.length
          len.times do |i|
            output << ":: #{artists[i]} - #{tracks[i]} (#{track_plays[i]})"
            output.concat i == len - 1 ? ' ::' : ' '
          end
        elsif method == 'user.getTopAlbums'
          artists = []
          albums = []
          album_plays = []
          doc.xpath('//artist//name').each { |i| artists << i.text }
          doc.xpath('/lfm/topalbums/album/name').each { |i| albums << i.text }
          doc.xpath('//album//playcount').each { |i| album_plays << i.text }

          puts "Artists: #{artists.length}, #{artists}"
          puts "Albums: #{albums.length}, #{albums}"
          puts "Playcount: #{album_plays.length}, #{album_plays}"

          unless artists.length == albums.length && album_plays.length == albums.length
            # Something went horribly wrong, abort!
            m.reply('Fission mailed!')
            return
          end
          len = albums.length >= 5 ? 5 : albums.length
          len.times do |i|
            output << ":: #{artists[i]} - #{albums[i]} (#{album_plays[i]})"
            output.concat i == len - 1 ? ' ::' : ' '
          end
        end

        m.reply output
      end

      # This doesn't seem to work either. Thanks last.fm
      match(/toptags(:? (.+))?/, method: :top_tags)
      def top_tags(m, u)
        user = u.nil? ? get_user(m.user.nick) : get_user(u.strip)
        user = u.nil? ? m.user.nick : u.strip unless user

        method = 'user.getTopTags'
        urlget = "#{@api_url}#{method}&user=#{user}&limit=10"
        puts urlget
        page = HTTParty.get(Addressable::URI.parse(urlget))
        doc = Nokogiri::XML(page.body)

        tags = []
        counts = []

        doc.xpath('//name').each { |i| tags << i }
        doc.xpath('//count').each { |i| counts << i }
        output = "#{user}'s most used tags "

        tagusage = Hash[tags.zip(counts)]

        len = tagusage.length >= 5 ? 5 : tagusage.length
        tagusage.first(len).each_with_index do |(name, plays), i|
          puts "name: #{name} :: plays: #{plays}, i: #{i}"
          output << ":: #{name} (#{plays})"
          output.concat i == len - 1 ? ' ::' : ' '
        end
        output = 'User has not tagged anything!' if tags.empty? || counts.empty?
        m.reply output
      end

      match(/tag(:? (.+))?/, method: :tag_search)
      def tag_search(m, query)
        method = 'tag.getInfo'
        urlget = "#{@api_url}#{method}&tag=#{query.strip}"
        puts urlget
        page = HTTParty.get(Addressable::URI.parse(urlget))
        doc = Nokogiri::XML(page.body)

        num_used = doc.xpath('//tag//total').text
        name = doc.xpath('//tag//name').text
        # Clean up the summary: remove HTML tags, truncate, etc.
        summary = doc.xpath('//tag//wiki//summary').text.gsub(%r{<\/?[^>]*>}, '')
        summary.sub!('Read more on Last.fm.', '')
        summary = if summary.length > 220
                    summary[0..220] + '...'
                  else
                    summary
                  end
        summary = '???' if summary.strip.empty?
        output = "#{name} :: Used: #{num_used} times :: #{summary} ::"
        output += " http://www.last.fm/tag/#{name} ::"
        m.reply output
      end

      match(/profile(:? (.+))?/, method: :profile)
      def profile(m, query)
        method = 'user.getInfo'

        user = query.nil? ? get_user(m.user.nick) : get_user(query.strip)
        user = query.nil? ? m.user.nick : query.strip unless user

        # Fetch the data
        url = "#{@api_url}#{method}&user=#{user}"
        page = HTTParty.get(Addressable::URI.parse(url))
        doc = Nokogiri::XML(page.body)

        realname = doc.xpath('//realname').text
        realname = 'No name' if realname.empty?
        gender = doc.xpath('//gender').text
        playcount = doc.xpath('//playcount').text
        userurl = doc.xpath('//url').text
        country = doc.xpath('//country').text
        country = 'Nowhere' if country.empty?
        reg = doc.xpath('//registered')[0]['unixtime']
        regdate = DateTime.strptime(reg, '%s')

        output = "#{user} :: #{realname} / #{gender} / #{country}"
        output << " :: Plays: #{playcount}"
        output << " :: Registered on: #{regdate.day} #{regdate.strftime('%b')} #{regdate.year}"
        output << " :: #{userurl}"
        m.reply(output)
      end

      match(/fmset(?: (.+))?/, method: :fmset)
      def fmset(m, username = nil)
        m.reply 'You need to input a username to set your username' && return if username.nil?
        username = username.strip
        if @db[:lastfm].where(nick: m.user.nick).empty?
          @db[:lastfm].insert(nick: m.user.nick, username: username)
        else
          uid = @db[:lastfm].where(nick: m.user.nick).first[:id]
          @db[:lastfm].where(id: uid).update(username: username)
        end
        m.reply "#{m.user.nick} is now #{username}!"
      end

      match(/fmget(?: (.+))?/, method: :fmget)
      def fmget(m)
        user = get_user(m.user.nick)
        m.reply user ? "#{m.user.nick} is #{user}!" : 'I don\'t know your username!'
      end
    end
  end
end

# vim:tabstop=2 softtabstop=2 expandtab shiftwidth=2 smarttab foldmethod=syntax:
