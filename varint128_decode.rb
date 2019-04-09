# For every byte from the right, the value is how far each byte is above 127, multiplied by 128**n

# a52f      =                                         (0xa5-127)*128 + 0x2f
# 4911

# c08426    =                     (0xc0-127)*128**2 + (0x84-127)*128 + 0x26
# 1065638

# a7cf8207  = (0xa7-127)*128**3 + (0xcf-127)*128**2 + (0x82-127)*128 + 0x07
# 85197191

# This function uses bitwise operations to decode the varint128
def varint128_decode(hex, verbose=false)
  n = 0
  offset = 0

  if verbose
    puts hex
    puts "n = #{n}"
  end

  loop do
    # grab each byte
    d = hex[offset..offset+1]

    # calculate the n value of each byte
    if verbose
      puts
      puts "#{d} #{d.to_i(16).to_s(2).rjust(8, " ")} AND #{0b01111111.to_s(2)}" # take the byte and AND it with 0b01111111
      puts "   #{(d.to_i(16) & 0b01111111).to_s(2).rjust(8, " ")} OR  #{(n << 7).to_s(2)} (n << 7)" # then OR that value with n << 7
    end

    n = n << 7 | d.to_i(16) & 0b01111111 # shift the n value over 7 bits then OR it with (byte AND 0b01111111)
    # 0b01111111 127 0x7F (the highest number that doesn't have the 8th bit set)

    if verbose
      puts "             n= #{n.to_s(2)}"
    end

    # keep going until the 8th bit isn't set
    if d.to_i(16) & 0b10000000 == 0 # if the 8th bit is not set
      if verbose
        puts
      end
      return n
    else
      n += 1
      offset +=2
    end
  end

end

# Test
# puts varint128_decode("a7cf8207", true) # 85197191
# puts varint128_decode("b98276", true) # 950774
# puts varint128_decode("c08426", true) # 1065638
# puts varint128_decode("80ed59", true) # 1065638
