RSpec.describe "distort chunk integrity" do
  DistortHelpers::CIPHERS.each do |cipher|
    context "with #{cipher}" do
      let(:option) { "--cipher=#{cipher}" }
      let(:geometry) { stream_geometry(cipher) }
      let(:plaintext) { random_bytes((3 * geometry.chunk) + (geometry.chunk / 2)) }
      let(:ciphertext) { ciphertext_of(plaintext, option) }
      let(:header) { geometry.header_of(ciphertext) }
      let(:chunks) { geometry.chunks_of(ciphertext) }

      def reassembled(header, chunks)
        header + chunks.join
      end

      describe "the discovered stream geometry" do
        it "splits a stream of three and a half chunks into four chunks" do
          expect(chunks.size).to eq(4)
        end

        it "reassembles into a stream that decrypts to the original plaintext" do
          expect(sha256(decrypt(reassembled(header, chunks)).stdout)).to eq(sha256(plaintext))
        end
      end

      [0, 1, 2, 3].each do |index|
        context "when the stream is truncated exactly before chunk #{index}" do
          subject(:result) { decrypt(ciphertext.byteslice(0, geometry.offset(index))) }

          it "fails" do
            expect(result).not_to be_success
          end

          it "reports that the stream ended early rather than blaming authentication" do
            expect(result.stderr).to match(/truncat|end of (input|file|stream)|ended early/i).and not_match(/authenticat/i)
          end
        end
      end

      [[0, 1], [1, 2], [0, 2]].each do |first, second|
        context "when chunks #{first} and #{second} are swapped" do
          it "fails" do
            swapped = chunks.dup.tap { |list| list[first], list[second] = list[second], list[first] }
            expect(decrypt(reassembled(header, swapped))).not_to be_success
          end
        end
      end

      [1, 2].each do |index|
        context "when middle chunk #{index} is dropped" do
          it "fails" do
            expect(decrypt(reassembled(header, chunks.reject.with_index { |_, i| i == index }))).not_to be_success
          end
        end

        context "when chunk #{index} is duplicated" do
          it "fails" do
            expect(decrypt(reassembled(header, chunks.dup.insert(index, chunks[index])))).not_to be_success
          end
        end
      end

      context "when splicing with a second stream of equal-length plaintext under the same key" do
        let(:other) { ciphertext_of(random_bytes(plaintext.bytesize), option) }
        let(:other_chunks) { geometry.chunks_of(other) }

        [0, 1, 3].each do |index|
          it "rejects chunk #{index} taken from the other stream" do
            spliced = chunks.dup.tap { |list| list[index] = other_chunks[index] }
            expect(decrypt(reassembled(header, spliced))).not_to be_success
          end
        end

        it "rejects the other stream's header in front of these chunks" do
          expect(decrypt(reassembled(geometry.header_of(other), chunks))).not_to be_success
        end
      end

      context "when the plaintext is several chunks of zeros" do
        let(:zeros) { "\0".b * ((3 * geometry.chunk) + (geometry.chunk / 2)) }
        let(:zero_ciphertext) { ciphertext_of(zeros, option) }
        let(:windows) { (0..2).map { |index| geometry.window(zero_ciphertext, index) } }

        it "never repeats a ciphertext chunk within the stream" do
          expect(windows.uniq.size).to eq(windows.size)
        end

        it "shares no ciphertext chunk body with a second encryption of the same plaintext" do
          second = ciphertext_of(zeros, option)
          expect(windows.select { |window| second.include?(window) }).to be_empty
        end
      end
    end
  end
end
