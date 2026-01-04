#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/rishizamvar/Desktop/CalmMind/CalmMind.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find targets
main_target = project.targets.find { |t| t.name == 'CalmMind' }
test_target = project.targets.find { |t| t.name == 'CalmMindTests' }
ui_test_target = project.targets.find { |t| t.name == 'CalmMindUITests' }

puts "Found targets:"
puts "  Main: #{main_target&.name}"
puts "  Tests: #{test_target&.name}"
puts "  UI Tests: #{ui_test_target&.name}"

# Helper to find or create group
def find_or_create_group(parent, name)
  group = parent.groups.find { |g| g.name == name }
  group ||= parent.new_group(name)
  group
end

# Add files to main target
main_group = project.main_group['CalmMind']
if main_group
  # App group - add AppEnvironment.swift
  app_group = find_or_create_group(main_group, 'App')
  app_env = '/Users/rishizamvar/Desktop/CalmMind/CalmMind/App/AppEnvironment.swift'
  unless app_group.files.any? { |f| f.real_path.to_s == app_env }
    file_ref = app_group.new_file(app_env)
    main_target.add_file_references([file_ref])
    puts "Added: AppEnvironment.swift"
  end

  # Services/Protocols group
  services_group = find_or_create_group(main_group, 'Services')
  protocols_group = find_or_create_group(services_group, 'Protocols')

  protocol_files = [
    '/Users/rishizamvar/Desktop/CalmMind/CalmMind/Services/Protocols/ClockProtocol.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMind/Services/Protocols/PromptCacheProtocol.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMind/Services/Protocols/PromptServiceProtocol.swift'
  ]

  protocol_files.each do |path|
    unless protocols_group.files.any? { |f| f.real_path.to_s == path }
      file_ref = protocols_group.new_file(path)
      main_target.add_file_references([file_ref])
      puts "Added: #{File.basename(path)}"
    end
  end
end

# Add files to test target
tests_group = project.main_group['CalmMindTests']
if tests_group && test_target
  # Mocks
  mocks_group = find_or_create_group(tests_group, 'Mocks')
  mock_files = [
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Mocks/MockClock.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Mocks/MockPromptCache.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Mocks/MockPromptService.swift'
  ]

  mock_files.each do |path|
    unless mocks_group.files.any? { |f| f.real_path.to_s == path }
      file_ref = mocks_group.new_file(path)
      test_target.add_file_references([file_ref])
      puts "Added: #{File.basename(path)}"
    end
  end

  # Helpers
  helpers_group = find_or_create_group(tests_group, 'Helpers')
  helper_files = [
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Helpers/TestCalendar.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Helpers/TodoItemTestFactory.swift'
  ]

  helper_files.each do |path|
    unless helpers_group.files.any? { |f| f.real_path.to_s == path }
      file_ref = helpers_group.new_file(path)
      test_target.add_file_references([file_ref])
      puts "Added: #{File.basename(path)}"
    end
  end

  # Unit/Design
  unit_group = find_or_create_group(tests_group, 'Unit')
  design_group = find_or_create_group(unit_group, 'Design')
  design_files = [
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Unit/Design/DesignTokensTests.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Unit/Design/WarmCopyTests.swift'
  ]

  design_files.each do |path|
    unless design_group.files.any? { |f| f.real_path.to_s == path }
      file_ref = design_group.new_file(path)
      test_target.add_file_references([file_ref])
      puts "Added: #{File.basename(path)}"
    end
  end

  # Unit/Components
  components_group = find_or_create_group(unit_group, 'Components')
  components_files = [
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindTests/Unit/Components/PriorityTodosCardTests.swift'
  ]

  components_files.each do |path|
    unless components_group.files.any? { |f| f.real_path.to_s == path }
      file_ref = components_group.new_file(path)
      test_target.add_file_references([file_ref])
      puts "Added: #{File.basename(path)}"
    end
  end
end

# Add files to UI test target
ui_tests_group = project.main_group['CalmMindUITests']
if ui_tests_group && ui_test_target
  ui_test_files = [
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindUITests/UsabilitySmokeUITests.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindUITests/HomeScreenUITests.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindUITests/NavigationUITests.swift',
    '/Users/rishizamvar/Desktop/CalmMind/CalmMindUITests/DarkModeSmokeUITests.swift'
  ]

  ui_test_files.each do |path|
    unless ui_tests_group.files.any? { |f| f.real_path.to_s == path }
      file_ref = ui_tests_group.new_file(path)
      ui_test_target.add_file_references([file_ref])
      puts "Added: #{File.basename(path)}"
    end
  end
end

project.save
puts "\nProject saved successfully!"
