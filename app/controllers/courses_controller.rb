class CoursesController < ApplicationController
  # Removed forced onboarding - users can navigate freely
  before_action :set_course, only: [:show, :hole, :update_hole, :create_hole_tee, :update_hole_tee, :destroy_hole_tee, :upload_layout, :vote_image, :redo_stylization, :destroy_hole_image, :destroy, :generate_holes]
  before_action :set_hole, only: [:hole, :update_hole, :upload_layout]

  def index
    @courses = Course.order(:name)
  end

  def new
    @course = Course.new
  end

  def create
    # Check duplicates by case-insensitive name+location
    normalized_name = params.dig(:course, :name).to_s.strip
    normalized_location = params.dig(:course, :location).to_s.strip
    existing = Course.where('LOWER(name) = ? AND LOWER(location) = ?', normalized_name.downcase, normalized_location.downcase).first
    if existing
      redirect_to course_path(existing), alert: 'That course already exists for this location.'
      return
    end

    @course = Course.new(course_params)
    num_holes = params.dig(:course, :num_holes).to_i
    num_holes = 18 if num_holes <= 0
    num_holes = 18 unless [9, 18].include?(num_holes)

    ActiveRecord::Base.transaction do
      if @course.save
        (1..num_holes).each do |n|
          @course.holes.create!(number: n)
        end
        redirect_to @course, notice: "Course created with #{num_holes} holes."
      else
        raise ActiveRecord::Rollback
      end
    end

    unless @course.persisted?
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @holes = @course.holes.order(:number)
  end

  def hole
    @display_image = @hole.select_image_for_display
    
    # Find category with caching since it's static data
    course_tip_category = Rails.cache.fetch('category_course_tip', expires_in: 1.hour) do
      Category.find_by(slug: 'course-tip')
    end
    
    # Show ALL tips for this hole (except dismissed ones)
    dismissed_tip_ids = current_user.dismissed_tip_items.pluck(:id)
    @hole_tips = if course_tip_category
                   Tip.where(category_id: course_tip_category.id)
                      .where(course_id: @course.id, hole_number: @hole.number)
                      .where.not(id: dismissed_tip_ids)
                      .includes(:user)
                      .order(created_at: :desc)
                 else
                   Tip.none
                 end
    
    # Get saved tips for this hole specifically (for UI state)
    @saved_tips = current_user.saved_tip_items
                      .where(id: @hole_tips.pluck(:id))
    
    # Cache max hole number to avoid query in view
    @max_hole_number = @course.holes.maximum(:number) || 18
    
    # Preload recent hole images to avoid N+1 queries in media tab
    @recent_hole_images = @hole.hole_images
                               .order(created_at: :desc)
                               .limit(8)
                               .includes(image_attachment: :blob, hole: :course)
    
    @hole_image_stream = "hole_#{@hole.id}_images"
    @hole_flash_stream = "hole_#{@hole.id}_flash"
  end

  def vote_image
    @hole = @course.holes.find_by!(number: params[:number])
    image = @hole.hole_images.find(params[:image_id])
    vote = image.hole_image_votes.find_or_initialize_by(user: current_user)
    vote.value = params[:value].to_i == -1 ? -1 : 1
    vote.save!
    redirect_to hole_course_path(@course, number: @hole.number)
  end

  def redo_stylization
    @hole = @course.holes.find_by!(number: params[:number])
    image = @hole.hole_images.find(params[:image_id])
    # Only allow the uploader to redo
    if image.user_id == current_user.id
      StylizeHoleImageJob.perform_later(@hole.id, image.id)
      image.update!(status: 'processing')
      redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), notice: 'Redo requested.'
    else
      redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), alert: 'You can only redo your own uploads.'
    end
  end

  def destroy_hole_image
    @hole = @course.holes.find_by!(number: params[:number])
    image = @hole.hole_images.find(params[:image_id])
    if image.user_id != current_user.id
      redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), alert: 'You can only delete your own uploads.'
      return
    end

    # Destroy derived images owned by the same user (if any) to avoid orphans
    @hole.hole_images.where(source_image_id: image.id).find_each do |derived|
      begin
        derived.image.purge_later if derived.image.attached?
      rescue => _e
        # ignore purge errors, still destroy record
      end
      derived.destroy
    end

    begin
      image.image.purge_later if image.image.attached?
    rescue => _e
      # ignore purge errors, still destroy record
    end
    image.destroy

    redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), notice: 'Image deleted.'
  end

  def upload_layout
    if params[:layout_image].present?
      uploaded = params[:layout_image]
      content_type = uploaded.content_type.to_s

      if content_type.start_with?('video/')
        # Enforce 10MB max for videos
        if uploaded.size.to_i > 10.megabytes
          redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), alert: 'Video must be 10MB or smaller.'
          return
        end
        # Videos: no stylization. Show placeholder, then attach and mark ready.
        original = @hole.hole_images.create!(
          user: current_user,
          kind: 'original',
          status: 'processing'
        )
        original.image.attach(uploaded)
        original.update!(status: 'ready')
        redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), notice: 'Video uploaded.'
      else
        # Images: go through stylization pipeline
        original = @hole.hole_images.create!(
          user: current_user,
          kind: 'original',
          status: 'processing'
        )
        original.image.attach(uploaded)
        StylizeHoleImageJob.perform_later(@hole.id, original.id)
        redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), notice: 'Layout image uploaded and is processing…'
      end
    else
      redirect_to hole_course_path(@course, number: @hole.number, tab: 'media'), alert: 'Please choose a file to upload.'
    end
  end

  def update_hole
    if @hole.update(hole_params)
      redirect_to hole_course_path(@course, number: @hole.number), notice: 'Hole updated.'
    else
      redirect_to hole_course_path(@course, number: @hole.number), alert: @hole.errors.full_messages.to_sentence
    end
  end

  def create_hole_tee
    hole = @course.holes.find_by!(number: params[:number])
    tee = hole.hole_tees.new(hole_tee_params)
    if tee.save
      redirect_to hole_course_path(@course, number: hole.number), notice: 'Tee added.'
    else
      redirect_to hole_course_path(@course, number: hole.number), alert: tee.errors.full_messages.to_sentence
    end
  end

  def update_hole_tee
    hole = @course.holes.find_by!(number: params[:number])
    tee = hole.hole_tees.find(params[:tee_id])
    if tee.update(hole_tee_params)
      redirect_to hole_course_path(@course, number: hole.number), notice: 'Tee updated.'
    else
      redirect_to hole_course_path(@course, number: hole.number), alert: tee.errors.full_messages.to_sentence
    end
  end

  def destroy_hole_tee
    hole = @course.holes.find_by!(number: params[:number])
    tee = hole.hole_tees.find(params[:tee_id])
    tee.destroy
    redirect_to hole_course_path(@course, number: hole.number), notice: 'Tee removed.'
  end

  def generate_holes
    count = params[:num_holes].to_i
    count = 18 if count <= 0
    count = 18 unless [9, 18].include?(count)

    missing_numbers = (1..count).to_a - @course.holes.pluck(:number)
    if missing_numbers.empty?
      redirect_to @course, notice: 'All requested holes already exist.'
      return
    end

    ActiveRecord::Base.transaction do
      missing_numbers.sort.each do |n|
        @course.holes.create!(number: n)
      end
    end
    redirect_to @course, notice: "Added #{missing_numbers.size} holes (up to #{count})."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @course, alert: "Failed to add holes: #{e.record.errors.full_messages.to_sentence}"
  end

  def destroy
    @course.destroy
    redirect_to courses_path, notice: 'Course deleted.'
  end

  private

  # Removed - onboarding is now optional
  # def ensure_onboarding_completed
  #   unless current_user.onboarding_completed?
  #     redirect_to onboarding_welcome_path, notice: "Please complete onboarding first."
  #   end
  # end

  def set_course
    @course = Course.find(params[:id])
  end

  def set_hole
    # Preload hole_tees to avoid N+1 queries in the stats tab
    @hole = @course.holes.includes(:hole_tees).find_by!(number: params[:number])
  end

  def course_params
    params.require(:course).permit(:name, :location, :description)
  end

  def hole_params
    params.require(:hole).permit(:par, :yardage)
  end

  def hole_tee_params
    params.require(:hole_tee).permit(:name, :color, :yardage)
  end
end


