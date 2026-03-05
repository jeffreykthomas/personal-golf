require 'net/http'
require 'json'

class GolfCourseApiService
  BASE_URL = 'https://api.golfcourseapi.com'.freeze

  def self.configured?
    api_key.present?
  end

  def self.fetch_course_stats(course_name:, location:, force_refresh: false)
    return nil unless configured?

    normalized_name = course_name.to_s.strip
    normalized_location = location.to_s.strip
    cache_key = "golfcourseapi_stats:#{normalized_name.downcase}:#{normalized_location.downcase}"

    service = new(api_key: api_key)
    if force_refresh
      fresh = lookup_course_stats(service, normalized_name, normalized_location)
      Rails.cache.write(cache_key, fresh, expires_in: 6.hours)
      return fresh
    end

    Rails.cache.fetch(cache_key, expires_in: 6.hours) do
      lookup_course_stats(service, normalized_name, normalized_location)
    end
  rescue => e
    Rails.logger.error("GolfCourseAPI fetch failed: #{e.class} - #{e.message}")
    nil
  end

  def self.api_key
    Rails.application.credentials.dig(:golfcourseapi, :api_key) || ENV['GOLFCOURSEAPI_API_KEY']
  end

  def self.city_or_state_from_location(location)
    return nil if location.blank?
    location.split(',').map(&:strip).first
  end

  def self.search_candidates(service, name, location)
    queries = build_search_queries(name, location)
    queries.each do |query|
      next if query.blank?
      results = service.search_courses(query)
      courses = Array(results['courses'])
      return courses if courses.any?
    rescue => e
      Rails.logger.warn("GolfCourseAPI search query failed '#{query}': #{e.class} - #{e.message}")
    end
    []
  end

  def self.build_search_queries(name, location)
    parts = location.to_s.split(',').map(&:strip).reject(&:blank?)
    city = parts[0]
    state = parts[1]

    # Prefer broad/simple queries first so APIs that score relevance loosely still return matches.
    [
      name,
      [name, city].compact.join(' '),
      [name, state].compact.join(' '),
      city,
      [city, state].compact.join(' '),
      location
    ].map { |q| q.to_s.squish }.reject(&:blank?).uniq
  end

  def self.best_match(courses, name, location)
    return nil unless courses.is_a?(Array) && courses.any?

    name_down = name.to_s.downcase
    location_parts = location.to_s.downcase.split(',').map(&:strip).reject(&:blank?)
    location_city = location_parts[0]
    location_state = location_parts[1]

    ranked = courses.map do |course|
      candidate = [course['club_name'], course['course_name']].compact.join(' ').downcase
      candidate_city = course.dig('location', 'city').to_s.downcase
      candidate_state = course.dig('location', 'state').to_s.downcase

      name_penalty = candidate.include?(name_down) ? 0 : 1
      city_penalty = location_city.present? && candidate_city.present? && location_city != candidate_city ? 2 : 0
      state_penalty = location_state.present? && candidate_state.present? && location_state != candidate_state ? 3 : 0
      [course, name_penalty + city_penalty + state_penalty]
    end

    best_course, best_score = ranked.min_by { |(_, score)| score }
    # Avoid obviously wrong matches (e.g., same name but different state/city).
    return nil if best_score >= 3

    best_course
  end

  def self.summarize_course(course)
    return nil unless course.is_a?(Hash)

    data = course['course'].is_a?(Hash) ? course['course'] : course

    male_tees = Array(data.dig('tees', 'male'))
    female_tees = Array(data.dig('tees', 'female'))
    featured_tee = male_tees.first || female_tees.first

    {
      club_name: data['club_name'],
      course_name: data['course_name'],
      location: data['location'],
      hole_stats: extract_hole_stats(featured_tee),
      featured_tee: {
        tee_name: featured_tee&.dig('tee_name'),
        total_yards: featured_tee&.dig('total_yards'),
        par_total: featured_tee&.dig('par_total'),
        course_rating: featured_tee&.dig('course_rating'),
        slope_rating: featured_tee&.dig('slope_rating'),
        number_of_holes: featured_tee&.dig('number_of_holes')
      },
      tee_counts: {
        male: male_tees.size,
        female: female_tees.size
      }
    }
  end

  def self.extract_hole_stats(featured_tee)
    holes = Array(featured_tee&.dig('holes'))
    holes.each_with_index.map do |hole_data, idx|
      {
        number: idx + 1,
        par: hole_data['par'],
        yardage: hole_data['yardage'],
        handicap: hole_data['handicap']
      }
    end
  end

  def initialize(api_key:)
    @api_key = api_key
  end

  def search_courses(search_query)
    get('/v1/search', search_query: search_query)
  end

  def fetch_course(course_id)
    get("/v1/courses/#{course_id}")
  end

  private

  def self.lookup_course_stats(service, normalized_name, normalized_location)
    courses = search_candidates(service, normalized_name, normalized_location)
    chosen = best_match(courses, normalized_name, normalized_location)
    return nil unless chosen && chosen['id']

    details = service.fetch_course(chosen['id'])
    summarize_course(details)
  end

  def get(path, query = {})
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(query) if query.present?

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Key #{@api_key}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    response = http.request(request)
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
