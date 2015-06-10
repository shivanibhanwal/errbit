class Api::V3::NoticesController < ApplicationController
  respond_to :json, :xml

  def index
    binding.pry
    query = {}
    fields = %w{created_at message error_class}

    if params.key?(:start_date) && params.key?(:end_date)
      start_date = Time.parse(params[:start_date]).utc
      end_date = Time.parse(params[:end_date]).utc
      query = {:created_at => {"$lte" => end_date, "$gte" => start_date}}
    end

    results = benchmark("[api/v1/notices_controller] query time") do
      Notice.where(query).with(:consistency => :strong).only(fields).to_a
    end

    respond_to do |format|
      format.any(:html, :json) { render :json => Yajl.dump(results) } # render JSON if no extension specified on path
      format.xml  { render :xml  => results }
    end
  end

  def create
    report = ErrorReport.new(params)
    if report.valid?
      binding.pry
      if report.should_keep?
        report.generate_notice!
        api_xml = report.notice.to_xml(:only => false, :methods => [:id]) do |xml|
         xml.url locate_url(report.notice.id, :host => Errbit::Config.host)
        end
        render :xml => api_xml
      else
        render :text => "Notice for old app version ignored"
      end
    else
      render :text => "Your API key is unknown", :status => 422
    end
  end
  # @notice = Notice.new(
  #     message: @attributes["errors"][0]["message"],
  #     error_class: @attributes["errors"][0]["type"],
  #     backtrace: @attributes["errors"][0]["backtrace"].to_json,
  #     request: {"controller" => @attributes["controller"]},
  #     server_environment: @attributes["context"],
  #     notifier: notifier,
  #     user_attributes: user_attributes,
  #     framework:  @attributes["context"].to_json,
  #   )

  private

  def notice_params
    return @notice_params if @notice_params
    @notice_params = params[:data] || request.raw_post
    if @notice_params.blank?
      raise ParamsError.new('Need a data params in GET or raw post data')
    end
    @notice_params
  end


end
