require 'xcodeproj'

# Get project path and target name from command line arguments
project_path = ARGV[0]
target_name = ARGV[1]

unless project_path && target_name
  puts "Usage: ruby set_xcconfig_base_configs.rb <path_to_xcodeproj> <target_name>"
  exit 1
end

begin
  project = Xcodeproj::Project.open(project_path)
rescue => e
  puts "Error opening Xcode project at #{project_path}: #{e.message}"
  exit 1
end

target = project.targets.find { |t| t.name == target_name }

unless target
  puts "Error: Target '#{target_name}' not found in project #{project_path}."
  exit 1
end

puts "Setting base configurations for target '#{target_name}' in #{project_path}..."

target.build_configurations.each do |config|
  # Construct the expected path for the Pods-generated xcconfig file
  pods_xcconfig_path = "Pods/Target Support Files/Pods-#{target_name}/Pods-#{target_name}.#{config.name.downcase}.xcconfig"

  # Find or create the file reference for the Pods xcconfig
  # It's important to find it by path, as it might already exist from a previous pod install
  xcconfig_file_ref = project.files.find { |f| f.path == pods_xcconfig_path }

  unless xcconfig_file_ref
    # If the file reference doesn't exist, create it.
    # This might happen if pod install hasn't run yet, or if the project was just created.
    # We add it to the main group, but its primary purpose is to be referenced by baseConfigurationReference.
    xcconfig_file_ref = project.main_group.new_file(pods_xcconfig_path)
    puts "Created new file reference for #{pods_xcconfig_path}"
  end

  # Set the baseConfigurationReference
  config.base_configuration_reference = xcconfig_file_ref
  puts "  - Set '#{config.name}' base configuration to #{pods_xcconfig_path}"
end

project.save
puts "✅ Base configurations successfully updated in Xcode project."
