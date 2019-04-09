# Read a varint128 from a deobfuscated hex string value.
# Basically just keep reading bytes until one of them is less than 128 (so the 8th bit wouldn't be set).

def varint128_read(value, offset=0, verbose=false) # use offset to start reading from a number of characters in from the string
  if verbose
    puts value # display the starting value we have been given
  end

  # read varint128
  data = '' # build up a string of bytes from the hex string value we have been given
  offset = offset || 0 # keep track of our place as we read through the hex string

  # keep reading bytes until one of them doesn't have the 8th bit set. e.g.
  #  b98276a2ec7700cbc2986ff9aed6825920aece14aa6f5382ca5580
  #  b9 = 10111001 XOR 10000000 (0x80) (128)
  #  82 = 10000010 XOR 10000000
  #  76 =  1110110 XOR 10000000 <- 8th bit has not been set
  #
  # Basically just keep reading bytes until one of them is less than 128 (so the 8th bit wouldn't be set)
  loop do

    # split value in to bytes (2 hexadecimal characters)
    byte = value[offset..offset+1]
    binary = byte.to_i(16).to_s(2) # convert byte to a binary string (for debugging)
    check =  byte.to_i(16) & 0b10000000 # check that the 8th bit is set by using bitwise AND 10000000 (0x80)

    # print results
    if verbose
      puts "#{byte} #{binary.rjust(8, " ")} AND (#{byte.to_i(16)})"
      puts "   #{check.to_s(2).rjust(8, " ")} #{0b10000000.to_s(2)}"
    end

    # append this byte to the result
    data += byte

    # return the hexadecimal string of bytes and stop looking for more if the 8th bit isn't set for the current byte
    return data if check == 0

    # move on to the next byte
    offset += 2
  end

end

# Test
# puts varint128_read("c49132a52f00700b18f2629ea0dc9514a09bd633dc0b47b8d180", 0, true) # c49132
# puts varint128_read("969460a7cf820700d957c2536c205e2483b635ce17b2e02036788d54", 0, true) # 969460
# puts varint128_read("c0842680ed5900a38f35518de4487c108e3810e6794fb68b189d8b", 0, true) # c08426
