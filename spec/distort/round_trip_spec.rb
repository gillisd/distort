RSpec.describe "distort round trips" do
  cipher_options = { "the default cipher" => [], "chacha20-poly1305" => ["--cipher=chacha20-poly1305"] }.freeze
  sizes = [0, 1, 15, 16, 17, 4095, 4096, 4097, 16_383, 16_384, 16_385, 65_535, 65_536, 65_537,
           (1024 * 1024) + 3].freeze

  cipher_options.each do |label, options|
    context "with #{label}" do
      sizes.each do |size|
        it "restores #{size} random bytes exactly" do
          plaintext = random_bytes(size)
          expect(sha256(decrypt(ciphertext_of(plaintext, *options), *options).stdout)).to eq(sha256(plaintext))
        end
      end

      it "restores text containing NUL bytes and newlines" do
        plaintext = "line one\n\0\0line two\r\n\xFF\xFE".b
        expect(decrypt(ciphertext_of(plaintext, *options), *options).stdout).to eq(plaintext)
      end

      describe "encrypt" do
        subject(:result) { encrypt(plaintext, *options) }

        let(:plaintext) { "a secret worth keeping\n" * 100 }

        it "exits successfully" do
          expect(result).to be_success
        end

        it "writes nothing to stderr" do
          expect(result.stderr).to be_empty
        end

        it "produces output larger than its input" do
          expect(result.stdout.bytesize).to be > plaintext.bytesize
        end

        it "does not leak the plaintext" do
          expect(result.stdout).not_to include("a secret worth keeping")
        end

        it "produces different ciphertext for the same input on every run" do
          expect(result.stdout).not_to eq(ciphertext_of(plaintext, *options))
        end

        it "produces output for empty input" do
          expect(ciphertext_of("", *options)).not_to be_empty
        end
      end

      describe "decrypt" do
        subject(:result) { decrypt(ciphertext_of(plaintext, *options), *options) }

        let(:plaintext) { random_bytes(10_000) }

        it "exits successfully" do
          expect(result).to be_success
        end

        it "writes nothing to stderr" do
          expect(result.stderr).to be_empty
        end
      end
    end
  end
end
