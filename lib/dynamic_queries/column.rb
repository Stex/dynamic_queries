class DynamicQueries::Column
  unloadable if Rails.env.development?

  delegate :name, :type, :sql_type, :klass, :to => :column_object

  def initialize(model_proxy, column)
    @model_proxy = model_proxy
    @column      = column
  end

  #
  # @return [String] the localized name of this column
  #
  def localized_name
    @model_proxy.human_attribute_name(name)
  end

  #
  # @return [DynamicQueries::Model]
  #   The model proxy this column belongs to
  #
  def model
    @model_proxy
  end

  #
  # @return [Boolean] +true+ if this column is the table's primary key
  #
  def primary_key?
    column_object.primary
  end

  #
  # @return [Boolean] +true+ if this column is the foreign key of an association
  #
  def foreign_key?
    !!foreign_key_association
  end

  #
  # @return [DynamicQueries::Association, NilClass]
  #   The association if this column is its foreign key or nil otherwise.
  #
  def foreign_key_association
    @foreign_key_association ||= model.associations.select {|a| a.primary_key_name.to_s == name.to_s}.first
  end

  def dom_id(*args)
    model.dom_id('column', name, *args)
  end

  def name_with_table
    "#{model.table_name}.#{name}"
  end

  private

  #
  # @return [ActiveRecord::ConnectionAdapters::Column]
  #   The original column object
  #
  def column_object
    @column
  end

  #
  # @return [ActiveRecord::Base] The original model object
  #
  def original_model
    model.model_class
  end
end