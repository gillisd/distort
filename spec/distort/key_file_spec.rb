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

          it "explains the problem on stderr" do
            expect(result.stderr).not_to be_empty
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

  context "when the key is written as 64 hex digits" do
    let(:raw_key) { random_bytes(DistortHelpers::KEY_BYTES) }
    let(:raw_key_path) { write_file("raw.key", raw_key) }
    let(:hex) { raw_key.unpack1("H*") }

    {
      "without a line ending" => "",
      "with a trailing newline" => "\n",
      "with a trailing CRLF" => "\r\n"
    }.each do |description, ending|
      context description do
        let(:hex_key_path) { write_file("hex.key", hex + ending) }

        it "encrypts to a stream that the same key in raw form decrypts" do
          ciphertext = ciphertext_of(plaintext, key: hex_key_path)
          expect(decrypt(ciphertext, key: raw_key_path).stdout).to eq(plaintext)
        end

        it "decrypts a stream that the same key in raw form encrypted" do
          ciphertext = ciphertext_of(plaintext, key: raw_key_path)
          expect(decrypt(ciphertext, key: hex_key_path).stdout).to eq(plaintext)
        end
      end
    end

    context "with upper-case digits" do
      it "decrypts a stream that the same key in raw form encrypted" do
        ciphertext = ciphertext_of(plaintext, key: raw_key_path)
        expect(decrypt(ciphertext, key: write_file("hex.key", "#{hex.upcase}\n")).stdout).to eq(plaintext)
      end
    end

    {
      "two newlines" => "\n\n",
      "three newlines" => "\n\n\n",
      "a bare carriage return" => "\r",
      "two CRLFs" => "\r\n\r\n",
      "a trailing space" => " \n"
    }.each do |description, ending|
      context "when followed by #{description}" do
        subject(:result) { encrypt(plaintext, key: write_file("hex.key", hex + ending)) }

        it "exits with status 1" do
          expect(result.exitstatus).to eq(1)
        end

        it "writes nothing to stdout" do
          expect(result.stdout).to be_empty
        end

        it "reports an invalid key" do
          expect(result.stderr).to match(/invalid key/)
        end
      end
    end

    context "when a digit is not hexadecimal" do
      subject(:result) { encrypt(plaintext, key: write_file("hex.key", "#{hex[0, 63]}g\n")) }

      it "exits with status 1" do
        expect(result.exitstatus).to eq(1)
      end

      it "reports an invalid key" do
        expect(result.stderr).to match(/invalid key/)
      end
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
