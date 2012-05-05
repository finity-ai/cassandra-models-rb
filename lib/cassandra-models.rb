class Object
  def define_singleton_method name, &body
    singleton_class = class << self; self; end
    singleton_class.send(:define_method, name, &body)
  end
end

module Cassandra
  module Models
    # Your code goes here...
    class Base

      @fields = {}

      def self.init(dbh)
        @@dbh = dbh
      end

      def self.dbh
        @@dbh
      end

      attr_accessor :new_record
      attr_accessor :data

      def initialize(data={})
        @data = data
        @new_record = true
      end

      class << self

        def cfname name
          @cfname = name.to_s
        end

        def get_cfname
          @cfname
        end

        def field name, opts={}

          puts "creating field #{name}"
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

          define_singleton_method "find_by_#{name.to_s}" do |key|
            keys = @fields.keys.map{|k| "'#{k.to_s}'"}.join ","
            q = "SELECT #{keys} FROM #{@cfname} WHERE #{name.to_s}=?"
            res = dbh.execute(q, [key])

            data = clean_data res.fetch_hash

            if data.empty?
              return nil
            else
              puts "res = #{data.inspect}"
              return self.new data
            end
          end
        end

        def find_by_id(key)
          keys = @fields.keys.map{|k| "'#{k.to_s}'"}.join ","
          q = "SELECT #{keys} FROM #{@cfname} WHERE KEY=?"
          res = dbh.execute(q, [key])
          raw_data = res.fetch_hash

          data = clean_data raw_data

          if data.empty?
            return nil
          else
            return self.new data
          end
        end

        private

        def clean_data (data)
          return data.merge(data) { |key, value|
            if value.blank?
              # no value is just returned as it otherwise can create errors
              value
            elsif value.kind_of? SimpleUUID::UUID
              # it is a uuid
              value.to_guid
            elsif value.is_a?(String) && value.count("\0") == 2
              # it is a date
              CassandraCQL::Types::DateType.cast(value)
            elsif value.is_a?(String) && value.count("\0") == 1
              # it is a boolean
              CassandraCQL::Types::BooleanType.cast(value)
            elsif value.is_a?(String) && value.include?('{') && value.include?('}')
              # it is a json data string
              begin
                JSON.parse value
              rescue Exception => e
                value
              end
            else
              # okay, no clue so just return it
              value
            end
          }
        end

      end # class << self
    end
  end
end
