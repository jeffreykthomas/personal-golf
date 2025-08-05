# YouTube Integration

The Personal Golf app now supports YouTube video integration in tips, allowing users to include relevant instructional videos alongside their text tips.

## Features

- **YouTube URL Validation**: Automatically validates YouTube URLs using regex patterns
- **Thumbnail Display**: Shows video thumbnails in tip cards and saved tips
- **AI Integration**: Gemini AI can suggest relevant YouTube videos for generated tips
- **Responsive Design**: Thumbnails adapt to different screen sizes and contexts

## Supported URL Formats

The app supports the following YouTube URL formats:

- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`
- `https://www.youtube.com/v/VIDEO_ID`

## Implementation Details

### Database Schema

```ruby
# Migration: AddYoutubeUrlToTips
add_column :tips, :youtube_url, :string
add_index :tips, :youtube_url
```

### Model Methods

The `Tip` model includes several methods for YouTube functionality:

```ruby
# Extract video ID from URL
tip.youtube_video_id
# => "dQw4w9WgXcQ"

# Generate thumbnail URL
tip.youtube_thumbnail_url
# => "https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"

# Check if tip has YouTube video
tip.has_youtube_video?
# => true/false
```

### Validation

YouTube URLs are validated using a regex pattern that ensures:
- Valid YouTube domain
- Correct URL structure
- Valid video ID format (11 characters)

### AI Integration

The Gemini service can now include YouTube URLs in generated tips:

```json
{
  "title": "Perfect Your Putting Stroke",
  "content": "Focus on keeping your head still and following through...",
  "phase": "during_round",
  "youtube_url": "https://www.youtube.com/watch?v=example"
}
```

## UI Components

### Tip Cards

YouTube thumbnails are displayed in:
- Main tip cards (`_swipeable_tip_card.html.erb`)
- Saved tips view (`saved.html.erb`)
- Onboarding first tip (`first_tip.html.erb`)

### Thumbnail Features

- **Hover Effects**: Scale and overlay animations
- **Play Button**: Red YouTube-style play button overlay
- **Fallback Handling**: Graceful degradation if thumbnail fails to load
- **Responsive Sizing**: Different heights for different contexts

## Usage Examples

### Creating a Tip with YouTube URL

```ruby
tip = Tip.create!(
  title: "Improve Your Drive",
  content: "Focus on your stance and grip...",
  youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  user: current_user,
  category: driving_category
)
```

### Displaying in Views

```erb
<% if tip.has_youtube_video? %>
  <div class="youtube-thumbnail">
    <a href="<%= tip.youtube_url %>" target="_blank">
      <img src="<%= tip.youtube_thumbnail_url %>" alt="Video thumbnail">
    </a>
  </div>
<% end %>
```

## Testing

The feature includes comprehensive tests in `test/models/tip_test.rb`:

- URL validation
- Video ID extraction
- Thumbnail URL generation
- Helper method functionality

## Future Enhancements

Potential improvements for the YouTube integration:

- **Video Duration**: Display video length on thumbnails
- **Multiple Videos**: Support for multiple videos per tip
- **Video Preview**: In-app video preview modal
- **Analytics**: Track video engagement metrics
- **Caching**: Cache thumbnail images for better performance