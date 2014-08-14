module DynamicQueries::Concerns::Models
  unloadable if Rails.env.development?

  #
  # The main model which is the start of a possible join chain.
  # This is due to the way active record works.
  #
  # @return [DynamicQueries::Model] a model proxy representing the query's main model
  #
  def main_model
    main_model_name && model_proxy(main_model_name)
  end

  def main_model?(model)
    main_model == model
  end

  #
  # @return [Array<DynamicQueries::Model>]
  #   model proxies representing all models which are part of the query
  #
  def models
    model_names.map {|m| DynamicQueries::DataCache.models[m]}
  end

  #
  # @param [String, ActiveRecord::Base, DynamicQueries::Model] model_or_name
  #   Anything, that to_s'd results in a valid model classname
  #
  # @return [Boolean] +true+ if the given model is managed by this query
  #
  def includes_model?(model_or_name)
    model_names.include?(model_or_name.to_s)
  end

  #
  # Adds a new model to the managed models array
  #
  # @param [String, ActiveRecord::Base, DynamicQueries::Model] model
  #   Anything, that to_s'd results in a valid model classname
  #
  # @return [DynamicQueries::Model] the newly added model proxy
  #
  def add_model(model)
    model_names << model.to_s
    DynamicQueries::DataCache.models[model.to_s]
  end

  #
  # @return [Boolean, DynamicQueries::Model]
  #   +false+ if the model wasn't found or not part of the query
  #   the model proxy if the model was successfully removed from the query
  #
  # Removing the model will also remove all associations to and from it
  # (and all associations from models previously connected after it in the join chain)
  #
  # Columns are not removed in this action, they are automatically removed for
  # non-query-models as after_save callback (see #remove_abandoned_columns)
  #
  def remove_model(model_name)
    model = model_proxy(model_name)

    if model && models.include?(model)
      #First, see if there is an association coming to this model.
      #If yes, remove it.
      #If not, it wasn't part of the association chain at all
      #and we can simply remove it.
      associations.values.flatten.each do |association|
        if association.end_point == model
          remove_association(association.model, association.name)
          break
        end
      end

      #Delete the model from the query
      model_names.delete(model.to_s)

      #Remove the model position
      model_positions.delete(model.name)

      return model
    end

    false
  end

  #
  # Removes the given model and saves the query
  # @see #remove_model
  #
  def remove_model!(model_name)
    res = remove_model(model_name)
    res && save ? res : false
  end

  #
  # Sets the model names managed by this query
  #
  def model_names=(new_model_names)
    self.model_names_array = new_model_names.map(&:to_s)
  end

  #
  # Names of the models managed by this query
  #
  def model_names
    self.model_names_array ||= []
  end

  #
  # @return [Hash]
  #   Model box positions in the format
  #     {model_name => {:top => x, :left => y}}
  #
  def model_positions
    self.model_positions_hash ||= {}
  end

  #
  # Sets the model positions after a model box
  # was dragged to a new position within the canvas
  #
  def model_positions=(new_positions)
    new_positions.each do |model_name, (top, left)|
      model_positions[model_name.classify] = {:top => top.to_i, :left => left.to_i}
    end
  end

  #
  # @return [Boolean] +true+ if the given model is part of the join chain
  #
  def joined_model?(model_name)
    model = model_proxy(model_name)
    main_model?(model) || association_targets.include?(model)
  end

  #
  # @return [Array<DynamicQueries::Model>]
  #   All model which are part of the query, but not part of the join chain
  #
  def stand_alone_models
    models - association_targets - [main_model]
  end

end