# LevelDB
#
#     type                             txid                                   vout
#         \                              |                                   /
#         <><--------------------------------------------------------------><>
#  key:   43000006b4e26afc5d904f239930611606a97e730727b40d1d82d4f3f1438cf2a101
#
#
#  value: 71a9e87d62de25953e189f706bcf59263f15de1bf6c893bda9b045
#         b12dcefd8f872536b12dcefd8f872536b12dcefd8f872536b12dce <- obfuscate key extended (XOR)
#         c0842680ed5900a38f35518de4487c108e3810e6794fb68b189d8b
#         <----><----><><-------------------------------------->
#          /      |    \                   |
#    varint    varint   varint          script <- hash160 for P2PKH and P2SH, public key for P2PK, full script for rest
#        |     amount   type
#        |        \
# decode |         decompress
#        |
#        |
#   11101000000111110110
#   <----------------->^coinbase
#          height
#
# * varint is a varint128 (C++)
#   * first varint  - first 19 bits of decoded varint is height, last bit is coinbase (0 or 1)
#   * second varint - the amount (in satoshis), which must decoded and then decompressed
#   * third varint  - the type of scriptpubkey (P2PKH, P2SH, P2PK), or the size of the upcoming script if not one of these 3


# sudo apt install libleveldb-dev
# sudo gem install leveldb-ruby
require 'leveldb'
require 'json' # for formatting the results

# Functions
require_relative 'varint128_read'
require_relative 'varint128_decode'     # decode varint - uses bitwise operations and is about 20% faster than my arithmetic implementation
require_relative 'decompress_value'     # the value of the output needs to be decompressed from from the decoded varint128 (for some reason)

# Settings
debug = false # print lots of details about decoding the values
results = 'csv' # how to format the results - csv, json

# Check that bitcoind isn't running before trying to access the chainstate database.
running = system("bitcoin-cli getblockcount", :out => File::NULL, :err => File::NULL) # returns true if command is successful
abort "Looks like bitcoind is running. Shutdown bitcoin before accessing the chainstate LevelDB." if running

# Select LevelDB folder (~/.bitcoin/chainstate)
chainstate = LevelDB::DB.new "#{Dir.home}/.bitcoin/chainstate/", {:compression => LevelDB::CompressionType::NoCompression} # chainstate contains utxo set
# Make sure you set the option for compression to NoCompression, or you will corrupt the chainstate leveldb.
#   https://github.com/wmorgan/leveldb-ruby/blob/master/lib/leveldb.rb#L93
#   https://github.com/wmorgan/leveldb-ruby/blob/master/leveldb/include/leveldb/options.h#L26

# Get obfuscate_key (use byte array to query the database) (it's also the first key)
obfuscate_key = chainstate.get ["0e006f62667573636174655f6b6579"].pack("H*") # "\x0E\x00obfuscate_key"
obfuscate_key = obfuscate_key.unpack("H*").join
obfuscate_key = obfuscate_key[2..-1] # the first 2 characters is just the size of the actual key
if debug
  puts "obfuscate_key: #{obfuscate_key}"
end

