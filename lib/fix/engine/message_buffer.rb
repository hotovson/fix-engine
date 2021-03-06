require 'fix/protocol'

module Fix
  module Engine
    #
    # A FIX message to which fields get appended, once it is completed by a
    # proper terminator it is handled
    #
    class MessageBuffer
      include Logger

      attr_accessor :fields, :client

      def initialize(&block)
        @fields = []

        raise 'A block accepting a FP::Message as single parameter must be provided' unless block && (block.arity == 1)
        @msg_handler = block
      end

      #
      # Adds received bytes to the message buffer and attempt to process them
      #
      # @param data [String] The received FIX message bits, as they come
      #
      def add_data(data)
        msg_buf << data.chomp
        parse_messages
      end

      #
      # Append a single FIX field to the message
      #
      # @param fld [String] A FIX formatted field, such as "35=0\x01"
      #
      def append(fld)
        raise 'Cannot append to complete message' if complete?
        field = fld.split('=')
        field[0] = field[0].to_i
        field[1] = field[1].gsub(/\x01\Z/, '')
        @fields << field
      end

      #
      # Returns true if the last field of the collection is a FIX checksum
      #
      # @return [Boolean] Whether the message is complete
      #
      def complete?
        @fields.count > 0 && (@fields.last[0] == 10)
      end

      #
      # Attempts to parse fields from the message buffer, if the fields that get parsed
      # complete the temporary message, it is processed
      #
      def parse_messages(&block)
        while idx = msg_buf.index("\x01")
          field = msg_buf.slice!(0, idx + 1).gsub(/\x01\Z/, '')
          append(field)

          next unless complete?

          parsed = FP.parse(to_s)
          @fields = []
          @msg_handler.call(parsed)
        end
      end

      #
      # The data buffer string
      #
      def msg_buf
        @msg_buf ||= ''
      end

      #
      # Returns a human-friendly string of the currently handled data
      #
      # @return [String] The parsed fields and the temporary buffer
      #
      def debug
        "#{to_s('|')}#{@msg_buf}"
      end

      #
      # Returns the current fields as a string joined by a given separator
      #
      # @param sep [String] The separator
      # @return [String] The fields joined by the separator
      #
      def to_s(sep = "\x01")
        fields.map { |f| f.join('=') }.join(sep) + sep
      end
    end
  end
end
