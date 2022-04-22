# frozen_string_literal: true

class Project
  include ActiveModel::Model
  include ActiveModel::Validations

  class << self
    def all
      return [] unless dataroot.directory? && dataroot.executable? && dataroot.readable?

      dataroot.children.map do |d|
        Project.from_directory(d)
      rescue StandardError => e
        Rails.logger.warn("Didn't create project. #{e.message}")
        nil
      end.compact
    end

    def find(project_path)
      from_directory(dataroot.join(project_path))
    end

    def dataroot
      OodAppkit.dataroot.join('projects').tap do |path|
        path.mkpath unless path.exist?
      rescue StandardError => e
        Pathname.new('')
      end
    end

    def from_directory(full_path)
      return nil unless full_path.directory? && full_path.executable? && full_path.readable?

      Project.new({project_directory: full_path.basename})
    end
  end
  
  attr_reader :dir
  delegate :icon, :name, :description, to: :manifest

  def initialize(attributes = {})
    @dir = attributes.delete(:project_directory) || attributes[:name].to_s.downcase.tr_s(' ', '_')
    @manifest = Manifest.new(attributes).merge(Manifest.load(manifest_path))
  end
 
  # @params [Hash] 
  # @return [Bool]
  def save(attributes)
    make_dir
    update(attributes)
  end

  # @params [Hash] 
  # @return [Bool]
  def update(attributes)
    # only have side effects in update
    new_manifest = manifest.merge(attributes)

    if new_manifest.valid?
      if new_manifest.save(manifest_path)
        true
      else
        errors.add(:update, "Cannot save manifest to #{manifest_path}")
        false
      end  
    else
      errors.add(:update, "Cannot not save an invalid manifest.")
      Rails.logger.debug("did not update invalid manfest.")
      false
    end
  end

  def destroy!
    FileUtils.remove_dir(project_dataroot, force = true)
  end

  def configuration_directory
    project_dataroot.join('.ondemand')
  end

  def project_dataroot
    Project.dataroot.join(dir)
  end

  def title
    name.titleize
  end

  def manifest_path
    configuration_directory.join('manifest.yml')
  end

  private 

  attr_reader :manifest

  def make_dir
    begin
      project_dataroot.mkpath unless project_dataroot.exist?
      configuration_directory.mkpath unless configuration_directory.exist?
    rescue => e
      errors.add(:make_directory, "failed to make directory: #{e.message}")
    end
  end
end
