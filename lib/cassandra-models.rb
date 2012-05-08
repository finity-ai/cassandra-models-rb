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
        @data = data
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
        end

        def indexed_field name, opts={}
          field name, opts

          define_singleton_method "find_by_#{name.to_s}" do |value|
            res = []
            q = "SELECT #{keys} FROM #{@cfname} WHERE #{name.to_s}=?"
            dbh.execute(q, [value]).fetch do |row|
              res << create(row)
            end
            
            res
          end
        end

        def find_by_id(value)
          q = "SELECT #{keys} FROM #{@cfname} WHERE KEY=?"
          row = dbh.execute(q, [value]).fetch_row
          
          create(row) || (raise RecordNotFound.new)
        end

        private
        
        def keys
          @fields.keys.map{|k| "'#{k.to_s}'"}.join ","
        end
        
        def create(row)
          unless row.nil?
            row_data = row.to_hash.select{|k, v| @fields.keys.include? k.to_sym}
            return if row_data.empty? # in this case only KEY was present
            
            data = Hash[row_data.map{|k, v| [k, type_cast(k, v)]}]
            self.new data
          end
        end
        
        def type_cast(key, value)
          return if value.nil?
          
          type = @fields[key.to_sym][:type] || (value.kind_of?(CassandraCQL::UUID) ? :uuid : :string)
          case type
          when :uuid
            value.to_guid
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
