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

      def message(id = nil, payload = '')
        ids = id.nil? ? '' : [id].pack('C')
        packet = ids + payload
        plen = [packet.size].pack('N')
        plen + packet
      end

      def read_message(sock)
        pkt = sock.read(4)
        return nil if pkt.nil?
        size = pkt.unpack('N').first
        if size > 0
          id_payload = sock.read(size)
          id = id_payload[0, 1].unpack('C').first
          payload = id_payload[1, size - 1]
          [id, payload]
        end
      end

      def show_have(have)
        puts have.map{|i| i ? '1' : '0'}.join.to_i(2).to_s(16)
      end

      def handshake(ip, port, info_hash, peer_id, total_size, pieces,
          piece_length)
        have = [false] * pieces.size
        peer_have = [false] * pieces.size
        pstr = 'BitTorrent protocol'
        pstrlen = [pstr.size].pack('C')
        reserved = "\000" * 8
        packet = [pstrlen, pstr, reserved, info_hash, peer_id].join
        blk_size = 16 * 1024
        cur_p = 0
        cur_o = 0
        TCPSocket.open(ip, port) do |sock|
          sock.write(packet)
          size = sock.read(1).unpack('C').first
          recvpkt = sock.read(size + 48)
          sock.write(message(2)) # interested
          #sock.write(message(1)) # unchoke
          # bitfield (all zero)
          sock.write(message(5, ([0] * ((pieces.size + 7) / 8)).pack('C*')))
          req = 0
          loop do
            id, payload = read_message(sock)
            case id
            when 0 # choke
              p :choke
            when 1 # unchoke
              p :unchoke
              req += 50
            when 2 # interested
              p :interested
            when 3 # not interested
              p :not_interested
            when 4 # have
              no = payload.unpack("N").first
              peer_have[no] = true
              show_have(peer_have)
            when 5 # bitfield
              bitstr = payload.unpack("C*").map{|i|"%08b" % i}.join
              peer_have = bitstr.each_char.map{|i|i == '1'}
              show_have(peer_have)
            when 6 # request
              p :request
            when 7 # piece
              index, bgn = payload.unpack('NN')
p [index, pieces.size]
              blk = payload[8, payload.size - 8]
              req += 1
            when 8 # cancel
              p :cancel
            else
              #p :nil
            end
            while req > 0
              break if cur_p >= pieces.size
              req -= 1
              sock.write(message(6, [cur_p, cur_o, blk_size].pack('NNN')))
              cur_o += blk_size
              if cur_o >= piece_length
                cur_o = 0
                sock.write(message(4, [cur_p].pack('N'))) # have
                cur_p += 1
              end
            end
          end
        end
      end

      def run
        # TODO
        torrentf = File.join(SETTING_DIR, 'test.torrent')
        torrent = BEncode.load(File.read(torrentf))
        announce = torrent['announce']
        info = torrent['info']
        total_size = info['length']
        if total_size.nil?
          total_size = info['files'].inject(0){|t,i| t + i['length']}
        end
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
        handshake(*(peers.first +
            [info_hash, peer_id, total_size, pieces, piece_length]))
      end
    end
  end
end
