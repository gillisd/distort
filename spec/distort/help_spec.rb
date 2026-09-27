RSpec.describe "distort help and usage" do
  describe "--help" do
    subject(:result) { distort("--help") }

    it "exits successfully" do
      expect(result).to be_success
    end

    it "prints a usage line naming the program" do
      expect(result.stdout).to match(/^Usage: distort/)
    end

    it "writes nothing to stderr" do
      expect(result.stderr).to be_empty
    end

    %w[encrypt decrypt --key-file --cipher chacha20-poly1305].each do |term|
      it "documents #{term}" do
        expect(result.stdout).to include(term)
      end
    end
  end

  describe "--version" do
    subject(:result) { distort("--version") }

    it "exits successfully" do
      expect(result).to be_success
    end

    it "prints the program name" do
      expect(result.stdout).to start_with("distort")
    end
  end

  context "without any arguments" do
    subject(:result) { distort }

    it "fails" do
      expect(result).not_to be_success
    end

    it "points the user at usage information on stderr" do
      expect(result.stderr).to match(/usage|--help/i)
    end

    it "writes nothing to stdout" do
      expect(result.stdout).to be_empty
    end
  end

  context "with an unknown command" do
    subject(:result) { distort("scramble", "--key-file=#{key_path}") }

    it "fails" do
      expect(result).not_to be_success
    end

    it "explains the problem on stderr" do
      expect(result.stderr).not_to be_empty
    end
  end

  context "with an unknown option" do
    subject(:result) { distort("encrypt", "--key-file=#{key_path}", "--bogus", stdin: "data") }

    it "fails" do
      expect(result).not_to be_success
    end

    it "writes nothing to stdout" do
      expect(result.stdout).to be_empty
    end
  end
end
