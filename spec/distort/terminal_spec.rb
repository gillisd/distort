RSpec.describe "distort on a terminal", :terminal do
  let(:errors) { File.join(workdir, "errors.txt") }
  let(:stderr) { result.then { File.binread(errors) } }

  describe "encrypt" do
    context "when stdout is a terminal" do
      subject(:result) do
        on_terminal("distort", "encrypt", "--key-file=#{key_path}", redirects: "</dev/null 2>#{errors.shellescape}")
      end

      it "exits with status 1" do
        expect(result.exitstatus).to eq(1)
      end

      it "explains the refusal on stderr" do
        expect(stderr).to eq("distort: refusing to write encrypted data to a terminal\n")
      end

      it "writes no ciphertext to the terminal" do
        expect(result.stdout).to be_empty
      end
    end

    context "when stdin is a terminal" do
      subject(:result) do
        on_terminal("distort", "encrypt", "--key-file=#{key_path}", redirects: ">#{sealed.shellescape}")
      end

      let(:sealed) { File.join(workdir, "sealed.enc") }

      it "exits successfully" do
        expect(result).to be_success
      end
    end
  end

  describe "decrypt" do
    {
      "stdin" => [],
      "stdin named as -" => ["-"]
    }.each do |source, args|
      context "when #{source} is a terminal" do
        subject(:result) do
          on_terminal("distort", "decrypt", "--key-file=#{key_path}", *args, redirects: "2>#{errors.shellescape}")
        end

        it "exits with status 1" do
          expect(result.exitstatus).to eq(1)
        end

        it "explains the refusal on stderr" do
          expect(stderr).to eq("distort: refusing to read encrypted data from a terminal\n")
        end
      end
    end

    context "when stdout is a terminal" do
      subject(:result) do
        on_terminal("distort", "decrypt", "--key-file=#{key_path}", write_file("note.enc", ciphertext_of("attack at dawn\n")),
                    redirects: "2>#{errors.shellescape}")
      end

      it "writes the plaintext to the terminal" do
        expect(result.stdout).to eq("attack at dawn\r\n")
      end
    end
  end
end
