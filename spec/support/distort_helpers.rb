module DistortHelpers
  KEY_BYTES = 32
  CIPHERS = %w[chacha20-poly1305].freeze

  def distort(*args, stdin: "".b)
    capture("distort", *args, stdin:)
  end

  def distort_executable
    ENV.fetch("PATH").split(File::PATH_SEPARATOR)
       .map { |dir| File.expand_path("distort", dir) }
       .find { |path| File.file?(path) && File.executable?(path) }
  end

  def fixture(name)
    File.expand_path(File.join("..", "fixtures", name), __dir__)
  end

  def encrypt(plaintext, *options, key: key_path)
    distort("encrypt", "--key-file=#{key}", *options, stdin: plaintext)
  end

  def decrypt(ciphertext, *options, key: key_path)
    distort("decrypt", "--key-file=#{key}", *options, stdin: ciphertext)
  end

  def bounded(*command, stdin_from: nil)
    argv = stdin_from ? redirect(command, "<", stdin_from) : command
    run(*argv) { |session| session.outcome(limit: 1024 * 1024, within: 5) }
  end

  def on_terminal(*command, redirects:)
    capture("script", "-qec", "#{command.shelljoin} #{redirects}", "/dev/null")
  end

  def redirect(command, operator, path)
    ["sh", "-c", %(exec "$@" #{operator} "$0"), path, *command]
  end

  def ciphertext_of(plaintext, *options, key: key_path)
    encrypt(plaintext, *options, key:).stdout
  end

  def write_file(name, bytes)
    File.join(workdir, name).tap { |path| File.binwrite(path, bytes) }
  end

  def random_bytes(count)
    SecureRandom.random_bytes(count)
  end

  def sha256(bytes)
    Digest::SHA256.hexdigest(bytes)
  end

  def stream_geometry(cipher)
    DistortHelpers.geometries[cipher] ||= StreamGeometry.discover do |size|
      ciphertext_of("\0".b * size, "--cipher=#{cipher}").bytesize - size
    end
  end

  def self.geometries
    @geometries ||= {}
  end

  def flip_byte(bytes, index)
    bytes.dup.tap { |copy| copy.setbyte(index, copy.getbyte(index) ^ 0x01) }
  end
end

RSpec.shared_context "with a scratch directory" do
  let(:workdir) { Dir.mktmpdir("distort-spec") }
  let(:key_path) { write_file("key.key", random_bytes(DistortHelpers::KEY_BYTES)) }
  let(:other_key_path) { write_file("other.key", random_bytes(DistortHelpers::KEY_BYTES)) }

  after { FileUtils.remove_entry(workdir) }
end
