require 'rubygems'
require 'fileutils'
require 'bencode'
require 'digest/sha1'

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
        announce = torrent["announce"]
        info = torrent["info"]
p info["pieces"].size
        piece_length = info["piece length"]
        info_hash = Digest::SHA1.hexdigest(BEncode.dump(info)) # TODO
p info_hash
      end
    end
  end
end
