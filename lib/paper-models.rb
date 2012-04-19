module Paper
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
            puts "query = #{q}"
            res = @dbh.execute(q, [key])


            self.new res.fetch_hash
          end
        end

        def find(key)
          keys = @fields.keys.map{|k| "'#{k.to_s}'"}.join ","
          q = "SELECT #{keys} FROM #{@cfname} WHERE KEY=?"
          puts "query = #{q}"
          res = @dbh.execute(q, [key])
          
          self.new res.fetch_hash
        end

      end # class << self
    end
  end
end
