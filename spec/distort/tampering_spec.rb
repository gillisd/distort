RSpec.describe "distort decrypt of untrustworthy input" do
  let(:plaintext) { random_bytes(100_000) }
  let(:ciphertext) { ciphertext_of(plaintext) }

  context "when the wrong key is used" do
    subject(:result) { decrypt(ciphertext, key: other_key_path) }

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "releases no plaintext" do
      expect(result.stdout).to be_empty
    end

    it "explains the failure on stderr" do
      expect(result.stderr).not_to be_empty
    end
  end

  context "when the format byte is not 1" do
    subject(:result) { decrypt(ciphertext.dup.tap { |bytes| bytes.setbyte(7, 2) }) }

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "reports an unsupported format on stderr" do
      expect(result.stderr).to eq("distort: unsupported stream format version 2\n")
    end
  end

  context "when the first byte is altered" do
    subject(:result) { decrypt(flip_byte(ciphertext, 0)) }

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "releases no plaintext" do
      expect(result.stdout).to be_empty
    end
  end

  {
    "a byte in the middle is altered" => ->(bytes) { flip_byte(bytes, bytes.bytesize / 2) },
    "the last byte is altered" => ->(bytes) { flip_byte(bytes, bytes.bytesize - 1) },
    "the last byte is removed" => ->(bytes) { bytes.byteslice(0, bytes.bytesize - 1) },
    "the second half is removed" => ->(bytes) { bytes.byteslice(0, bytes.bytesize / 2) },
    "trailing bytes are appended" => ->(bytes) { bytes + random_bytes(32) },
    "the stream is appended to itself" => ->(bytes) { bytes + bytes }
  }.each do |description, corrupt|
    context "when #{description}" do
      subject(:result) { decrypt(instance_exec(ciphertext, &corrupt)) }

      it "exits with status 1" do
        expect(result.exitstatus).to eq(1)
      end

      it "explains the failure on stderr" do
        expect(result.stderr).not_to be_empty
      end
    end
  end

  context "when the ciphertext of an empty input is cut short anywhere" do
    it "rejects every proper prefix" do
      full = ciphertext_of("")
      outcomes = (0...full.bytesize).map { |length| decrypt(full.byteslice(0, length)).success? }
      expect(outcomes).to all(be(false))
    end
  end

  context "when the ciphertext of a short message is cut short anywhere" do
    it "rejects every proper prefix" do
      full = ciphertext_of("hi")
      outcomes = (0...full.bytesize).map { |length| decrypt(full.byteslice(0, length)).success? }
      expect(outcomes).to all(be(false))
    end
  end

  context "when stdin is empty" do
    it "exits with status 1" do
      expect(decrypt("").exitstatus).to eq(1)
    end
  end

  context "when stdin is random noise" do
    subject(:result) { decrypt(random_bytes(4096)) }

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "releases no plaintext" do
      expect(result.stdout).to be_empty
    end
  end

  context "when stdin is plaintext" do
    it "exits with status 1" do
      expect(decrypt("hello, world\n" * 100).exitstatus).to eq(1)
    end
  end
end
