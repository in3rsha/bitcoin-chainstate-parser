# My simplified version of decompressing a decoded varint to get the output value (in satoshis)

# "To store CAmount values (integers representing numbers of satoshis), a transformation is applied beforehand that turns more common numbers (multiples of powers of 10) into smaller numbers first:" - https://bitcoin.stackexchange.com/questions/51620/cvarint-serialization-format

def decompress_value(x)

  # Just return the value if it is zero (nothing to do)
  return x if x == 0

  # otherwise...
  x = x - 1   # subtract 1 from the number we've got

  e = x % 10  # get the remainder
  x = x / 10  # get the quotient by dividing x by 10 (how many 10s are there in the number?)

  # if the remainder is less than 9
  if e < 9
    d = (x % 9)        # get the remainder of the quotient mod 9
    x = x / 9          # get another quotient by dividing the previous quotient by 9
    n = x * 10 + d + 1 # create an n value - the quotient times 10 plus the remainder from doing the mod 9 above (plus 1)
  else
    n = x + 1
  end

  # increase the result by muliplying it by 10 to the power of the original remainder mod 10
  n *= 10**e

  return n
end

# Test
# puts decompress_value(587511) # 65279
# puts decompress_value(30553)  # 339500
