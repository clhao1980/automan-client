require 'sequel/core'

module Sequel
  # Lets you create a Model subclass with its dataset already set.
  # source can be an existing dataset or a symbol (in which case
  # it will create a dataset using the default database with 
  # the given symbol as the table name).
  #
  # The purpose of this method is to set the dataset automatically
  # for a model class, if the table name doesn't match the implicit
  # name.  This is neater than using set_dataset inside the class,
  # doesn't require a bogus query for the schema, and allows
  # it to work correctly in a system that uses code reloading.
  #
  # Example:
  #   class Comment < Sequel::Model(:something)
  #     table_name # => :something
  #   end
  def self.Model(source)
    Model::ANONYMOUS_MODEL_CLASSES[source] ||= if source.is_a?(Database)
      c = Class.new(Model)
      c.db = source
      c
    else
      Class.new(Model).set_dataset(source)
    end
  end

  # Sequel::Model is an object relational mapper built on top of Sequel core.  Each
  # model class is backed by a dataset instance, and many dataset methods can be
  # called directly on the class.  Model datasets return rows as model instances,
  # which have fairly standard ORM instance behavior.
  #
  # Sequel::Model is built completely out of plugins, the only method not part of a
  # plugin is the plugin method itself.  Plugins can override any class, instance, or
  # dataset method defined by a previous plugin and call super to get the default
  # behavior.
  #
  # You can set the SEQUEL_NO_ASSOCIATIONS constant or environment variable to
  # make Sequel not load the associations plugin by default.
  class Model
    # Map that stores model classes created with Sequel::Model(), to allow the reopening
    # of classes when dealing with code reloading.
    ANONYMOUS_MODEL_CLASSES = {}

    # Class methods added to model that call the method of the same name on the dataset
    DATASET_METHODS = (Dataset::ACTION_METHODS + Dataset::QUERY_METHODS +
      [:eager, :eager_graph, :each_page, :each_server, :print]) - [:and, :or, :[], :[]=, :columns, :columns!]
    
    # Class instance variables to set to nil when a subclass is created, for -w compliance
    EMPTY_INSTANCE_VARIABLES = [:@overridable_methods_module, :@db]

    # Boolean settings that can be modified at the global, class, or instance level.
    BOOLEAN_SETTINGS = [:typecast_empty_string_to_nil, :typecast_on_assignment, :strict_param_setting, :raise_on_save_failure, :raise_on_typecast_failure, :require_modification, :use_transactions]

    # Hooks that are called before an action.  Can return false to not do the action.  When
    # overriding these, it is recommended to call super as the last line of your method,
    # so later hooks are called before earlier hooks.
    BEFORE_HOOKS = [:before_create, :before_update, :before_save, :before_destroy, :before_validation]

    # Hooks that are called after an action.  When overriding these, it is recommended to call
    # super on the first line of your method, so later hooks are called before earlier hooks.
    AFTER_HOOKS = [:after_initialize, :after_create, :after_update, :after_save, :after_destroy, :after_validation]

    # Empty instance methods to create that the user can override to get hook/callback behavior.
    # Just like any other method defined by Sequel, if you override one of these, you should
    # call super to get the default behavior (while empty by default, they can also be defined
    # by plugins).  See the {"Model Hooks" guide}[link:files/doc/model_hooks_rdoc.html] for
    # more detail on hooks.
    HOOKS = BEFORE_HOOKS + AFTER_HOOKS

    # Class instance variables that are inherited in subclasses.  If the value is :dup, dup is called
    # on the superclass's instance variable when creating the instance variable in the subclass.
    # If the value is nil, the superclass's instance variable is used directly in the subclass.
    INHERITED_INSTANCE_VARIABLES = {:@allowed_columns=>:dup, :@dataset_methods=>:dup, 
      :@dataset_method_modules=>:dup, :@primary_key=>nil, :@use_transactions=>nil,
      :@raise_on_save_failure=>nil, :@require_modification=>nil, 
      :@restricted_columns=>:dup, :@restrict_primary_key=>nil,
      :@simple_pk=>nil, :@simple_table=>nil, :@strict_param_setting=>nil,
      :@typecast_empty_string_to_nil=>nil, :@typecast_on_assignment=>nil,
      :@raise_on_typecast_failure=>nil, :@plugins=>:dup}

    # Regexp that determines if a method name is normal in the sense that
    # it could be called directly in ruby code without using send.  Used to
    # avoid problems when using eval with a string to define methods.
    NORMAL_METHOD_NAME_REGEXP = /\A[A-Za-z_][A-Za-z0-9_]*\z/

    # Regular expression that determines if the method is a valid setter name
    # (i.e. it ends with =).
    SETTER_METHOD_REGEXP = /=\z/

    @allowed_columns = nil
    @db = nil
    @db_schema = nil
    @dataset_method_modules = []
    @dataset_methods = {}
    @overridable_methods_module = nil
    @plugins = []
    @primary_key = :id
    @raise_on_save_failure = true
    @raise_on_typecast_failure = true
    @require_modification = nil
    @restrict_primary_key = true
    @restricted_columns = nil
    @simple_pk = nil
    @simple_table = nil
    @strict_param_setting = true
    @typecast_empty_string_to_nil = true
    @typecast_on_assignment = true
    @use_transactions = true

    Sequel.require %w"default_inflections inflections plugins base exceptions errors", "model"
    if !defined?(::SEQUEL_NO_ASSOCIATIONS) && !ENV.has_key?('SEQUEL_NO_ASSOCIATIONS')
      Sequel.require 'associations', 'model'
      plugin Model::Associations
    end

    # The setter methods (methods ending with =) that are never allowed
    # to be called automatically via set/update/new/etc..
    RESTRICTED_SETTER_METHODS = instance_methods.map{|x| x.to_s}.grep(SETTER_METHOD_REGEXP)
  end
end
