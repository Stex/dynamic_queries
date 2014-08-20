#
# This file generates the main controller class for manipulating dynamic queries.
# It will automatically let it inherit from the parent class set in the plugin's configuration
#

class DynamicQueriesController < DynamicQueries::Configuration.parent_controller
  unloadable if Rails.env.development?

  before_filter :load_query, :except => [:index, :new, :create]

  helper_method :dq_url, :dqt

  if DynamicQueries::Configuration.layout
    layout DynamicQueries::Configuration.layout
  end

  def index
    @queries = DynamicQueries::Query.all

    respond_to do |format|
      format.html
    end
  end

  def show
    page = params[:page] || 1

    respond_to do |format|
      format.html {
        unless @query.valid_sql?
          flash[:error] = dqt('show.invalid_sql')
          flash.keep
          redirect_to :back and return
        end

        if @query.sufficient_variables?(params[:variables])
          @result_set = @query.execute(:variables => params[:variables], :page => page, :per_page => 30, :custom_order => params[:order_by])
        end
      }
      format.csv {
        if @query.sufficient_variables?(params[:variables])
          @result_set = @query.execute(:variables => params[:variables], :custom_order => params[:order_by])
          render :text => @result_set.to_csv
        else
          render :text => 'Insufficient Variable Assignment!'
        end
      }
    end
  end

  def edit
    respond_to do |format|
      format.html {render :action => :new}
    end
  end

  def update
    respond_to do |format|
      format.html {
        if @query.update_attributes(params[:dynamic_queries_query])
          redirect_to dq_url(:associations, @query)
        else
          render :action => :new
        end
      }
    end
  end

  def destroy
    if @query.destroy
      flash[:success] = dqt('destroy.flash.success')
    else
      flash[:error] = dqt('destroy.flash.error')
    end

    flash.keep

    respond_to do |format|
      format.html { redirect_to dq_url }
    end
  end

  #
  # First step in the query creation step. It lets the user choose
  # the main model which is the core of the new query
  #
  def new
    @query = DynamicQueries::Query.new

    respond_to do |format|
      format.html
    end
  end

  #
  # Creates a new query record. Note that this is not part
  # of the creation wizard, it is just used to save the progress
  # on a new query.
  #
  # Once the query is saved, the user is redirected to the next
  # wizard step.
  #
  def create
    @query = DynamicQueries::Query.new(params[:dynamic_queries_query])

    respond_to do |format|
      format.html {
        if @query.save
          redirect_to dq_url(:associations, @query)
        else
          render :action => :new
        end
      }
    end
  end

  #----------------------------------------------------------------
  #                    Step 2 : Associations
  #----------------------------------------------------------------

  #
  # Second step in the query creation process
  # Lets the user choose the associations between the models from step 1
  #
  def associations
    respond_to do |format|
      format.html
    end
  end

  #
  # Saves the model box positions after one of them
  # was dragged to a new position in the canvas
  #
  def update_model_positions
    @query.set_model_positions(params[:key], params[:positions])
    @query.save

    respond_to do |format|
      format.js {render :nothing => true}
    end
  end
  
  #
  # Adds a association between two models to the current query.
  # If its end point was not part of the query yet, the model
  # is added as well.
  #
  def add_association
    @association, @added_model = @query.add_association!(params[:model_name], params[:association])

    respond_to do |format|
      format.js { render 'dynamic_queries/associations/add_association' }
    end
  end

  #
  # Removes the given association(chain) from the query
  #
  def remove_association
    @result = @query.remove_association!(params[:model_name], params[:association])

    respond_to do |format|
      format.js { render 'dynamic_queries/associations/remove_association' }
    end
  end

  def remove_model
    @model = @query.remove_model!(params[:model_name])

    respond_to do |format|
      format.js { render 'dynamic_queries/associations/remove_model' }
    end
  end

  #----------------------------------------------------------------
  #                    Step 3: Column selection
  #----------------------------------------------------------------

  def columns
    respond_to do |format|
      format.html
    end
  end

  #
  # Adds a new QueryColumn object to the current query
  # Expects the param keys +:model_name+ and +:column_name+ to be set.
  #
  def add_column
    @step         = 'columns'
    @query_column = @query.add_column!(params[:model_name], params[:column_name])

    respond_to do |format|
      format.js { render 'dynamic_queries/columns/toggle_column' }
    end
  end

  #
  # Removes a QueryColumn from the current query
  # Expects the param key +:column_identifier+ to be set.
  #
  def remove_column
    @step         = 'columns'
    @query_column = @query.remove_column!(params[:column_identifier])

    respond_to do |format|
      format.js { render 'dynamic_queries/columns/toggle_column' }
    end
  end

  #----------------------------------------------------------------
  #                     Step 4: Query Options
  #----------------------------------------------------------------

  def query_options
    respond_to do |format|
      format.html
    end
  end

  #
  # Sets the given column option to the given value
  #
  def set_column_option
    @column = @query.set_column_option!(params[:column_identifier], params[:option_name], params[:value])

    respond_to do |format|
      format.js {render 'dynamic_queries/query_options/set_column_option'}
    end
  end

  #
  # Updates the column order for the SELECT and ORDER BY clauses
  #
  def set_column_order
    @query.update_column_order!(params[:order_type], params[:order])

    respond_to do |format|
      format.js {render 'dynamic_queries/query_options/set_column_order'}
    end
  end

  def new_condition
    @condition = @query_column.build_condition

    respond_to do |format|
      format.js {render 'dynamic_queries/query_options/new_condition'}
    end
  end

  def edit_condition
    @condition = @query_column.condition_by_identifier(params[:condition_identifier])

    respond_to do |format|
      format.js {render 'dynamic_queries/query_options/new_condition'}
    end
  end

  #
  # Updates (or creates) a query column condition
  # Expects the following params to be set: +:column_identifier+ and +:condition_identifier+
  #
  def update_condition
    @result    = @query.update_condition!(params[:column_identifier], params[:condition_identifier], params[:dynamic_queries_condition])
    @condition = @query_column.condition_by_identifier(params[:condition_identifier])

    respond_to do |format|
      format.js {render 'dynamic_queries/query_options/update_condition'}
    end
  end
  
  #
  # Removes a condition from the query
  # Expects the following params to be set: +:column_identifier+ and +:condition_identifier+
  #
  def remove_condition
    @query.remove_condition!(params[:column_identifier], params[:condition_identifier])

    respond_to do |format|
      format.js {render 'dynamic_queries/query_options/remove_condition'}
    end
  end

  #
  # Actually sets the conditions for the query from the given identifiers, connectors and parenthesis
  #
  def update_condition_order
    @result = @query.update_conditions_order!(params[:order])

    respond_to do |format|
      format.js {render 'dynamic_queries/query_options/update_condition_order'}
    end
  end

  private

  def load_query
    @query        = DynamicQueries::Query.find(params[:id])
    @query_column = @query.query_column(params[:column_identifier]) if params[:column_identifier].present?
  end

  #
  # Generates a URL to an action within this controller.
  # The correct namespace is automatically inserted.
  #
  # @param [String, Symbol] action
  #   The action to be linked to, e.g. :new
  #
  # @param [Hash] args
  #   Optional parameters for the URL, e.g. {:foo => :bar}
  #
  # @example Creating a link to the new action
  #   link_to 'New', dq_url(:new)
  #
  # Note that the url_for([]) variant isn't used as it would expect
  # the records to be in the form dynamic_queries_query instead of just dynamic_query
  #
  def dq_url(action = nil, *args)
    ending = if action.to_s == 'new' || args.first.is_a?(DynamicQueries::Query)
               :dynamic_query
             else
               :dynamic_queries
             end
    method = [action, DynamicQueries::Configuration.path_prefix, ending, 'path'].compact.join('_')
    send(method, *args)
  end

  #
  # @return [String] A I18n translation for the given
  #   dot path. It automatically sets the scope to 'dynamic_queries',
  #   so the host application's locales are ignored.
  #
  # @see I18n#translate
  #
  def dqt(dot_path, args = {})
    args[:scope] = 'dynamic_queries'
    I18n.t(dot_path, args).try_html_safe
  end
end