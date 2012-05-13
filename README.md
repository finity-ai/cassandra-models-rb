Cassandra models
=====================================

Goal
-------------------------------
A slim interaction layer with a cassandra database

Use
-------------------------------
you will need to initialize the connection with the cassandra nodes during initialization of you application

``` Ruby
  # get the cassandra connections
  db = CassandraCQL::Database.new("localhost", {:keyspace => "something"})

  # init models
  ObjectModel.init db
```

Your models in rails can have these kinds of additions:

``` Ruby
  class ObjectModel < Cassandra::Models::Base

    # define the object's Cassandra column family
    cfname :object_models

    # a plain field
    field :uuid

    # a field that can be searched
    indexed_field :index

    # fields with the respective types.
    field :interesting, :type => :boolean
    field :bag, :type => :compound
    field :created_at, :type => :date

    # a field that is required and will throw Cassandra::Models::ValueNotFound if the value is not returned
    field :owner_id, :required => true
  end
```

Types:
* boolean
* compound (a compound is a string in the shape of JSON data, compound will turn that data into a Ruby Hash)
* data
* uuid (this type is detected automatically)
* string (this is the default type)

Find methods:
* Class.find_by_id (Do a KEY find for one row)
* Class.find_by_index (Do a search for rows that match the index value. Note: This is for indexed_fields defined columns only)

Column methods:
* object.column (Get the column data)
* object.column= 'something' (set the column data. Note that the data is NOT stored to cassandra)

Validation methods:
* object.validate_field_column (validate the field for presence. Note: This is only for columns that had :required set to true)

Dependencies
-------------------------------
Gems:
* [cassandra-cql](https://github.com/kreynolds/cassandra-cql)
* [json](https://github.com/flori/json)

Ruby:
Currently the gem is tested and works on RubyEE 1.8

NOTE: Object is currently ducktyped to include define_singleton_method that was only added in MRI 1.9.1. This means that if you are running a Ruby interpreter that has this method the implementation of it is overwritten by the local method.