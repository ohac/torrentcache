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
        info_hash_u = URI.encode(info_hash)
        scrape = announce.gsub(/\/announce\z/, '/scrape')
=begin
        res = open("#{scrape}?info_hash=#{info_hash_u}") do |fd|
          BEncode.load(fd.read)
        end
p res
=end
        peer_id = '-TC0000-abcdef12341j'
        params = { :info_hash => info_hash_u, :peer_id => peer_id,
          :port => 34217, :uploaded => 0, :downloaded => 0, :corrupt => 0,
          :left => 0, :compact => 1, :supportcrypto => 0, :numwant => 200,
          :key => '1234567890'
        }.map{|k,v|"#{k}=#{v}"}.join('&')

        res = open("#{announce}?#{params}"){|fd| BEncode.load(fd.read)}
        peers = res['peers'].each_byte.each_slice(6).map{|i|i.pack('c*')}
p res['interval']
p peers
      end
    end
  end
end
