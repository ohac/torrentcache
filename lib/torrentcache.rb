require 'rubygems'
require 'fileutils'
require 'bencode'
require 'digest/sha1'
require 'net/http'
require 'open-uri'

module TorrentCache

  HOME_DIR = ENV['HOME']
  SETTING_DIR = "#{HOME_DIR}/.torrentcache"
  unless File.exist? SETTING_DIR
    FileUtils.mkdir SETTING_DIR
  end

  module Client
    class << self
      def run
        # TODO
        torrentf = File.join(SETTING_DIR, 'test.torrent')
        torrent = BEncode.load(File.read(torrentf))
        announce = torrent['announce']
        info = torrent['info']
        pieces = info['pieces'].each_byte.each_slice(20).map{|cs|cs.pack('c*')}
        piece_length = info['piece length']
        info_hash = Digest::SHA1.digest(BEncode.dump(info))
        scrape = announce.gsub(/\/announce\z/, '/scrape')
        res = open("#{scrape}?info_hash=#{URI.encode(info_hash)}") do |fd|
          BEncode.load(fd.read)
        end
p res
      end
    end
  end
end
