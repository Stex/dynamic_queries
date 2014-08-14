class DynamicQueries::Configuration
  include Singleton

  DEFAULT_CONFIGURATION = {
      :parent_controller => 'ApplicationController',
      :layout            => nil,
      :path_prefix       => nil,
      :user_class        => nil,
      :excluded_models   => [],
      :cancan            => false
  }

  #
  # Bulk sets the plugin configuration.
  #
  # @example Setting the configuration in an initializer
  #   DynamicQueries::Configuration.set do
  #     parent_controller Admin::ApplicationController
  #     layout            'plain_layout'
  #   end
  #
  # Available options:
  #
  #   [String, ActionController::Base] parent_controller (ApplicationController)
  #     The controller which the DynamicQueries controller will inherit from.
  #     This is particularly useful if you want to restrict access to it
  #     altogether through a namespace filter. If you only need a certain namespace
  #     in the routes, you don't have to set it and can just add the
  #     dynamic query routes in the correct namespace in config/routes.rb
  #
  #   [String] layout (nil)
  #     If given, the dynamic_queries controller will use the given layout.
  #     Otherwise, it will use the parent controller's layout
  #
  #   [String, ActiveRecord::Base] user_class (nil)
  #     If given, the system will automatically set the creator and updater
  #     of a dynamic query using the given class. As it can't be taken for certain
  #     that such a model exists, it has to be set manually through the configuration.
  #
  #   [Array<Class>] excluded_models ([])
  #     Classes which are not taken into account by the plugin, meaning
  #     that they will not appear in the query generator and will not be indexed
  #     by the data cache.
  #     Please note that DynamicQueries::Query will never be available
  #
  #   [Boolean] cancan (false)
  #     If set to +true+, the plugin will try to authorize its queries
  #     using the cancan gem.
  #
  def self.set(&proc)
    instance.instance_eval(&proc)
  end

  #----------------------------------------------------------------
  #                    Configuration Methods
  #----------------------------------------------------------------

  def parent_controller(new_parent = nil)
    if new_parent
      configuration[:parent_controller] = new_parent.to_s.classify
    else
      configuration[:parent_controller].constantize
    end
  end

  def layout(new_layout = nil)
    if new_layout
      configuration[:layout] = new_layout.to_s
    else
      configuration[:layout]
    end
  end

  def user_class(new_user_class = nil)
    if new_user_class
      configuration[:user_class] = new_user_class.to_s.classify
    else
      configuration[:user_class].try(:constantize)
    end
  end

  def excluded_models(new_models = nil)
    if new_models
      configuration[:excluded_models] = Array(new_models).map {|m| m.to_s.classify}
    else
      configuration[:excluded_models].map {|m| m.constantize}
    end
  end

  def cancan(new_bool = nil)
    if new_bool.present?
      configuration[:cancan] = new_bool
    else
      !!configuration[:cancan]
    end
  end

  #
  # Option not to be set manually by the developer
  # It is set automatically when the routes are drawn, so we
  # know to which namespace we have to point links going
  # to actions within the dynamic_queries controller
  #
  def path_prefix(new_path_prefix = nil)
    if new_path_prefix
      configuration[:path_prefix] = new_path_prefix
    else
      configuration[:path_prefix]
    end
  end

  private

  #
  # Forward unknown methods to the instance
  #
  def self.method_missing(method, *args)
    self.instance.send(method, *args)
  end

  def configuration
    @configuration ||= DEFAULT_CONFIGURATION
  end
end