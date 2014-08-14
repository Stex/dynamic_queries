#
# This file adds a method to Rails' route mapper to easily add the
# query generator routes to where-ever the user wants in the system.
#
# If coming from a namespace, the OptionMerger will have already added
# the necessary information about the path and name prefix to the options hash
#
class ActionController::Routing::RouteSet::Mapper
  def dynamic_query_routes(options = {})
    options[:controller] = 'dynamic_queries'

    # Delete a possible namespace as otherwise, the routes would point to
    #   namespace/dynamic_queries_controller
    # instead of just dynamic_queries_controller
    options.delete(:namespace)

    #Save the path prefix if any so we can generate links to our controller later
    DynamicQueries::Configuration.path_prefix options[:path_prefix] if options[:path_prefix]

    options[:member] = {
        :associations           => :get,
        :columns                => :get,
        :query_options          => :get,
        :update_model_positions => :post,
        :add_association        => :post,
        :remove_association     => :post,
        :remove_model           => :post,
        :add_column             => :post,
        :remove_column          => :post,
        :set_column_option      => :post,
        :set_column_order       => :post,
        :new_condition          => :get,
        :edit_condition         => :get,
        :update_condition       => :put,
        :remove_condition       => :post,
        :update_condition_order => :post
    }

    # Generate the actual routes
    self.resources :dynamic_queries, options
  end
end