RSpec.describe "distort help and usage" do
  describe "--help" do
    subject(:result) { distort("--help") }

    it "exits with status 0" do
      expect(result.exitstatus).to eq(0)
    end

    it "prints a usage line naming the program" do
      expect(result.stdout).to match(/^Usage: distort/)
    end

    it "shows both commands on one usage line with -k FILE required" do
      expect(result.stdout).to start_with("Usage: distort [OPTION...] -k FILE {encrypt|decrypt} [FILE]\n")
    end

    it "shows no alternative usage lines" do
      expect(result.stdout).not_to match(/^\s+or: /)
    end

    it "never shows -k FILE as optional" do
      expect(result.stdout).not_to include("[-k FILE]")
    end

    it "writes nothing to stderr" do
      expect(result.stderr).to be_empty
    end

    %w[encrypt decrypt --key-file --cipher chacha20-poly1305].each do |term|
      it "documents #{term}" do
        expect(result.stdout).to include(term)
      end
    end

    it "describes the key as 32 bytes" do
      expect(result.stdout).to match(/^\s+-k, --key-file=FILE\s.*\b32-byte key\b/)
    end

    it "marks --key-file as required" do
      expect(result.stdout).to match(/^\s+-k, --key-file=FILE\s.*\brequired$/)
    end

    it "documents -h alongside --help" do
      expect(result.stdout).to match(/^\s+-h, --help\s/)
    end

    it "shows how to make a key" do
      expect(result.stdout).to include("head -c 32 /dev/urandom > key.key")
    end

    it "documents the exit status" do
      expect(result.stdout).to match(/exit status.*\b0\b.*\b1\b.*\b64\b/im)
    end
  end

  describe "-h" do
    subject(:result) { distort("-h") }

    it "exits with status 0" do
      expect(result.exitstatus).to eq(0)
    end

    it "prints the same text as --help" do
      expect(result.stdout).to eq(distort("--help").stdout)
    end

    it "writes nothing to stderr" do
      expect(result.stderr).to be_empty
    end
  end

  describe "--usage" do
    subject(:result) { distort("--usage") }

    it "exits with status 0" do
      expect(result.exitstatus).to eq(0)
    end

    it "ends the usage with -k FILE required before either command" do
      expect(result.stdout).to match(/^Usage: distort .*\s-k FILE \{encrypt\|decrypt\} \[FILE\]\n\z/m)
    end

    it "shows no alternative usage lines" do
      expect(result.stdout).not_to match(/^\s+or: /)
    end

    it "never shows -k FILE as optional" do
      expect(result.stdout).not_to include("[-k FILE]")
    end

    it "writes nothing to stderr" do
      expect(result.stderr).to be_empty
    end
  end

  describe "--version" do
    subject(:result) { distort("--version") }

    it "exits with status 0" do
      expect(result.exitstatus).to eq(0)
    end

    it "prints the program name and version first" do
      expect(result.stdout).to match(/\Adistort \d+\.\d+\.\d+\n/)
    end

    it "shows the copyright" do
      expect(result.stdout).to match(/^Copyright \(c\) 2026 David Gillis$/)
    end

    it "shows the license" do
      expect(result.stdout).to match(%r{^License: MIT <https://opensource\.org/licenses/MIT>$})
    end

    it "prints the license on the line after the copyright" do
      expect(result.stdout).to match(/^Copyright .*\nLicense: /)
    end

    it "writes nothing to stderr" do
      expect(result.stderr).to be_empty
    end
  end

  context "without any arguments" do
    subject(:result) { distort }

    it "exits with status 64" do
      expect(result.exitstatus).to eq(64)
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

    it "exits with status 64" do
      expect(result.exitstatus).to eq(64)
    end

    it "explains the problem on stderr" do
      expect(result.stderr).not_to be_empty
    end
  end

  context "with more than one FILE" do
    subject(:result) { distort("encrypt", "--key-file=#{key_path}", write_file("a.bin", "a"), write_file("b.bin", "b")) }

    it "exits with status 64" do
      expect(result.exitstatus).to eq(64)
    end

    it "writes nothing to stdout" do
      expect(result.stdout).to be_empty
    end

    it "explains the problem on stderr" do
      expect(result.stderr).to match(/too many arguments/i)
    end
  end

  context "with an unknown option" do
    subject(:result) { distort("encrypt", "--key-file=#{key_path}", "--bogus", stdin: "data") }

    it "exits with status 64" do
      expect(result.exitstatus).to eq(64)
    end

    it "writes nothing to stdout" do
      expect(result.stdout).to be_empty
    end

    it "names the program and the option on stderr" do
      expect(result.stderr).to start_with("distort: unrecognized option '--bogus'")
    end
  end

  context "when run by absolute path with an unknown option" do
    it "names the program without its directory" do
      expect(capture(distort_executable, "--bogus").stderr).to start_with("distort: unrecognized option '--bogus'")
    end
  end

  context "when run by relative path with an unknown option" do
    it "names the program without its directory" do
      result = capture("sh", "-c", 'cd "$1" && exec ./distort --bogus', "sh", File.dirname(distort_executable))
      expect(result.stderr).to start_with("distort: unrecognized option '--bogus'")
    end
  end
end
