class Object
  def define_singleton_method name, &body
    singleton_class = class << self; self; end
    singleton_class.send(:define_method, name, &body)
  end
end

module Cassandra
  module Models
    class RecordNotFound < StandardError
    end

    class ValueNotFound < StandardError
    end

    class InvalidRequest < StandardError
    end
    
    class InvalidResponse < StandardError
    end

    class Base

      @fields = {}

      def self.init(dbh)
        @@dbh = dbh
      end

      def self.dbh
        @@dbh
      end

      attr_accessor :data

      def initialize(data={})
        @data = validate_data data
      end

      def validate_data data
        self.methods.select{|method| method =~ /^validate_field_/}.each do |method|
          self.send method, data
        end

        return data
      end

      class << self

        def cfname name
          @cfname = name.to_s
        end

        def get_cfname
          @cfname
        end

        def field name, opts={}
          @fields ||= {}
          @fields[name] = opts

          define_method name do
            @data[name.to_s]
          end

          define_method "#{name.to_s}=".to_sym do |val|
            @data[name.to_s] = val
          end

          define_method "validate_field_#{name.to_s}".to_sym do |data|
            # if the field is required and is nil
            raise ValueNotFound.new if opts[:required] && data[name.to_s].nil?
          end
          
          if opts[:key]
            define_singleton_method "key_type".to_sym do
              # if the field is required and is nil
              opts[:type] || :uuid
            end
          end
        end

        def indexed_field name, opts={}
          field name, opts

          define_singleton_method "find_by_#{name.to_s}" do |value|
            raise InvalidRequest.new if value.nil? || value.empty?

            begin
              res = []
              q = "SELECT #{keys} FROM #{@cfname} USING CONSISTENCY QUORUM WHERE #{name.to_s}=?"
              dbh.execute(q, [value]).fetch do |row|
                assert(value, name, row) {dbh.reset!}
                
                res << create(row)
              end

              res
            rescue CassandraCQL::Error::InvalidRequestException
              raise InvalidRequest.new
            end
          end
        end

        def find_by_id(value)
          raise InvalidRequest.new if value.nil? || value.empty?

          begin
            q = "SELECT KEY,#{keys} FROM #{@cfname} USING CONSISTENCY QUORUM WHERE KEY=?"
            row = dbh.execute(q, [value]).fetch_row
  
            assert(value, 'KEY', row) {dbh.reset!}

            create(row) || (raise RecordNotFound.new)
          rescue CassandraCQL::Error::InvalidRequestException
            raise InvalidRequest.new
          end
        end

        private

        def keys
          @fields.keys.map{|k| "'#{k.to_s}'"}.join ","
        end

        def create(row)
          unless row.nil?
            row_data = row.to_hash.select{|k, v| @fields.keys.include? k.to_sym}
            return if is_tombstone?(row_data)

            data = Hash[row_data.map{|k, v| [k, type_cast(k, v)]}]
            self.new data
          end
        end
        
        def assert(value, name, row, &body)
          if value != type_cast(name, row[name.to_s])
            yield body
            
            raise InvalidResponse.new("invalid cql response, #{name.to_s}: #{value}, response: #{row.inspect}")
          end
        end
        
        def is_tombstone?(data)
          data.empty? || data.all?{|k, v| v.nil?}
        end

        def type_cast(key, value)
          return if value.nil?

          if key == 'KEY'
            type = key_type
          else
            type = @fields[key.to_sym][:type] || (value.kind_of?(CassandraCQL::UUID) ? :uuid : :string)
          end
          
          case type
          when :uuid
            value.to_guid
          when :timeuuid
            CassandraCQL::Types::TimeUUIDType.cast(value).to_guid
          when :boolean
            CassandraCQL::Types::BooleanType.cast(value)
          when :date
            CassandraCQL::Types::DateType.cast(value)
          when :compound
            JSON.parse value
          else
            value
          end
        end

      end # class << self
    end
  end
end
