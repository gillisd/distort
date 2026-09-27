RSpec.describe "distort when stdout cannot be written", :dev_full do
  let(:geometry) { stream_geometry }

  {
    "a small input" => ->(_geometry) { "attack at dawn\n" },
    "a multi-chunk input" => ->(geometry) { SecureRandom.random_bytes((3 * geometry.chunk) + 7) }
  }.each do |size, plaintext_for|
    context "with #{size}" do
      let(:plaintext) { plaintext_for.call(geometry) }

      {
        "encrypt" => ->(plaintext) { plaintext },
        "decrypt" => ->(plaintext) { ciphertext_of(plaintext) }
      }.each do |command, input_for|
        describe command do
          subject(:result) do
            capture(*redirect(["distort", command, "--key-file=#{key_path}"], ">", "/dev/full"),
                    stdin: instance_exec(plaintext, &input_for))
          end

          it "exits with status 1" do
            expect(result.exitstatus).to eq(1)
          end

          it "reports the write error once on stderr, with its reason" do
            expect(result.stderr).to eq("distort: write error: No space left on device\n")
          end
        end
      end
    end
  end

  %w[--help -h --usage --version -V].each do |option|
    describe option do
      subject(:result) { capture(*redirect(["distort", option], ">", "/dev/full")) }

      it "exits with status 1" do
        expect(result.exitstatus).to eq(1)
      end

      it "reports the write error on stderr, with its reason" do
        expect(result.stderr).to eq("distort: write error: No space left on device\n")
      end
    end
  end
end
