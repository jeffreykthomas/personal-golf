module ApplicationHelper
  def sort_options
    [
      ['Timing (Pre, During, Post)', 'phase'],
      ['Distance from Hole', 'distance'],
      ['Newest First', 'newest'],
      ['Category', 'category']
    ]
  end
end
