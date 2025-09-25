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

  desc "Export HoleImage attachments and metadata (default: db/sample_data/hole_images)"
  task :export_hole_images, [:output_dir] => :environment do |_, args|
    require "yaml"
    require "fileutils"

    output_dir = args[:output_dir].presence || Rails.root.join("db", "sample_data", "hole_images").to_s
    files_dir = File.join(output_dir, "files")
    FileUtils.mkdir_p(files_dir)

    images = HoleImage.includes(image_attachment: :blob).where.not(image_attachment: { id: nil })
    puts "Exporting #{images.count} HoleImage records..."

    manifest = { "images" => [] }

    images.find_each do |img|
      blob = img.image&.blob
      next unless blob

      # Only supported on Disk service (development)
      if ActiveStorage::Blob.service.respond_to?(:path_for)
        src_path = ActiveStorage::Blob.service.path_for(blob.key)
      else
        src_path = ActiveStorage::Blob.service.send(:path_for, blob.key)
      end

      ext = File.extname(blob.filename.to_s)
      basename = "#{blob.key}#{ext.presence || ''}"
      dest_path = File.join(files_dir, basename)
      FileUtils.cp(src_path, dest_path)

      course = img.hole.course
      manifest["images"] << {
        "course_name" => course.name,
        "course_location" => course.location,
        "hole_number" => img.hole.number,
        "kind" => img.kind,
        "status" => img.status,
        "original_filename" => blob.filename.to_s,
        "content_type" => blob.content_type,
        "byte_size" => blob.byte_size,
        "file" => basename
      }
    end

    manifest_path = File.join(output_dir, "manifest.yml")
    File.write(manifest_path, manifest.to_yaml)
    puts "✅ Exported #{manifest["images"].size} images to #{output_dir} (manifest.yml + files/)"
  end

  desc "Import HoleImage attachments from manifest (default: db/sample_data/hole_images)"
  task :import_hole_images, [:owner_email, :input_dir] => :environment do |_, args|
    require "yaml"
    require "fileutils"

    input_dir = args[:input_dir].presence || Rails.root.join("db", "sample_data", "hole_images").to_s
    manifest_path = File.join(input_dir, "manifest.yml")
    files_dir = File.join(input_dir, "files")
    unless File.exist?(manifest_path)
      puts "⚠️  HoleImage manifest not found: #{manifest_path}"
      next
    end

    owner_email = args[:owner_email].presence || ENV["IMPORT_OWNER_EMAIL"].presence
    owner = if owner_email.present?
      User.find_by(email_address: owner_email) || User.first
    else
      User.first
    end
    raise "No user found to own imported images" unless owner

    data = YAML.load_file(manifest_path)
    images = data.is_a?(Hash) ? (data["images"] || []) : []
    imported = 0

    images.each do |entry|
      course = Course.find_by(name: entry["course_name"], location: entry["course_location"])
      next unless course
      hole = course.holes.find_by(number: entry["hole_number"])
      next unless hole

      file_path = File.join(files_dir, entry["file"])
      next unless File.exist?(file_path)

      hi = HoleImage.new(
        hole: hole,
        user: owner,
        kind: entry["kind"].presence || "original",
        status: "ready"
      )
      hi.image.attach(io: File.open(file_path, "rb"), filename: entry["original_filename"], content_type: entry["content_type"]) 
      hi.save!
      imported += 1
    end

    puts "✅ Imported #{imported} HoleImage records from #{input_dir}"
  end
end


