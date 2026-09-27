RSpec.describe "distort when stdout is closed" do
  let(:geometry) { stream_geometry }

  {
    "an empty input" => ->(_geometry) { "".b },
    "a small input" => ->(_geometry) { "attack at dawn\n" },
    "a multi-chunk input" => ->(geometry) { SecureRandom.random_bytes((3 * geometry.chunk) + 7) }
  }.each do |size, plaintext_for|
    context "when encrypting #{size}" do
      subject(:result) do
        capture(*with_stdout_closed(["distort", "encrypt", "--key-file=#{key_path}"]), stdin: plaintext_for.call(geometry))
      end

      it "exits with status 1" do
        expect(result.exitstatus).to eq(1)
      end

      it "reports the write error once on stderr, with its reason" do
        expect(result.stderr).to eq("distort: write error: Bad file descriptor\n")
      end
    end
  end

  context "when decrypting a multi-chunk stream" do
    subject(:result) do
      capture(*with_stdout_closed(["distort", "decrypt", "--key-file=#{key_path}"]),
              stdin: ciphertext_of(random_bytes((2 * geometry.chunk) + 1)))
    end

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "reports the write error once on stderr, with its reason" do
      expect(result.stderr).to eq("distort: write error: Bad file descriptor\n")
    end
  end

  context "when decrypting a stream of empty plaintext, so there is nothing to write" do
    subject(:result) do
      capture(*with_stdout_closed(["distort", "decrypt", "--key-file=#{key_path}"]), stdin: ciphertext_of("".b))
    end

    it "exits with status 0" do
      expect(result.exitstatus).to eq(0)
    end

    it "writes nothing to stderr" do
      expect(result.stderr).to be_empty
    end
  end

  context "when decrypting input that is not a distort stream" do
    subject(:result) do
      capture(*with_stdout_closed(["distort", "decrypt", "--key-file=#{key_path}"]), stdin: "plain text\n")
    end

    it "exits with status 1" do
      expect(result.exitstatus).to eq(1)
    end

    it "reports only the bad input on stderr" do
      expect(result.stderr).to eq("distort: input is not a distort stream\n")
    end
  end

  context "with a usage error" do
    subject(:result) { capture(*with_stdout_closed(%w[distort scramble])) }

    it "exits with status 64" do
      expect(result.exitstatus).to eq(64)
    end

    it "reports no write error" do
      expect(result.stderr).not_to include("write error")
    end
  end

  %w[--version --usage].each do |option|
    context "with #{option}" do
      subject(:result) { capture(*with_stdout_closed(["distort", option])) }

      it "exits with status 1" do
        expect(result.exitstatus).to eq(1)
      end

      it "reports the write error on stderr, with its reason" do
        expect(result.stderr).to eq("distort: write error: Bad file descriptor\n")
      end
    end
  end
end
