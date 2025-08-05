# Golf Tips Sample Data

This directory contains YAML files with golf tips organized by category and skill level.

## File Structure

- `tips.yml` - Core tips for all categories and skill levels
- `tips_advanced.yml` - Advanced tips for experienced players
- `tips_template.yml` - Template for creating new tip files

## Adding More Tips

### Option 1: Add to Existing Files

Edit `tips.yml` or `tips_advanced.yml` to add more tips to existing categories.

### Option 2: Create New Files

1. Copy `tips_template.yml`
2. Rename it (e.g., `tips_putting_mastery.yml`)
3. Add your tips following the YAML structure
4. Update `db/seeds.rb` to include your new file in the `tip_files` array

### Option 3: Category-Specific Files

Create files like:

- `tips_driving_distance.yml`
- `tips_putting_mastery.yml`
- `tips_short_game_secrets.yml`
- `tips_mental_game_pro.yml`

## YAML Structure

```yaml
category_slug:
  - title: 'Tip Title'
    content: 'Detailed tip content'
    phase: 'pre_round|during_round|post_round'
    skill_level: 'beginner|intermediate|advanced'
```

## Available Categories

- `basics` → Basics
- `driving` → Driving
- `putting` → Putting
- `short_game` → Short Game
- `mental_game` → Mental Game
- `course_management` → Course Management
- `practice` → Practice

## Phases (REQUIRED - only these 3 values)

- `pre_round` - Before playing (warm-up, strategy, practice)
- `during_round` - On-course tips and techniques
- `post_round` - After-round analysis and improvement

## Skill Levels

- `beginner` - New to golf or struggling with basics
- `intermediate` - Has fundamentals but improving consistency
- `advanced` - Experienced players looking to fine-tune

## Best Practices for Hundreds of Tips

1. **Organize by theme** - Create focused files (e.g., `tips_bunker_play.yml`)
2. **Balance skill levels** - Ensure good distribution across beginner/intermediate/advanced
3. **Vary phases** - Include pre-round, during-round, and post-round tips
4. **Keep titles concise** - 5-50 characters work best
5. **Make content actionable** - Specific, practical advice users can immediately apply
6. **Test regularly** - Run `rails db:seed` to ensure YAML is valid

## Scaling Strategies

For 500+ tips, consider:

- **Automated content generation** from golf instruction books/articles
- **Community contributions** - Allow users to submit tips
- **Professional partnerships** - License content from golf instructors
- **AI assistance** - Generate variations of proven tips
- **Import tools** - Build CSV/JSON importers for bulk uploads
