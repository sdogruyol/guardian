require "./guardian/*"
require "yaml"
require "option_parser"
require "colorize"

module Guardian

  class WatcherYML
    YAML.mapping({
      files: String,
      run: String
    })
  end

  class Watcher

    setter files

    def initialize

      if ARGV.includes? "init"
        init_yml_files
        exit 0
      end

      file = "./.guardian.yml"

      @runners = {} of String => Array(String)
      @timestamps = {} of String => String

      @watchers = [] of WatcherYML

      if File.exists? file
        YAML.load_all(File.read(file)).each do |yaml|
          @watchers << WatcherYML.from_yaml(yaml.to_yaml)
        end
      else
        puts "#{".guardian.yml".colorize(:red)} does not exists!"
        exit 1
      end

      collect_files
      start_watching
    end

    def start_watching
      puts "💂  #{"Guardian is on duty!".colorize(:green)}"
      loop do
        watch
        sleep 1
      end
    end

    def file_creation_date(file : String)
      File.stat(file).mtime.to_s("%Y%m%d%H%M%S")
    end

    def collect_files
      @runners = {} of String => Array(String)
      @timestamps = {} of String => String

      @watchers.each do |watcher|
        Dir.glob(watcher.files) do |file|
          unless File.executable? file
            @timestamps[file] = file_creation_date(file)

            unless @runners.has_key? file
              @runners[file] = [watcher.run]
            else
              @runners[file] << watcher.run
            end
          end
        end
      end
    end

    def run_tasks(file)
      @runners[file].each do |command|
        command = command.gsub(/%file%/, file)
        puts "#{"$".colorize(:dark_gray)} #{command.colorize(:dark_gray)}"
        output = `#{command}`
        output.lines.each do |line|
          puts "#{">".colorize(:dark_gray)}    #{line.gsub(/\n$/, "").colorize(:dark_gray)}"
        end
      end
    end

    def watch
      @timestamps.each do |file, file_time|
        begin
          check_time = file_creation_date(file)
          if check_time != file_time
            if File.directory? file
              puts "#{"+".colorize(:green)} #{file}/"
            else
              puts "#{"±".colorize(:yellow)} #{file}"
            end
            run_tasks file
            collect_files
          end
        rescue
          puts "#{"-".colorize(:red)} #{file}"
          run_tasks file
          collect_files
        end
      end
    end

    def init_yml_files
      file = nil
      files = Dir.glob("./src/*.cr")
      if files.size > 0
        file = files.first
      end
      if file && File.exists? file
        puts "Created #{".guardian.yml".colorize(:green)} of #{file.colorize(:green)}"
        File.write "./.guardian.yml", <<-YAML
files: ./**/*.cr
run: crystal build #{file}
---
files: ./shard.yml
run: crystal deps
YAML
      else
        puts "Created #{".guardian.yml".colorize(:green)}"
        File.write "./.guardian.yml", <<-YAML
files: ./**/*
run: echo "File is changed %file%"
YAML
      end
    end

  end
end

Guardian::Watcher.new
