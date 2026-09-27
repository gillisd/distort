StreamGeometry = Data.define(:header, :chunk, :overhead) do
  def self.discover(&expansion)
    base = expansion.call(1)
    high = 2
    high *= 2 while expansion.call(high) == base && high < 1 << 28
    low = high / 2
    while high - low > 1
      mid = (low + high) / 2
      expansion.call(mid) == base ? low = mid : high = mid
    end
    overhead = expansion.call(high) - base
    new(header: base - overhead, chunk: low, overhead:)
  end

  def stride = chunk + overhead

  def offset(index) = header + (index * stride)

  def header_of(bytes) = bytes.byteslice(0, header)

  def chunks_of(bytes)
    bytes.byteslice(header..).bytes.each_slice(stride).map { |slice| slice.pack("C*") }
  end

  def window(bytes, index, size = 32)
    bytes.byteslice(offset(index) + (stride / 2) - (size / 2), size)
  end
end
