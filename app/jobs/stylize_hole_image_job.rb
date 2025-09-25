class StylizeHoleImageJob < ApplicationJob
  queue_as :ai_generation

  def perform(hole_id, original_image_id = nil)
    hole = Hole.find(hole_id)
    original = original_image_id && HoleImage.find_by(id: original_image_id)
    source_attachment = original&.image&.attached? ? original.image : hole.layout_image
    return unless source_attachment&.attached?

    Rails.logger.info "Stylizing hole image for hole #{hole.id}"

    begin
      hole.update!(stylization_status: 'processing', stylization_error: nil) if hole.respond_to?(:stylization_status)
      io = source_attachment.download
      input_type = source_attachment.content_type || 'image/png'
      styled_io = GeminiService.stylize_course_image(io, seed: hole.course.style_seed, input_mime_type: input_type)
      if styled_io
        if original
          styled = hole.hole_images.create!(
            user: original.user,
            kind: 'stylized',
            status: 'ready',
            source_image: original
          )
          styled.image.attach(io: StringIO.new(styled_io), filename: "styled.png", content_type: 'image/png')
          original.update!(status: 'ready') if original.status != 'ready'
          hole.update!(stylization_status: 'ready', stylization_error: nil) if hole.respond_to?(:stylization_status)
          Rails.logger.info "Attached stylized HoleImage #{styled.id} for hole #{hole.id}"
        else
          filename = hole.layout_image.filename.base + "_stylized.png"
          hole.stylized_layout_image.attach(
            io: StringIO.new(styled_io),
            filename: filename,
            content_type: 'image/png'
          )
          hole.update!(stylization_status: 'ready') if hole.respond_to?(:stylization_status)
          Rails.logger.info "Attached stylized image for hole #{hole.id}"
        end
      else
        hole.update!(stylization_status: 'failed', stylization_error: 'No data returned') if hole.respond_to?(:stylization_status)
        Rails.logger.warn "Stylization returned nil for hole #{hole.id}"
      end
    rescue => e
      hole.update!(stylization_status: 'failed', stylization_error: e.message) if hole.respond_to?(:stylization_status)
      original.update!(status: 'failed', error_message: e.message) if original
      Rails.logger.error "StylizeHoleImageJob failed: #{e.class} - #{e.message}"
    end
  end
end


