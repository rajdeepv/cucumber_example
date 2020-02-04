require 'socket'

# Crappy REDIS for the Linux agents, to avoid having to install redis everywhere.
# Would have been better had I realised the manual mode wasn't the standard.

# ADD TO YOUR TC BUILD:
#
#        --queue-connection-params redis://localhost:6379,skanky
#  -- or --
#        --obfuscate --queue_connection=redis://localhost:6379,skanky
#  == AND ==
#        env.LC_ALL  en_US.UTF-8

class SkankyRedis
  def initialize
    @db = {}
    @pops = {}
    @db_mutex = Mutex.new
    @server = nil
    @stopping = false
    @flogf = File.absolute_path('skanky_redis.log')
    begin
      File.write(@flogf, "#{Time.now} server started\n")
    rescue StandardError => e
      warn("Unexpectedly, #{@flogf} creation caused #{e}")
    end
  end

  def stop
    @stopping = true
    @server&.close
    if File.file?(@flogf)
      File.write(@flogf, "#{Time.now} server terminated, dumping...\n", mode: 'a')
      @db.sort.each do |k, v|
        File.write(@flogf, "#{Time.now} #{k} : #{v.respond_to?(:length) && v.length} : #{v.inspect}\n", mode: 'a')
      end
    end
    @server = nil
  end

  OK_200 = "HTTP/1.0 200 OK\r\nConnection: Close\r\n"
  TEXT_PLAIN = "Content-type: text/plain\r\n\r\n"
  TEXT_HTML = "Content-type: text/html\r\n\r\n"

  def start
    @server = TCPServer.new(0) # Default is normally 6379
    @port = @server.addr[1]
    @server_url = "http://#{%x(hostname -f).chomp}:#{@port}"
    urls = %x(/sbin/ifconfig).each_line.map { |it| it.match(/inet (?:addr:)?(1[0|9]\S+)/) }.compact.map { |it| "http://#{it[1]}:#{@port}" }
    server_info = "hacky redis server on #{@server_url} (#{urls}) log #{@flogf}"
    puts("Starting #{server_info}")
    Thread.start do
      puts("Running #{server_info}")
      loop do
        Thread.start(@server.accept) do |client|
          service_request(client)
        rescue StandardError
          raise unless @stopping
        end
        # puts "lost #{client}"
      end
    rescue StandardError
      raise unless @stopping
    end
    "redis://127.0.0.1:#{@port},skanky"
  end

  def lpush(k, vv)
    @db_mutex.synchronize do
      vv.each { |v| (@db[k] ||= []).push("$#{v.length}\r\n#{v}") }
      ":#{@db.fetch(k, []).size}"
    end
  end

  def rpush(k, vv)
    @db_mutex.synchronize do
      vv.each { |v| (@db[k] ||= []).unshift("$#{v.length}\r\n#{v}") }
      ":#{@db.fetch(k, []).size}"
    end
  end

  def rpop(k)
    @db_mutex.synchronize do
      l = @db.fetch(k, [])
      p = (@pops[k] ||= []).push(Time.now)
      c = p.count
      if File.file?(@flogf)
        File.write(@flogf, "Time remaining obtained tests_per_second_all tps_last_100 tps_last_10\n", mode: 'a') if c == 1
        File.write(@flogf, "#{p.last} #{l.count} #{c} #{rate(k, c)} #{rate(k, 100)} #{rate(k, 10)}\n", mode: 'a')
      end
      l.empty? ? '$-1' : l.shift
    end
  end

  def get(k)
    @db_mutex.synchronize do
      value = @db.fetch(k, [])
      if value.empty?
        return "*0\r"
      else
        data = value.join("\r\n")
        header = "*#{value.size}\r\n"
        return(header + data)
      end
    end
  end

  def rate(k, c)
    p = @pops[k].last(c)
    if p.count > 1
      (p.count - 1) / (p.last - p.first)
    else
      0
    end
  end

  def llen(k)
    @db_mutex.synchronize do
      ":#{@db.fetch(k, []).size}"
    end
  end

  def http_get(k)
    if /(.\/)?staging-log\//.match?(k)
      if File.directory?(k)
        return [
            OK_200, TEXT_HTML,
            k,
            Dir.entries(k).sort.map { |f| "<br><a href='/#{k}/#{f}'>#{f}</a> #{File.size("#{k}/#{f}")}\n" }
        ].join
      else
        return [
            OK_200, TEXT_PLAIN,
            File.readlines(k).last(200)
        ].join
      end
    end
    @db_mutex.synchronize do
      fetch = @db.fetch(k, [])
      [
          OK_200, TEXT_PLAIN,
          "Size = #{fetch.size}\n",
          fetch.map.with_index { |x, i| "#{i} #{x.inspect}\n" }
      ].join
    end
  end

  def http_collect(k, client, line)
    # Web: env = { SKANKY_HP_SERVER: redis.sub(/^.*redis:\/\//, 'http://').sub(/,.*/, '/hotpanel') }
    # Web: vs __hpid params['__hpurl'] = [skanky_hp_server, '/collect?test_run_id=', make_hotpanel_test_id].join
    @db_mutex.synchronize do
      fetch = (@db[k] ||= [])
      now = Time.now
      s = line + "\r\n"
      begin
        until (f = client.read_nonblock(8192)).empty?
          s += f
        end
      rescue IO::WaitReadable
        retry if Time.now - now < 3
      rescue StandardError => e
        s += e.inspect
      end
      json = s.split("\r\n\r\n", 2).last
      fetch << "$#{json.length}\r\n#{json}"
      [OK_200, TEXT_PLAIN, "Size = #{fetch.size}"].join
    end
  end

  def http_json(k, _client, _line)
    # hotpanel_event_search_server: "#{skanky_hp_server}/json#{query_test_run_id}"
    @db_mutex.synchronize do
      fetch = (@db[k] ||= [])
      [OK_200, TEXT_PLAIN, '[' + fetch.map { |s| "{\"message\":\"\",\"event\":#{s.split("\r\n").last}}" }.join(',') + ']'].join
    end
  end

  def http_list
    @db_mutex.synchronize do
      fetch = @db.keys
      [
          OK_200, TEXT_HTML,
          '<html><body>',
          "<a href='/staging-log/'>staging-log/</a>",
          "<p>Indexes: #{fetch.size}</p>\n<ol>",
          fetch.sort.map { |k| "<li><a href='/#{k}'>#{k}</a> (size=#{@db.fetch(k, []).size})\n" },
          "</ol>\n</body></html>"
      ].join
    end
  end

  private

  def service_request(client)
    # puts "new #{client}"
    client_quit = false
    while client && (line = client.gets)
      line.chomp!
      array = nil
      if line =~ /^\*(\d+)$/
        array = []
        array_len = $1.to_i
        # puts "Array[#{$1} = #{array_len}]"
        array_len.times do
          line = client.gets.chomp
          length = line[1..-1].to_i
          # puts "A[#{array.size}]=#{line}=#{line[1..-1]} = #{length}"
          data = ''
          while data.size < length
            line = client.gets
            data += line
          end
          array << data.chomp
        end
        line = array.join(' ')
        # puts array, line
      end

      begin
        # puts "Respond to #{line}"
        response =
            case line.chomp
              when /^(?i)llen\s+(\S+)$/
                llen($1)
              when /^(?i)rpop\s+(\S+)$/
                rpop($1)
              when /^(?i)lpush\s+(\S+)\s+(.*)$/
                lpush($1, array ? array[2..-1] : $2.scan(/(")((?:[^"]|\\")*)\1|(\S+)/).map(&:compact).map(&:last))
              when /^(?i)rpush\s+(\S+)\s+(.*)$/
                rpush($1, array ? array[2..-1] : $2.scan(/(")((?:[^"]|\\")*)\1|(\S+)/).map(&:compact).map(&:last))
              when /^(?i)get\s+(\S+)$/
                get($1)
              when /^quit/
                client_quit = "client quit - byebye\n"
              when /^\S+\s+\/(\S+?)\/collect(\??\S*)\s+HTTP.*$/ # SKANKY_HP_SERVER magic url
                # Need to clear these eventually
                client_quit = http_collect($1 + $2, client, line)
              when /^\S+\s+\/(\S+?)\/json(\??\S*)\s+HTTP.*$/ # SKANKY_HP_SERVER magic url
                client_quit = http_json($1 + $2, client, line)
              when /^GET\s+\/\s+HTTP.*$/
                client_quit = http_list
              when /^GET\s+\/(\S+)\s+HTTP.*$/
                client_quit = http_get($1)
              else
                "-Don't know #{line.chomp}"
            end
      rescue RuntimeError => e
        response = "Threw: #{e}"
      end
      # rubocop:enable Style/PerlBackrefs
      # puts "Skanky : #{response}"
      client.puts("#{response}\r") unless response.empty?
      client&.flush
      if client_quit
        client.close
        client = nil
      end
    end
    client&.close
  rescue StandardError => e
    puts(e, caller)
  end
end

def with_redis(connection = nil)
  our_redis = connection && !connection.empty? ? nil : SkankyRedis.new
  if our_redis
    # e.g.     "redis://127.0.0.1:#{@port},skanky"
    address = our_redis.start
    # e.g.     "redis://127.0.0.1:#{@port}"
    ENV['REDIS'] = address.split(',').first
    connection = address
  end
  yield(connection)
ensure
  our_redis&.stop
end
