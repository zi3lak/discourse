# frozen_string_literal: true

require 'yaml'
require 'zip'

def add_upload(zip_file, upload_or_id_or_url)
  return nil if upload_or_id_or_url.blank?

  if Integer === upload_or_id_or_url
    upload = Upload.find_by(id: upload_or_id_or_url)
  elsif String === upload_or_id_or_url
    upload = Upload.get_from_url(upload_or_id_or_url)
  elsif Upload === upload_or_id_or_url
    upload = upload_or_id_or_url
  end

  if !upload
    STDERR.puts "ERROR: Could not find upload #{upload_or_id_or_url.inspect}"
    return
  end

  file_path = upload.local? ? Discourse.store.path_for(upload) : Discourse.store.download(upload).path
  file_zip_path = File.join('uploads', File.basename(file_path))
  puts "  - Exporting upload #{upload_or_id_or_url} to #{file_zip_path}"
  zip_file.add(file_zip_path, file_path)

  { filename: upload.original_filename, path: file_zip_path }
end

def get_upload(zip_file, zip_upload, opts = {})
  return nil if zip_upload.blank?

  puts "  - Importing upload #{zip_upload['filename']} from #{zip_upload['path']}"
  tempfile = Tempfile.new(zip_upload['filename'], binmode: true)
  tempfile.write(zip_file.get_input_stream(zip_upload['path']).read)
  tempfile.rewind
  UploadCreator.new(tempfile, zip_upload['filename'], opts).create_for(Discourse::SYSTEM_USER_ID)
end

desc 'Exports site data'
task 'data:export', [:zip_path] => :environment do |task, args|
  zip_path = args[:zip_path]
  zip_file = Zip::File.open(zip_path, Zip::File::CREATE)

  puts
  puts "Exporting data to #{zip_path}"
  puts

  puts
  puts "Exporting site settings"
  puts

  settings = {}

  SiteSetting.all_settings(true).each do |site_setting|
    next if site_setting[:default] == site_setting[:value]

    puts "- Site setting #{site_setting[:setting]} -> #{site_setting[:value]}"

    if site_setting[:type] == 'upload'
      settings[site_setting[:setting]] = add_upload(zip_file, site_setting[:value])
    else
      settings[site_setting[:setting]] = site_setting[:value]
    end
  end

  zip_file.get_output_stream('site_settings.json') { |f| f.write(settings.to_json) }

  puts
  puts "Exporting categories"
  puts

  categories = []

  Category.find_each do |category|
    puts "- Category #{category.name} (#{category.slug})"

    categories << {
      name: category.name,
      color: category.color,
      slug: category.slug,
      description: category.description,
      text_color: category.text_color,
      read_restricted: category.read_restricted,
      auto_close_hours: category.auto_close_hours,
      position: category.position,
      email_in: category.email_in,
      email_in_allow_strangers: category.email_in_allow_strangers,
      allow_badges: category.allow_badges,
      auto_close_based_on_last_post: category.auto_close_based_on_last_post,
      topic_template: category.topic_template,
      sort_order: category.sort_order,
      sort_ascending: category.sort_ascending,
      uploaded_logo_id: add_upload(zip_file, category.uploaded_logo_id),
      uploaded_background_id: add_upload(zip_file, category.uploaded_background_id),
      topic_featured_link_allowed: category.topic_featured_link_allowed,
      all_topics_wiki: category.all_topics_wiki,
      show_subcategory_list: category.show_subcategory_list,
      default_view: category.default_view,
      subcategory_list_style: category.subcategory_list_style,
      default_top_period: category.default_top_period,
      mailinglist_mirror: category.mailinglist_mirror,
      minimum_required_tags: category.minimum_required_tags,
      navigate_to_first_post_after_read: category.navigate_to_first_post_after_read,
      search_priority: category.search_priority,
      allow_global_tags: category.allow_global_tags,
      read_only_banner: category.read_only_banner,
      default_list_filter: category.default_list_filter,
      permissions: category.permissions_params,
    }
  end

  zip_file.get_output_stream('categories.json') { |f| f.write(categories.to_json) }

  puts
  puts "Exporting tags"
  puts

  tags = []

  Tag.find_each do |t|
    puts "- Tag #{t.name}"

    tag = { name: t.name }
    tag[:target_tag] = t.target_tag.name if t.target_tag.present?

    tags << tag
  end

  zip_file.get_output_stream('tags.json') { |f| f.write(tags.to_json) }

  puts
  puts "Exporting themes and theme components"
  puts

  themes = []

  Theme.find_each do |theme|
    puts "- Theme #{theme.name}"

    exporter = ThemeStore::ZipExporter.new(theme)
    file_path = exporter.package_filename
    file_zip_path = File.join('themes', File.basename(file_path))
    zip_file.add(file_zip_path, file_path)
    themes << { name: theme.name, filename: File.basename(file_path), path: file_zip_path }
  end

  zip_file.get_output_stream('themes.json') { |f| f.write(themes.to_json) }

  puts
  puts "Exporting theme settings"
  puts

  theme_settings = []

  ThemeSetting.find_each do |theme_setting|
    puts "- Theme setting #{theme_setting.name} -> #{theme_setting.value}"

    value = if theme_setting.data_type == ThemeSetting.types[:upload]
      add_upload(zip_file, theme_setting.value)
    else
      theme_setting.value
    end

    theme_settings << {
      name: theme_setting.name,
      data_type: theme_setting.data_type,
      value: value,
      theme: theme_setting.theme.name,
    }
  end

  zip_file.get_output_stream('theme_settings.json') { |f| f.write(theme_settings.to_json) }

  puts
  puts "Exporting zip file #{zip_path}"
  puts

  zip_file.close
