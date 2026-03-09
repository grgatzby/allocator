class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :data, :analyse ]
  INGESTION_SOURCES = %w[all world_bank imf eurostat oecd].freeze

  def home
    inflation_series = Series.joins(:indicator).where(indicators: { category: "inflation" })
    @stats = {
      countries: Country.count,
      indicators: Indicator.count,
      series: Series.count,
      observations: Observation.count,
      inflation_series: inflation_series.count,
      inflation_observations: Observation.where(series_id: inflation_series.select(:id)).count
    }
    @recent_runs = IngestionRun.includes(:data_source).order(started_at: :desc).limit(10)
  end

  def data
    @countries = Country.order(:name)
    @selected_country = Country.find_by(iso3: params[:country].to_s.upcase) if params[:country].present?
    @limit = normalize_limit(params[:limit])

    if params[:country].present? && @selected_country.nil?
      flash.now[:alert] = "Pays inconnu: #{params[:country]}"
    end

    @observations = Observation.none
    @chart_labels = []
    @chart_datasets = []
    return unless @selected_country

    @observations = Observation.includes(series: [ :country, :indicator, :data_source ])
                               .joins(series: [ :country, :indicator, :data_source ])
                               .where(series: { country_id: @selected_country.id })
                               .order(period_date: :desc)
                               .limit(@limit)

    build_chart_payload(@observations.to_a)
  end

  def run_ingestion
    source = params[:source].to_s
    unless INGESTION_SOURCES.include?(source)
      redirect_to root_path, alert: "Source invalide: #{source}" and return
    end

    if source == "all"
      Ingestion::RunAll.call
    else
      Ingestion::RunSource.call(data_source_code: source)
    end

    redirect_to root_path, notice: "Ingestion #{source} lancee avec succes."
  rescue StandardError => e
    redirect_to root_path, alert: "Echec ingestion #{source}: #{e.message}"
  end

  def delete_run_data
    run = IngestionRun.find(params[:id])
    started_at = run.started_at
    finished_at = run.finished_at || Time.current
    finished_at = started_at if finished_at < started_at

    deleted_rows = Observation.joins(:series)
                              .where(series: { data_source_id: run.data_source_id })
                              .where(ingested_at: started_at..finished_at)
                              .delete_all

    run_id = run.id
    run.destroy!

    redirect_to root_path, notice: "Donnees du run #{run_id} supprimees (#{deleted_rows} observations) et ligne run effacee."
  rescue StandardError => e
    redirect_to root_path, alert: "Echec suppression des donnees du run: #{e.message}"
  end

  def delete_run
    run = IngestionRun.find(params[:id])
    run_id = run.id
    run.destroy!
    redirect_to root_path, notice: "Run #{run_id} supprime."
  rescue StandardError => e
    redirect_to root_path, alert: "Echec suppression run: #{e.message}"
  end

  def run_log
    run = IngestionRun.find(params[:id])
    path = Ingestion::RunSource.log_file_path_for(run.id)
    unless File.exist?(path)
      redirect_to root_path, alert: "Log introuvable pour le run #{run.id}." and return
    end

    @run_log = JSON.parse(File.read(path))
    @run = run

    respond_to do |format|
      format.html
      format.json { render json: @run_log }
    end
  rescue StandardError => e
    redirect_to root_path, alert: "Echec lecture log run: #{e.message}"
  end

  def cleanup_runs
    failed_runs = IngestionRun.where(status: "failed")
    empty_runs = IngestionRun.where(rows_read: 0, rows_written: 0).where.not(status: "running")
    deletable_runs = failed_runs.or(empty_runs)
    deleted_count = deletable_runs.delete_all

    redirect_to root_path, notice: "#{deleted_count} ligne(s) de runs supprimee(s)."
  rescue StandardError => e
    redirect_to root_path, alert: "Echec nettoyage runs: #{e.message}"
  end

  def analyse
    @countries = Country.order(:name)
    @selected_country = Country.find_by(iso3: params[:country].to_s.upcase) if params[:country].present?
    @analysis_points = []

    if params[:country].present? && @selected_country.nil?
      flash.now[:alert] = "Pays inconnu: #{params[:country]}"
      return
    end

    return unless @selected_country

    gdp_observations = Observation.joins(series: :indicator)
                                  .where(series: { country_id: @selected_country.id }, indicators: { code: "NY.GDP.MKTP.KD.ZG" })
                                  .order(:period_date)

    inflation_monthly = Observation.joins(series: :indicator)
                                   .where(series: { country_id: @selected_country.id }, indicators: { code: [ "HICP_YOY", "INFLATION_CPI_YOY", "FP.CPI.TOTL.ZG" ] })
                                   .order(:period_date)

    gdp_by_year = gdp_observations.each_with_object({}) { |obs, memo| memo[obs.period_date.year] = obs.value.to_f }
    inflation_by_year = inflation_monthly.group_by { |obs| obs.period_date.year }
                                         .transform_values { |rows| (rows.sum { |r| r.value.to_f } / rows.size).round(4) }

    years = (gdp_by_year.keys & inflation_by_year.keys).sort
    @analysis_points = years.map do |year|
      { x: gdp_by_year[year], y: inflation_by_year[year], year: year, label: year.to_s }
    end
    @analysis_frequency = "A"
  end

  private

  def normalize_limit(limit_param)
    requested = limit_param.to_i
    requested = 200 if requested <= 0
    [ requested, 1000 ].min
  end

  def build_chart_payload(observations)
    sorted = observations.sort_by(&:period_date)
    @chart_labels = sorted.map { |obs| obs.period_date.to_s }.uniq

    palette = %w[#0d6efd #198754 #dc3545 #ffc107 #6f42c1 #20c997 #fd7e14 #0dcaf0]
    grouped = sorted.group_by do |obs|
      indicator = obs.series.indicator
      indicator_name = indicator.name.presence || indicator.code
      {
        code: indicator.code,
        name: indicator_name
      }
    end

    @chart_datasets = grouped.each_with_index.map do |(indicator, rows), idx|
      values_by_date = rows.each_with_object({}) do |obs, memo|
        memo[obs.period_date.to_s] = obs.value.to_f
      end

      color = palette[idx % palette.size]
      y_axis_id = indicator[:code] == "FX_USD" ? "yFx" : "y"
      color = "#343a40" if indicator[:code] == "FX_USD"
      connect_points = [ "NY.GDP.MKTP.KD.ZG", "FP.CPI.TOTL.ZG", "INFLATION_CPI_YOY" ].include?(indicator[:code])
      {
        label: indicator[:name],
        data: @chart_labels.map { |date| values_by_date[date] },
        yAxisID: y_axis_id,
        borderColor: color,
        backgroundColor: color,
        fill: false,
        tension: 0.2,
        spanGaps: connect_points
      }
    end
  end
end
