module NavigationHelper
  def app_shell_title
    life_mode? ? "Personal Life" : "Personal Golf"
  end

  def app_home_path
    life_mode? ? self_understanding_report_path : tips_path
  end

  def header_shortcut_path
    life_mode? ? self_understanding_report_path : saved_tips_path
  end

  def header_shortcut_label
    life_mode? ? "Self-understanding report" : "Saved tips"
  end

  def header_shortcut_badge_count
    return 0 unless golf_mode?

    current_user.saved_tip_items.count
  end

  def bottom_nav_items(coach_enabled:)
    [
      {
        kind: :link,
        label: "Home",
        path: tips_path,
        active: controller_name == "tips" && action_name == "index",
        icon: :home
      },
      {
        kind: :link,
        label: life_mode? ? "Self" : "Saved",
        path: life_mode? ? self_understanding_report_path : saved_tips_path,
        active: life_mode? ? controller_name == "self_understanding_reports" : controller_name == "tips" && action_name == "saved",
        icon: life_mode? ? :self_report : :saved
      },
      {
        kind: :coach,
        label: "Coach",
        enabled: coach_enabled,
        icon: :coach
      },
      {
        kind: :link,
        label: life_mode? ? "Learning" : "Courses",
        path: life_mode? ? learning_path : courses_path,
        active: life_mode? ? learning_controller_active? : controller_name == "courses",
        icon: life_mode? ? :learning : :courses
      },
      {
        kind: :link,
        label: "Browse",
        path: categories_path,
        active: controller_name == "categories",
        icon: :browse
      }
    ]
  end

  def nav_icon(name, classes: "w-5 h-5")
    svg = case name
          when :home
            %(<svg class="#{classes}" fill="currentColor" viewBox="0 0 20 20"><path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z"/></svg>)
          when :saved
            %(<svg class="#{classes}" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/></svg>)
          when :self_report
            %(<svg class="#{classes}" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3l1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8L12 3z"/><path stroke-linecap="round" stroke-linejoin="round" d="M18 14l.9 2.1L21 17l-2.1.9L18 20l-.9-2.1L15 17l2.1-.9L18 14z"/><path stroke-linecap="round" stroke-linejoin="round" d="M6 14l.9 2.1L9 17l-2.1.9L6 20l-.9-2.1L3 17l2.1-.9L6 14z"/></svg>)
          when :coach
            %(<svg class="#{classes}" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>)
          when :courses
            %(<svg class="#{classes}" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M3 21V3l6 3 6-3 6 3v18l-6-3-6 3-6-3z"/></svg>)
          when :learning
            %(<svg class="#{classes}" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6.5A2.5 2.5 0 016.5 4H20v14H6.5A2.5 2.5 0 004 20.5V6.5z"/><path stroke-linecap="round" stroke-linejoin="round" d="M6.5 4H18v16H6.5A2.5 2.5 0 014 17.5"/></svg>)
          when :browse
            %(<svg class="#{classes}" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/></svg>)
          else
            ""
          end

    svg.html_safe
  end

  private

  def learning_controller_active?
    controller_name == "learning" || controller_name.start_with?("learning_")
  end
end
