# frozen_string_literal: true


class Project
  include ActiveModel::Model

  class << self
    def all
      # return [Array] of all projects in ~/ondemand/data/sys/projects
      return [] unless dataroot.directory? && dataroot.executable? && dataroot.readable?

      dataroot.children.map do |d|
        Project.new({ :dir => d.basename })
      rescue StandardError => e
        Rails.logger.warn("Didn't create project. #{e.message}")
        nil
      end.compact
    end

    def find(project_path)
      full_path = dataroot.join(project_path)
      return nil unless full_path.directory?

      Project.new({ dir: full_path })
    end

    def dataroot
      Rails.logger.debug("project path is: #{OodAppkit.dataroot.join('projects')}")

      OodAppkit.dataroot.join('projects').tap do |path|
        Rails.logger.debug("tap dataroot running on path = #{path}")
        p.mkpath unless p.exist?
      rescue StandardError => e
        Pathname.new('')
      end
    end
  end

  validates :dir, presence: true
  validates :dir, format: {
    with: /[\w-]+\z/,
    message: 'Name may only contain letters, digits, dashes, and underscores'
  }

  attr_reader :dir
  delegate :icon, :title, :description, to: :manifest

  def initialize(attributes = {})
    @dir            = attributes.fetch(:dir, nil).to_s
  end

  def save!
    make_manifest
    write_manifest
  end

  def update(attributes)
    manifest = Manifest.load(manifest_path)
    manifest = manifest.merge(attributes)
    manifest.valid? ? manifest.save(manifest_path) : false
  end

  def destroy!
    FileUtils.remove_dir(project_dataroot, force = true)
  end

  def make_manifest
    File.new(manifest_path, 'w+') # try this: unless Dir.pwd != Project.dataroot
  end
  
  def manifest_path
    File.join(configuration_directory, 'manifest.yml')
  end

  def configuration_directory
    Pathname.new("#{project_dataroot}/.ondemand").tap { |path| path.mkpath unless path.exist? } 
  end

  def project_dataroot
    Project.dataroot.join(dir)
  end

  def manifest
    @manifest ||= Manifest.load(manifest_path)
  end

  def metadata
    manifest.metadata
  end

  def title
    manifest.metadata[:title]
  end

  def description
    manifest.description
  end

  def name
    proj = dir.scan(/[\w-]+\z/)
    proj[0].titleize
  end

  def write_manifest
    manifest = Manifest.load(manifest_path)
    manifest = manifest.merge({ title: title, description: description, icon: icon })
    manifest.save(manifest_path)
  end
end
