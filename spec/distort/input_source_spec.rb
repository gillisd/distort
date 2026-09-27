RSpec.describe "distort input sources" do
  let(:plaintext) { random_bytes(200_000) }
  let(:digest) { sha256(plaintext) }

  context "when encrypting a file named on the command line" do
    subject(:result) { distort("encrypt", "--key-file=#{key_path}", write_file("bigfile.bin", plaintext)) }

    it "exits successfully" do
      expect(result).to be_success
    end

    it "produces ciphertext that decrypts from stdin" do
      expect(sha256(decrypt(result.stdout).stdout)).to eq(digest)
    end
  end

  context "when decrypting a file named on the command line" do
    subject(:result) { distort("decrypt", "--key-file=#{key_path}", write_file("bigfile.bin.enc", ciphertext_of(plaintext))) }

    it "exits successfully" do
      expect(result).to be_success
    end

    it "restores the plaintext" do
      expect(sha256(result.stdout)).to eq(digest)
    end
  end

  context "when a file is named and stdin also carries data" do
    it "reads the named file" do
      path = write_file("bigfile.bin", plaintext)
      ciphertext = distort("encrypt", "--key-file=#{key_path}", path, stdin: "not the file").stdout
      expect(sha256(decrypt(ciphertext).stdout)).to eq(digest)
    end
  end

  context "when options follow the file name" do
    it "still honours them" do
      path = write_file("bigfile.bin", plaintext)
      ciphertext = distort("encrypt", path, "--cipher=chacha20-poly1305", "--key-file=#{key_path}").stdout
      expect(sha256(decrypt(ciphertext, "--cipher=chacha20-poly1305").stdout)).to eq(digest)
    end
  end

  context "when the file is named as -" do
    it "reads stdin" do
      ciphertext = distort("encrypt", "--key-file=#{key_path}", "-", stdin: plaintext).stdout
      expect(sha256(decrypt(ciphertext).stdout)).to eq(digest)
    end
  end

  %w[encrypt decrypt].each do |command|
    context "when #{command} is given a file that does not exist" do
      subject(:result) { distort(command, "--key-file=#{key_path}", missing) }

      let(:missing) { File.join(workdir, "nope.bin") }

      it "fails" do
        expect(result).not_to be_success
      end

      it "names the file on stderr" do
        expect(result.stderr).to include(missing)
      end

      it "writes nothing to stdout" do
        expect(result.stdout).to be_empty
      end
    end
  end
end