end

task 'data:import', [:zip_path] => :environment do |task, args|
  zip_path = args[:zip_path]
  zip_file = Zip::File.open(zip_path)

  puts
  puts "Importing data from #{zip_path}"
  puts

  puts
  puts "Importing site settings"
  puts

  settings = JSON.parse(zip_file.get_input_stream('site_settings.json').read)
  imported_settings = Set.new

  3.times.each do |try|
    settings.each do |key, value|
      next if imported_settings.include?(key)

      begin
        value = get_upload(zip_file, value, for_site_setting: true) if SiteSetting.type_supervisor.get_type(key) == :upload
        if SiteSetting.public_send(key) != value
          puts "- Site setting #{key} -> #{value}"
          SiteSetting.set_and_log(key, value)
        end

        imported_settings << key
      rescue => e
        STDERR.puts "ERROR: Cannot set #{key} to #{value}" if try == 2
      end
    end
  end

  zip_file.get_output_stream('site_settings.json') { |f| f.write(settings.to_json) }

  puts
  puts "Importing categories"
  puts

  categories = JSON.parse(zip_file.get_input_stream('categories.json').read)

  categories.each do |c|
    puts "- Category #{c['name']} (#{c['slug']})"

    begin
      category = Category.find_or_initialize_by(slug: c.delete('slug'))
      category.user ||= Discourse.system_user
      category.permissions = c.delete('permissions')
      category.update!(c)
    rescue => e
      STDERR.puts "ERROR: Cannot import category: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing tags"
  puts

  tags = JSON.parse(zip_file.get_input_stream('tags.json').read)

  tags.each do |t|
    puts "- Tag #{t['name']}"

    begin
      target_tag = Tag.find_or_create_by!(name: t['target_tag']) if t['target_tag'].present?
    rescue => e
      STDERR.puts "ERROR: Cannot import target tag: #{e.message}"
      puts e.backtrace
    end

    begin
      tag = Tag.find_or_create_by!(name: t['name']).update!(target_tag: target_tag)
    rescue => e
      STDERR.puts "ERROR: Cannot import tag: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing themes and theme components"
  puts

  themes = JSON.parse(zip_file.get_input_stream('themes.json').read)

  themes.each do |t|
    puts "- Theme #{t['name']}"

    tempfile = Tempfile.new(t['filename'], binmode: true)
    tempfile.write(zip_file.get_input_stream(t['path']).read)
    tempfile.flush

    begin
      RemoteTheme.update_zipped_theme(
        tempfile.path,
        t['filename'],
        user: Discourse.system_user,
        theme_id: Theme.find_by(name: t['name'])&.id,
      )
    rescue => e
      STDERR.puts "ERROR: Cannot import theme: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Importing theme settings"
  puts

  theme_settings = JSON.parse(zip_file.get_input_stream('theme_settings.json').read)

  theme_settings.each do |ts|
    puts "- Theme setting #{ts['name']} -> #{ts['value']}"

    begin
      if ts['data_type'] == ThemeSetting.types[:upload]
        ts['value'] = get_upload(zip_file, ts['value'], for_theme: true)
      end

      ThemeSetting
        .find_or_initialize_by(name: ts['name'], theme: Theme.find_by(name: ts['theme']))
        .update!(data_type: ts['data_type'], value: ts['value'])
    rescue => e
      STDERR.puts "ERROR: Cannot import theme setting: #{e.message}"
      puts e.backtrace
    end
  end

  puts
  puts "Done"
  puts

  zip_file.close
end
