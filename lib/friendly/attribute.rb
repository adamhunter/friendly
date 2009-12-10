require 'friendly/uuid'

module Friendly
  class Attribute
    CONVERTERS = {}
    CONVERTERS[UUID] = lambda { |s| UUID.new(s) }

    attr_reader :klass, :name, :type

    def initialize(klass, name, type)
      @klass = klass
      @name  = name
      @type  = type
      build_accessors
    end

    def typecast(value)
      value.is_a?(type) ? value : convert(value)
    end

    def convert(value)
      assert_converter_exists(value)
      CONVERTERS[type].call(value)
    end

    def default
      type.new
    end

    protected
      def build_accessors
        n = name
        klass.class_eval do
          eval <<-__END__
            def #{n}=(value)
              @#{n} = self.class.attributes[:#{n}].typecast(value)
            end

            def #{n}
              @#{n} ||= self.class.attributes[:#{n}].default
            end
          __END__
        end
      end

      def assert_converter_exists(value)
        unless CONVERTERS.has_key?(type)
          msg = "Can't convert #{value} to #{type}. 
                 Add a custom converter to Friendly::Attribute::CONVERTERS."
          raise NoConverterExists, msg
        end
      end
  end
end
