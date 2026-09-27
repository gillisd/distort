RSpec.describe "distort --cipher" do
  let(:plaintext) { "the quick brown fox jumps over the lazy dog\n" * 10 }

  context "when no cipher is chosen" do
    it "encrypts with xchacha20-poly1305" do
      expect(decrypt(ciphertext_of(plaintext), "--cipher=xchacha20-poly1305").stdout).to eq(plaintext)
    end
  end

  context "when xchacha20-poly1305 is chosen" do
    let(:ciphertext) { ciphertext_of(plaintext, "--cipher=xchacha20-poly1305") }

    it "decrypts when the same cipher is named" do
      expect(decrypt(ciphertext, "--cipher=xchacha20-poly1305").stdout).to eq(plaintext)
    end

    it "decrypts without naming the cipher" do
      expect(decrypt(ciphertext).stdout).to eq(plaintext)
    end
  end

  context "when the cipher is given as a separate argument" do
    it "is accepted by encrypt" do
      expect(encrypt(plaintext, "--cipher", "xchacha20-poly1305")).to be_success
    end

    it "is accepted by decrypt" do
      expect(decrypt(ciphertext_of(plaintext), "--cipher", "xchacha20-poly1305").stdout).to eq(plaintext)
    end
  end

  %w[chacha20 chacha20-poly1305 xsalsa20-poly1305 aegis256 blowfish des].each do |name|
    context "when encrypting with the unsupported cipher #{name}" do
      subject(:result) { encrypt(plaintext, "--cipher=#{name}") }

      it "exits with status 64" do
        expect(result.exitstatus).to eq(64)
      end

      it "writes nothing to stdout" do
        expect(result.stdout).to be_empty
      end

      it "explains the problem on stderr" do
        expect(result.stderr).not_to be_empty
      end
    end

    context "when decrypting with the unsupported cipher #{name}" do
      subject(:result) { decrypt(ciphertext_of(plaintext), "--cipher=#{name}") }

      it "exits with status 64" do
        expect(result.exitstatus).to eq(64)
      end

      it "writes nothing to stdout" do
        expect(result.stdout).to be_empty
      end

      it "explains the problem on stderr" do
        expect(result.stderr).not_to be_empty
      end
    end
  end
end
