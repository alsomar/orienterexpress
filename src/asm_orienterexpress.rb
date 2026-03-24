require "json"
require "sketchup"

module ASM_Extensions
  module OrienterExpress

    unless file_loaded?(__FILE__)
      # Resolve extension paths
      file   = __FILE__.dup.force_encoding('UTF-8')
      dir    = __dir__.dup.force_encoding('UTF-8')
      EXT_ID  = File.basename(file, ".*")
      EXT_DIR = File.join(dir, EXT_ID)
      loader  = File.join(EXT_DIR, "bootstrap")
      info    = File.join(EXT_DIR, "extension.json")

      # Read extension metadata
      EXTENSION = JSON.parse(File.read(info), symbolize_names: true).freeze
      EXT_NAME  = EXTENSION[:name].to_s

      # Register extension
      @ext = SketchupExtension.new(EXT_NAME, loader)
      @ext.version     = EXTENSION[:version].to_s
      @ext.description = EXTENSION[:description].to_s
      @ext.creator     = EXTENSION[:creator].to_s
      @ext.copyright   = EXTENSION[:copyright].to_s

      Sketchup.register_extension(@ext, true)
      file_loaded(__FILE__)
    end

    def self.extension
      @ext
    end

  end # module OrienterExpress
end # module ASM_Extensions
