RSpec.describe "distort --key-file" do
  let(:plaintext) { "attack at dawn\n" }

  %w[encrypt decrypt].each do |command|
    describe command do
      context "when --key-file is omitted" do
        subject(:result) { distort(command, stdin: plaintext) }

        it "fails" do
          expect(result).not_to be_success
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

        it "fails" do
          expect(result).not_to be_success
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

          it "fails" do
            expect(result).not_to be_success
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
end
