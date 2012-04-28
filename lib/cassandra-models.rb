module Cassandra
  module Models
    # Your code goes here...
    class Base

      @fields = {}

      def self.init(dbh)
        @dbh = dbh
      end

      def self.dbh
        @dbh
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

        def field name, opts={}

          puts "creating field #{name}"
          @fields ||= {}
          @fields[name] = opts

          define_method name do
            if opts[:compound]
              begin
                JSON.parse @data[name.to_s]
              rescue Exception => e
                @data[name.to_s]
              end
            else
              @data[name.to_s]
            end
          end

          define_method "#{name.to_s}=".to_sym do |val|
            if opts[:compound]
              @data[name.to_s] = val
            else
              begin
                @data[name.to_s] = val.to_json
              rescue Exception => e
                @data[name.to_s] = val
              end
            end
          end
        end

        def indexed_field name, opts={}
          field name, opts

          define_singleton_method "find_by_#{name.to_s}" do |key|
            keys = @fields.keys.map{|k| "'#{k.to_s}'"}.join ","
            q = "SELECT #{keys} FROM #{@cfname} WHERE #{name.to_s}=?"
            res = @dbh.execute(q, [key])

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
          res = @dbh.execute(q, [key])

          data = clean_data res.fetch_hash

          if data.empty?
            return nil
          else
            return self.new data
          end
        end

        private

          def clean_data (data)
            return data.merge(data) { |key, value|
              puts "value_class = #{key} || #{value.class} || #{value}"

              if value.blank?
                value
              elsif value.kind_of? SimpleUUID::UUID
                value.to_guid
              elsif value.is_a?(String) && value.include?("\0")
                CassandraCQL::Types::DateType.cast(value)
              else
                value
              end
            }
          end

      end # class << self
    end
  end
end
