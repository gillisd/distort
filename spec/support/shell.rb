require "digest"
require "open3"

module Shell
  Result = Data.define(:stdout, :stderr, :status) do
    def success? = status&.success? || false

    def finished? = !status.nil?

    def exitstatus = status&.exitstatus
  end

  class Session
    CHUNK = 64 * 1024

    def initialize(stdin, stdout, stderr, wait)
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @wait = wait
      @writer = nil
    end

    def write_in_background(bytes)
      @writer = Thread.new do
        @stdin.write(bytes)
      rescue IOError, SystemCallError
        nil
      end
    end

    def read_available(timeout:)
      ready, = IO.select([@stdout], nil, nil, timeout)
      ready ? @stdout.readpartial(CHUNK) : "".b
    rescue EOFError
      "".b
    end

    def pump(pieces)
      sent = Digest::SHA256.new
      writer = Thread.new do
        pieces.each { |piece| @stdin.write(piece.tap { sent << piece }) }
        @stdin.close
      end
      received = Digest::SHA256.new
      loop { received << @stdout.readpartial(CHUNK) }
    rescue EOFError
      writer.join
      [sent.hexdigest, received.hexdigest]
    end

    def outcome(limit:, within:)
      deadline = now + within
      @stdin.close
      errors = "".b
      reader = collect_stderr(errors, limit)
      out = read_stdout(limit, deadline)
      status = @wait.join([deadline - now, 0].max)&.value
      reader.join(0.5)
      Result.new(stdout: out, stderr: errors.dup, status:)
    end

    def close
      @stdin.close unless @stdin.closed?
      @writer&.join(5)
      @writer&.kill
      terminate
      [@stdout, @stderr].each { |io| io.close unless io.closed? }
    end

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def read_stdout(limit, deadline)
      buffer = "".b
      while buffer.bytesize < limit && deadline > now
        break unless IO.select([@stdout], nil, nil, deadline - now)

        buffer << @stdout.readpartial([CHUNK, limit - buffer.bytesize].min)
      end
      buffer
    rescue EOFError
      buffer
    end

    def collect_stderr(buffer, limit)
      Thread.new do
        buffer << @stderr.readpartial(CHUNK) while buffer.bytesize < limit
      rescue EOFError, IOError
        nil
      end
    end

    def terminate
      %w[TERM KILL].each do |signal|
        return if @wait.join(signal == "TERM" ? 0 : 1)

        signal_group(signal)
      end
      @wait.join
    end

    def signal_group(signal)
      Process.kill(signal, -@wait.pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
  end

  def capture(*command, stdin: "".b)
    stdout, stderr, status = Open3.capture3(*command, stdin_data: stdin, binmode: true)
    Result.new(stdout:, stderr:, status:)
  end

  def run(*command)
    stdin, stdout, stderr, wait = Open3.popen3(*command, pgroup: true)
    [stdin, stdout, stderr].each(&:binmode)
    session = Session.new(stdin, stdout, stderr, wait)
    yield session
  ensure
    session&.close
  end
end
