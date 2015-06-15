# Creates classes for value objects/read-only records.  Most useful
# when creating model objects for concepts not stored in the database.
#
# This will create a class that has attr_readers for all given attributes, as
# well as a hash-based constructor.  Further, the block given to with_attributes
# will be evaluated as if it were inside a class definition, allowing you
# to add methods, include or extend modules, or do whatever else you want.
class ImmutableStruct
  VERSION='2.1.1' #:nodoc:
  # Create a new class with the given read-only attributes.
  #
  # attributes:: list of symbols or strings that can be used to create attributes.
  #              Any attribute with a question mark in it (e.g. +:foo?+) will create
  #              an attribute without a question mark that passes through the raw
  #              value and an attribute *with* the question mark that coerces that
  #              value to a boolean.  You would initialize it with the non-question-mark value
  #              An attribute that is an array of one symbol will create an attribute named for
  #              that symbol, but that doesn't return nil, instead returning the +to_a+ of the
  #              value passed to the construtor.
  # block:: if present, evaluates in the context of the new class, so +def+, +def.self+, +include+
  #         and +extend+ should all work as in a normal class definition.
  #
  # Example:
  #
  #     Person = ImmutableStruct.new(:name, :location, :minor?)
  #
  #     p = Person.new(name: 'Dave', location: Location.new("DC"), minor: false)
  #     p.name     # => 'Dave'
  #     p.location # => <Location: @where="DC">
  #     p.minor    # => false
  #     p.minor?   # => false
  #
  #     p = Person.new(name: 'Rudy', minor: "yup")
  #     p.name     # => 'Rudy'
  #     p.location # => nil
  #     p.minor    # => "yup"
  #     p.minor?   # => true
  #
  def self.new(*attributes,&block)
    raise ArgumentError if attributes.empty?
    klass = Class.new do
      array_attr = lambda { |attr| attr.kind_of?(Array) && attr.size == 1 }
      boolean_attr = lambda { |attr| String(attr).match(/(^.*)\?$/) }
      add_reader = lambda { |attr| begin; attr_reader attr; rescue; raise ArgumentError; end }

      attributes.each do |attribute|
        case attribute
        when String
          raise ArgumentError
        when boolean_attr
          raw_name = $1
          add_reader.call(raw_name)
          define_method(attribute) do
            !!instance_variable_get("@#{raw_name}")  # get boolean value
          end
        when array_attr
          add_reader.call(attribute[0])
        else
          add_reader.call(attribute)
        end
      end

      define_method(:initialize) do |*args|
        attrs = args[0] || {}
        attributes.each do |attribute|
          case attribute
          when array_attr
            ivar_name = attribute[0].to_s
            instance_variable_set("@#{ivar_name}", (attrs[ivar_name.to_s] || attrs[ivar_name.to_sym]).to_a)
          else
            ivar_name = attribute.to_s.gsub(/\?$/,'')
            instance_variable_set("@#{ivar_name}",attrs[ivar_name.to_s] || attrs[ivar_name.to_sym])
          end
        end
      end
    end
    klass.class_exec(&block) unless block.nil?
    imethods = klass.instance_methods(include_super=false)
    klass.class_exec(imethods) do |imethods|
      define_method(:to_h) do
        imethods.inject({}){ |hash, method| hash.merge(method.to_sym => self.send(method)) }
      end
    end
    klass
  end
end
