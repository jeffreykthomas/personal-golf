# Performance & Deployment Fixes

## Issues Identified

### 1. 503 Errors & WebSocket Failures

- **Root Cause #1**: **PORT/PERMISSION ISSUES**
  - Initially: Fly.io trying to connect to port 3000, but Thruster on port 80
  - Then: Permission denied - non-root user can't bind to port 80 (privileged port)
  - App not reachable by fly-proxy
  - No listening sockets on expected port
- **Root Cause #2**: Insufficient memory (256MB) + machine auto-suspension + slow health checks
- **Symptoms**:
  - Pages taking 60+ seconds to load
  - Health checks timing out (5s timeout, 30s grace period)
  - Proxy errors: `[PR04] could not find a good candidate within 20 attempts`
  - WebSocket connections failing when machines are suspended
  - WARNING: "The app is not listening on the expected address"

### 2. Database Query Performance

- **N+1 Queries**: Multiple unoptimized queries in hole view
- **Ruby-side filtering**: Image content type filtering done in Ruby instead of SQL
- **Repeated queries**: Category lookup on every request
- **Missing preloads**: Related data not eager-loaded

### 3. Active Storage Performance

- **Slow URL generation**: Generating signed URLs for Tigris storage
- **Excessive image loading**: Loading all images then filtering

## Fixes Applied

### Infrastructure (fly.toml)

**Critical Port Fix - Use Non-Privileged Port:**

```toml
# PROBLEM 1: Port mismatch (3000 vs 80)
# PROBLEM 2: Permission denied - port 80 requires root (ports < 1024 are privileged)
# Error: Permission denied - bind(2) for "0.0.0.0" port 80 (Errno::EACCES)

# BEFORE - Complex setup with Thruster proxy
internal_port = 3000
[env]
  PORT = '3000'
Dockerfile: CMD ["./bin/thrust", "./bin/rails", "server"]

# AFTER - Direct Puma on non-privileged port 8080
internal_port = 8080
[env]
  PORT = '8080'  # Non-privileged port (>1024) that non-root user can bind to
Dockerfile: EXPOSE 8080
Dockerfile: CMD ["./bin/rails", "server"]
```

**Memory & Health Checks:**

```toml
# BEFORE
memory = '256mb'
min_machines_running = 0
timeout = '5s'
grace_period = '30s'

# AFTER
memory = '1gb'                # Increased to 1GB for better performance and headroom
min_machines_running = 1      # Keep 1 machine running to avoid cold starts
timeout = '10s'               # Increased timeout for slow Tigris responses
grace_period = '60s'          # More startup time
```

**Puma Binding:**

```ruby
# config/puma.rb - CHANGED
# Before: port ENV.fetch("PORT", 3000)
# After:
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"  # Bind to all interfaces
# Now with PORT=8080, Puma binds to 0.0.0.0:8080 ✅
```

**Why Port 8080?**

- Ports < 1024 (like 80) are "privileged ports" requiring root access
- Docker runs app as non-root user (UID 1000) for security
- Port 8080 is non-privileged (>1024) so non-root user can bind to it
- Fly.io proxy still listens on 80/443 externally, forwards to 8080 internally

**Why Bypass Thruster?**

- Thruster added complexity without clear benefit for this deployment
- Direct Puma → Fly.io proxy is simpler and more debuggable
- Reduces moving parts and potential configuration issues
- Still performant for this app size

### Database Optimizations (app/models/hole.rb)

1. **SQL-level filtering** for image content types:

   ```ruby
   # BEFORE: Load all, filter in Ruby
   images = images.select { |img| img.image.blob&.content_type.to_s.start_with?("image/") }

   # AFTER: Filter in database
   .joins(image_attachment: :blob)
   .where("active_storage_blobs.content_type LIKE ?", "image/%")
   ```

2. **Optimized exists? checks**:
   ```ruby
   # BEFORE: stylized.exists? then query again
   # AFTER: Use efficient count with limit(1)
   stylized_count = hole_images.ready.stylized
                               .joins(image_attachment: :blob)
                               .where("active_storage_blobs.content_type LIKE ?", "image/%")
                               .limit(1).count
   ```

### Controller Optimizations (app/controllers/courses_controller.rb)

1. **Category caching** (static data):

   ```ruby
   course_tip_category = Rails.cache.fetch('category_course_tip', expires_in: 1.hour) do
     Category.find_by(slug: 'course-tip')
   end
   ```

2. **Preload associations**:

   ```ruby
   # Hole tees for stats tab
   @hole = @course.holes.includes(:hole_tees).find_by!(number: params[:number])

   # Recent images for media tab
   @recent_hole_images = @hole.hole_images
                              .order(created_at: :desc)
                              .limit(8)
                              .includes(image_attachment: :blob, hole: :course)
   ```

3. **Cache max hole number**:
   ```ruby
   @max_hole_number = @course.holes.maximum(:number) || 18
   ```

### View Optimizations (app/views/courses/hole.html.erb)

1. **Limit image swiper to 6 images**:

   ```ruby
   # BEFORE: Load all images, filter, then take 6
   images.select { |i| i.image.attached? }.first(6).map { |i| url_for(i.image) }

   # AFTER: Limit query to 6
   @hole.images_for_display.limit(6).to_a.map { |i| url_for(i.image) }
   ```

2. **Use preloaded images**:

   ```ruby
   # BEFORE: @hole.hole_images.order(created_at: :desc).limit(8)
   # AFTER: @recent_hole_images (preloaded in controller)
   ```

3. **Use cached max hole number**:
   ```ruby
   # BEFORE: @course.holes.maximum(:number).to_i
   # AFTER: @max_hole_number
   ```

## Expected Performance Improvements

### Query Reduction

- **Before**: ~38 queries taking 7500ms
- **After**: ~15-20 queries taking <500ms (estimated)

### Page Load Time

- **Before**: 60+ seconds (with health check failures)
- **After**: 2-5 seconds (estimated)

### Memory Usage

- **Before**: 256MB (hitting limits)
- **After**: 1GB (plenty of headroom for spikes and concurrent requests)

### Reliability

- **Before**: Frequent 503 errors due to suspended machines
- **After**: 1 machine always running, faster health checks pass

## Deployment

When ready to deploy:

```bash
cd /Users/jeffreythomas/Documents/personal-golf

# Verify changes
git status

# Deploy to Fly.io
fly deploy

# Monitor deployment
fly logs -f

# Check status
fly status
```

## Monitoring

After deployment, monitor:

1. Health check status: `fly status`
2. Memory usage: `fly dashboard` → Metrics
3. Response times in logs: `fly logs -n`
4. WebSocket connections: Check browser console

## Additional Recommendations

### For Future Optimization

1. **CDN for Active Storage**: Consider CloudFront or Cloudflare R2 proxy for faster asset delivery
2. **Image optimization**: Resize images before storage to reduce transfer size
3. **Fragment caching**: Cache rendered hole partials
4. **Database indices**: Add indices on frequently queried columns
5. **Redis caching**: Use Redis for Rails.cache instead of solid_cache for better performance

### Cost Considerations

- 1GB machine on Fly.io: Provides excellent performance with room to grow
- Keeping 1 machine running: No cold start delays but uses more hours
- Consider scaling to 0 during off-hours if needed to save resources
