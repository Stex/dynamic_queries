class DynamicQueries::Association
  unloadable if Rails.env.development?

  def initialize(model_proxy, association)
    @model_proxy = model_proxy
    @association = association
  end

  delegate :macro, :name, :collection?, :primary_key_name, :association_foreign_key, :to => :association

  #
  # @return [DynamicQueries::Model] The model proxy this association belongs to
  #
  def model
    @model_proxy
  end

  #
  # @return [DynamicQueries::Model, NilClass]
  #   The model class this association is pointing to
  #
  #   Returns +nil+ if either the association is not valid or
  #   the association is of an unknown reflection type.
  #
  def end_point
    #Check if the association is valid. If not, we don't have to bother with it further.
    return nil unless valid?

    #Find the end point class based on the reflection object
    #If it's an unknown reflection object (who knows...), return +nil+
    case @association.class.to_s
      when 'ActiveRecord::Reflection::ThroughReflection', 'ActiveRecord::Reflection::AssociationReflection'
        DynamicQueries::DataCache.models[@association.klass.to_s]
      else
        Rails.logger.error "Unknown reflection type: #{@association.class.to_s}"
        nil
    end
  end

  #
  # Uses Rails' internal mechanisms to check if the inverse association
  # and/or the correct columns in the through model (for has_X :through associations)
  # can be determined.
  #
  # As this will not automatically check whether the association might
  # direct to a non-existing model (possible typos etc),
  # we also check if the model name can be constantized.
  #
  # Please note that polymorphic associations are marked as "invalid" here as well,
  # even if they are technically valid. This is due to the fact that we cannot
  # determine a real end point class if the other part might be every model.
  #
  def valid?
    return false if polymorphic?

    begin
      @association.check_validity!
      @association.class_name.constantize
      true
    rescue Exception => e
      DynamicQueries::DataCache.log_erroneous_association(self, e.message)
      false
    end
  end

  def inspect
    "#{macro} #{name.inspect}"
  end

  def dom_id(*args)
    model.dom_id('association', name, *args)
  end

  #
  # Returns a database diagram representation of the association's macro
  # TODO: let someone check if that's correct, I can never remember what's written when
  #
  def macro_string
    case macro
      when :has_one    then '1..1'
      when :belongs_to then '1..'
      when :has_many   then '1..n'
      when :has_and_belongs_to_many then 'n..n'
      else '?'
    end
  end

  private

  #
  # @return [Boolean] +true+ if this association is the non-polymorphic part of the binding
  #
  # This is e.g. the case for
  #   belongs_to :something, :polymorphic => true
  #
  def polymorphic?
    @association.options[:polymorphic]
  end

  #
  # @return [ActiveRecord::Reflection::MacroReflection]
  #   The original reflection object
  #
  def association
    @association
  end
end