module ASM_Extensions
  module OrienterExpress

    def self.init_config
      Sketchup.require "asm_orienterexpress/config/debug"
      Sketchup.require "asm_orienterexpress/config/paths"
      Sketchup.require "asm_orienterexpress/config/environment"
      Sketchup.require "asm_orienterexpress/config/settings"
      true
    end

  end # module OrienterExpress
end # module ASM_Extensions

ASM_Extensions::OrienterExpress.init_config
