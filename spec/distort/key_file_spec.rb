RSpec.describe "distort --key-file" do
  let(:plaintext) { "attack at dawn\n" }

  %w[encrypt decrypt].each do |command|
    describe command do
      context "when --key-file is omitted" do
        subject(:result) { distort(command, stdin: plaintext) }

        it "exits with status 64" do
          expect(result.exitstatus).to eq(64)
        end

        it "mentions the key on stderr" do
          expect(result.stderr).to match(/key/i)
        end

        it "writes nothing to stdout" do
          expect(result.stdout).to be_empty
        end
      end

      context "when the key file does not exist" do
        subject(:result) { distort(command, "--key-file=#{missing}", stdin: plaintext) }

        let(:missing) { File.join(workdir, "missing.key") }

        it "exits with status 1" do
          expect(result.exitstatus).to eq(1)
        end

        it "names the missing file on stderr" do
          expect(result.stderr).to include(missing)
        end

        it "writes nothing to stdout" do
          expect(result.stdout).to be_empty
        end
      end

      [0, 16, 31, 33, 64].each do |size|
        context "when the key file holds #{size} bytes" do
          subject(:result) { distort(command, "--key-file=#{write_file('bad.key', random_bytes(size))}", stdin: plaintext) }

          it "exits with status 1" do
            expect(result.exitstatus).to eq(1)
          end

          it "writes nothing to stdout" do
            expect(result.stdout).to be_empty
          end

          it "reports that the key must be 32 bytes" do
            expect(result.stderr).to eq("distort: #{File.join(workdir, 'bad.key')}: invalid key: expected 32 bytes\n")
          end
        end
      end
    end
  end

  context "when given as a separate argument" do
    it "round-trips the plaintext" do
      ciphertext = distort("encrypt", "--key-file", key_path, stdin: plaintext).stdout
      expect(distort("decrypt", "--key-file", key_path, stdin: ciphertext).stdout).to eq(plaintext)
    end
  end

  context "when the key file holds 64 hex digits as text" do
    subject(:result) { encrypt(plaintext, key: hex_key_path) }

    let(:hex_key_path) { write_file("hex.key", random_bytes(DistortHelpers::KEY_BYTES).unpack1("H*")) }

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "writes nothing to stdout" do
      expect(result.stdout).to be_empty
    end

    it "reports that the key must be 32 bytes" do
      expect(result.stderr).to eq("distort: #{hex_key_path}: invalid key: expected 32 bytes\n")
    end
  end

  context "when the key file holds 32 hex characters as text" do
    let(:hex_key_path) { write_file("hex.key", random_bytes(DistortHelpers::KEY_BYTES / 2).unpack1("H*")) }
    let(:raw_key_path) { write_file("raw.key", File.binread(hex_key_path)) }

    it "encrypts with the characters themselves as the key" do
      expect(encrypt(plaintext, key: hex_key_path).exitstatus).to eq(0)
    end

    it "encrypts to a stream that the same 32 bytes decrypt" do
      ciphertext = ciphertext_of(plaintext, key: hex_key_path)
      expect(decrypt(ciphertext, key: raw_key_path).stdout).to eq(plaintext)
    end
  end

  context "when a 32-byte key is followed by a newline" do
    subject(:result) { encrypt(plaintext, key: write_file("newline.key", "#{random_bytes(DistortHelpers::KEY_BYTES)}\n")) }

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "reports an invalid key" do
      expect(result.stderr).to match(/invalid key: expected 32 bytes$/)
    end
  end

  context "when the key file holds only line endings" do
    subject(:result) { encrypt(plaintext, key: write_file("blank.key", "\n\n\n")) }

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "reports an invalid key" do
      expect(result.stderr).to match(/invalid key/)
    end
  end
end
