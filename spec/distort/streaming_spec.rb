RSpec.describe "distort streaming" do
  let(:megabyte) { 1024 * 1024 }

  describe "encrypt" do
    it "emits ciphertext before its input has ended" do
      first_output = run("distort", "encrypt", "--key-file=#{key_path}") do |session|
        session.write_in_background(random_bytes(megabyte))
        session.read_available(timeout: 10)
      end
      expect(first_output).not_to be_empty
    end
  end

  describe "decrypt" do
    it "emits plaintext before its input has ended" do
      ciphertext = ciphertext_of(random_bytes(4 * megabyte))
      first_output = run("distort", "decrypt", "--key-file=#{key_path}") do |session|
        session.write_in_background(ciphertext.byteslice(0, 2 * megabyte))
        session.read_available(timeout: 10)
      end
      expect(first_output).not_to be_empty
    end
  end

  context "with a volume far larger than a pipe buffer" do
    it "round-trips 32 MiB through an encrypt and decrypt pipeline" do
      pieces = Enumerator.new { |yielder| 512.times { yielder << random_bytes(64 * 1024) } }
      sent, received = run("sh", "-c", 'distort encrypt --key-file="$1" | distort decrypt --key-file="$1"', "sh", key_path) do |session|
        session.pump(pieces)
      end
      expect(received).to eq(sent)
    end
  end
end