# ----------------------------
# Iterate over keys and values
# ----------------------------
i = 1
chainstate.each do |key, value|

  # C  txid (32 bytes)                                                index (varint)
  # --|--------------------------------------------------------------|--
  # 430000155b9869d56c66d9e86e3c01de38e3892a42b99949fe109ac034fff6583900

  if key[0] == 'C' # if key starts with a C - means it's a transaction

    # ---
    # key
    # ---
    type = key[0] # first 1 byte (C = transaction)
    txid = key[1..32].unpack("H*").join('').scan(/../).reverse.join # bytes 1 to 32 (convert from little-endian)
    vout = varint128_decode(key[33..-1].unpack("H*").join) # last 1 or 2 bytes (varint128)

    if debug
      # puts key.unpack("H*").join
      puts "#{i}. #{type}:#{txid}:#{vout}"
    end

    # -----
    # value
    # -----
    value = value.unpack("H*").join

    # extend the obfuscate_key to the length of the value
    # TIP: Make sure you remove the size of the key from the start before extending: 08b12dcefd8f872536
    # e.g. obfuscate_key: b12dcefd8f872536
    # e.g. extended:         b12dcefd8f872536b12dcefd8f872536b12dcefd8f872536b12dcefd
    quotient = (value.length / obfuscate_key.length.to_f).ceil   # get one quotient above
    obfuscate_key_extended = obfuscate_key * quotient

    remainder = value.length % obfuscate_key.length              # get the remainder
    if remainder > 0
      trim = obfuscate_key.length - remainder                    # substract the remainder
      obfuscate_key_extended = obfuscate_key_extended[0...-trim]
    end
    # e.g. value:         71a9e87d62de25953e189f706bcf59263f15de1bf6c893bda9b045
    # e.g. obfuscate_key: b12dcefd8f872536b12dcefd8f872536b12dcefd8f872536b12dce
    # puts "value:                  " + value
    # puts "obfuscate_key           " + obfuscate_key
    # puts "obfuscate_key_extended: " + obfuscate_key_extended

    # xor the value with the obfuscate_key
    xor = value.hex ^ obfuscate_key_extended.hex
    if debug
      puts " value:    #{value}"
      puts " value:    #{value.to_i(16)}"
      puts " ob key:   #{obfuscate_key_extended}"
      puts " ob key:   #{obfuscate_key_extended.to_i(16)}"
      puts " xor:      #{xor.to_s(16)}"
      puts " xor:      #{xor}"
    end

    # height
    # ------
    # 1. read a varint from the deobfuscated value
    data = varint128_read(xor.to_s(16), offset=0)
    offset = data.length # keep track of how far we have read in to the value

    # 2. Decode the base128 encoded value to an integer value
    n = varint128_decode(data)

    # 3. Work out the height from the decoded base128
    # 11101000000111110110
    # <----------------->   all the bits except for the last
    height = n >> 1 # remove the right-most bit
    if debug
      puts " height:   #{data} #{data.to_i(16).to_s(2)} #{data.to_i(16)}"
      puts " height:   #{n} #{n.to_s(2).rjust(data.to_i(16).to_s(2).length, " ")}"
      puts " height:   #{height} #{height.to_s(2).rjust(data.to_i(16).to_s(2).length - (n.to_s(2).length - height.to_s(2).length), " ")}"
    end

    # coinbase
    # --------
    # 11101000000111110110
    #                    ^ last bit
    coinbase = n & 0x01
    if debug
      puts " coinbase: #{coinbase}      #{coinbase.to_s(2).rjust(data.to_i(16).to_s(2).length, " ")}"
    end

    # amount
    # -----
    # 1. Get another varint
    data = varint128_read(xor.to_s(16), offset) # we are now probably 3 bytes (6 characters in to reading the string)
    offset += data.length # keep track of how far we have read in to the value
    if debug
      puts " amount:    #{data}"
    end

    # 2. decode the varint
    n = varint128_decode(data)
    if debug
      puts " amount:    #{n}"
    end

    # 3. Decompress the decoded varint to get the value https://github.com/bitcoin/bitcoin/blob/master/src/compressor.cpp
    amount = decompress_value(n)

    if debug
      puts " amount:    #{amount}"
    end

    # script
    # ------
    # 1. the next varint tells you the type of script
    data = varint128_read(xor.to_s(16), offset) # we are now probably 3 bytes (6 characters in to reading the string)
    offset += data.length # keep track of how far we have read in to the value
    if debug
      puts " type:     #{data}"
    end

    # 2. decode that varint too to get the script type number
    #   0 = 20 bytes P2PKH (hash160)
    #   1 = 20 bytes P2SH  (hash160)
    #   2 = 33 bytes P2PK
    #   3 = 33 bytes P2PK
    #   4 = 33 bytes P2PK (uncompressed)
    #   5 = 33 bytes P2PK (uncompressed)
    #   > = [special script size] (subtract 6 from this to get the actual script size)
    type = varint128_decode(data)
    if debug
      puts " type:     #{type}"
    end

    # 3. the rest of the value is the script
    if [0, 1].include?(type) # if it's a 0 or 1
      data_size = 40 # 20 bytes
    elsif [2, 3, 4, 5].include?(type) # if it's a 2, 3, 4, or 5
      data_size = 66 # 33 bytes (1 byte for the type + 32 bytes of data)
      offset -= 2 # set the offset back a byte (for some reason)
    else
      # if the data is not compacted, the out_type corresponds to the data size adding the number of special scripts
      nspecialscripts = 6
      data_size = (type - nspecialscripts) * 2 # times 2 for number of bytes
    end

    script = xor.to_s(16)[offset..-1]
    if debug
      puts " script:   #{script}"
    end

    # 4. quick check to make sure the script is the expected length
    raise "script not expected size" if script.length != data_size


    # -------
    # Results
    # -------
    if results == 'csv'
      puts "count,txid,vout,height,amount,coinbase,type,script" if i == 1
      puts "#{i},#{txid},#{vout},#{height},#{amount},#{coinbase},#{type},#{script}"
    end

    if results == 'json'
      hash = {count: i, txid: txid, vout: vout, height: height, amount: amount, coinbase: coinbase, type: type, script: script}
      puts JSON.generate(hash)
    end

    # Loop
    i = i + 1
    # puts i if i % 100000 == 0
    # exit if i == 5

  end
end
