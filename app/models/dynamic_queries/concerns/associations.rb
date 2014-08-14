module DynamicQueries::Concerns::Associations
  unloadable if Rails.env.development?

  #
  # @return [Hash] mapping of model proxies to association proxies
  #   {DynamicQueries::Model => [DynamicQueries::Association]}
  #
  def associations
    unless @associations
      @associations = {}
      self.associations_hash ||= {}
      associations_hash.map do |model_name, association_names|
        model = model_proxy(model_name)
        @associations[model] ||= []

        association_names.each do |association_name|
          @associations[model] << model.association_by_name(association_name)
        end
      end
    end

    @associations
  end

  #
  # @return [Boolean] +true+ if there are associations with the given model as source
  #
  def model_associations?(model_name)
    model = model_proxy(model_name)
    associations[model] && associations[model].any?
  end

  #
  # Adds a given association to the query
  #
  # @param [String] model_name
  #   The source model's name
  #
  # @param [String] association_name
  #   The association's name. Has to be a valid association in the source model
  #
  # @return [Array<DynamicQueries::Association, DynamicQueries::Model>]
  #   First array element is the newly added association,
  #   second array element is the added model (if any).
  #   The association's end point is added to the query if it wasn't part of it before.
  #
  def add_association(model_name, association_name)
    model  = model_proxy(model_name)
    result = []

    if model
      #check if the association name is valid
      if association = model.association_by_name(association_name)
        result << association

        #Add the association's end point if it is not yet part of the models
        unless models.include?(association.end_point)
          result << add_model(association.end_point)
        end

        self.associations_hash ||= {}
        associations_hash[model.to_s] ||= []
        associations_hash[model.to_s] << association.name.to_s
        @associations        = nil
        @association_targets = nil
      end
    end

    result
  end

  #
  # Adds the given association to the query and saves the query
  # @see #add_association
  #
  def add_association!(model_name, association_name)
    res = add_association(model_name, association_name)
    res && save ? res : false
  end

  #
  # @return [Array<DynamicQueries::Model>]
  #   All models which are part of the join chain
  #
  def association_targets
    @association_targets ||= associations.values.flatten.map {|a| a.end_point }
  end

  #
  # @param [DynamicQueries::Association] association
  #   The association to be checked
  #
  # @return [Boolean] +true+ if the query contains this association
  #
  def has_association?(association)
    (associations[association.model] || []).include?(association)
  end

  #
  # @see #remove_association
  # Only difference is, that the query is saved after removing the association
  #
  def remove_association!(*args)
    remove_association(*args) && save
  end

  #
  # Removes an association from the query.
  # As each model may have at most 1 incoming connection,
  # we can remove all connections from end points before deleting this association.
  # This has to be done as a chain to remove all remaining links
  #
  # @return [Boolean] +true+ if the association was removed,
  #   +false+ if either the model or association wasn't found
  #
  def remove_association(model_name, association_name)
    model = model_proxy(model_name)

    if model && models.include?(model)
      association = model.association_by_name(association_name)

      if association && associations[model].include?(association)
        remove_all_associations(association.end_point)

        #Remove the actual association
        associations_hash[model.to_s].delete(association.name.to_s)
        associations_hash.delete(model.to_s) if associations_hash[model.to_s].empty?

        @associations = nil
        @association_targets = nil
        return true
      end
    end

    false
  end

  #
  # Removes all outgoing associations from the given model
  # and continues the chain with all its end points
  #
  def remove_all_associations(model)
    #If there are no associations for the model, we can return
    return unless associations[model]

    #Otherwise, remove all outgoing associations
    associations[model].each do |association|
      remove_all_associations(association.end_point)
      associations_hash[model.to_s] = []
    end
  end

  #
  # Checks whether the given association may be added to the
  # query. This is the case if all of the following conditions are met:
  #
  #  - The target may not be the main model
  #  - The association's target may not be hit by another association yet
  #  - There may not be an association in the opposite direction yet
  #
  def available_association?(association)
    !main_model?(association.end_point) &&
        !joined_model?(association.end_point) &&
        (associations[association.end_point] || []).none? {|a| a.end_point == association.model}
  end

  #
  # Generates a join/include chain for the given model
  #
  def joins_for(model_name, pretty = true)
    model  = model_proxy(model_name)
    result = []

    if model_associations?(model)
      associations[model].each do |association|
        #First case: The end point is not an end of the association chain
        #In this case, we have to go deeper.
        if model_associations?(association.end_point)
          result << {association.name => joins_for(association.end_point)}
        else
          #Otherwise, we can just add the association and continue
          result << association.name
        end
      end
    end

    #If there is only one association, we don't have to return an array, just the association
    result.size == 1 && pretty ? result.first : result
  end

  #
  # Builds a join chain from the query's associations.
  # It is in a structure .find() (resp. .all or .first) will accept
  #
  def join_chain(pretty = true)
    joins_for(main_model, pretty)
  end

  private

  #
  # Builds an INNER JOIN string based on the chosen associations
  # This is done using ActiveRecord's internal mechanisms which are
  # also used by .find().
  #
  def inner_joins_string
    sql = ''
    main_model.model_class.__send__(:add_joins!, sql, join_chain(false))
    sql
  end

  #
  # Builds a string containing the association chain AND stand-alone models
  # This string may be passed to ActiveRecord's .find() method using the :joins
  #
  # Stand-alone models are models which are not part of the join chain.
  # They are added to the query using CROSS JOINs
  #
  # TODO: Maybe the user should have to option to create custom LEFT/INNER joins in the way conditions are made
  #       Currently, these cross joins may however already be manipulated through the conditions.
  #
  def joins_string
    #Get the automatically generated joins from the association chain
    str = inner_joins_string

    stand_alone_models.each do |model|
      str << " CROSS JOIN \"#{model.table_name}\" "
    end

    '   ' << str.strip << '   '
  end

  def joins?
    joins_string.strip.present?
  end

end