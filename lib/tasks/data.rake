namespace :data do
  desc "Export courses and holes to YAML (default: db/sample_data/courses.yml)"
  task :export_courses, [:output_path] => :environment do |_, args|
    require "yaml"

    output_path = args[:output_path].presence || Rails.root.join("db", "sample_data", "courses.yml").to_s

    courses_data = Course.includes(:holes).order(:name).map do |course|
      {
        "name" => course.name,
        "location" => course.location,
        "description" => course.description,
        "holes" => course.holes.order(:number).map do |h|
          {
            "number" => h.number,
            "par" => h.par,
            "yardage" => h.yardage
          }
        end
      }
    end

    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, { "courses" => courses_data }.to_yaml)
    puts "✅ Exported #{courses_data.size} courses to #{output_path}"
  end

  desc "Import courses and holes from YAML (default: db/sample_data/courses.yml)"
  task :import_courses, [:input_path] => :environment do |_, args|
    require "yaml"

    input_path = args[:input_path].presence || Rails.root.join("db", "sample_data", "courses.yml").to_s
    unless File.exist?(input_path)
      puts "⚠️  File not found: #{input_path}"
      next
    end

    payload = YAML.load_file(input_path)
    courses_array = payload.is_a?(Hash) ? (payload["courses"] || payload[:courses] || []) : payload

    created_or_updated = 0
    courses_array.each do |c|
      name = c["name"] || c[:name]
      location = c["location"] || c[:location]
      description = c["description"] || c[:description]

      course = Course.find_or_initialize_by(name: name.to_s.strip, location: location.to_s.strip)
      course.description = description if description.present?
      course.save! if course.changed?

      (c["holes"] || c[:holes] || []).each do |h|
        number = h["number"] || h[:number]
        hole = course.holes.find_or_initialize_by(number: number)
        hole.par = h["par"] || h[:par]
        hole.yardage = h["yardage"] || h[:yardage]
        hole.save! if hole.changed?
      end

      created_or_updated += 1
    end

    puts "✅ Imported #{created_or_updated} courses from #{input_path}"
  end
end


