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
      def scrape(announce, info_hash)
        params = "info_hash=#{URI.encode(info_hash)}"
        scrape = announce.gsub(/\/announce\z/, '/scrape')
        res = open("#{scrape}?#{params}"){|fd| BEncode.load(fd.read)}
        status = res['files'][info_hash]
        [status['complete'], status['downloaded'], status['incomplete']]
      end

      def message
        id = "\000" # keep alive
        payload = ''
        packet = id + payload
        plen = [packet.size].pack('N')
        plen + packet
      end

      def handshake(ip, port, info_hash, peer_id)
        pstr = 'BitTorrent protocol'
        pstrlen = [pstr.size].pack('C')
        reserved = "\000" * 8
        packet = [pstrlen, pstr, reserved, info_hash, peer_id].join
        TCPSocket.open(ip, port) do |sock|
          sock.write(packet)
          size = sock.read(1).unpack('C').first
          recvpkt = sock.read(size + 49)
p recvpkt
          loop do
            sleep 30
            sock.write(message)
          end
        end
      end

      def run
        # TODO
        torrentf = File.join(SETTING_DIR, 'test.torrent')
        torrent = BEncode.load(File.read(torrentf))
        announce = torrent['announce']
        info = torrent['info']
        total_size = info['files'].inject(0){|t,i| t + i['length']}
        pieces = info['pieces'].each_byte.each_slice(20).map{|cs|cs.pack('c*')}
        piece_length = info['piece length']
        info_hash = Digest::SHA1.digest(BEncode.dump(info))
p scrape(announce, info_hash)
        info_hash_u = URI.encode(info_hash)
        peer_id = '-TC0000-abcdef12341j'
        params = { :info_hash => info_hash_u, :peer_id => peer_id,
          :port => 34217, :uploaded => 0, :downloaded => 0, :corrupt => 0,
          :left => total_size, :compact => 1, :supportcrypto => 0,
# :event => 'stopped' # or started, completed
        }.map{|k,v|"#{k}=#{v}"}.join('&')

        res = open("#{announce}?#{params}"){|fd| BEncode.load(fd.read)}
        peers_raw = res['peers'].each_byte.each_slice(6).map{|i|i.pack('c*')}
        peers = peers_raw.map do |peer_raw|
          ipp = peer_raw.unpack('C4n')
          [ipp.take(4).join('.'), ipp.last]
        end
        interval = res['interval']
        handshake(*(peers.first + [info_hash, peer_id]))
      end
    end
  end
end
