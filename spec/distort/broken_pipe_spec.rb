RSpec.describe "distort when SIGPIPE is ignored and the reader has gone" do
  subject(:result) { capture(*into_closed_reader_ignoring_sigpipe(command), stdin: input) }

  let(:plaintext) { random_bytes((16 * stream_geometry.chunk) + 7) }

  shared_examples "a quiet broken pipe" do
    it "exits with status 1" do
      expect(result.stdout).to eq("1\n")
    end

    it "reports no write error" do
      expect(result.stderr).not_to include("write error")
    end
  end

  context "when encrypting a multi-chunk stream" do
    let(:command) { ["distort", "encrypt", "--key-file=#{key_path}"] }
    let(:input) { plaintext }

    it_behaves_like "a quiet broken pipe"
  end

  context "when decrypting a multi-chunk stream" do
    let(:command) { ["distort", "decrypt", "--key-file=#{key_path}"] }
    let(:input) { ciphertext_of(plaintext) }

    it_behaves_like "a quiet broken pipe"
  end

  context "with --help" do
    let(:command) { %w[distort --help] }
    let(:input) { "".b }

    it_behaves_like "a quiet broken pipe"
  end
end
